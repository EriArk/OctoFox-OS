# Bazaar card appearance and owner access — 10 November 2026

Separate branch `codex/bazaar-catalogue-20261110`, following buy-now/create-later
commit `292bb9004d65baa1c75c702d38482f31ad7dc604`. No merge, Setup replacement,
handheld installation or real-account purchase/moderation test.

## Delivered preparation

Free cover/badge selection previews the actual catalogue card and remains draft
until the owner saves settings. Market reuses the original illustration; Grove
and Harbor are new original images generated with the built-in image_gen tool.
[Assets, provenance and full prompts](../../../assets/bazaar/README.md).
No paid profile scene is granted; no arbitrary URL or uploaded image is accepted.

Catalogue visibility and visitor policy are independent. The persistent owner
manages blocked players through the existing player profile and a paged blocked
list, with explicit block/unblock actions. Account changes clear private access
state. Backend checks ownership, forbids blocking the owner, fences conflicting
changes by revision and commits each mutation with audit/outbox. No Sparks are
charged. Purchase-right and later free creation remain separate.

[Current API and transaction contract](../../../services/backend/bazaar.md),
[product decisions](../../BAZAAR.md).

## Validation

- Backend: **174 tests passed**, one existing Starlette/httpx deprecation warning
  (29.25 seconds). Disposable PostgreSQL, network disabled. Covers artwork
  validation/legacy-client preservation, owner-only access, self-block rejection,
  stale opposite mutations, idempotent repeat, outbox rollback, revoked sessions,
  forged host authority, closed/hidden policy and 101-row pagination.
- Native Qt/C++ Release build and [focused CTest](ctest.txt), **4/4 passed**;
  [Bazaar OpenGL/Xvfb smoke](bazaar-report.json) and [Chats regression](chats-report.json).
  Both UI scenarios passed with **zero QML warnings**.
  The extended Bazaar scenario covers appearance draft/Save, 960 dark and 800 light
  preview, visibility/access controls, existing profile → owner access, block,
  blocked list and unblock. SDL virtual controller/pointer and fake transport only.

## Live Backend

API/worker image `traineros-backend:bazaar-cards11`:
`sha256:b520b0ec6779fa629e7fff7c93c2314d8de0d71dc63b2b5051c07a6efeffee50`.
The pre-deployment package matched the branch baseline. Private database and
source/compose backups were preserved. Restored the private backup into an
isolated disposable PostgreSQL and rehearsed migration **0017**: candidate ready
and compatible rollback ready, **17 migrations**. Live migration applied;
API/DB healthy, worker running. All **57 Python/SQL files** match candidate hashes.
Public HTTPS health/capabilities/auth/private-route checks passed read-only.

Compatible rollback image `traineros-backend:bazaar-cards11-rollback` is the
previous buy-now/create-later application with the additional migration manifest.
Keep the migrated database and stored access/appearance records when rolling
back; old clients preserve appearance columns. This rollback lacks the new access
routes and does not implement game admission. Do not replace later purchases with
an old database backup.

## Captures

- [Card preview, dark 960](card-preview-dark-960.png)
- [Card preview, light 800](card-preview-light-800.png)
- [Player access, light 800](player-blocked-light-800.png)
- [Blocked list, light 800](blocked-list-light-800.png)

## Remaining

Own-image uploads were left for a later increment; this preparation uses ready
illustrations. The game, live roster/removal, Lobby/SDK admission and host migration
are not implemented. Policy reads return `join_available: false` and owner access
responses `live_moderation: false`; these are stored rules, not admission tickets
or successful kicks. Rental terms, stalls/trade and physical handheld acceptance
remain separate work. No fabricated visitors or moderation success is exposed.
