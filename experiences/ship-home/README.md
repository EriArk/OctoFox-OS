# Ship Home — development preview

A separate third-person home for the OctoFox character. A panoramic lounge leads
into a central passage, with a workshop, gallery, cabin and wardrobe on either
side. Large windows look out onto a procedural star field and planet.

This is the **first playable layout**, not the finished art or a public release.
Walking, a collision-aware camera, per-profile furnishing saves and the shared
avatar are implemented. The workbench, wardrobe and gallery have physical spaces
and explanatory interactions; crafting, equipping clothes here and displaying
owned rewards still need their real providers. There is no new economy or shop.

## Run on a development computer

Use the tested Godot **4.7.x** Linux runtime. From the repository root:

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
through the same path as other native applications. Full minimize/return/close
acceptance with the handheld compositor is still pending.

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
| Interact | A | F |
| Undo / remove / exit | Pause menu | Pause menu; Z also undoes |

Seven starter furniture types can be placed, moved, rotated and removed. A
translucent green preview means placement is valid; red means it overlaps a
solid object or blocks a protected route. Changes save immediately. Undo restores
the previous arrangement. The menu releases the mouse; losing focus pauses
movement and caps rendering at 10 fps. Foreground rendering is capped at 60 fps.

## Identity, saves and resources

The game consumes `sdk/godot/avatar_client.gd` and `avatar_presenter.gd`; run
`sync_sdk.py` after SDK updates. The host provides the active profile's checked
model descriptor. No character models or private profiles are bundled. Same-owner
appearance refreshes preserve furniture; a revoked/disconnected identity clears
the character and returns to a separate guest home. A basic guest figure is
available when the host is absent.

Layouts live under Godot's custom user folder, normally
`$XDG_DATA_HOME/octofox-ship-home/homes/<profile-hash>.json` (or
`~/.local/share/octofox-ship-home/homes`). Saves use a bounded schema, temporary
file and atomic replacement. Invalid files remain untouched/read-only. The Linux
launcher keeps a single-instance lock through `exec`, retaining the process ID
tracked by Apps. Start failures are logged under
`$XDG_STATE_HOME/octofox-ship-home/launch-error.txt`, with a desktop dialog when
KDialog or Zenity is available.

The shared rig gets a simple, game-owned procedural walk; this is an early
animation, not a new outfit or a replacement avatar system. Fixed room meshes are batched by shared material; movable furniture stays separate.
Geometry, materials,
planet and sky are original code, without image textures or third-party room
models. All project code is GPL-3.0-or-later; the host's avatar assets keep their
existing [separate licensing](../../assets/avatar/README.md).

## Verification

```sh
/path/to/godot --headless --path experiences/ship-home --script res://tests/checks.gd
SHIP_CAPTURE_DIR=/tmp/ship-tour /path/to/godot --path experiences/ship-home --script res://tests/tour.gd
```

`checks.gd` covers replacement/reload, profile isolation, corrupt-save protection,
placement and undo, protected doors, world collisions and camera retraction.
`live_avatar.gd` is driven by the native `shipConsumesLiveHostAvatar` test against
an actual PlatformBinding host; set `OCTOFOX_SHIP_TEST_GODOT` and
`OCTOFOX_SHIP_TEST_PROJECT` when running `trainer_interaction_tests`. It checks
shared mesh/rig loading, locomotion posing, appearance refresh and revocation.
An optional `SHIP_TEST_DESCRIPTOR` lets the screenshot tour show a locally
resolved development character; it is not a production identity override.

[Development evidence and screenshots](../../docs/evidence/2026-11-14-ship-home/README.md).
No Odin or Flip access was used for this increment.
