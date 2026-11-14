# Bazaar services — 14 November 2026

Separate branch/source verification. No production migration/deployment, real
Sparks spending, game save mutation, merge or handheld install.

- [Backend](backend-tests.txt): **201 passed** in a disposable, loopback-only
  PostgreSQL, including rental fees, NPC fee, concurrent buyers, replay, rollback,
  expiry/withdrawal, payload isolation, HTTP validation, operator identity binding,
  official/personal coexistence, and unavailable 50-Spark costumes.
- [Native](native-tests.txt): BackendAccount, Platform SDK real TCP socket and Bazaar
  controller suites pass. TrainerOS application and test targets build. SDK tests
  check credential containment, read pagination, rejection of financial/arbitrary
  URL requests, and profile revocation.
- [Game visuals/checks](https://github.com/EriArk/crates/blob/codex/bazaar-world-20261114/games/bazaar/docs/SERVICES.md): walk-in office, NPC previews, numbered stalls, Back,
  disconnected/confirmed data and leased appearance revocation.

[Contract and unfinished scope](../../../services/backend/bazaar-trading.md).
These tests do **not** demonstrate a paid user journey through the game. That still
requires trusted host write confirmation/recovery, real inventory custody,
costume assets/equip, world launch/admission and reviewed server delivery.
