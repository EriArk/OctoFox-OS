# Profile inventory UI — 13 November 2026

Separate branch `codex/bazaar-catalogue-20261110`, following `f4af1d8e`.
[Contract](../../PROFILE_INVENTORY.md). Native UI preparation only; no merge,
handheld installation, backend deployment, save edit or Sparks charge.

## Scope

Free Inventory entry beside Wardrobe in the existing profile. Honest development
empty state; three-column grid and detailed item presentation exercised with
isolated, explicitly labeled sample Pokémon. Controller/pointer navigation,
scrolling, listed status, Back focus return, Home, Start and global docks retain
existing shell ownership. A local profile or signed-in Backend identity change
clears the old presentation. The inventory has no production sample injector,
file writer, possession mutation or payment action.

Existing original Cuboid art is rendered through the same adapter image provider.
Fixture artwork is symbolic; fixture records are not user-owned game individuals.
All actual game-save transfer and server-held item ownership remain unimplemented.

## Validation

The native application and focused test targets built in the isolated existing
Qt CI container. The original touched source files matched branch `f4af1d8e`
before staging; all **12 changed native files** match the final tested source. [CTest](native-tests.txt) passed **5/5** suites: inventory and
Bazaar QML smoke, Bazaar model, Backend account and shared interactions. After a
small compact-layout/scrollbar refinement, the affected [inventory test](layout-test.txt)
passed again. The final [OpenGL inventory run](inventory-report.json) and
[Bazaar regression](bazaar-report.json) succeeded with **zero QML warnings**.
Existing compiler indentation warnings remain outside this increment.

Visual checks at 800×450 and 960×540 covered light/dark themes, readable facts,
scrolling, empty-state honesty and visible system docks over the inventory.
Fixture screenshots explicitly identify sample items. Their fabricated metadata
is layout evidence, not valid game-transfer payloads or adapter legality proof.

- [Profile entry](profile-entry-960.png).
- Empty state: [960×540](inventory-empty-960.png), [800×450](inventory-empty-800.png),
  [dark](inventory-empty-dark-800.png).
- Fixture grid: [960×540](inventory-grid-960.png), [scrolled 800×450](inventory-grid-scrolled-800.png).
- Fixture details: [960×540](inventory-detail-960.png), [800×450](inventory-detail-800.png),
  [listed/dark](inventory-listed-dark-800.png).
- [Quick Apps overlay](inventory-dock-800.png) preserves the selected item.

Physical Odin/Flip acceptance is not claimed; neither device was installed.
Server custody, save transfers, receipts and actual trades remain next work.
