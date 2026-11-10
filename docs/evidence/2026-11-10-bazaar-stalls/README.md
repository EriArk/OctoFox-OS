# Ordinary Bazaar stalls — 10 November 2026

Separate branch `codex/bazaar-catalogue-20261110`, following rental commit
`fefce7ad54a182b49ef407fa5476e922c0d34d2c`. Owner selected **500 Sparks once per
ordinary trading place**. No merge, handheld installation or real-account charge.

## Delivered path

My bazaar → Trading places → Buy trading place → confirm 500 Sparks → owned
place → set weekly rent. A created personal bazaar is required. Each fresh,
confirmed purchase adds one permanent place; exact retries recover the same one.
Multiple places use separate purchases. New places have no rental price until the
owner sets it. World placement and actual goods/trading are separate work.

The existing Shop transaction owns receipt, place provisioning, debit, balance,
audit and outbox. Migration 0019 adds the repeatable `bazaar.stall` SKU while
preserving uniqueness for other licenses and all per-player operation IDs.
Runtime still cannot insert arbitrary places: a bounded SQL function provisions
only from a stall receipt into that receipt owner's bazaar. The immutable unique
purchase FK binds the place to its receipt; a place UUID is its purchase UUID.
No free starter stall, commission or invented weekly price was added.

Native recovery persists the intent before sending, validates the receipt and its
owned place, and retains pending state on missing/mismatched proof. Requests use
explicit shop contract fields, so internal/legacy `kind: null` metadata does not
leak into strict purchase bodies. Back/Home cancels unconfirmed stall reviews.
[Current API contract](../../../services/backend/bazaar.md), [product contract](../../BAZAAR.md).

## Validation

- [Backend](backend-tests.txt): **185 passed**, one existing Starlette/httpx
  deprecation warning. Disposable PostgreSQL, network-disabled container.
  New coverage includes buy-before-create refusal, one paid place per replay,
  multiple distinct purchases, concurrent repeated operations, last-balance races,
  atomic rollback on outbox failure, strict price/owner payloads, private recovery,
  immutable purchase binding, preserved ordinary-license uniqueness, and purchased
  place → weekly rent → owner income.
- [Compatible rollback test](rollback-check.txt): **1 passed**. The
  [explicit isolated check](rollback_check.py) imports Shop from the actual rollback
  image and proves recovery of the paid place with no second debit, while rejecting
  new stall purchases. Run with `python -m pytest` in the isolated fixture image,
  so it imports the staged package rather than an older installed package.
- [Native CTest](ctest.txt): **4/4 passed** (39.59 seconds), covering Backend account,
  Bazaar presentation, interactions and
  Bazaar QML smoke. Covers saved intent, storage failure, lost POST and recovery
  lookup, legacy pending metadata, malformed place proof, multiple purchases,
  cancellation through Back/Home, shared keyboard and the purchase → price → rent
  UI path. [Bazaar OpenGL/Xvfb](bazaar-report.json) and [Chats regression](chats-report.json)
  both passed with **zero QML warnings**. They use synthetic identities, fake
  transport and virtual SDL controller/pointer.
  These checks are not physical handheld or real-user payment acceptance.

## Server delivery

API/worker image `traineros-backend:bazaar-stalls11`:
`sha256:f5552a9c7dd963a76e4df6ca6743d5a280693826c0a67ae50b68812457dd5af4`.
All **59** baseline Python/SQL files matched the branch before deployment.
Private DB and source/compose backups were preserved. [Restored-copy rehearsal](migration-rehearsal.txt)
passed **19 migrations**, with candidate and compatible rollback ready.
Live migration applied; API/DB healthy, worker running. All **60** Python/SQL files
in both running containers and deployed source match the candidate.
[External read-only checks](public-check.json) passed for health, capabilities,
auth requirements and hidden internal routes.

Rollback image `traineros-backend:bazaar-stalls11-rollback` includes the migration
manifest plus a bounded old-Shop patch: new stall purchases are refused; existing
receipts still return their purchased place. An unpatched earlier shop must not
serve the repeatable SKU. Preserve the migrated DB and all purchases/rentals when
rolling back; never restore an old backup over later transactions.

## Captures

- [Empty owned list with purchase action](stalls-empty-light-800.png)
- [500-Spark purchase review](stall-review-light-800.png)
- [Purchased place in the owner's list](places-owner-light-800.png)
- [Occupied paid place after rental](place-rented-light-800.png)

## Remaining

3D placement and the Bazaar game world, actual goods/trading/custody, other stall
and function types, Lobby/SDK admission/host migration and official realms.
Neither Odin nor Flip was installed; physical controller/touch acceptance remains.
