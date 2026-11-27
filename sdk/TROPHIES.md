# Game trophies

A game defines a trophy by its stable game ID and trophy ID. The SDK returns the definition together with the signed-in player's current eligibility. Ship Home reads the same evidence to display a cup, medal or plaque. This contract uses personal awards. It does not mint inventory, Sparks or tradable loot.

## Register a definition

Ship a JSON definition with the game. The service operator reviews it and runs `traineros-backend register-trophy --file <path>` with the migration connection after applying the schema and runtime grants. Register a scorecard ruleset before any trophy that depends on it. Repeating the same registration is safe. Changed definitions require a new trophy ID. [Pocket Golf example](../services/backend/registry/trophies/pocket-golf-club-isles.json)

| Criterion | Evidence |
| --- | --- |
| `confirmed_win` | A confirmed winning side in the specified registered ruleset for this game. Every member of the winning team qualifies. Ties and pending, disputed or voided matches do not count. |
| `verified_event` | A game-specific trusted service verifies an objective, then calls `play.trophies.attest(conn, player, game, trophy, evidence_uuid)` inside its transaction. It can withdraw that proof. Other valid proofs retain the trophy. Use `ruleset: null`. |
| RetroAchievements | The collection also reads existing verified prize facts under keys such as `ra.123/beaten`. This namespace is reserved. |

For example, a single-player exploration game could register an `island-survey` plaque and have its survey validator attest the completed journal. The validator must derive the player and objective from authenticated, verified records. Only its trusted database role needs write access to trophy proofs. The public API and SDK offer read access.

## Read from a game

After the usual protocol-1 handshake, check `trophies.game: 1`. Send `trophies.list` with optional `limit` (1–50, default 24) and `after` (the opaque `next` value from the prior page). The host supplies the game's namespace. Rows contain `key`, `game_id`, `id`, `title`, `shape`, `criterion` and `earned`. Missing sign-in and unavailable service are different from a successful empty list. Games can continue playing locally in either case.

```python
if client.supports("trophies.game"):
    page = client.trophies()
    for trophy in page["items"]:
        print(trophy["title"], trophy["earned"])
```

Godot activities can use their existing SDK bridge:

```gdscript
if bridge.capabilities.get("trophies.game") == 1:
    bridge.request("trophies.list", {"limit": 12}, func(result: Dictionary, error: String):
        if error.is_empty():
            show_trophy_page(result.items, result.next)
    )
```

Read again after the game's validator confirms or withdraws a result. `play.submit` receipts acknowledge a submission and can precede confirmation. The service evaluates current evidence on each read, including for previously completed matches.

## Ship Home

The host exposes `trophies.collection` only to the ship launched with its session key. It returns earned rows across games. An exact `key` lookup restores a saved display reference. Pagination by `after` browses the physical shelf one trophy at a time. The home save stores the key per local profile. The ship rechecks it on entry and once per minute while selected. A disconnected shelf hides the model and keeps its selection for reconnection.

[Three display models on Odin 2, using test awards](../docs/evidence/ship-collections-20261127/trophies.jpg)
