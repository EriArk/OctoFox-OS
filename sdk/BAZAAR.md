# Bazaar reads — Platform SDK v1, separate branch preview

Capability `bazaar.read: 1` exposes authenticated, bounded reads through the
existing local JSON-lines connection. Backend access/refresh credentials remain
inside `BackendAccount`. The SDK app ID is self-declared, not publisher authority.

| Method | Parameters |
|---|---|
| `bazaar.world` | `{}`; the registered `festival` world |
| `bazaar.sellers` | `{}` |
| `bazaar.costumes` | `{}`; unavailable offers, no wearable delivery yet |
| `bazaar.listings` | `place_id` UUID, optional `after` UUID |
| `bazaar.own_listings` | optional `after` UUID |

Results use the [Backend projections](../services/backend/bazaar-trading.md).
A missing binding is `world_not_configured`, not twelve free stalls. Sign-out,
network errors and an empty confirmed shop are distinct. Responses over 60000
bytes or with another player identity fail; credentials/URLs cannot be supplied
in params. One service request is outstanding per connection. Profile/account
revocation discards callbacks and closes the connection.

`bazaar.buy`, `bazaar.rent`, `bazaar.hire` and arbitrary URLs are **not supported**.
There is no wallet authority or financial consent based on a game/app name.
A trusted host confirmation/durable recovery path is still required for writes.
These reads do not launch a world or authorize admission/multiplayer.
