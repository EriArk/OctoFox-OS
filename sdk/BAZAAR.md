# Bazaar services — Platform SDK v1

Capability `bazaar.read: 1` exposes authenticated, bounded reads through the
existing local JSON-lines connection. Backend access/refresh credentials remain
inside `BackendAccount`. The SDK app ID is self-declared, not publisher authority.

| Method | Parameters |
|---|---|
| `bazaar.world` | Empty for Festival Park or `{"world":"mika-island"}` for the bound beach island |
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
| festival | game, price | Reviews the current ticket and creates one paid round for the active profile. |
| inventory | — | Opens the private profile inventory. The requesting game gets only a viewed acknowledgement. |
| resolve | — | Reviews and resends the exact approved operation from the durable journal. |

Slots are integers 1–12, prices are positive integers, revisions are decimal strings.
The world response includes the current account's `checkout_pending` flag. Each
occupied place can carry a public `tenant_name` and up to three `showcase` entries
with title, game, icon and price. Older hosts may omit the game name. The production Backend's payment policy stays closed.

## Festival tickets

Hosts advertising `bazaar.festival` version 1 support the following calls.

| Method | Arguments | Result |
| --- | --- | --- |
| `bazaar.festival` | `game` | Current price, attempt limit, payment availability, pending checkout flag and latest round for this player. |
| `bazaar.festival.attempt` | `game`, `ticket`, zero-based `index`, integer `x`, `y` | Updated round with accepted attempts, points, completion and prize. |

Games are `gallery`, `rings`, `golf_local` and `golf_online`. Coordinates use
centimetres in the gallery target plane or on the Wanage counter. A local cup
consumes one attempt at (0, 0). Online cup admission checks the active player's
ticket at `activity.cup.join` and redeems it when Golf enters that match.
A withdrawn player can use their unredeemed ticket at the next registration.

Each game may have one unfinished ticket per profile. Replaying an identical
indexed attempt returns the saved result. Buying a ticket goes through the
native checkout window. The third distinct gallery hit deposits that toy in
the profile inventory in the same transaction that records the hit.

### Personal counter and visits

Hosts advertising `bazaar.counter: 1` support `build`, `weekly`, `withdraw` and `reprice` in the native checkout. Pass `world: "mika-island"` for the island. Slot 1 is the first purchased counter. Only its world owner can build it or change its weekly rent. The tenant controls the keeper and stock. The world response includes the latest sale for the current tenant and the public preview of up to three items. Festival Park returns the current player's won plush titles.

On the island, `bazaar.visit` registers a random per-entry UUID. Poll every three seconds. The oldest present visitor hosts the peer links. Explicit departure or eighteen seconds without a heartbeat releases the role. Each guest receives its own secure-channel invitation. Movement travels over the TrainerOS records transport. Every economic action still requires the authenticated Backend and the appropriate owner, tenant or buyer.
