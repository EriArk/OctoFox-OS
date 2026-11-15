# Live Bazaar reads — 14 November 2026

The existing Backend now runs source `3cb40ccd`, image `traineros-backend:bazaar-read14`.
API is healthy; worker is running. [Final verification](deployment.json) records
exact candidate/fallback image IDs and the 23-migration database state.

Festival Park belongs to the real owner of the existing Lobby Directory application.
The application-owner response was checked privately against its configured app ID,
then the exact Fluxer subject was matched to an existing active Backend identity.
No nickname/test-profile guess, new account, wallet grant or loot issuance was used.
Twelve numbered places are registered idempotently; weekly prices are unset.
The owner manifest, account IDs, credentials and backups remain private on the server.

## Verification

- Backend suite: **201 passed**, one existing Starlette/httpx deprecation warning.
- Private production backup restored into an isolated database; all 23 migrations,
  runtime readiness, owner registration, twelve mappings and registration replay passed.
- Compatible rollback retains the full migration manifest and personal-only lookup
  filters, so an official venue cannot masquerade as a personal entitlement.
  Its readiness and the official owner's absent personal venue passed on the clone.
- First activation migrated successfully but operator registration hit file permissions.
  The compatible fallback started healthy. Registration was retried using the normal
  maintenance UID and a readable single-file manifest bind, then the candidate was
  resumed. The final standard `manage.py register-bazaar` replay passed unchanged.
- [Public HTTPS probe](public-check.json): liveness/capabilities pass; private read
  routes require authentication (401); internal readiness/OpenAPI remain hidden (404).
  `bazaar.world_read` and `inventory.loot_read` are enabled; payments/transfers are not.
- Native host socket check `bazaarReadsNeverAuthorizeWritesOrExposeCredentials` passed
  with its mock provider. It is not an authenticated live-account/game HTTP test.
- Game service checks passed: twelve places/previews, queued refresh after tab changes,
  stale-response fencing, server-provided seller prices, failure/revocation cleanup,
  disabled purchases, controller Back and four enterable rooms.

No handheld was contacted or changed. The installed newer shell still lacks the
read bridge; source preparation in this older feature branch is not a deployment
of that shell. No merge or public game release. Preserve the newer shell baseline
when device work resumes.

## Remaining

Authenticated game → native host → live Backend acceptance, recoverable adapter /
profile inventory custody, trusted checkout and costume delivery. Weekly rent is
still the venue owner's choice. The server payment gate stays closed; none of
these read checks proves transfers or purchases are usable.
