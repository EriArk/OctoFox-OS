# Bazaar services — Platform SDK v1

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
Checkout uses the host window and account journal described below.
These reads do not launch a world or authorize admission/multiplayer.

## Checkout

When hello advertises `bazaar.checkout: 1`, a game may request one review with
`bazaar.checkout`. The host re-reads the world and selected offer, shows its own
window and records the account-bound operation ID before sending a payment.
The SDK response contains the outcome. Credentials, private inventory pages and
adapter payloads stay inside the host. Losing the requesting connection dismisses
an unconfirmed review.

| Action | Other arguments | Host action |
| --- | --- | --- |
| rent | slot, price, revision, species, seller_price | Shows the weekly price, keeper fee and total. One transaction creates both. |
| list | slot, price | Owner picks one stored item from their paged profile inventory and can change the proposed price before confirming. |
| buy | slot, listing_id, revision, price | Reviews the current item and price. The backend transfers the existing item. |
| inventory | — | Opens the private profile inventory. The requesting game gets only a viewed acknowledgement. |
| resolve | — | Reviews and resends the exact approved operation from the durable journal. |

Slots are integers 1–12, prices are positive integers, revisions are decimal strings.
The world response includes the current account's `checkout_pending` flag. Each
occupied place can carry a public `tenant_name` and up to three `showcase` entries
with title, game, icon and price. Older hosts may omit the game name. The production Backend's payment policy stays closed.
