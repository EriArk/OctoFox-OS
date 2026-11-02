# Qt avatar cards

## Live avatar scene

`AvatarScene.h/.cpp` and `AvatarView3D.qml` provide a shared live presenter,
independent of Home care state. They consume the full, host-resolved SDK GLB,
including the selected wardrobe, skeletal clips and signed sparse morph deltas.
The approved source model is not rewritten. The neutral portrait path below
remains useful for static cards.

Build with C++20, AUTOMOC and Qt Core/Gui/Qml/Quick/Quick3D/Concurrent. Register `AvatarScene`
and `AvatarView3D.qml` in the `TrainerOS` QML module (see the standalone example
in `tests/home-companion-preview`). Link matching Qt Quick 3D runtime plugins.
Use a descriptor already verified by the host or `AvatarCards`; `source` is a
trusted local file URL, not an arbitrary downloaded model or a network address.

```qml
AvatarView3D {
    source: verifiedFullModel
    running: sceneVisible
    actions: descriptor.actions
    action: "sit"
    clipPosition: 0.5 // -1 plays; 0..1 samples a normalized clip position
    expression: "content"
    face: ({})       // optional named facial control weights, 0..1
    pose: ({})       // optional bone-local Euler offsets in degrees
}
```

The host owns camera, lights and identity lifetime. `ready`, `error`,
`vertexCount`, `supportsExpression(name)` and `supportsAction(name)` describe
the current instance. `sockets["hand.R"]`, `sockets["hand.L"]` and `sockets.head`
provide avatar-local position/quaternion pairs for attachments. Parent the prop
to the same avatar node and apply the socket transform plus a prop-specific
grip offset. Prop scale, contact and action timing belong to the consuming scene.

File/accessor/morph parsing runs in a worker. `source` initially clears the old
model; observe `ready`/`error` for completion. Qt geometry is created only on the
GUI thread. Each source change advances a generation fence: a late result cannot
restore a revoked or replaced identity. This also applies when the scene is
destroyed during loading. Do not synchronously wait for readiness from QML.

Expressions and additional poses interpolate; setting `running=false` stops
automatic updates and freezes clip time. Explicit changes while stopped sample
the requested state. Settled static poses do not rebuild geometry. Mesh-list
notifications are separate from pose changes, so animation does not recreate
QML materials/delegates. `clearIdentity()` removes geometry, sockets and transient
face/action state. On account revocation clear the old instance before resolving
another identity. Inactive hosts may unload the scene entirely.

This first Qt implementation evaluates morphs and skinning on CPU at up to 24 Hz.
It supports the current pack's LINEAR/STEP tracks, embedded base-colour textures,
vertex colours and PBR factors; it is not a general glTF renderer (CUBICSPLINE,
normal maps and arbitrary extensions are outside this path). Qt texture V
orientation is corrected at sampling, leaving source UVs intact.
Handheld resource/performance acceptance remains required; a software-rendered
server preview is not a handheld measurement.

Tests: `trainer_avatar_scene_tests`, `trainer_home_companion_tests`,
`trainer_history_tests`, `trainer_experience_tests`, plus the rendered example.
See [Home companion evidence](../../docs/evidence/2026-11-02-home-companion/README.md).

## Static cards

Optional GPL-3.0-or-later SDK consumer code. Add `AvatarCards.h` to an AUTOMOC
target linked to Qt Core/Network, and bundle the three QML files together.
The card UI itself uses Qt Quick; the short-lived portrait renderer additionally
needs matching Qt Quick 3D/AssetUtils plugins. Without those plugins or an avatar
capability the card retains an anonymous silhouette and gameplay continues.

Construct `AvatarCards(appId, endpoint)`, expose it as a QObject to QML and call
`start()` after the first application frame. It uses a separate read-only avatar
connection, so local play does not impersonate a second Trainer or need Lobby.
Bind `sendRecord` to the game's existing reliable channel. On `network.ready`
call `session(session.peer)`; on close call `clearPeer()`. Validate the channel,
sequence and **peer against the admitted session** before routing records with
namespace `traineros.avatar.v1` to `receive()`. Keep these records outside the
game rules decoder and return normal receive credit. No extra transport exists.

`local` and `peer` are descriptors suitable for `PlayerCard.descriptor`.
Set the label/seat/accent from game state; never use the local descriptor for a
guest/bot. Empty recipes withdraw identity. Replacement, close and context
revocation fence outstanding resolutions. Latest peer recipes coalesce behind
one resolver and a one-second interval. Invalid files/digests use the fallback.
Only the small recipe crosses the channel, never GLB files, paths or tokens.

`AvatarPortrait` captures a 256px transparent bust and releases its renderer.
The grab result stays alive with the 2D image. Saved appearance invalidates the
image; there is no continuous 3D card rendering. Qt uses the descriptor's neutral
preview GLB after validating the companion game GLB; both are host-resolved files.
For Godot use `sdk/godot/avatar_portrait.gd` and generation-fence asynchronous
completion when identity changes. The helper returns a Texture2D and releases
its SubViewport. Headless callers receive null.

Checks: `cmake -S sdk/qt/tests -B build/avatar-cards-checks`, build, then CTest.
The socket fixture covers replacement/withdrawal/revocation, not mesh rendering.
`avatar-portrait-preview MODEL-preview.glb OUTPUT.png` separately exercises the
actual QML importer, capture and renderer release. Device acceptance is separate.
