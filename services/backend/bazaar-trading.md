# Bazaar rentals, sellers and trading — 14 November 2026

Read services are deployed on the existing server; this is not a live economy release.
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

**Registered on the live server, 14 November.** The Lobby Directory application
owner was verified through Fluxer and matched to the existing Backend identity.
Twelve places are mapped; their weekly prices remain unset. The deployment
maintenance wrapper is `python /ops/manage.py register-bazaar /ops/official-owner.json`
on the normal maintenance UID, with a read-only single-file manifest bind.
Exact replay was verified. [Deployment evidence](../../docs/evidence/2026-11-14-bazaar-live-reads/README.md).

## Integration and remaining work

The host exposes [SDK reads and host-reviewed checkout](../../sdk/BAZAAR.md).
The game has the office, seller previews, goods and tailor surfaces, and applies
server-assigned NPCs and projects active listings onto counter signs. Payment controls require host checkout support and an open server policy.
A self-declared SDK application ID cannot authorize spending.

Still needed for a usable paid journey: in-world withdrawal of unsold items, world admission/launch/return, protected
save-to-inventory custody, real costume assets + ownership/equip, and a reviewed
production registration/deployment. These are unfinished parts of the requested
scope, not tests passed or implemented by the preview menus.

[Verification: 201 Backend tests and native SDK/account/Bazaar suites](../../docs/evidence/2026-11-14-bazaar-services/README.md).

### Staffed checkout in the test market

`POST /v1/bazaars/{bazaar_id}/places/{place_id}/staffed-rental` accepts the rent
operation body plus species and seller_price. Both receipts share the operation ID
and commit in one transaction. A failed keeper hire rolls back rent and owner income.
`listing_id` optionally filters a public counter's listing read for host review.

The optional CMake target `bazaar_trade_lab` uses the same PlatformHost, account
checkout and QML window as TrainerOS with a disposable loopback Backend.
Build with `-DTRAINER_BUILD_BAZAAR_TEST_HOST=ON`. In the backend test image,
`PYTHONPATH=. python tests/market_lab.py /tmp/market-wallets` starts a new private
PostgreSQL cluster, seeds 1,000 test Sparks per visitor, and sets stall 02 to 150.
Give each test host only its own generated wallet as a private `session.json` in
its lab directory. Forward the loopback port 18641 to that device, then run
`bazaar_trade_lab Mika /absolute/lab/directory 18641` (Ren on the other device).
The game's field menu detects the host at
`$XDG_RUNTIME_DIR/traineros-bazaar-lab/sdk/endpoint.json`. For automated runs the
game accepts `--test-market` and a separate `TRAINEROS_TEST_MARKET_ENDPOINT`.
The rehearsal drives the displayed window through its controller actions. The
buyer host can drop a committed reply with `--drop-buy-response`. After host
and game restart, Resolve uses the saved operation and the same receipt.
