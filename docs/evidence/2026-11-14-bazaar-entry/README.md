# Bazaar catalogue entry correction — 14 November 2026

The Apps-only installation was the wrong product entry. The owner explicitly
corrected it: the installed island must open from the **Bazaar tab**.

**Online → Bazaar → Official Bazaar** now launches the installed local island.
The card says **ENTER · LOCAL ALPHA**. Without a registered, available launcher,
the existing explanatory placeholder remains. Player bazaars and spending remain
closed. No fictional online realms or occupancy are introduced for a local walk.

The fixed internal desktop ID reuses Apps' existing launch guards, input lease,
window ownership and return behavior. It is omitted from the ordinary Apps grid,
while a running instance remains accessible through Quick Apps. Directory data
cannot supply an executable/command. Launch errors still use the existing owner.
Exiting the game restores the Bazaar tab and the selected official card.
The unrelated pre-existing system application named Bazaar is untouched.

## Source and signed device package

- Feature branch fix: `2f9000bd` on `codex/bazaar-catalogue-20261110`.
- Device-compatible source: `8ca92f5666d58e911a9f14c5542e4720e60f4972`, on
  `codex/bazaar-entry-device-20261114`, based on the installed release checkpoint
  `0cddf297`. Only the entry fix is added; recent Crates artwork/categories,
  resource improvements, branding and PC lifecycle changes are retained.
- Private Software **sequence 43**, version `0.1.0-alpha.8-device.8ca92f56`.
  Reserve **44+** for the next signed device candidate.
- Shell SHA-256: `a32ca8ddc953966e9d6f7172650ff57589e2cdfc8f56431ef527721d42a75462`.
- Signed identity: `a4ae59121901aa65018ac6a874bf37e815fe827763d6fd31c715939814b8a2f0`.
- Only `bin/traineros` differs from the verified sequence-42 payload. Existing
  island **0.0.7** is retained. No public release/feed, Backend deployment or merge.

Do not replace the current device shell with the entire older Bazaar branch:
that would discard unrelated newer delivery changes. This isolated device branch
is the bounded integration, with the same entry fix saved in the feature branch.

## Verification

[Native tests](native-tests.txt): **8 Bazaar tests and 20 Apps tests passed**.
They cover both entry paths, missing-launcher fallback, closed commerce, managed
launch/minimize and Quick Apps access despite the hidden grid row. The existing
[catalogue UI smoke](bazaar-report.json) passed with zero collected QML warnings.
The production ARM64 build uses `BUILD_TESTING=OFF`; fixtures are only in the
separate native test build. [Package evidence](package.json).

Both Flip 2 and Odin 2 were exited through the actual Start → Switch → Desktop
confirmation before activation and resumed through the normal session controller.
Flip used signed managed installation; Odin changed only its existing executable,
with its previous binary saved and verified. Both live shell hashes match above;
Flip reports `first-frame-confirmed` with sequence 42 retained as managed rollback.
SQLite quick_check passed on both and profile/owner/library row counts match
pre-update snapshots. Profiles, games, saves and each character were preserved.

On both devices the official card rendered the new entry label, opened the island
with the local SDK character and returned to the selected card in the Bazaar tab.
Flip used remote pointer activation; Odin used keyboard Confirm. The preview
shortcut is absent from Flip's Apps grid. Odin volume remains zero. Screenshots
include personal state, so they remain private instead of being committed.
Physical controller/touch, sustained performance and listening remain separate
owner acceptance; these checks use remote XTest input on real devices.

Device installation archives, preparation caches and helper scripts are cleaned
up after verification; recovery copies and installed payloads are retained. Odin's
slow microSD write stalled preparation, so temporary unpacking used internal
storage and was removed afterwards. No active game was interrupted.

## Still unavailable

The live shell still lacks the newer `bazaar.read` host capability. Service screens
remain previews; live checkout, save custody, costume delivery, multiplayer and
parallel-realm admission are not enabled. No Sparks were spent. This correction
completes the proper local entry/return path, not those future services.
