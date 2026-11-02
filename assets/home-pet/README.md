# Home companion art preparation

Prepared 2026-11-02; not yet connected to the Home widget.

`manifest.json` records the 14 selected Kenney props, original archive/file hashes,
output hashes and triangle counts. Source licenses remain in each pack directory.
These props are **CC0-1.0**, separate from TrainerOS's GPL source-code license.
Thank you, Kenney. Only external PNG images were embedded into self-contained GLB;
geometry, materials and node transforms were retained.

Rebuild with `tools/home_pet/import_props.py`; original ZIP archives belong in the
server research cache, not the repository. Mesh sizes do not prove frame rate.
`animations.json` describes the downloaded free Quaternius animation sources;
the original rigs/clips are not shipped here or retargeted yet.

See [accepted behavior, art selection and remaining work](../../docs/HOME_COMPANION.md).

## Backgrounds

Three new background plates were generated with the built-in image_gen tool:
`backgrounds/cozy-room.png`, `backgrounds/sunny-garden.png`, and
`backgrounds/evening-nook.png`. Full prompts are in `background-prompts.json`.
These generated illustrations are not Kenney/Quaternius assets and are not
covered by those authors' CC0 notices. Original generated files are retained;
no avatar, UI, food or central movable furniture is baked into the plates.

Use a bounded QML Image sourceSize for the widget's physical display size and
load only the selected background. Match the live avatar camera, lighting and
contact shadow to the background. Do not use the room as a free-rotation 3D
environment. Wide/compact widget composition and real-avatar integration still
need visual review; the pictures alone are not proof of that integration.
