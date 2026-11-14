# Bazaar rentals, sellers and trading — 14 November 2026

This is prepared source on the separate Bazaar branch, not a live economy release.
`bazaar.policy.PAYMENTS_AVAILABLE` remains false. Exact receipt recovery and owner
withdrawal remain available when spending is closed. No live accounts were charged.

## Accepted rules

- The official Bazaar has the owner's real Backend player identity. He sets weekly
  prices and receives rent through the existing Sparks ledger. It does not consume
  his one personal Bazaar or require a 5000-Spark personal license.
- Rent lasts 168 hours, with no automatic renewal. Existing player-owned Bazaar
  rules remain: one personal right at 5000; an ordinary permanent stall at 500.
- A chosen NPC costs **100 Sparks per rental**, expires with that rental, and is
  not a permanent collection unlock. Selection happens before payment. Replacing a
  paid seller mid-rental is not offered; a retry cannot buy a second seller.
- Players sell already-custodied items from their profile inventory. Item identity,
  game, adapter, kind and opaque payload stay generic. No Pokemon-specific fields.
- Traveller, Mage and Merchant are proposed new avatar costumes, **50 Sparks each
  during alpha**. Their prices/revisions are in existing `shop_offers`. Offers stay
  unavailable, with an additional purchase guard, until actual wearable delivery and
  equip exist. Existing free garments and outfit-save slots are separate products.
- Blueprints, crafting and a personal home like an Orbiter are accepted future
  directions. No recipes, production, home ownership or costs are implemented here.

## Ownership and persistence

Migration 0021 adds per-rental sellers, listings and immutable trade receipts,
linked to the existing reward ledger. Runtime can update only loot owner/state;
it still cannot insert/delete items or edit payload/presentation. The existing
revision trigger now runs as its owner to update private inventory revisions;
runtime cannot forge revision rows.

A listing references one real inventory item and one active rental. It requires
that rental's paid seller and a stored item owned by the authenticated tenant.
The payload is never accepted from clients or returned publicly. Public listings
return validated presentation only. One active listing per item is enforced by SQL.

Buy locks both progression accounts in UUID order, then Bazaar/place/listing/item.
It checks access, blocked seller/buyer, expiry, listing revision/price, ownership,
funds and balance bounds, and atomically moves the same item, marks the listing sold,
writes debit/credit, receipt and audit. There is no commission. Seller hire debits
100 once and writes a rental-scoped receipt; it does not credit the venue owner.

A lost response is recovered by buyer + operation ID. Reusing that operation for
another price/revision/subject fails. Replays work after spending closes. An expired
lease hides goods from the public storefront; items remain the seller's. Withdrawal
works after expiry, closed access or closed spending and restores `stored`. It does
not manufacture a save-file return or delete the item's original payload.

## HTTP surfaces

All routes authenticate the Backend account; request bodies are strict.

| Route | Meaning |
|---|---|
| `GET /v1/bazaar-worlds/festival` | Owner and twelve mapped places, active rental/NPC, server prices |
| `GET /v1/bazaar-sellers` | Whitelisted native NPC identities, 100-Spark rental offer |
| `POST /v1/me/bazaar-rentals/{id}/seller` | `operation_id`, `species`, revision `1`, expected price `100` |
| `POST /v1/me/bazaar-rentals/{id}/listings` | `operation_id`, owned `item_id`, positive `price` |
| `GET /v1/me/bazaar-listings` | Own history/current listings, including expired rentals |
| `GET /v1/bazaar-places/{id}/listings` | Public active listings |
| `POST /v1/me/bazaar-listings/{id}/withdraw` | Exact listing `revision` |
| `POST /v1/bazaar-listings/{id}/buy` | `operation_id`, `revision`, `expected_price` |
| `GET /v1/me/bazaar-trades/{operation_id}` | Private immutable hire/purchase receipt |
| `GET /v1/bazaar-costumes` | Three unavailable alpha costume offers with server prices |

Listing pages contain at most 24 rows and an optional UUID `next` cursor. Existing
weekly rent/price APIs remain in [bazaar.md](bazaar.md). New goods issuance or
save-import endpoints are deliberately absent.

## Official registration

Migration 0022 separates `official` from `personal` while preserving personal
license FK, one-personal-Bazaar index and paid personal-stall provisioning.
The runtime role cannot create an official row or bind world slots.

`traineros-backend register-bazaar --file <operator-manifest.json>` uses the existing
migration connection, never the HTTP account credential. Manifest keys are exactly
`world_key: "festival"`, `owner_id`, `expected_fluxer_subject`, `name`. It verifies
that existing active player's Fluxer identity, creates the official venue and 12
numbered places atomically, with no price initially. Exact repeats preserve it;
a different owner conflicts. It does not mint a personal license or debit Sparks.
The owner then sets weekly prices through the existing authenticated place API.
After official registration, a compatible rollback must retain the `kind=personal`
owner lookup and personal-stall provisioning filter; older pre-0022 code cannot
safely distinguish the owner's two venue types. Do not drop paid/history tables.

**Not run against production.** Owner identity must be explicitly verified for the
real binding; no account was guessed from a nickname or source checkout.

## Integration and remaining work

The host exposes [read-only SDK methods](../../sdk/BAZAAR.md), not financial writes.
The game has the office, seller previews, goods and tailor surfaces, and applies
server-assigned NPCs. Payment buttons are disabled with a visible explanation.
A self-declared SDK application ID cannot authorize spending.

Still needed for a usable paid journey: host-owned confirmation + durable recovery
for hire/buy/withdraw/listing operations, world admission/launch/return, protected
save-to-inventory custody, real costume assets + ownership/equip, and a reviewed
production registration/deployment. These are unfinished parts of the requested
scope, not tests passed or implemented by the preview menus.

[Verification: 201 Backend tests and native SDK/account/Bazaar suites](../../docs/evidence/2026-11-14-bazaar-services/README.md).
