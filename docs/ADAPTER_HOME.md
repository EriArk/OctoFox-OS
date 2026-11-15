# Adapter home — 14 November 2026

Opening the Adapter tab or its library action opens a three-column sticker home.
Large artwork and separate short labels identify each declared screen. Two rows
fit at the small native viewport; additional rows scroll with touch, pointer or
controller focus. Selecting a button opens the existing full workspace.

L2/R2 cycle every screen in descriptor order after entry. They do not open a
screen from the home. B closes an inner action first, then returns to adapter home
with the last screen selected. B again goes to system Home. The Spaces button
provides pointer/touch return subject to the same modal/write gates. X/Y/Start
retain their global roles. Explicit game actions/deep links can enter a screen
directly; restoring navigation restores home/workspace state. Ordinary tab entry
starts at adapter home while retaining each workspace's local state.

`ExperienceDescriptor.adapter.screens` owns IDs, order, labels, icon keys and an
optional `artwork` URL. The trusted compiled module supplies that URL. The host
contains no game title switches or game-specific screen list. Missing artwork
falls back to the shared icon sticker. Optional art does not grant a capability
or save-write authority. Existing groups stay backward-compatible metadata.

The Pokemon adapter is the first art consumer, with nine original transparent
illustrations generated for this change. An independent fixture adapter checks
that unrelated screen sets and state use the same host. These fixtures do not
claim additional supported games. [Art provenance and prompts](../assets/adapters/pokemon/navigation/README.md).

Profile inventory and future custody remain game-neutral; see
[the shared inventory boundary](PROFILE_INVENTORY.md#common-item-boundary).
No transfer, ownership issuance, listing or spending is activated by this redesign.

[Native validation and screenshots](evidence/2026-11-14-adapter-home/README.md).
