# Bazaar creation and Backend foundation — 10 November 2026

Prepared in `codex/bazaar-catalogue-20261110`, following catalogue commit
`049d08e69a33d54c91920020865af186f20a2cc2`. No merge, Setup replacement or handheld
installation. The Backend API/worker were deployed separately to the existing server.

## Delivered slice

One permanent personal bazaar for **5000 Sparks**, enforced server-side. Native
Create/My bazaar forms, shared text keyboard, price review, durable purchase
recovery, catalogue visibility/visitor settings, free edits with version conflict
handling, card details/favorites and paged authenticated directory. Existing
Backend account, inventory/purchases and append-only ledger remain the owners.

[Contract/API](../../../services/backend/bazaar.md), [product target](../../BAZAAR.md).

## Verification

- Native Release build: `traineros`, `trainer_account_tests`,
  `trainer_bazaar_tests`, `trainer_interaction_tests`, Qt/C++ in the existing
  pinned `traineros-browser-ci:20261110` image. Network disabled during checks.
- [Focused CTest](ctest.txt): **4/4 passed** — Backend account, Bazaar model,
  shared interactions and offscreen QML smoke. Account tests include durable-intent
  failure, lost response/restart recovery, exact receipt validation and free edits.
- [Bazaar OpenGL/Xvfb smoke](bazaar-report.json) and
  [Chats regression](chats-report.json): success, **0 QML warnings**. Bazaar
  traverses catalogue, realms, shared keyboard, explicit purchase confirmation,
  settings, conflict and Home return; SDL virtual controller and pointer events.
  Inspected 960×540 dark and 800×450 light captures. These are deterministic fake
  accounts/transports, never real purchases or hardware input acceptance.
- Full Backend pytest: **169 passed**, 1 existing Starlette/httpx deprecation
  warning (28.43 seconds), disposable PostgreSQL, network disabled. Includes
  concurrent/different-shop spending, one-owner limit, exact replay, atomic failure
  rollback, ownership/edit permissions, hidden records, pagination, stale prices,
  insufficient funds, receipt recovery and forged HTTP fields.
- A QML activation binding loop found in the initial run was fixed with deferred
  binding evaluation; the full focused checks and both UI smoke runs passed again.

## Server delivery

Live API and worker image `traineros-backend:bazaar11`:
`sha256:126fc61492c5070bc273ae1240933d73940e5e775a83e367b1576e986aead37d`.
The existing production package matched the pre-change branch baseline before
replacement. A private database backup and previous source/config were preserved.
Migration 0016 applied; API/DB healthy, worker running. All 56 deployed Python/SQL
source files match the branch candidate hashes.

Read-only external HTTPS check (`deploy/check-public.py --accounts`): health and
capabilities 200, unauthenticated account/catalogue 401, private readiness/OpenAPI
404. New capabilities are `bazaar.catalogue=1`, `bazaar.management=1`; these do not
advertise game admission. No production user was created, funded or charged.

Restored the private pre-deployment backup into an isolated temporary PostgreSQL
container and rehearsed migration: 16 migrations, candidate ready, rollback ready.
Preserved `traineros-backend:bazaar11-rollback`: previous application plus the new
migration manifest and an explicit rejection of `bazaar.personal` purchases.
This prevents the older shop from charging for a license without creating its
bazaar record. The rollback rejection was executed and verified. Normal rollback
keeps the migrated database and purchased records; do not restore the old backup
over later purchases. Live migration/backup details stay private on the server.

## Captures

- [Creation form, dark 960](create-form-dark-960.png)
- [5000 Sparks confirmation, dark 960](create-review-dark-960.png)
- [Saved settings, light 800](manage-light-800.png)
- [Version conflict, light 800](manage-conflict-light-800.png)

## Remaining

No Bazaar game/SDK launch-return, peer admission/host migration, official realm
allocation/occupancy, stall purchases, trade or rentals. The owner approved future
renting of trading places for Sparks; terms and implementation are still pending.
Persistent ownership and tenant trading rights must stay distinct from temporary
network hosting. Live multi-account purchase/recovery and physical handheld
controller/touch acceptance remain untested; no device build was installed.
