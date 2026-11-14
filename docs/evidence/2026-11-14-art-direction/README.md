# Approved artwork replacement — 14 November 2026

**Crates layout superseded:** the owner rejected this 2+4 composition. The
[following correction](../2026-11-14-crates-grid/README.md) uses larger, equal
3×2 tiles. This record and its sequence 39 screenshots remain historical.

Runtime replaces 12 genre and 10 series paintings with editable SVG-derived
icons, six painted Crates with Kenney-based low-poly chest renders, and 31
platform drawings with attributed hardware photographs. Unknown/virtual
platforms retain their procedural illustration. User artwork, saved resource
addresses, catalogue actions and colourful game Home are preserved.

Sources and reproduction: [collections](../../../assets/genres/README.md),
[series](../../../assets/series/README.md), [Crates](../../../assets/crates/README.md),
[photographs](../../../assets/platforms/README.md). Source/output hashes and
per-file licences are retained; photography and Kenney notices are installed.

## Delivered build and checks

- Source: `4c5c2c36098f90bae730c2c4477010918efe89c2` (art integration
  `ff705c1c`, followed by the physical-resolution mask correction).
- Private signed Software sequence **39**, version `0.1.0-alpha.8-device.4c5c2c36`.
  Sequence 38 was the tested intermediate; reserve 40+ next. No public release.
- ARM binary SHA-256:
  `3550a48379463fec254e0ea7c06ea1b7d7bcafa91af755930c3e8f8088caa1b5`.
- Flip managed identity:
  `89b53db6c6d942fe729302bee1168215de7808a005ae0d17df43f9c37173985d`,
  health `first-frame-confirmed`, previous sequence 38 retained. Odin uses the
  established in-place installation, with verified prior files/profile backup.
- Native and ARM builds used the existing cached builder
  `traineros-validation-arm-cross:20261110`. 27 Crates and 32 Series tests passed.
  Art and ordinary Crates UI scenarios passed with zero collected QML warnings:
  960×540 light/dark, 1280×800 dark, readable resources, virtual SDL selection,
  open animation, catalogue, Back/focus and immediate reduced-motion opening.
- Both real devices ran the expected binary and displayed all six chest renders.
  Pointer activation opened Workshop; Back restored its focus. Games displayed
  original player collections/counts and hardware photographs. Captures are
  actual Gamescope output at 1920×1080, not composited mockups. Remote pointer/key
  input does **not** establish physical touchscreen/gamepad acceptance.
- The first device pass revealed soft circular art at 200% UI scale. Sequence 39
  sizes source/mask textures to physical pixels; final captures show the fix.
- SQLite quick-check passed and adventure row counts matched each pre-update
  backup. Both original profiles remained visible. The PC exit helper retained
  SHA-256 `903a8fe8eda3f8abf79b955dc38a05f67ec8d7047302226562ce071610d13f3e`.

During sequence 38 maintenance, direct external desktop transition ended Flip's
managed launcher before it released its session marker. The update correctly
refused to proceed. One **normal reboot** recovered it; the guard was not bypassed.
For sequence 39, both devices exited through **Start → Switch → Desktop → Continue**;
markers were cleared normally and installation/start completed without reboot.
There were no active games/apps at either update. No suspend/lid/Power test.

## Captures

| Surface | Odin | Flip |
| --- | --- | --- |
| Previous Crates, sequence 37 | [Before](devices/odin-art-crates-before.png) | [Before](devices/flip-art-crates-before.png) |
| Collections and platforms, sequence 39 | [Genres](devices/odin-art-library-final.png) | [Series](devices/flip-art-library-final.png), [photographs](devices/flip-art-platforms-final.png) |
| Six Crates, sequence 39 | [Overview](devices/odin-art-crates-final.png) | [Overview](devices/flip-art-crates-final.png) |
| Opened Workshop | [Catalogue](devices/odin-art-workshop-final.png) | [Catalogue](devices/flip-art-workshop-final.png) |
| Back preserves Workshop selection | [Back](devices/odin-art-crates-back-final.png) | [Back](devices/flip-art-crates-back-final.png) |

Native synthetic-profile checks: [light 960](native/art-crates-light-960.png),
[opening 960](native/art-crate-opening-960.png),
[dark 1280](native/art-crates-dark-1280.png). These are host evidence, not devices.
The remote catalogue's old “Made for TrainerOS” subtitle remains visible in device
captures; it comes from catalogue metadata, not the new artwork.

## Resource measurements and limits

The 22 collection PNGs fell from **54.49 MiB to 0.30 MiB**. Added platform/chest
PNGs total **7.93 MiB**; the old Crates atlas is excluded from runtime resources.
Only the opening chest loads a six-frame 1536×224 strip. Static closed images
are 512×448; no permanent 3D view or idle animation was introduced.

Short `/proc/<pid>/smaps_rollup` observations on the Crates overview:

| Device | Before RSS / PSS MiB | Final RSS / PSS MiB | CPU ticks over 2 s, before → after |
| --- | --- | --- | --- |
| Odin | 748.64 / 694.63 | 707.88 / 652.43 | 6 → 6 |
| Flip | 623.14 / 565.46 | 594.19 / 536.42 | 9 → 7 |

These compare a long-running old process with a fresh updated process and
slightly different preceding navigation/cache history (Flip was rebooted).
They are **spot checks, not isolated causal savings or FPS benchmarks**.
Frame-time tails, sustained sessions, physical controls and exhaustive game
performance are not certified here.

Our archives, extraction caches, screenshots on internal storage and superseded
rollback files were removed after verification. Current installation and one
working rollback were retained; games, saves, BIOS and profiles were preserved.
Internal free space before the task was 9.82 GiB (Odin) / 22.74 GiB (Flip);
final post-cleanup readings were **9.90 GiB / 22.82 GiB** respectively.

The approved replacement slice is delivered. General visual QA #34, broader
asset review #116, other generated fallback/profile scenes and Bazaar artwork
remain separate; this record does not close those scopes or issue #267 wholesale.
