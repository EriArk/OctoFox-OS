# Dense profile inventory — 14 November 2026

Separate branch `codex/bazaar-catalogue-20261110`, following `aa41c0d6`.
The owner rejected the initial low-density grid and separate detail page.
[Current contract](../../PROFILE_INVENTORY.md). No merge, handheld installation,
backend deployment, save editing or payment activation is part of this change.

## Layout and input

Six columns / five full rows at the minimum native viewport; the grid and inspector
stay visible together. Hover, touch and controller movement change the same selected
record. Back returns directly to the profile. Slots carry art/level/listed marker;
the inspector owns names, source and attributes. Search/filter/sort share a compact
toolbar. Stable-ID selection survives sorting; search/filter empty results show no
stale inspector. Scope changes invalidate records and pending search acceptance.
All transfer/list/withdraw actions remain disabled; normal profiles have no samples.

The isolated fixture supplies 36 sample records so the screenshot scenario checks
thirty complete visible cells, scroll beyond row five, direct selection, searches,
listing filters and sorting. Sample metadata remains layout evidence, not game-save
legality or real ownership. Existing original Cuboid illustrations are reused.

## Design references

These informed density and inspection behavior, not copied artwork or a franchise
skin. No external screenshots or assets were added to the shipped application.

- [Diablo II manual](https://download.blizzard.com/pub/misc/Diablo%20II%20Manual.pdf): inspect highlighted items without leaving inventory.
- [Guild Wars 2 inventory](https://wiki.guildwars2.com/wiki/Inventory): compact slots, search and state markers.
- [Final Fantasy XIV UI guide](https://eu.finalfantasyxiv.com/uiguide/equipment/equipment-bag/setting_itemsort.html): expand the simultaneously visible inventory instead of adding page changes.

## Verification

Native Linux build uses Qt 6.11.2 in `traineros-browser-ci:20261110`, with isolated
configuration/data and no personal profiles. Native build passed. All five targeted
CTest suites passed (`backend_account`, `inventory_qml_smoke`, `bazaar_qml_smoke`,
`bazaar`, `interactions`); see [CTest output](ctest.txt). Two existing individual cases
remain skipped: Windows credential-vault regression on Linux and live-game Quick
Looks requiring an avatar pack. Inventory coverage is not skipped.

The Xvfb/OpenGL runs passed with **zero QML warnings** for both
[inventory](inventory-report.json) and [Bazaar regression](bazaar-report.json).
The [source hashes](source-sha256.json) match all eight changed native source/test
files in the final remote build to this checkout. Existing compiler indentation and
headless audio/VDPAU diagnostics are unrelated to these UI results.

The scenario exercises the normal empty state, all thirty cells fitting at 800×450,
immediate controller/hover/pointer-tap selection, scrolling to row six without a
stationary pointer stealing selection, shared
keyboard search, listing filter, sort identity, dark theme at 960×540 and X/Y/Start/
Home/Back routing. Interaction tests also cover R3 with Lobby behind the profile,
no-match selection clearing, descending level sort and stale/closed search rejection.
Pointer taps and controller actions are synthesized; this is host UI evidence,
not physical touch/gamepad acceptance on Odin/Flip.

Screenshots (isolated sample items except the empty state):

- [Compact inventory, 800×450](dense-grid-800.png)
- [Listed marker and inspector](dense-listed-800.png)
- [Sixth row reached by focus](dense-scrolled-800.png)
- [Search](dense-search-800.png) and [On sale filter](dense-filter-800.png)
- [Dark theme, 960×540](dense-dark-960.png)
- [Normal empty profile](dense-empty-800.png)

The actual game-to-profile transfer and server custody are still future work;
the prior no-spending gate stays closed.
