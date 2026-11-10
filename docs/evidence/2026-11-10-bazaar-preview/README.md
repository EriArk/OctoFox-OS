# Bazaar world placeholders and no-spending gate — 10 November 2026

Separate branch `codex/bazaar-catalogue-20261110`, following `a21ad56f`.
The owner clarified that the worlds do not exist and requested colorful explanatory
placeholders, with no spending on unavailable content. This supersedes enabling
Bazaar licenses, stalls and rentals in the preceding preparation increments.
No merge, handheld installation, real-account charge or refund was performed.

## Delivered behavior

Official Bazaar, the personal-bazaar teaser and player cards open full-window
illustrated previews. Large **PLACEHOLDER**, **UNDER DEVELOPMENT** and **NOT A
PLAYABLE WORLD YET** labels distinguish plans from gameplay. Official preview:
connected fantasy squares, walking as your character, meetings and parallel realms.
Player preview: a personal gathering space, visitors and trading stalls. Preview
access is free and works without sign-in. The existing fantasy art is reused;
[provenance](../../../assets/bazaar/README.md) is unchanged. No fabricated 3D world,
active visitors, trade, realm admission or launch success is shown.

The catalogue keeps its fixed official card and scrolling player cards. Its empty
player side is now an illustrated, explicitly marked teaser. Back/Home closes the
preview, Start overlays it, and existing global docks/face navigation retain their
owners. The full-window preview is native QML, not a browser/web page.

## No new Bazaar charges

Production `bazaar.policy.PAYMENTS_AVAILABLE` is false, without an environment or
HTTP switch. New license, stall and rental payments return
`bazaar_under_development` before debit/provisioning. Inventory advertises no Bazaar
offers and places are not rentable. Exact previous operations/receipt reads remain
recoverable; existing rights, places and history are not deleted. Ordinary profile
purchases continue to work. No database schema or balance migration was needed.

The native client independently blocks Bazaar review/confirmation/rent against
cached or older-server offers. Pending Bazaar operations recover with GET only;
there is no fallback payment POST. Prepared paid-flow regression tests use an
explicit isolated Services fixture opt-in; it is not a user/runtime/SDK setting.
Backend legacy tests similarly opt in only inside monkeypatch fixtures, while new
default-policy tests verify the real closed behavior.

[Backend tests](backend-tests.txt): **187 passed**, one existing Starlette/httpx
warning. Includes blocked old-client POSTs for both purchase SKUs and rent, no
balance changes, preserved old purchase/rental receipts and inventory, ordinary
shop spending unaffected, plus the prepared commerce regressions.

## Native validation and screenshots

Release host build completed in the existing isolated Qt CI container. The focused
[CTest run](native-tests.txt) passed **4/4**: Backend account commerce/recovery,
Bazaar catalogue, shared interactions and the Bazaar QML smoke scenario. The final
[OpenGL Bazaar scenario](bazaar-report.json) and [Chats regression](chats-report.json)
report success with **zero QML warnings**. Existing compiler indentation warnings
and host multimedia diagnostics are separate from those QML checks.

The UI run covers anonymous and signed-in previews, controller and pointer Back,
Home/Start, X/Y docks over the preview, fixed official/scrolled player cards,
search/favorites, preserved scroll and refusal of direct paid actions even when an
old test provider advertises offers. Visual inspection caught and corrected a dock
handle covering the warning; the closed handles now stay hidden in the full-window
preview. Opening X/Y uses the usual system panels without closing the preview.

- Official: [960×540](official-preview-960.png), [800×450](official-preview-800.png).
- Player: [960×540](player-preview-960.png), [800×450](player-preview-800.png).
- Catalogue: [empty preview](catalogue-preview-960.png),
  [dark fixture cards](catalogue-dark-800.png), [scrolled cards](catalogue-scrolled-800.png).

Captures use original bundled artwork and isolated fictional account/card fixtures.
They demonstrate native rendering/input on the build host, not handheld acceptance.

## Server

API/worker: `traineros-backend:bazaar-preview11`, image
`sha256:af6c7ee08e48c98041109e05bd44d2051d50c47a3bb678b5d69114cdb85b037c`.
Baseline source was checked against the branch before replacement; private DB and
source/compose backups remain on the server. Schema stays at **0019**. API/DB are
healthy; worker is running. Both running containers and deployed source match all
**61 Python/SQL files**. [Public read-only checks](public-check.json) passed and
capabilities report Bazaar payments/rentals/stall purchases disabled.

Compatible rollback `traineros-backend:bazaar-preview11-rollback` is based on the
previous application **with the same payment guards retained**. Both images were
checked to import the false production payment policy. Do not use an unguarded
older image: it could re-enable spending. No restoration of old balances or
purchase records is part of this delivery.

## Remaining

The actual Bazaar worlds, playable character movement, realm allocation, hosting,
3D placement and goods trading are still unimplemented. Paid functions remain
closed. Device acceptance on Odin/Flip remains separate; this branch was not merged
or installed on either handheld.
