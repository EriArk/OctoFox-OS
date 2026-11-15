# Private profile loot — 14 November 2026


**14 November update:** the read projection remains private and payload-free.
[Prepared Bazaar trading](bazaar-trading.md) now changes owner/state of existing
items and bumps revisions. Runtime still cannot mint, delete or edit payloads.
The older SELECT-only description below records the preceding read-only increment;
no save-import/export custody or enabled transfers are claimed.

This increment implements **read-only storage/projection**, not item issuance or
save transfers. It is deployed to the existing Backend after isolated database tests and a
restore/migration rehearsal. [Live evidence](../../docs/evidence/2026-11-14-bazaar-live-reads/README.md).
Shop licenses (`owned_items`), wardrobe slots and Bazaar entitlements retain their
existing endpoints. Profile loot is free and does not require Bazaar ownership.

## Implemented API

`GET /v1/me/loot` requires a current TrainerOS bearer session. The owner comes
only from authentication. No public-profile / player-ID route exposes loot.
Responses are `Cache-Control: no-store`; existing ingress limits apply.

The version-1 response has `player_id`, decimal-string `revision`, numeric `total`,
up to 60 `items`, nullable decimal-string `next`, and `transfers_available: false`.
Each item contains a UUID `id`, `game_id`, `adapter_id`, positive `payload_version`,
`kind`, `state` (`stored` / `listed`), `received_at`, `presentation`, and empty
`actions`. Listing/withdrawal is prepared in the Bazaar contract; new paid operations remain closed.

Presentation consists of `title`, source title `game`, `subtitle`, a fixed local
`icon` key, optional numeric `level`, and at most 16 label/value `facts`.
It has no Pokemon-specific fields. Icons are `inventory`, `star`, `shield`, `shop`,
`gamepad`, `map`; game-specific art resolution is future adapter work. Arbitrary
image URLs and local file paths are not accepted. Text renders as plain text.
Presentation is strictly validated; corrupt records fail as a service error,
not an apparently empty collection. The opaque `payload` is never selected by
this API and never forwarded into the native view.

For the next page send **both** `before=<next>` and `revision=<revision>`.
Newest received sequence comes first; ordering uses a private monotonic sequence,
not a mutable title or non-unique timestamp. Revision, count and rows are read in
one repeatable-read transaction. Any committed insertion, deletion, edit or owner
change bumps the affected inventory revision. Continuing an old revision returns
409 `inventory_changed`; refresh from the start. Every page authenticates anew.

The native presenter validates the response owner/version, fields, page size,
counts, descending cursors and duplicate IDs before adopting it. It fences old
callbacks on scope change, close or a newer request. A failed next-page read keeps
already loaded items with an explicit error; a changed revision discards the old
chain. Refresh failures do not masquerade as empty. There is no persisted loot
cache. Search, filters and sorting currently cover **loaded items**, stated on the
screen while further pages remain.

## Storage and permissions

Migration `0020_profile_loot.sql` adds `loot_items`, `loot_revisions` and a revision
trigger. Runtime has **SELECT only** on both tables; there are no mint, import,
transfer, listing or delete routes. Neither normal clients nor SDK apps can turn
arbitrary metadata into owned possessions. Tests seed fictional items using the
owner of an isolated throwaway PostgreSQL database, never a production role.
Opaque payload is a bounded JSON object with its adapter namespace and version;
the shared platform does not decode a creature, vehicle or equipment record.

Deploying later requires the usual explicit migration and runtime-grant update
alongside the matching backend build. Startup never runs DDL. Existing schema
history is unchanged. Do not roll an old schema-expecting build onto an upgraded
DB without the existing compatible rollback procedure.

## Remaining transfer boundary

The existing save owner (`SaveBackupService` and its storage implementation)
already has exact-game/source-revision, running-session, backup, atomic replacement
and readback gates. Its move/release operations do **not** establish server custody.
A later transfer must bind one individual and exact source revision to a durable
operation, remove it only through that owner, recover either interrupted side,
and expose custody only after verified removal. Returning must validate the
adapter/version, destination capacity and exact revision, with idempotent recovery.
Listed items must remain locked. Offline save restoration / external duplicates
remain a separate trust limitation. No distributed-atomic-write claim is made.

[Native inventory contract](../../docs/PROFILE_INVENTORY.md) ·
[Evidence](../../docs/evidence/2026-11-14-inventory-server/README.md)
