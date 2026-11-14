# Crates low-poly artwork

Current runtime artwork (14 November 2026, #267) is rendered from the actual
Kenney Pirate Kit 2.1 chest mesh (CC0). Original model, texture and complete
notice are retained in [models/kenney](models/kenney/). Six derived GLBs add
colours and geometric emblems; original adaptation code is GPL-3.0-or-later.

Regenerate with Blender 4.5.3:
`blender -b -t 4 --python tools/art/render-crates.py`, then
`python3 tools/art/pack-crates.py` (Pillow required).
The fixed camera covers both closed and open poses. Runtime uses one 512 × 448
closed PNG per chest and a 1536 × 224 six-frame opening strip. Only the opening
chest loads its strip; reduced motion skips it. There is no live 3D scene or idle
animation. QML retains navigation, live labels, focus and catalogue routing.

`illustrations-wide.png` is the **historical October AI-generated atlas**; it is
no longer bundled or displayed. The obsolete `CrateIllustration.qml` is likewise
excluded from the QML module. Existing example project artwork and licences are
separate: [examples/README.md](examples/README.md). `gamepad.svg` remains original
GPL-3.0-or-later vector artwork.
