# Personal bazaars — persistent foundation, 10 November 2026

> **Current delivery — placeholders, no new Bazaar spending (10 November).**
> The worlds do not exist. The prepared commerce below is disabled by default.
> `bazaar.policy.PAYMENTS_AVAILABLE` is false, with no HTTP or environment switch.
> A new `bazaar.personal` / `bazaar.stall` purchase or rental returns
> `bazaar_under_development` (409) before any charge. Existing exact operation
> replays and receipt reads still recover their original result; acquired rights,
> places, balances and history are preserved. Inventory returns null Bazaar offers
> and `bazaar_payments_available: false`; places never advertise `rentable: true`.
> Other shop purchases remain available. Tests opt in only within isolated fixtures.
>
> The native client independently refuses new Bazaar spending, even with old cached
> offers or an older server. Pending Bazaar payments use GET-only recovery, never
> a retry POST while the worlds are unavailable. Free full-screen previews explain
> official and personal worlds. Prepared owner settings and existing rights remain.
> Do not roll back to an unguarded commerce build; the compatible preview rollback
> retains the same closed payment policy. [Evidence](../../docs/evidence/2026-11-10-bazaar-preview/README.md).

Owner-approved flow: **buy the permanent right for 5000 Sparks, create the one
personal bazaar later whenever convenient, without another charge**. Purchase
needs no name/settings and creates no catalogue row.
The verified TrainerOS account owns the place permanently. A realtime peer host is
not its owner. This increment implements records and owner menus, not the Bazaar
game, realtime admission, peer hosting, migration or official realm allocation.

## Storage and transaction

Migration `0016_bazaars.sql` adds the `bazaar_space` purpose of the existing
`permanent_license`, offer `bazaar.personal`, immutable purchase details and
`bazaars`. A stable UUID identifies the space; unique `owner_id` enforces one per
account and a composite FK binds it to that player's owned item. The runtime can
read/insert rows and update only the name, description, listing/access settings,
revision and timestamp. It cannot transfer the owner, change the offer or delete
purchased spaces. There is no ephemeral host column masquerading as ownership.

`Shop.purchase` remains the transaction owner: authenticate, lock the existing
progression account and offer, compare the reviewed price/revision, check funds
and permanent ownership, then insert the receipt/owned item, debit the
existing append-only reward ledger and publish audit/outbox events atomically.
Any failure rolls back every effect. Concurrent scene/slot/bazaar purchases share
that same account lock. A repeated operation returns its existing receipt;
a different purchase identity with the same operation ID conflicts.

New license purchases store `{}` in `purchases.details`. Old combined receipts
remain recoverable with their exact original details; new purchase requests with
creation details are rejected before charging. Existing spaces/ownership survive.
No new wallet, account or room coordinator exists.

`Bazaars.create` separately authenticates, locks the same progression account,
checks the purchased `bazaar.personal` item and inserts the space/audit/outbox
atomically. It never writes the balance or purchase ledger. Repeats/concurrent
requests return the existing space without overwriting its settings (first creation
wins). Failure rolls back creation only; the paid right remains available.

## API and shell

All Bazaar data routes require an existing account session. No owner/host/balance
is accepted from a client. The auth middleware retains its body and rate limits.

- `GET /v1/me/inventory` additionally returns `bazaar_offer` (or null) and the
  caller's `bazaar` (or null), plus `bazaar_license` (boolean). Retired offers do not erase ownership.
- `POST /v1/me/purchases` keeps operation ID, offer ID/revision and expected price.
  Buy `bazaar.personal` without creation details. The shell stores this exact intent
  through existing commerce recovery **before** sending it.
- `POST /v1/me/bazaars` accepts `name` (1–48 chars), `description` (0–280),
  `listed` (boolean), and `access` (`open` or `closed`). Requires the purchased
  right (`bazaar_license_required`, 409 otherwise), costs nothing, and returns
  the same space on retry. No operation ID is needed for this one-per-owner create.
- `GET /v1/me/purchases/{operation_id}` recovers the receipt and purchased right, whether or not a space exists.
- `GET /v1/bazaars?q=...&after=...&favorites=...` returns at most 24 cards and a
  stable UUID cursor. Query length is at most 64; favorites at most 100 UUIDs.
  Other players see listed places only; the owner also sees their hidden place.
  A UUID or favorite never grants visibility. Names/owner names are literal search.
- `PUT /v1/me/bazaars/{id}` accepts the four settings and expected decimal-string
  `revision`. Ownership is checked server-side. Conflicting changes return 409;
  an identical replay is harmless. Changes cost no Sparks. Events use fresh IDs
  and the bazaar UUID/revision as their aggregate.

Cards report `join_available: false`, `visitors: null`: no fabricated occupancy
or game-start success. `access` expresses the owner's future visitor policy;
`listed` controls catalogue visibility now. Hiding/closing is reversible and never
refunds/deletes the paid place. Official realms remain unavailable in this slice.

Native menus: Buy personal bazaar → price review → explicit purchase → Create
bazaar or Later. Returning/restarting preserves the purchased right. Creation
then asks for name/description via the shared keyboard, listing/visitor settings,
pending-purchase recovery, Save/reload on edit conflict, card details/favorites,
and catalogue refresh/load-more. Controller and pointer use the same actions.
The existing BackendAccount keeps credentials and commerce recovery; BazaarCatalogue
owns presentation/drafts. No arbitrary authenticated URL is exposed to QML/SDK.
Late responses are fenced on account changes; cached ownership is not permission
to spend or edit offline. Catalogue requests stop when hidden; returning reuses
loaded cards/scroll, and explicit refresh fetches current records.

## Card appearance and owner access — next increment

Migration 0017 adds `cover` (`market`, `grove`, `harbor`) and `badge` (`shop`,
`community`, `companion`, `trophy`, `guide`) to the persistent space. They are
optional in create/edit requests; old clients editing four fields preserve the
saved artwork. Unknown IDs/URLs/paths are rejected. Catalogue and owner inventory
return the saved IDs. The native appearance editor previews the same card widget
used in the catalogue; choices remain draft until Save. No extra Sparks are charged.

`bazaar_blocks` stores only `(bazaar_id, player_id)` with creation timestamp.
Only the persistent owner can list/block/unblock. No host authority field is
accepted, and the owner cannot block themselves. Mutations serialize on the
bazaar row, check its expected revision, increment it, and commit audit/outbox
with the change. Identical retries are harmless; delayed opposite mutations
cannot override a newer decision. There is no automatic expiry or fee.

- `GET /v1/me/bazaars/{id}/access?after=UUID&target=UUID`: owner-only blocked
  players, at most 100 per page, UUID cursor, optional selected player status.
- `PUT /v1/me/bazaars/{id}/blocks/{player}`: `blocked` boolean and decimal-string
  `revision`. Returns the updated bazaar and selected player's state.
- `GET /v1/bazaars/{id}/access`: authenticated caller's current `policy_allows`
  and reason (`owner`, `open`, `closed`, `blocked`), plus revision. Hidden spaces
  are not disclosed to non-owners by this route. `join_available` stays false.

A policy read is **not** admission, a reservation, or a host lease. `live_moderation`
is false. SDK/Lobby admission and live removal must enforce/recheck these records
when realtime worlds exist; no successful kick or fabricated roster is exposed.
The owner reaches a specific player from the existing public profile's
“My bazaar access” action, and can restore access from the paged blocked list.
No new social search/account system or technical-ID text entry is introduced.

## Weekly trading-place rentals — 10 November

Migration `0018_bazaar_rentals.sql` stores provisioned `bazaar_places` and immutable
`bazaar_rentals` receipts. No places are granted on migration or Bazaar creation.
Migration 0019 now provisions ordinary places from paid 500-Spark purchases,
as described below. Runtime cannot directly insert/delete places or change their identity,
bazaar, tenant or deadlines. Tests provision fixtures only in disposable databases.
An unset weekly price means the place is not offered yet.

- `GET /v1/bazaars/{id}/places?after=UUID`: authenticated, same catalogue visibility,
  at most 24 places plus cursor. Returns price, decimal-string revision, current
  tenant/deadline (or null), owner flag and caller-specific `rentable`. Closed or
  blocked access cannot rent. Owners cannot rent their own places.
- `PUT /v1/me/bazaars/{id}/places/{place}`: owner sets `weekly_price` (positive whole
  Sparks, bounded to 2147483647) with expected decimal-string `revision`. Identical
  replay is harmless; changed stale settings return 409. Updating the next price
  preserves a current tenant's paid time.
- `POST /v1/bazaars/{id}/places/{place}/rent`: `operation_id` UUID string,
  `revision` decimal string, `expected_price` positive whole Sparks. Duration,
  owner, host, tenant and balance cannot be supplied by the client.
- `GET /v1/me/bazaar-rentals/{operation_id}`: only the paying account can recover
  its immutable receipt, including its exact original payment/deadline.

Rent authenticates, locks both existing progression accounts in UUID order, then
locks the bazaar policy and place. It validates price/revision, access, vacancy
and balance, inserts a receipt for **seven days / 168 hours from server payment**,
adds the debit and equal owner credit to the existing append-only reward ledger,
updates both balances/revisions and publishes audit/outbox atomically. It uses
`bazaar.rent` / `bazaar.rent_income` sources, no separate wallet. Failed writes roll
back all effects; competing tenants and ordinary shop spending share the locks.
Each new rental increments the place revision. Exact operation replays return
that receipt even after expiry/price/access changes, never buy another week.

Occupancy is a read against the server deadline; no polling worker or destructive
expiry task is required. Expired receipts remain history. No inventory or tenant
goods are deleted/transferred on expiry. **Trade and goods custody are still future
work**; preserving existing inventory is not an implemented goods-return system.
No commission, automatic renewal, variable duration or complex refund flow is added.

Native menus: My bazaar / Bazaar details → Trading places → place → weekly price
(owner) or price review → Pay for seven days (visitor). Occupied places show the
local-time deadline. Existing shared keyboard, controller actions and modal Back/
Home behavior are reused. Empty bazaars honestly show no trading places yet.
`BackendAccount` stores rental intent through the same durable commerce recovery
before sending payment. Only an exact receipt or known definitive refusal clears
it; lost replies/restarts retain the operation. Profile history displays rental
debits and owner income. A previous client may not understand these new history
sources; use a matching client for stall purchases.

Future additions remain other separately purchased stall/shop/function types,
their concrete catalogue/prices, goods/trading and actual game-world integration. Permanent owner,
temporary tenant and P2P host remain separate. Existing rights survive extensions.


## Ordinary stall purchase — 500 Sparks once per place

Migration `0019_bazaar_stalls.sql` adds the single `bazaar.stall` offer, purpose
`bazaar_stall`, price **500**, revision 1. It is a permanent owned instance in the
player's created personal bazaar; it does not create another Bazaar license or
`owned_items` row for the repeatable SKU. Non-stall purchase uniqueness is retained
by a partial unique index. All operation IDs keep the existing per-player unique
constraint. Places gain an immutable unique `purchase_id` FK.

The existing `Shop.purchase` authenticates, locks the same account/offer, validates
reviewed price/revision/funds and requires the caller's created bazaar. Within
one transaction it inserts the receipt, provisions one place, writes the existing
`shop.purchase` debit, updates balance/revision and publishes audit/outbox. Any
failure rolls back receipt, place and charge. Replaying an operation returns the
same purchased place; a fresh reviewed purchase can add another. No extra cap,
commission, free starter place or automatic rental price was invented.

Runtime has no direct INSERT permission on places. The bounded SECURITY DEFINER
`provision_bazaar_stall(receipt)` inserts only from an existing `bazaar.stall`
purchase joined to that receipt owner's bazaar. It uses the receipt UUID as the
place UUID, starts with `weekly_price: null`, and returns nothing for an unknown/
unrelated/already provisioned receipt. Host or client-supplied destination IDs
are never used to grant ownership.

- `GET /v1/me/inventory` adds `bazaar_stall_offer` (or null if unavailable).
- `POST /v1/me/purchases`: normal `operation_id`, `offer_id: "bazaar.stall"`,
  `offer_revision`, `expected_price`; no new public purchase endpoint or owner/host
  arguments. `bazaar_required` (409) rejects buying before creating the bazaar.
- Purchase/recovery snapshots include `purchased_place` only for that caller's
  requested stall receipt. Ordinary inventory snapshots do not enumerate all
  places; the existing paged Bazaar places API owns that list.

Native flow: My bazaar → Trading places → Buy trading place → confirm **500 Sparks**
→ owned place → set weekly rent. The shared commerce file saves intent before POST;
restart/lost replies recover the same receipt. The client additionally validates
that the purchased place is bound to that receipt and its own bazaar before clearing
pending state. A missing/mismatched place keeps recovery pending. This slice also
uses non-mutating reads for the optional pending-operation kind, preventing a
synthetic `kind: null` field from leaking into strict shop request bodies. Shop
requests are built from explicit contract fields, so legacy recovery files with
internal metadata can still retry safely. Back/Home cancels an unconfirmed review.

A compatible rollback must reject new `bazaar.stall` purchases and still return
`purchased_place` for existing receipts. The former generic shop cannot safely
interpret this repeatable SKU by itself. Preserve the migrated database, receipts,
places and rentals on rollback. World placement and goods/trading remain separate.
