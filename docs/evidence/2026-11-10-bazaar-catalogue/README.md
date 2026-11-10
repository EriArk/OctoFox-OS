# Bazaar catalogue — 10 November 2026

Prepared on `codex/bazaar-catalogue-20261110`, based on
`06fa01f642045de92b3e22a623540c914daa293c`. Do not merge this branch in this
preparation chat; the owner will resume integration separately. No handheld
installation, Setup replacement, live Bazaar publication or account charge.

## Scope

The native Online → Bazaar page replaces the empty text placeholder with the
approved fixed official card on the left and a scrolling two-column player grid
on the right. Search, favorites and Create remain outside that scroll area.
The official card uses original generated fantasy cover art, with provenance in
[assets/bazaar](../../../assets/bazaar/README.md). It is not gameplay evidence.

`BazaarCatalogue` owns presentation only. It retains stable card selection,
search/favorites and scroll through the existing per-profile navigation snapshot;
account changes clear its transient state. It does not poll, join a game lobby,
spawn a host, charge Sparks or create a second room/identity service. Normal
production has no player fixtures or advertised live realities. Enter opens the
realm picker directly; without a provider it clearly says no realms are open.
Create explains the future Sparks feature without inventing a price.

The UI fixture contains 14 sample cards and three sample realms (12/32, 28/32,
32/32). Those capacities are test inputs, not the accepted production limit.
Available fixture rows still cannot launch; full rows cannot request entry.

## Verification

Native Release build passed with Qt 6.11.2 in the existing
`traineros-browser-ci:20261110` container (image digest
`sha256:044727eae44f56a49e1c320b4aefcc854e8ee813faf553165f46d647b0de81ef`).
Build/test folders were isolated, with network disabled; another chat's build
was not modified. An intermediate copied object had a stale timestamp and failed
to link after `setScroll` was added; changed sources were invalidated and rebuilt
before the results below. Baseline compiler warnings remain outside this change.

| Check | Result |
| --- | --- |
| `traineros`, `trainer_bazaar_tests`, `trainer_interaction_tests` Release build | Passed |
| Bazaar state tests | 6 passed (including init/cleanup), 0 failed |
| Shared interaction tests | 59 passed, 0 failed; 1 skipped because the separate avatar asset pack is absent |
| Bazaar QML, offscreen/software | Passed, 0 QML warnings |
| Bazaar QML, Xvfb/OpenGL with software GL | Passed, 0 QML warnings |
| Existing Chats QML, Xvfb/OpenGL with software GL | Passed, 0 QML warnings |

The UI checks render 960×540 and 800×450 in light/dark themes. They exercise SDL
virtual controller movement/Back, simulated pointer clicks/wheel, automatic grid
scrolling, a fixed official card, face/snapshot return, shared search keyboard,
favorites/no matches, unavailable creation, empty/error directory, full realm
refusal, Home/Start and global X/Y plus L2/R2. Unit tests also cover stable IDs
through reorder/removal, profile isolation and non-restoration of dialogs/joins.
The small-screen Favorites control was widened after screenshot review.

Reproduce in a Qt/SDL build environment with `BUILD_TESTING=ON`:

```sh
cmake --build build --target traineros trainer_bazaar_tests trainer_interaction_tests --parallel 2
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software ctest --test-dir build --output-on-failure -R '^(bazaar|interactions|bazaar_qml_smoke)$'
```

For Xvfb/OpenGL, run `traineros --online-smoke-test --screenshot-dir <output>`
with `TRAINEROS_BAZAAR_SMOKE=1`, or `TRAINEROS_CHATS_SMOKE=1` for the existing
Chats scenario. Use an isolated XDG config/data directory and no network.
[CTest result](ctest.txt), [Bazaar report](bazaar-report.json),
[Chats report](chats-report.json).

Reviewed screenshots: [catalogue with test cards](catalogue-light.png),
[small dark layout](catalogue-dark-800.png), [realm picker](realms-dark-800.png),
and [normal empty catalogue](empty-light.png). Cards/occupancy on fixture
screenshots are explicitly test data; no player bazaars were published.

## Integration handoff and unfinished acceptance

- Preserve the newer Chats rail, Browser/Files and Apps lifecycle changes during
  later integration. Shared edits are limited to ShellController routing/state,
  OnlinePage, footer hints, CMake and the test dispatcher in Main.cpp.
- Connect the existing directory/Lobby/SDK owners to typed Bazaar records and
  authoritative admission. Raw ordinary game-lobby rows are not Bazaar records.
- Implement the single Bazaar Crate, world/realm destination and return, exact
  installation/launch handoff, empty-instance wake-up and host migration.
- Add one-owner persistent player spaces and an explicit server-validated Sparks
  purchase once the creation price is chosen. Catalogue state is not ownership.
- Verify actual official capacity, realm allocation and migration with real peers;
  current UI occupancy provides no admission guarantee.
- Physical controller/touch, both handhelds, actual gameplay and network acceptance
  remain open. Host screenshots and SDL virtual events do not replace those checks.

The current product decisions and ownership boundaries are in
[BAZAAR.md](../../BAZAAR.md); R147 remains partial, R148 remains unfinished.
