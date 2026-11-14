# OctoFox art direction — study 01

14 November 2026 · [Issue #267](https://github.com/EriArk/OctoFox-OS/issues/267)

The owner clarified that the primary problem is the recognisable appearance of
AI-generated illustrations, not merely excessive detail. The owner also authorised
using suitable freely downloadable artwork. This study uses editable vector
geometry, an attributed existing 3D model and real console photographs. No image
generator was used to create the proposed assets. The SVG and adaptation scripts
were code-authored with the coding assistant; they are not claimed as human-drawn
artist commissions.

[Comparison](comparison.png) · [Dark / small / open comparison](comparison-dark.png)
· [Interactive local preview](preview.html)

## What is ready

- Three editable genre emblems: RPG, Racing and Strategy. The same shapes render
  at 110 and 96 CSS pixels; counts and names are separate preview elements.
- A downloaded **Kenney Pirate Kit 2.1** chest, with separate hinged lid. Three
  material/emblem studies: Adventure, Workshop and Arcade. Original geometry is
  retained, widened, recoloured and given a small category badge. The output GLBs
  contain 292, 320 and 296 triangles respectively. Closed/open renders use a fixed
  camera fitted to both poses. A 1–25 frame lid animation is exported in each GLB.
- Four downloaded console photographs: NES, Game Boy, Game Boy Advance and DS Lite
  (used to represent Nintendo DS). Transparent margins are trimmed and photos
  resized proportionally to at most 640 px. Their device names remain live text.
- A local comparison page with light/dark, 96 px collection view and open-chest
  controls. Current Crates/platforms are CSS crops of historical Alpha 7 captures;
  collection baselines come directly from the bundled genre PNGs. Proposed counts
  are illustrative, not a scan of a person's library.

These are **design prototypes**, outside runtime assets/resources. No app source,
installed handheld build, user artwork or navigation was changed. Existing real
covers, logos and scraped media retain precedence. Series/franchise emblems are
still to be designed: the genre examples do not solve their identity problem.

## Proposed application

Keep the existing catalogue hierarchy and controller behaviour. A catalogue tile
would display a pre-rendered chest, with the existing title, focus and actions.
Do not create one permanent Qt Quick 3D viewport per tile. The GLBs make a focused
opening animation possible, but whether to use live 3D, a short atlas or the
existing QML timing still needs a measured comparison. Mesh size is not an ARM
performance result. Theme and focus treatments must be checked in the real QML.

The downloaded photos are objects for platform cards, not a replacement UI theme.
The preview only demonstrates placement; final integration must keep the existing
platform count, title, custom media and selection behaviour.

## Selective audit

Decisions below are proposals for follow-up, not a blanket replacement order.
Representative source images and historical screenshots were inspected.

| Surface | Decision | Reason / boundary |
| --- | --- | --- |
| Series collection paintings | Replace after style agreement | Similar generic landscapes obscure series identity. Original logos/characters are not automatically reusable artwork. No series artwork replaced in this study. |
| Genre collections | Replace after style agreement | RPG/Racing/Strategy samples lose detailed scenery in a small circle. Three vector trials now available. |
| Crates illustration atlas | Replace with model family after comparison | Remove inset painted scenes; retain six categories/order/actions. Three model variants are a study, not the full six-category rollout. |
| Platform illustrations | Refine with sourced hardware imagery | Four public-domain photo samples downloaded at owner's request. Current drawings are not being mislabelled as AI-generated. |
| Fallback covers | Refine | `fantasy-0.png` repeats the floating-island look. Try category motifs as fallback only; keep scraped/user covers first. |
| Home card backdrops | Keep for this increment; reassess selectively | `green.png` has useful quiet space. Preserve colourful game Home and its composition; no automatic replacement. |
| Bazaar | Coordinate separately | Historical catalogue/preview captures show the same generated-scene look. Worlds and their artwork are owned by the other active conversation; no changes here. Real world captures may replace placeholders later. |
| Preset avatars | Refine selectively | `fox.png` has conspicuously polished generated fur/detail. Consider a small coherent illustrated/3D family later; preserve user pictures. |
| Profile scenes | Refine selectively | `aurora.png` has dense decorative scenery. Evaluate behind the actual character before replacing; preserve the scene composition and owned choices. |
| Home companion backgrounds | Keep for this increment | `cozy-room.png` provides clear character space. Reassess against the actual companion, without rebuilding Home. |

## Reproduction

- `render_crates.py`: Blender **4.5.3 LTS**, Cycles CPU, 48 samples, four workers,
  768×640 RGBA. Run `blender -b -t 4 --python render_crates.py` from any directory.
  Paths resolve relative to the script. It imports the included Kenney source,
  writes three self-contained GLBs, four PNGs and `model-stats.json`.
- `collections/*.svg`: editable source; browser or Qt SVG renders them directly.
- `prepare_platforms.py DOWNLOAD_DIRECTORY`: requires Pillow. Input filenames are
  `<id>-original.png` and `platform-sources.json` with source SHA256 values.
  Original URLs/hashes and output hashes are preserved in the included manifest.
- `preview.html` loads local repository assets only; it needs no network, account
  or package installation. Screenshot viewport: 1440×1080. `?dark&small&open`
  selects the second comparison state. Review at 100% zoom for stated CSS sizes.

## Provenance and licences

- Kenney: [official pack](https://kenney.nl/assets/pirate-kit), downloaded from
  [Kenney's OpenGameArt publication](https://opengameart.org/content/pirate-kit).
  The download is `kenney_pirate-kit_2.1.zip`; exact SHA256 and source subset are in
  [model-sources.json](model-sources.json). The licence text (whitespace normalized) is included in
  [models/kenney/LICENSE.txt](models/kenney/LICENSE.txt). Original model/texture:
  **CC0**. Only the chest and its colour map are included, not the entire pack.
- Console photography: **Evan-Amos**, public-domain dedication on each Wikimedia
  Commons file page. Source URLs, original/output SHA256 and resize details are
  in [platform-sources.json](platform-sources.json). The PNG variants include
  transparent-background preparation by Commons contributors; Game Boy's page
  credits 風中的刀劍, GBA's upload credits DoDoDon. We retain the exact file-page
  links rather than claiming to have photographed/cut out the devices ourselves.
- Original SVG geometry, this preview, adaptation scripts, added emblems and
  modified model/render outputs: **GPL-3.0-or-later**, copyright 2026 EriArk and
  OctoFox contributors; see the repository [LICENSE](../../../LICENSE).
  This does not relicense the underlying CC0/public-domain files or third-party
  device marks. Existing baseline screenshots/illustrations retain their notices.

## Verification and remaining acceptance

Blender rendered all four views; source/output GLBs were inspected for geometry,
embedded resources and lid animation. Chromium rendered light and dark/small/open
comparisons; both were visually inspected. SVGs and provenance hashes were checked.
The initial opening render clipped the lid; the final renderer fits the union of
closed/open bounds and keeps that camera fixed. This correction is in the source.

Still open: owner feedback on these concrete examples, complete genre/series and
six-crate coverage, QML integration, install/open/focus regression checks, real
Odin/Flip before/after screenshots and ARM memory/frame-time measurement. These
studies do not close #267, licensing review #116 or general visual QA #34.
