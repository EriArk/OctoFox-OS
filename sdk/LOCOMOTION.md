# Optional Godot character movement

The Godot SDK includes `character_motor.gd`, `avatar_locomotion.gd` and the CC0
[Quaternius animation pack](godot/animations/provenance.json). Bazaar consumes the
same files under `addons/traineros`; it no longer owns a private retargeter.
No host API change, online account or bundled personal avatar is required.

## Integration

Copy the two scripts and the `animations` directory alongside the existing avatar
client/presenter. Create a motor, add it to a `CharacterBody3D`, then call
`motor.bind(body)` once. Set its speeds, height and radius before binding. The
body's origin is at its feet; Y is up and units are metres. The motor creates its
capsule. Do not also create a second character capsule or call `move_and_slide`.

From the body's physics callback:

```gdscript
motor.step(delta, camera_relative_direction, sprint, crouch, jump_pressed,
           controls_enabled, walk)
# Actual velocity after collisions, not input magnitude, drives the animation.
motion.advance(delta, motor.actual_speed, controls_enabled,
               motor.crouched, body.is_on_floor(), motor.gait)
```

Map raw left-stick input once with `TrainerCharacterMotor.stick_direction(raw)`.
Its default radial inner dead zone is 18%; the outer dead zone is 20%, so full
speed is reached at 80% travel. The remaining range is linear, with diagonal
magnitude capped at one. Do not apply another magnitude/dead-zone multiplication.
Both thresholds can be supplied explicitly; this helper does not change camera input.

`direction` is a horizontal world vector of length 0–1. The caller owns key/pad/
touch mappings, camera, permissions, networking and spawn/respawn. Full input
runs; a light stick walks. `walk` forces walking and `sprint` requests sprinting.
Crouch takes precedence. Resolved travel up to 2.4 m/s selects the walking clip;
partial input no longer plays a running clip in slow motion. `jump_pressed` is an edge, not a held button. A short
jump buffer and coyote time tolerate input near the edge of a step. Crouching
changes the capsule, and standing queries clearance before expanding it. Call
`motor.reset()` on teleport or input revocation to discard velocity/buffered jumps.

Load the avatar through `TrainerAvatarPresenter.from_descriptor`. Add it under
your scene anchor before calling `motion.bind(presenter)` on a new locomotion
node. Recreate that node when replacing/revoking the presenter. Uniform anchor
scale is supported; do not alter the SDK's bones, skin or saved appearance to
change a world's scale. Retargeting validates required joints and preserves the
approved arms-down bind silhouette, fingers and shoulder helpers.

Supported states: idle, walk, run, sprint, crouch idle, crouch walk and airborne
jump. AnimationPlayer blends transitions once; an additional pose filter is not
applied. At bind time, stance foot travel calibrates cadence for the actual
skeleton. At runtime cadence includes uniform world scale and resolved travel
speed. Pelvis translation preserves crouch depth and walking support height. Jog/sprint
retain the donor's flight clearance above the floor; the physics capsule remains
on the ground during the ordinary running cycle.
The world still owns gameplay: these are optional helpers, not mandatory avatar
protocol behavior. They do not replace a game's existing character controller.

## Bazaar tuning and verification

Bazaar uses a 1.8× visual anchor and a 1.8 m standing capsule. Walking is 1.5 m/s,
normal running 4.4, sprinting 6.2 and crouch walking 1.05. NPC bounding heights
range approximately 1.41–1.66 m, below the visitor; the stall canopy remains 2.23 m.
The original stall model and size are preserved. No profile asset was rescaled.

`godot --headless --path sdk/godot --script res://tests/character_motor.gd`
checks stopping, walking/running/sprinting, crouch clearance, jump/landing,
wall-blocked velocity, disabled input and the linear inner/outer stick zones. `tests/locomotion.gd` takes a synthetic
`--descriptor=/absolute/path.json` and `--output=/absolute/report.json` and checks
seven states over complete cycles, reference silhouettes, unchanged bind data,
finite rotations, shoulder helpers, lowered crouch pelvis, support feet and both
stance/flight phases for jogging and sprinting.

These are controller/pose checks, not physical handheld gamepad acceptance.
Terrain-specific two-foot IK, stairs, network prediction, swimming, climbing and
combat are not supplied by this increment. The single support-height correction
is not full foot locking on uneven terrain. Original clip sources and CC0 terms
are retained with the animation asset.
