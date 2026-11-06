# r/linux_gaming — Linux system integration angle

> DRAFT, not posted. Check current subreddit self-promotion and AI rules at publication time. Attach an actual TrainerOS shell clip, not an AI render. Replace [ALPHA_RELEASE_URL]. No claim of SteamOS/Bazzite support until an installer is released.

## Title

I started with a Pokémon system and ended up building a controller-first Linux gaming environment (TrainerOS alpha)

## Body

I didn't start by trying to build another Linux desktop or a Steam replacement.

I wanted a handheld system where a Pokémon game's party, storage and activities could live outside the emulator. That grew into a bigger question: could ordinary games, social features and applications all share one controller-first environment?

That's how **TrainerOS** happened. 😁

It's a Linux gaming shell with a game library, collections, several library views, a customizable Start panel, apps, file management and a browser. Steam games are discovered and launched through Steam itself — TrainerOS doesn't try to take over Proton, Steam Input or Steam's installation management.

The odd part is what sits around games:

- A single Lobby that coordinates supported multiplayer routes across RetroArch, PSP, GameCube and other emulators.
- Shared Fluxer chat and calls that can continue while people play different games.
- Game-specific adapters, starting with real Pokémon save data and activities.
- Crates, an installable games/apps/widgets catalogue, and an early local SDK for avatars, Lobby sessions and scorecards.

I've tested a clean one-run setup, game launch, return and reboot on a Retroid Pocket Flip 2 running ArmadaOS. The project has also been exercised on an Odin 2. There are real paired-game results, but I won't pretend that every emulator/game/network combination is solved.

The first public alpha targets **compatible ArmadaOS handhelds**. **SteamOS/Bazzite packages are planned, not available in this alpha.** Original project code is GPL-3.0-or-later; third-party components keep their own terms.

**Code:** https://github.com/EriArk/TrainerOS
**Alpha installer:** [ALPHA_RELEASE_URL]

I'm especially interested in practical Linux handheld feedback: controls, process handoff, game compatibility and what you'd want a game-focused shell to handle without switching to a desktop.
