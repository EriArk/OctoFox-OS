# Buy now, create later — 10 November 2026

Owner correction to the [combined foundation](../2026-11-10-bazaar-foundation/README.md):
**buy the permanent right for 5000 Sparks first; create the single personal bazaar
later whenever convenient, without another charge**. Same separate branch
`codex/bazaar-catalogue-20261110`; no merge or handheld installation.

## Behavior

Purchase takes no name/settings, creates no directory record and saves the right
in existing owned items. Inventory exposes `bazaar_license` independently of
`bazaar`. The shell offers Create bazaar / Later after purchase and retains this
state after restart. Only free creation asks for name/settings.

`POST /v1/me/bazaars` checks paid ownership under the existing account lock.
Concurrent/repeated creation returns the one existing space without overwriting
its settings. Creation/outbox failure leaves the purchased right intact. Old
combined purchase receipts remain recoverable, and existing spaces are preserved.
Late inventory responses cannot remove an already acquired permanent right/space.
[Current API and ownership contract](../../../services/backend/bazaar.md).

## Verification and deployment

- Backend: **170 tests passed**, one existing Starlette/httpx deprecation warning.
  Disposable PostgreSQL, network disabled. Includes delayed creation after login,
  absence of a directory row after purchase, no second payment, concurrent create,
  failed creation/retry, unlicensed/forged requests and the shared purchase suite.
- Native Qt/C++ build and [focused CTest](ctest.txt): **4/4 passed** — Backend
  account, Bazaar model, shared interactions, offscreen QML smoke. Covers durable
  purchase recovery across restart and stale inventory responses after creation.
- [Bazaar OpenGL/Xvfb](bazaar-report.json) and [Chats](chats-report.json): success,
  zero QML warnings. New journey: review purchase → buy → Later → Home → return →
  create for free → edit. Fixture account/transport, SDL virtual controller and
  pointer events; no real-account purchases or hardware input acceptance.
- Live API/worker updated to `traineros-backend:bazaar-later11`, image
  `sha256:8e276c1f2ac09de66b3ee329f1a3e9d8483b31aeb1338aa44b5a1bcbaadd8d16`.
  All 56 Python/SQL source hashes match the candidate. API healthy; worker running.
  Prior deployed package checked against branch baseline; private DB and source/
  compose backup retained. No schema change or data rewrite is needed.
- Read-only public ingress check passed: health/capabilities 200, unauthenticated
  account/catalogue 401, private readiness/OpenAPI 404. Existing guarded rollback
  image remains available: it disables Bazaar purchases and preserves records.

## Captures

- [Purchase confirmation](purchase-review-dark-960.png)
- [Purchased: create or later](purchased-later-dark-960.png)
- [Free creation settings](create-free-dark-960.png)

The Bazaar game, SDK admission/return, host migration, stalls, trade and rentals
remain unfinished. No merge, Setup replacement or handheld installation occurred.
