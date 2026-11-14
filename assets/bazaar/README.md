# Bazaar cover art

`official.png` is now a direct Godot render of the playable Festival Park island
(14 November 2026). It replaces the generated concept; `prompt.txt` records only
the superseded historical illustration. The render contains the island’s Kenney
Fantasy Town/Nature and Quaternius CC0 scenery/residents, with no personal avatar.
Reproduce from Crates `games/bazaar/tests/movement_review.gd`; source attribution
and original licence files are retained under that game’s `assets/` and `licenses/`.

The normal catalogue now has two owner-requested, explicitly labelled test-card
previews: Mika uses `island.png`, Ren uses `station.png`. They show the two local
empty starting grounds; no registered venue or player ownership is created. Isolated
scrolling fixtures additionally reuse the existing original profile-scene art.


`grove.png` and `harbor.png` are original player-card illustrations generated with
the built-in OpenAI image_gen tool on 2026-11-10. Full prompts are recorded in
[player-prompts.json](player-prompts.json). No references, third-party characters
or logos were supplied. These free catalogue decorations do not grant any paid
profile scene and do not claim that a playable world has been built. The market
preset reuses `official.png`; all three are bundled under the repository asset terms.

`island.png` and `station.png` are unedited renders of the shipped empty personal
worlds, introduced in Bazaar 0.0.10 (`029ff24`). They replace the previous
Mika/Ren concept illustrations in the catalogue. Reproduce with
`games/bazaar/tests/personal_review.gd`, `--world=island` / `--world=station`.
All new environment geometry and shaders are original project GPL code; the
camera hides the synthetic avatar and HUD before capturing the cover.
