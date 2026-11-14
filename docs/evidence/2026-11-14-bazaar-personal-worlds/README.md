# Personal starting worlds — 14 November 2026

Private **Software 47 / Bazaar 0.0.10** is installed on **Flip 2 and Odin 2**.
The right-hand Mika and Ren cards launch their own empty starting grounds:
a roughly circular beach island and a circular orbital station under glass.
Both reuse the profile avatar and SDK locomotion. Each has a clear central square
for later owner-bought facilities. No player venue, purchase or multiplayer
session is created. The official Festival Park remains a separate world.

## Source and packages

- Shell source: `a1eb3c6829e380793231c02473cac28003b9aaf1`, branch
  `codex/bazaar-entry-device-20261114`. [Package](shell-package.json).
- Game source: `029ff24e4a5affee524287e3bfc5be04be37fa75`, branch
  `codex/bazaar-world-20261114`. [Package](game-package.json).
- No merge or public release. Sequence 47 is consumed; reserve **48+** next.
- The game covers are renders of the shipped scenery; their source and licence
  are recorded in [assets](../../../assets/bazaar/README.md).

## Checks

Native and ARM shell builds passed, with **10 Bazaar and 20 Apps tests**.
The [UI report](ui-report.json) has zero diagnostics/warnings. Compact light/dark
layouts, selection, scroll and uninstalled-world explanation were checked.
[Catalogue image](catalogue.png) is a native fixture with the game uninstalled;
installed devices show **Enter / EMPTY SQUARE · ALPHA** instead.

Godot 4.7.2 source physics checks passed for both personal worlds: supported
arrival, nine construction-pad points, movement, pause, recovery, beach support
and station edge collision. The official walkthrough regression also passed.
Linux x86-64, ARM64 and Windows exports completed; both x86-64 personal worlds
passed normal exported startup. [Game evidence](https://github.com/EriArk/crates/blob/codex/bazaar-world-20261114/games/bazaar/docs/personal-worlds/README.md).

Both handhelds were observed entering each personal world through its card,
loading the correct profile avatar, moving, opening the menu and leaving normally.
Return restored the selected card and scrolling. Official island entry/movement/
Leave also passed on both. Logs had no game errors/warnings and no live game
process remained after Leave. Input was remote keyboard/pointer, **not physical
pad/touch acceptance or a sustained frame-time benchmark**.

- [Flip verification](flip-verification.json)
- [Odin verification](odin-verification.json)

Database quick checks and profile/owner/adventure counts passed; existing game
preferences were byte-identical. Private backups remain on their devices.
Flip's managed update confirmed its first frame; Odin's legacy install retained
its adjusted runtime libraries. Maintenance used normal Start → Switch → Desktop;
no sleep or lid test was performed. The existing PC exit helper was preserved.

## Cleanup and remaining work

Task staging and superseded Software 45 / game 0.0.8 were removed after live
reference checks. **Software 46 / Bazaar 0.0.9** remain as verified rollback.
[Flip cleanup](flip-cleanup.json) and [Odin cleanup](odin-cleanup.json) record free
space before and after. Profiles, games, saves and private backups are retained.

These are playable local frames. Paid facilities/placement, ownership provisioning,
trading and peer-hosted multiplayer are future work. Physical controls and the
owner's visual review remain acceptance items.
