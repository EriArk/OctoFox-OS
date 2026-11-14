# Adapter sticker home — 14 November 2026

Separate Bazaar branch, following `2ee4291a`. No merge, handheld installation,
backend deployment, save mutation, custody or payment enablement.
[Current contract](../../ADAPTER_HOME.md).

## Delivered source

- A large three-column sticker home replaces the permanent adapter section menu.
  Six buttons fit in the small viewport, with scrolling to the remaining row.
- Every trusted adapter supplies its screen order, names, icon keys and optional
  artwork URL. The host has no Pokemon screen list or item-specific type switch.
- Nine new original transparent PNGs were generated through built-in image_gen,
  copied into project resources and inspected; alpha and SHA-256 are recorded in
  the [art manifest](../../../assets/adapters/pokemon/navigation/manifest.json).
  [Exact prompts and provenance](../../../assets/adapters/pokemon/navigation/README.md).
  Runtime decoding is bounded to 256×256, independent of original source resolution.
- L2/R2 cycle actual screens; nested Back stays with the module, then returns to
  its home with remembered focus. Spaces provides pointer/touch return. System
  X/Y/Home/Start and protected operation/modal gates remain with their owners.
- Ordinary adapter entry starts at home; explicit actions can open a workspace.
  Navigation restoration retains the home/workspace distinction. Opaque module
  state and stable screen IDs remain compatible with existing saved navigation.

## Verification

Native build passed. All **six focused CTest suites passed**: `experience`,
`interactions`, `experience_qml_smoke`, `artwork_qml_smoke`, `inventory_qml_smoke`
and `bazaar_qml_smoke`. [CTest output](ctest.txt). The separate
[Xvfb/OpenGL run](opengl-check.txt) passed with **zero QML warnings**.
The final small/light/dark/scroll screenshots were visually inspected.
Host is Linux / Qt 6.11.2 in `traineros-browser-ci:20261110`, with isolated
config/data and no personal saves. Inputs are synthesized, including the existing
virtual controller fixture and pointer taps. This is not physical Odin/Flip
controller/touch acceptance.

The additional legacy `qml_smoke` **failed** and is not included in the six passing
suites. [Retained failure output](legacy-qml-smoke.txt). Its unchanged harness in
`src/app/Main.cpp` still expects retired primary routes (page 3 as Trainer, for
example), old focus objects and system-menu behavior. That broader harness was
not rewritten here; full-suite green is not claimed. The affected modern adapter
and artwork scenarios were updated and passed, rather than skipping their checks.

Final changed native [source hashes](source-sha256.json) match the remote build.
The nine resource hashes are verified separately in the art manifest.

Screenshots:

- [Light home, 800×450](adapter-home-800.png)
- [Dark home, 960×540](adapter-home-dark-960.png)
- [Remaining stickers, 800×450](adapter-home-more-800.png)
- [Full Boxes workspace, 800×450](adapter-boxes-800.png)
- [Independent adapter home](adapter-independent-home.png)

The updated real-host scenario checks independent RPG/racing fixture adapters,
all nine generated art resources, controller/pointer entry, Back focus return,
L2/R2 cycling, modal overlays, small/dark/scroll layouts and navigation restoration.
Fixtures are not additional supported commercial games.

The adapter export/check scripts refreshed the portable runtime snapshot to match
already-existing source (runtime path preparation changes); no runtime behavior
is changed by this UI increment. The exact-build registry/save providers remain
unchanged. Export and adapter knowledge checks passed.
