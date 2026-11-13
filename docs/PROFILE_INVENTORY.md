# Profile inventory — 13 November 2026

The inventory belongs to the TrainerOS profile. Bazaar listings and game adapters
will use this inventory; owning or renting a bazaar is not a prerequisite to
holding items. The owner selected Pokémon Emerald as the first and currently only
semantic game adapter in this scope.

## Current source implementation

Profile → Inventory is a free entry beside Wardrobe. The page has a controller
navigable three-column grid and item details: art/name, source game, level, sex,
nature, ability, held item and moves supplied as presentation data. Listed items
have a distinct status. Back returns from details to the same grid selection,
then to the profile Inventory entry. X/Y and Start retain their system roles.

Production opens an explicit **UNDER DEVELOPMENT** empty state. It does not claim
that a server returned an empty collection. No local Party/Box individual is
shown as profile-owned; no samples are inserted into real profiles. Transfers,
return to game and trading are unavailable. Profile/Backend identity changes
clear the presentation and selected detail. There is no persistent loot cache or
new HTTP API in this increment.

The native presenter accepts no QML mutations of possessions. Isolated UI/test
fixtures supply sample records and label them **DESIGN PREVIEW · SAMPLE ITEMS,
NOT OWNED**. Creature images reuse the adapter's original Cuboid image provider;
no new franchise artwork or item/game semantics are embedded into the shell.
The generic item view consumes metadata; it does not implement an Emerald writer.

## Next complete path

1. Verify eligibility for a particular Emerald individual and exact save revision.
2. Transfer from the save into server-held inventory through recoverable handoff,
   using the existing save backup/commit/readback owner.
3. Return to a compatible save with capacity; preserve an undelivered item in the
   profile inventory. Repeated requests must not issue a second copy.
4. Add fixed-price Bazaar listings. Listed items cannot return to a game until
   withdrawn; listing/custody/payment share authoritative Backend ownership.

Server inventory, save transfer, offline recovery and listing ownership need their
own implementation/acceptance. A successful local save edit and a server ledger
commit are separate operations; do not claim a single distributed atomic write.
Restoring external copies of offline saves remains a separate duplication/trust
limitation. No new paid features are enabled by this UI.

See [Bazaar](BAZAAR.md), [adapter knowledge](adapters/README.md),
[Emerald evidence](adapters/emerald-en.md), and
[UI evidence](evidence/2026-11-13-profile-inventory/README.md).
