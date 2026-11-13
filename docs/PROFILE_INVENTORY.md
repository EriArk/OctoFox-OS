# Profile inventory — 14 November 2026

The inventory belongs to the TrainerOS profile. Bazaar listings and game adapters
will use this inventory; owning or renting a bazaar is not a prerequisite to
holding items. The owner selected Pokémon Emerald as the first and currently only
semantic game adapter in this scope.

## Current source implementation

Profile → Inventory is a free entry beside Wardrobe. The owner rejected the
large three-column cards and separate details page on 14 November. The replacement
uses six columns and five fully visible rows at the 800×450 minimum, with a
permanent inspector beside the grid. Empty cells are visual space, not a capacity
limit or owned possessions. More items scroll vertically.

Only the image, level and a small listed marker occupy each cell. Pointer movement,
touch selection and directional focus update the inspector immediately, without
Confirm or a page transition. The inspector shows name/source, metadata and moves.
Transfer/list/withdraw controls remain explicitly disabled.

The compact toolbar provides shared-keyboard search by name/source, All / Stored /
On sale filtering, and received order / name / descending numeric level sorting.
Sorting retains the selected stable item ID; filtering retains it when present,
otherwise selects the first match. Search and filters persist during a same-owner
visit/return and reset on profile/account change. A search result from an old owner
or a closed page is ignored.

Up from the first row or Select focuses the toolbar; Left/Right choose its controls,
A activates and Down returns to items. R3 opens search directly. Directional
navigation moves through six columns; right-stick scroll reads the inspector.
Back returns straight to the profile Inventory entry. X/Y and Start retain their
system roles and the selected item. Touch/mouse controls use the same presenter.

Production opens an explicit **In development** empty state. It does not claim
that a server returned an empty collection. No local Party/Box individual is
shown as profile-owned; no samples are inserted into real profiles. Transfers,
return to game and trading are unavailable. Profile/Backend identity changes
clear the presentation, search and filters. There is no persistent loot cache or
new HTTP API in this increment.

The native presenter accepts no QML mutations of possessions. Isolated UI/test
fixtures supply sample records and label them **SAMPLE ITEMS** with a sample count. Creature images reuse the adapter's original Cuboid image provider;
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
[current UI evidence](evidence/2026-11-14-inventory-density/README.md).
The [13 November evidence](evidence/2026-11-13-profile-inventory/README.md) records
the superseded initial layout, not the current interaction contract.
