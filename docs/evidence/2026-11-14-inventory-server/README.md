# Private inventory reader — 14 November 2026

Separate Bazaar branch, following `f601efdf`. No merge, public backend rollout,
handheld install, save mutation, issuance, trading or paid-feature enablement.
[Native contract](../../PROFILE_INVENTORY.md) ·
[API/storage contract](../../../services/backend/inventory.md).

## Delivered source

- Generic collectible table and owner revision, distinct from shop rights. Game,
  adapter, payload version and kind are explicit; the payload stays private.
- Session-authenticated, no-store `GET /v1/me/loot`, 60 rows per page with revision
  checking. A different owner cannot be chosen by the client. Mutation routes and
  runtime SQL write privileges are absent.
- Native account → profile inventory wiring, refresh/load-more controls, separate
  loading/empty/error/signed-out/unavailable states. The six-by-five grid and
  permanent inspector remain. Search/filter/sort cover loaded items.
- Strict projection parsing, duplicate-page rejection, stale callback fencing and
  owner/connection reset. No persistent loot cache or production sample items.
- Synthetic equipment and vehicle fixtures exercise the generic contract. The
  older creature fixture remains only for dense layout/input regression.

## Verification

All **191 Backend tests passed** against the fixture's own throwaway PostgreSQL 17
with the restricted runtime role. [Output](backend-tests.txt). This includes
migration checks and all existing account/economy/Bazaar suites, plus private
ownership, revision invalidation, cursor bounds, revoked sessions, absent mutation
routes, SQL write denial, corrupt-presentation failure and no payload disclosure.
There is one upstream Starlette/httpx deprecation warning; it is retained in the
log. No external database URL or real user token/save is used by these fixtures.

Native build passed in the existing Linux/Qt 6.11.2 container. All **four focused
CTest suites passed**: `backend_account`, `interactions`, `inventory_qml_smoke`,
`bazaar_qml_smoke`. [Output](ctest.txt). The separate Xvfb/OpenGL inventory run
passed with **zero QML warnings**. [Report](opengl-report.json). These checks use
synthetic controller actions/pointer events, not physical handheld input.

The screen scenario uses the real BackendAccount → ShellController scope →
ProfileInventory composition with an in-memory authenticated transport. It covers
confirmed empty, loading, retry, unavailable old API, generic item rendering,
load-more via pointer and refresh via controller, plus the existing dense grid,
search/filter/sort, global overlays and Back/Home regression. The HTTP API is
separately exercised against PostgreSQL by the Backend suite; this is not a live
OAuth or public internet end-to-end claim. All 17 changed source/test files
[hash-match](source-sha256.json) the remote build/check inputs.

Reviewed OpenGL captures (fictional fixture records, no real possessions):

- [Generic equipment/vehicle grid](server-equipment-800.png)
- [Loading](server-loading-800.png)
- [Confirmed empty](server-empty-800.png)
- [Connection error and retry](server-error-800.png)
- [Older server unavailable](server-unavailable-800.png)

## Remaining acceptance

This is the storage/read side only. No code issues real collectibles yet. The next
functional chain is exact-save eligibility → protected removal → recoverable
server custody → return, with duplicate/retry handling. It must use the current
save owner rather than equating its existing release action with a transfer.
Game-specific item art resolution, listings/payments and external-save duplication
policy remain open. The public API still runs the prior build, so this reader
handles its 404 as unavailable. Physical Odin/Flip controls are not certified.

The earlier unrelated legacy `qml_smoke` failure is still open; see
[adapter-home evidence](../2026-11-14-adapter-home/README.md). It was not rewritten
or claimed green in this increment.
