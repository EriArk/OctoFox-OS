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

The source now reads the private server inventory through the existing TrainerOS
account owner. It distinguishes sign-in required, loading, confirmed empty,
connection failure and older-server unavailability. Refresh is in the toolbar;
the loaded/total counter loads another page when available. Select / Up opens
the toolbar and Left/Right reaches these controls on a controller. Search, filters
and sort apply to loaded rows; the status line states when more remain.

No local Party/Box individual is shown as profile-owned. Transfer, return and
trading controls remain disabled. There is no item-creation API or persistent
loot cache. Scope/connection changes clear data and invalidate in-flight requests;
identity changes also clear search/filters. Same-owner query/filter/sort persist
through refresh. Responses after closing the inventory are ignored.

The native presenter accepts no QML mutations of possessions. Isolated fixtures
supply sample records; none are inserted into real profiles. Server presentation
uses bounded text, facts and allowlisted local glyphs; arbitrary URLs/save payloads
never reach QML. Existing Cuboid art remains only in the older isolated creature
layout fixture. The new wire fixtures use unrelated equipment and vehicle kinds.

The private API and schema are prepared and tested, **not deployed publicly** in
this increment. The old server therefore yields an explicit unavailable state.
[Server contract](../services/backend/inventory.md).

## Common item boundary

The profile inventory and future server custody belong to the platform, not to
Pokemon. The shared read contract identifies each recorded item, owner, source game,
adapter/schema version, presentation metadata and allowed actions. Game-specific
payload stays namespaced and opaque to the host. The transfer adapter will validate eligibility,
serialize its own entity and perform protected save removal/restoration through
the existing owner. Another game can describe equipment or other collectibles
without adopting Pokemon fields. The current generic UI consumes facts and
presentation. Private storage/read projection exists; custody issuance and transfer recovery remain unimplemented.

## Next complete path

1. Verify eligibility for a particular Emerald individual and exact save revision.
2. Transfer from the save into server-held inventory through recoverable handoff,
   using the existing save backup/commit/readback owner.
3. Return to a compatible save with capacity; preserve an undelivered item in the
   profile inventory. Repeated requests must not issue a second copy.
4. Add fixed-price Bazaar listings. Listed items cannot return to a game until
   withdrawn; listing/custody/payment share authoritative Backend ownership.

Read-only server inventory is prepared. Save transfer, offline recovery and
listing ownership still need their own implementation/acceptance. A successful
local save edit and a server ledger commit are separate operations; do not claim a single distributed atomic write.
Restoring external copies of offline saves remains a separate duplication/trust
limitation. No new paid features are enabled by this UI.

See [Bazaar](BAZAAR.md), [adapter knowledge](adapters/README.md),
[Emerald evidence](adapters/emerald-en.md),
[current server/UI evidence](evidence/2026-11-14-inventory-server/README.md), and
[the dense layout evidence](evidence/2026-11-14-inventory-density/README.md).
The [13 November evidence](evidence/2026-11-13-profile-inventory/README.md) records
the superseded initial layout, not the current interaction contract.
