# Ship Home — Orbit-inspired interior redesign

14 November 2026. Source/development preview on `codex/ship-home-20261114`.
The owner rejected the [first layout](../2026-11-14-ship-home/README.md) as a
low-poly house in space and requested a spacecraft, a console at the panorama,
and ideas from the existing [Orbit profile background](../../../assets/profile-scenes/orbit.png).

## Changed

- Curved pressure-hull ceilings, continuous ribs, framed hatches and inset metal
  deck plates replace the domestic floor-and-wall treatment.
- The panoramic bridge has a curved five-section helm, amber instruments, a
  yoke and pilot chair. Its interaction explicitly says flight controls are not
  implemented; these are visual instruments, not simulated telemetry.
- Ivory panels, brass bands, blue inset lighting and a lavender ringed planet
  follow Orbit's visual language. Geometry, shaders and stars are built in code;
  no new generated bitmap or downloaded room model is used.
- Built-in seating, a sleeping pod, wardrobe lockers and fabrication/reward
  spaces retain the cozy home functions. Movable furniture has rounder forms.
- New-home furniture positions clear the helm and fitted seating. Existing saves
  retain their contents; this is not an automatic furniture-layout migration.

Fixed static batching of mixed indexed/unindexed geometry: previously, adding
cylinders to a material group could discard authored boxes. A regression check
now verifies triangle preservation. Tubular profiles share cross-sections at
joints, and the shallow circular deck inset clears the deck plates.

## Actual engine captures

These are 1280×720 Godot viewport captures, not concept illustrations. The
architecture tour hides the character and HUD and uses inspection cameras;
normal play remains third-person with the existing avatar and controls.

| View | Capture |
| --- | --- |
| Panoramic bridge and lounge | [bridge.png](bridge.png) |
| Helm and ringed planet | [cockpit.png](cockpit.png) |
| Central passage and hatches | [spine.png](spine.png) |
| Sleeping cabin | [cabin.png](cabin.png) |
| Workshop | [workshop.png](workshop.png) |
| Reward gallery | [gallery.png](gallery.png) |
| Wardrobe | [wardrobe.png](wardrobe.png) |

## Validation and limits

Godot 4.7.2 headless checks passed: persistence/profile isolation, corrupt-save
protection, placement/undo, protected routes, hull collision, camera retraction,
helm collision and mixed-mesh batching. The seven-view design tour completed
without script/render errors using Mesa llvmpipe under Xvfb on the development
server. Software rendering does not establish handheld performance.

Reproduce from the repository root after the SDK sync/import described in the
[project README](../../../experiences/ship-home/README.md):

```sh
godot --headless --path experiences/ship-home --script res://tests/checks.gd
SHIP_CAPTURE_DIR=/tmp/ship-design godot --path experiences/ship-home --script res://tests/design_tour.gd
```

This pass changes the game interior, not the shell entry or Apps supervisor.
The previous native integration checks remain dated evidence, not newly repeated
checks. No Odin/Flip access, device installation, Bazaar changes or release.
Final art, physical-controller/compositor acceptance, handheld performance,
functional crafting, wardrobe actions, owned reward displays and flight remain
unfinished. The aft engineering door is scenery, not an additional room.
