# Personal bazaars — persistent foundation, 10 November 2026

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

## Future additions accepted by the owner

Stalls, shops, decoration and functional upgrades will be separate purchases
attached to the persistent bazaar UUID through the same economy. The owner also
approved renting trading places to other players **for Sparks**. The space/stall
owner and a temporary tenant's trading right must remain separate from each other
and from the realtime host. These are targets, not implemented purchase/lease APIs.
Rent duration, price, renewal, termination/refund rules and the concrete stall
catalogue remain to be agreed; no commission or automatic forfeiture is invented.
Server-side permission/expiry and atomic payment will be required when rentals
are implemented. Existing ownership must survive adding these extensions.

[Product contract](../../docs/BAZAAR.md),
[build, deployment and remaining acceptance](../../docs/evidence/2026-11-10-bazaar-cards-access/README.md).
