# Ship Home — development preview

A separate third-person home for the OctoFox character. Rooms fit inside one
10.6 × 12.4 metre oval pressure hull. A single-seat cockpit sits at the bow,
a small galley/dinette occupies the middle, and four compact bays share a short
central passage. The curved ceiling lowers toward the rim; small portholes serve the living bays, while a panoramic bow canopy opens the
pilot view. Technical space is reserved beneath the deck, with flush service
hatches above. Warm ivory panels, sage upholstery, restrained wood and brass
retain the Orbit profile background's visual language. Smooth hull surfaces,
rounded console shells and oval portholes replace the earlier faceted treatment.
Warm ceiling halos, bulkhead lenses, task lights and recessed strips make the
lighting fixtures part of the ship itself. The warm interior is installed on
both handhelds as preview `34aa5da8b7518ad3`.

The pilot seat is surrounded by curved side consoles, a stick, throttle and
low instruments. Approach from behind and press **A / F** to sit: the camera
switches to the pilot's eyes. Mouse/right stick turns the view; **B / Esc / A / F**
stands up in a collision-checked free space and restores the chase camera.
Start/P opens the menu while seated. Flight controls remain unimplemented.
The transition is immediate with a simple shared-rig seated pose; there is no
authored boarding animation or separate first-person hand model yet.
This is the **first playable layout**, not the finished art or a public release.
Walking, a collision-aware camera, per-profile furnishing saves and the shared
avatar are implemented. The workbench, wardrobe and gallery have physical spaces
and explanatory interactions; crafting, equipping clothes here and displaying
owned rewards still need their real providers. There is no new economy or shop.

## Run on a development computer

Use the tested Godot **4.7.x** Linux runtime with Vulkan. The project defaults
to the **Mobile** renderer, checked on Odin/Flip with Turnip. Compatibility
produced camera-dependent black patches on Odin and is not the accepted handheld
path. Earlier software-renderer screenshots remain historical design evidence.
From the repository root:

```sh
python3 experiences/ship-home/sync_sdk.py
/path/to/godot --headless --path experiences/ship-home --editor --import --quit
/path/to/godot --path experiences/ship-home
```

For the header button and Apps catalogue, install the preview for the current
user. This does not download Godot or alter system packages:

```sh
python3 experiences/ship-home/install-dev.py --godot /absolute/path/to/godot
```

The executable must remain at that path. `--data-home /temporary/directory`
installs into an isolated XDG prefix for validation. The installer imports a
versioned copy before publishing its desktop entry. Re-running it with the same
source is idempotent. Old development copies are retained for deliberate cleanup;
no personal saves are deleted. This is **not yet part of Setup/OTA packaging**.

In the updated shell, use the saucer icon beside the profile. On Home, move Up
from the lobby row or screenshot collage to reach it with the controller.
The bottom notification bell still opens the inbox. The game uses the existing
Apps supervisor and stable desktop identity, so its launch/return requests go
through the same path as other native applications. Apps launch and the game’s Save and exit were checked on both handhelds.
Native Home/minimize/return acceptance with the handheld compositor is still pending.

## Controls

| Action | Controller | Keyboard / mouse |
| --- | --- | --- |
| Walk / look | Left / right stick | WASD / mouse |
| Run | L3 | Shift |
| Decorate | X | Tab |
| Place | A | Enter / left click |
| Choose furniture | LB / RB | `[` / `]` |
| Rotate | D-pad left / right | Q / E |
| Move a nearby piece | Y | Y |
| Cancel / menu | B / Start | Esc / P |
| Interact / sit / stand up | A; B also stands up | F; Esc also stands up |
| Undo / remove / exit | Pause menu | Pause menu; Z also undoes |

Seven starter furniture types can be placed, moved, rotated and removed. A
translucent green preview means placement is valid; red means it overlaps a
solid object or blocks a protected route. Changes save immediately. Undo restores
the previous arrangement. The menu releases the mouse; losing focus pauses
movement and caps rendering at 10 fps. Foreground rendering is capped at 60 fps.
The chase camera retracts against walls. At very short distances, the character
presentation is hidden until the camera clears it, avoiding an inside-head view.

## Identity, saves and resources

The game consumes `sdk/godot/avatar_client.gd` and `avatar_presenter.gd`, plus `avatar_locomotion.gd` and its animation dependency; run
`sync_sdk.py` after SDK updates. The host provides the active profile's checked
model descriptor. No character models or private profiles are bundled. Same-owner
appearance refreshes preserve furniture; a revoked/disconnected identity clears
the character and returns to a separate guest home. A basic guest figure is
available when the host is absent.

Layouts live under Godot's custom user folder, normally
`$XDG_DATA_HOME/octofox-ship-home/homes/saucer-v2/<profile-hash>.json` (or
`~/.local/share/octofox-ship-home/homes/saucer-v2`). Saves use a bounded schema, temporary
file and atomic replacement. Invalid files remain untouched/read-only.
The compact deck uses a separate `saucer-v2` layout namespace because the original
coordinates no longer fit. Earlier preview layouts remain unchanged in `homes/`;
they are not automatically migrated or deleted. Each profile starts a new compact
arrangement. This is a development-preview boundary, not a production migration. The Linux
launcher keeps a single-instance lock through `exec`, retaining the process ID
tracked by Apps. Start failures are logged under
`$XDG_STATE_HOME/octofox-ship-home/launch-error.txt`, with a desktop dialog when
KDialog or Zenity is available.

Idle, walking and running use the shared [Godot SDK locomotion](../../sdk/LOCOMOTION.md)
module and its attributed CC0 animation pack, synced unchanged from `c45675a5`.
Cadence follows actual travel after collisions. The ship owns its compact-deck
controller, camera and temporary seated pose; it no longer poses a private walk.
The animator is replaced along with the avatar and stops while seated. Fixed room meshes are batched by shared material; movable furniture stays separate.
Geometry, materials, planet and sky are original code. Two small procedural
noise textures add subtle wood grain and textile variation; no downloaded
texture sheets or third-party room models are bundled. Ceiling meshes batch
separately so the inspection cutaway still hides the complete roof and fixtures. All project code is GPL-3.0-or-later; the host's avatar assets keep their
existing [separate licensing](../../assets/avatar/README.md).

## Verification

```sh
/path/to/godot --headless --path experiences/ship-home --script res://tests/checks.gd
SHIP_CAPTURE_DIR=/tmp/ship-tour /path/to/godot --path experiences/ship-home --script res://tests/tour.gd
```

`checks.gd` covers replacement/reload, profile isolation, corrupt-save protection,
placement and undo, all starter furniture footprints, walking through all four
hatches, curved-hull/seat collisions, camera retraction/close-avatar hiding and
triangle preservation when batching indexed and unindexed meshes, including
ceiling-fixture ownership under the hideable roof.
`pilot_checks.gd` exercises keyboard/controller entry and exit, eye-camera
selection, fixed seated position, bounded look, pause/focus loss, blocked exit
and identity loss. The headless display cannot capture a pointer; `pilot_tour.gd`
checks SDK idle/walk/run selection, captured mouse input and same-profile appearance refresh in a graphical
session and captures first-person views.
`design_tour.gd` captures eleven architecture views and a roof cutaway of the
actual deck, with the avatar and HUD hidden. `tour.gd` retains the gameplay camera
and character for a separate visual check.
`live_avatar.gd` is driven by the native `shipConsumesLiveHostAvatar` test against
an actual PlatformBinding host; set `OCTOFOX_SHIP_TEST_GODOT` and
`OCTOFOX_SHIP_TEST_PROJECT` when running `trainer_interaction_tests`. It checks
shared mesh/rig loading, locomotion posing, appearance refresh and revocation.
An optional `SHIP_TEST_DESCRIPTOR` lets the screenshot tour show a locally
resolved development character; it is not a production identity override.

[Initial development evidence and screenshots](../../docs/evidence/2026-11-14-ship-home/README.md).
The initial preview was host-only; later handheld acceptance is recorded separately.

[Earlier Orbit interior study and screenshots](../../docs/evidence/2026-11-14-ship-redesign/README.md).

[Compact layout iteration and screenshots](../../docs/evidence/2026-11-14-ship-compact/README.md).

[Earlier cockpit, seating and device evidence](../../docs/evidence/2026-11-14-ship-pilot/README.md).

[Warm interior and lighting — earlier host evidence](../../docs/evidence/2026-11-14-ship-warm/README.md).

[Current warm handheld deployment and renderer evidence](../../docs/evidence/2026-11-14-ship-warm-devices/README.md).
