# r/foss — open-source project and architecture angle

> DRAFT, not posted. Check subreddit rules at publishing time. Replace [ALPHA_RELEASE_URL]; link to the source repository. The GPL license covers original TrainerOS code, while bundled third-party components follow their own licenses.

## Title

[Release] TrainerOS — a GPL-licensed Linux handheld gaming shell with a shared Lobby and app SDK

## Body

Hi! I've been working on **TrainerOS**, a controller-first gaming environment for Linux handhelds.

It began as a Pokémon-focused project that could interact with supported game saves outside the emulator. Since then, it's grown into a broader shell with game collections, apps, widgets, Steam library integration, multiplayer and an early platform SDK.

A few things that make it a little different:

- **Shared Lobby:** one user-facing workflow over various existing emulation multiplayer mechanisms, with compatibility checked per game/runtime.
- **Game adapters:** supported games can expose real progress, party/storage and activities outside their game window. The current deep integration is Pokémon.
- **Crates:** an install/update flow for games, applications and widgets that join the ordinary system library.
- **Local SDK:** JSON-based integration for avatar appearance, widgets, admitted multiplayer activity and match scorecards.
- **Separate runtimes:** the ArmadaOS installer provisions its own managed emulator environments without adopting or overwriting an existing EmuDeck setup.

The original TrainerOS source is **GPL-3.0-or-later**. External emulator and asset licenses are documented separately; no commercial ROMs or BIOS files are provided.

The first **experimental alpha** targets compatible ArmadaOS handhelds. A single-launch clean install and reboot have been checked on a Flip 2; broader device and game compatibility are still a community-testing effort.

**Repository:** https://github.com/EriArk/TrainerOS
**Alpha:** [ALPHA_RELEASE_URL]

I'd especially welcome feedback on the SDK design, managed runtime isolation and the approach to making game integrations optional rather than a requirement for ordinary launching.
