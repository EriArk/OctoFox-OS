# Ship Home and wardrobe checks · 27 November 2026

Ship Home and the shared wardrobe were tested from the source based on `95f05f17`, including `69abfb2f` and `d8efb0f5`. Both handhelds ran Godot 4.7.2 with Vulkan Mobile. Staged copies used their own app data and shader caches. The desktop entries still launched the installed versions.

## Interactive transit

The Odin 2 baseline was the installed Ship Home build `0cdd0dc602cb2deb`. Opening the normal transit scene produced a 9,064 ms gap between two interactive frames as the game attached the destination. The new build spreads scene construction over multiple frames. The table records elapsed time on a fresh cache through the cabin reveal. Stick motion was injected through the handheld's controller input device.

| Handheld | First flight frame duration | Longest gap during interactive flight | Frame crossing into arrival | Cabin visible |
| --- | ---: | ---: | ---: | ---: |
| Odin 2 | 1,148 ms | 273 ms | 724 ms | 16.62 s |
| Flip 2 | 2,401 ms | 683 ms | 1,313 ms | 36.07 s |

The ship responded to stick input in both runs. This trades some total loading time for control during loading. Flip still has noticeable frame drops. For a repeat measurement, run Godot on the ship project with `-s res://tests/transit_timing.gd` in a normal graphics session. Move the left stick during flight and confirm guest entry if the sign-in service is unavailable.

## Wardrobe

Two 22–27 MB GLBs exercised the normal Godot presenter. On the Odin baseline, repeatedly alternating between these two looks took 2.53–3.61 s per swap. On the candidate, the first unseen look loads on a worker. The last valid model remains on screen. After the cabin settled, the longest frame during the first change was 168 ms on Odin and 248 ms on Flip. The next fifteen changes produced maximum frame times of 25–28 ms and 44–79 ms respectively. Whole-process RSS stayed at approximately 1.10 GiB on Odin and 1.11 GiB on Flip across these samples. These measurements cover two alternating models.

Odin also ran the fitting booth with a real character, scripted controller events and test SDK responses. The scenario covered browsing pieces, cancelling, re-opening, saving and selecting dye channels. Invalid GLBs retained the current model. Separate in-flight tests cancelled a pending load and revoked the profile before it completed. Native tests resolved all twelve Traveller, Mage and Merchant pieces together on the shared rig and checked that equipping a saved outfit preserved the current character's hair.

## Economy and Bazaar

The PostgreSQL test suite ran 235 tests against a disposable database. It covered the closed-market response, repeat purchase receipts, blueprint ownership, timed printing and collection, garment finishes, refusal to list equipped clothing or blueprints, transfer between two accounts, and applying an owned profile scene. Open-market flows used the test policy override.

The desktop build linked the shell and ran the avatar, account and SDK host checks. Two environment-specific native tests skipped (Windows vault and external Godot socket consumer). The handheld game tests used scripted input. A live purchase across two signed-in production handhelds and human controller acceptance remain unverified.

The four Bazaar interiors and their merchant menus were checked on Odin. The before/after contact sheets are in [the Crates branch](https://github.com/EriArk/crates/tree/2b2bfa2/games/bazaar/docs/interiors).
