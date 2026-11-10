# Weekly Bazaar rentals — 10 November 2026

Separate branch `codex/bazaar-catalogue-20261110`, following rules commit
`fd935214a10a0de8ae9e02c7d4a8b0b894a82175`. No merge or handheld installation.
No real-account rental, grant or Sparks transfer was used for verification.

## Prepared behavior

My bazaar / player bazaar details → Trading places → place. The owner sets a
weekly price; another player reviews it and pays for seven days. The UI shows
occupied places and their deadline, provides explicit refresh and resolves lost
payment responses through the existing durable commerce recovery. Controller,
pointer, shared keyboard, Back and Home use the existing native shell paths.
Profile history recognizes rental debits and income without creating XP.

The Backend checks owner, price/revision, balance, visibility/access and vacancy.
Both existing balance accounts are locked in UUID order; receipt, two ledger
entries, balances, place revision, audit and outbox commit together. Concurrent
payments cannot share a place or spend the same Sparks twice. Exact operation
replays recover the original receipt even after expiry or changed terms/access.
The server computes 168 hours from payment. Expiry only releases occupancy; it
never deletes existing inventory or receipts. There is no automatic renewal,
commission, variable duration or tenant ownership transfer.

**No free stalls were invented.** Production provisioning/purchase of stalls is
still future work. Migration and Bazaar creation grant no trading places; runtime
cannot mint them. The menus honestly show an empty list until that purchase path
exists. Tests seed places only inside disposable fixtures. Trade/goods custody
is not implemented; the expiry test preserves an existing purchased inventory
item, not a fictional system for returning goods.

[Product contract](../../BAZAAR.md), [API/storage contract](../../../services/backend/bazaar.md).

## Checks

- [Backend](backend-tests.txt): **181 passed**, one pre-existing Starlette/httpx
  deprecation warning. Offline container, disposable PostgreSQL. Covers payment
  replay, two tenants racing, shared shop spending lock, changed price/access,
  exact seven-day deadline, expiry without inventory deletion, insufficient
  funds, owner-only terms, owner self-rental rejection, strict HTTP inputs,
  immutable receipts/provisioning permissions, rollback on outbox failure,
  private recovery, visibility and paged lists.
- [Native CTest](ctest.txt): **4/4 passed** (38.64 seconds). Backend account, Bazaar presentation, interactions and
  Bazaar QML smoke. Tests lost response/restart with one debit, receipt mismatch,
  storage failure before sending, valid rental history/balance, owner price editing,
  tenant review → controller confirmation → occupied deadline, shared keyboard,
  pointer and Home. The earlier test-transport defect (reading a missing JSON key
  accidentally made an empty receipt nonempty) was fixed, not bypassed.
- [Bazaar OpenGL/Xvfb smoke](bazaar-report.json) and [Chats regression](chats-report.json):
  both passed with **zero QML warnings**.
  These use synthetic identities/transport and virtual SDL controller/pointer;
  they are not physical handheld or real-user payment acceptance.

## Live server

API/worker image `traineros-backend:bazaar-rentals11`:
`sha256:521b96dea5cc30e624e88ad357c83b97696437e4e70aa36f6764535cc3bf6079`.
Before deployment, all 57 Python/SQL baseline files matched the branch. Private
DB and source/compose backups were preserved. A restored isolated copy passed
[migration rehearsal](migration-rehearsal.txt): **18 migrations**, candidate and
compatible rollback ready. Live migration applied; API/DB healthy, worker running.
All **59 Python/SQL files** in both running containers and deployed source match
the candidate. [Public read-only checks](public-check.json) passed, including
unauthenticated rental routes, health/capabilities and hidden internal endpoints.

Rollback `traineros-backend:bazaar-rentals11-rollback` is the previous card/access
application with the 0018 migration manifest. Keep the migrated database and
receipts when rolling back; do not restore an old database over later payments.
Rollback lacks rental routes. Older native clients may reject the new ledger
sources, so matching clients must precede enabling the future stall catalogue.

## Captures

- [Owner's places](places-owner-light-800.png)
- [Weekly price confirmation](rent-review-light-800.png)
- [Rented place and deadline](place-rented-light-800.png)

## Remaining

Stall purchase catalogue/prices and provisioning, actual goods/trading/custody,
Bazaar game world, Lobby/SDK admission/host migration and official realms.
Physical Odin/Flip acceptance remains separate; neither device was installed.
