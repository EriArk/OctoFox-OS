# Crates low-poly artwork

Current runtime artwork (14 November 2026, #267) is rendered from the actual
Kenney Pirate Kit 2.1 chest mesh (CC0). Original model, texture and complete
notice are retained in [models/kenney](models/kenney/). Six derived GLBs add
colours and geometric emblems; original adaptation code is GPL-3.0-or-later.

Regenerate with Blender 4.5.3:
`blender -b -t 4 --python tools/art/render-crates.py`, then
`python3 tools/art/pack-crates.py` (Pillow required).
The wider mesh is shown from a near-front angle. The offline camera covers both
closed and open poses; packing removes transparent margins, centres each pose
on a shared baseline and pulls back as the lid opens. Runtime uses one 512 × 320
closed PNG per chest and a 1536 × 160 six-frame opening strip. Only the opening
chest loads its strip; reduced motion skips it. There is no live 3D scene or idle
animation. The overview is a uniform three-column, two-row grid with large
chests and centred titles. Directional navigation follows that grid; subtitles
remain available to accessibility without crowding the overview.

`illustrations-wide.png` is the **historical October AI-generated atlas**; it is
no longer bundled or displayed. The obsolete `CrateIllustration.qml` is likewise
excluded from the QML module. Existing example project artwork and licences are
separate: [examples/README.md](examples/README.md). `gamepad.svg` remains original
GPL-3.0-or-later vector artwork.
