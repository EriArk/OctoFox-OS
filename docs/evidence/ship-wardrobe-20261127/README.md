# Ship Home and wardrobe checks · 27 November 2026

Ship Home and the shared wardrobe were tested from the source based on `95f05f17`, including `69abfb2f` and `d8efb0f5`. Both handhelds ran Godot 4.7.2 with Vulkan Mobile. Staged copies used their own app data and shader caches. The desktop entries still launched the previous versions during the staged tests. The later installed checks below used the normal Home and Online entries.

## Interactive transit

The Odin 2 baseline was the installed Ship Home build `0cdd0dc602cb2deb`. Opening the normal transit scene produced a 9,064 ms gap between two interactive frames as the game attached the destination. The new build spreads scene construction over multiple frames. The table records elapsed time on a fresh cache through the cabin reveal. Stick motion was injected through the handheld's controller input device.

| Handheld | First flight frame duration | Longest gap during interactive flight | Frame crossing into arrival | Cabin visible |
| --- | ---: | ---: | ---: | ---: |
| Odin 2 | 1,148 ms | 273 ms | 724 ms | 16.62 s |
| Flip 2 | 2,401 ms | 683 ms | 1,313 ms | 36.07 s |

The ship responded to stick input in both runs. This trades some total loading time for control during loading. Flip still has noticeable frame drops. For a repeat measurement, run Godot on the ship project with `-s res://tests/transit_timing.gd` in a normal graphics session. Move the left stick during flight and confirm guest entry if the sign-in service is unavailable.

## Wardrobe

The first test missed a rendering regression. Godot returned a skeleton with twelve import-only mesh nodes. Measurements from that build cannot establish wardrobe performance with visible clothing. The SDK fix in `ef739957` keeps the importing GLTFDocument through scene generation and rejects empty geometry. The same fixture then yielded twelve renderable meshes, with the body inside the fitting camera’s frustum.

The corrected build alternated two 22–27 MB GLBs on each handheld. The probe checked visible mesh surfaces after the initial load and every swap. The first unseen preview produced a longest frame of 100 ms on Odin and 269 ms on Flip. Across the following fifteen cache swaps, peak frame times ranged from 27–41 ms on Odin and 55–107 ms on Flip. Final whole-process RSS was 1,152,696 KiB and 1,162,700 KiB respectively. These are frame durations during this two-look test, not end-to-end times for requests to the live host.

Odin also ran the fitting booth with a real character, scripted controller events and test SDK responses. The scenario covered browsing pieces, cancelling, re-opening, saving and selecting dye channels. Invalid GLBs retained the current model. Separate in-flight tests cancelled a pending load and revoked the profile before it completed. Native tests resolved all twelve Traveller, Mage and Merchant pieces together on the shared rig and checked that equipping a saved outfit preserved the current character's hair.

## Economy and Bazaar

The PostgreSQL test suite ran 235 tests against a disposable database. It covered the closed-market response, repeat purchase receipts, blueprint ownership, timed printing and collection, garment finishes, refusal to list equipped clothing or blueprints, transfer between two accounts, and applying an owned profile scene. Open-market flows used the test policy override.

The desktop build linked the shell and ran the avatar, account and SDK host checks. Two environment-specific native tests skipped (Windows vault and external Godot socket consumer). The handheld game tests used scripted input. A live purchase across two signed-in production handhelds and human controller acceptance remain unverified.

The four Bazaar interiors and their merchant menus were checked on Odin. The before/after contact sheets are in [the Crates branch](https://github.com/EriArk/crates/tree/2b2bfa2/games/bazaar/docs/interiors).

## Installed path on Odin 2 and Flip 2

Both handhelds booted private Software 64 (`bcb59a6f`) and confirmed the first frame. Software 63 is the managed rollback. The upper saucer launched the corrected Ship Home (`0382deaac7e5279c`). Movement and interaction were injected through the handheld controller input. Both signed-in characters walked from spawn to the booth, opened Everyday and previewed an owned garment.

| Handheld | Worn outfit | Live preview | Result |
| --- | --- | --- | --- |
| Odin 2 · Ren | [Polo](odin-wardrobe.png) | [Sleeveless polo](odin-preview.png) | [Saved and equipped](odin-equipped.png), then restored the original polo. |
| Flip 2 · Mika | [Racing outfit](flip-wardrobe.png) | [Rose racing suit](flip-preview.png) | Cancelled the preview and exited the ship. |

Both devices retained their other Crates receipts and Bazaar save data through activation of private Bazaar 0.0.30-dev.1. Online → Bazaar → Festival Park launched the new ARM64 object on both. The production checkout gate stayed closed. A live purchase and a cross-account transfer remain outside this handheld check.
