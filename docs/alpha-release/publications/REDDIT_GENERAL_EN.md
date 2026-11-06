# Main Reddit release story — full project

> DRAFT, NOT POSTED. Use after the public alpha release is verified; replace [ALPHA_RELEASE_URL]. Adjust flair and follow the current community rules. Attach real handheld screenshots/video rather than promotional mockups. All main TrainerOS systems are intentionally included: different opening angles, not amputated features.

## Suggested title

I started building a Pokémon handheld system. It somehow turned into TrainerOS — first public Linux alpha 😁

## Post

Well, this got a little out of hand.

At first, **I was building a system specifically around Pokémon**. I wanted the party, boxes, progress and activities to exist outside the game itself. Then I started asking why the same idea couldn't make the *whole handheld* feel more connected: my games, friends, multiplayer, apps and the things I do between games.

One idea kept leading to another, and that became **TrainerOS**. Today I'm releasing its **first public alpha**. Here's what I ended up building. 😁

## The handheld itself

TrainerOS is a **controller-first Linux gaming environment**. Games are organized by platforms and collections, and you can browse by wheel, list, cover shelves or screenshot grid. The Home screen follows the selected game, while quick drawers bring up recent/favorite games and running apps without forcing a trip through a desktop.

Start is a customizable panel for widgets and device controls. There are also ordinary apps, a file manager, a browser, downloads, and Steam-library integration. Steam still owns its own installs, Proton and Steam Input; TrainerOS brings installed titles into the same game-focused experience. The idea is to pick up the handheld, choose something to play, and come back to your games, people and history when you're done.

## The part that started it: games that extend beyond the game window

The first deep integration is Pokémon. With **supported, exact game builds**, TrainerOS reads actual game saves for party members, boxes, Pokédex progress and milestones. For supported Emerald saves, it can also heal the party, manage members and held items, and buy things in a shop using real in-game currency. Launch Emerald afterward and the game sees the changes.

There's a little **Playroom** where the actual Pokémon in your team wander around and react to each other. I may have gotten slightly carried away with that one. 😁

There are also protected **Nearby Link** activities such as trades, gifts and battles between handhelds. These are separate from normal emulator multiplayer.

The bigger idea is **optional game adapters**: a game doesn't need one just to appear in the library and run, but a supported game can gain its own space and tools around the ordinary save. Future series can have completely different integrations rather than Pokémon features pasted onto everything.

## One Lobby for a ridiculous variety of multiplayer

Retro multiplayer is a zoo: NetPlay, link cables, wireless, PSP Ad Hoc, LAN adapters, arcade links, original online services... I wanted players to deal with *one familiar flow* instead of memorizing the network configuration of every emulator.

Create or join a **Lobby**, invite people, choose a game (or suggest several and vote), prepare local copies, confirm readiness, and have the organizer press **Start**. TrainerOS coordinates whichever supported mechanism is needed underneath.

Actual paired gameplay has already been exercised between a Flip 2 and an Odin 2 with games including **Super Smash Bros. Melee, Contra III, Streets of Rage 2, Mario Kart DS**, and PSP titles such as **Virtua Tennis, Tekken 6 and Killzone**. Those are specific tested routes, not a claim that all games, servers or Internet connections work. There are also experimental Local Lobby, Remote Play and game-viewing routes.

## Friends, chat, voice, and spectators

Fluxer powers friends, direct messages, communities, invitations and group calls inside the environment. A voice call can continue even when different people leave a game or start playing something else.

During a supported game there's a compact overlay for chat, participant avatars, voice activity and microphone controls. Watching a supported game stream doesn't require installing that game yourself. I wanted hanging out and playing to feel like one activity, not two unrelated apps.

## One player identity across games

TrainerOS has a **shared customizable 3D character** with outfits, hair, face expressions and animations. Games can use the same character and appearance through the SDK instead of creating separate avatars. **Pocket Golf** is already a working example.

You can even install **Companion**, a little Home-screen character based on your own avatar. It rests, looks around, reacts to notifications, and celebrates achievements by holding their real icons over its head. It's basically a low-maintenance tamagotchi. 🤣

Your profile also gathers RetroAchievements, gaming history, screenshots, trophies, outfits, levels, XP and experimental **Sparks** currency. For supported achievements, TrainerOS can save the actual screenshot of the moment you earned one. I like the idea that a console should help you keep memories of games, not only launch them.

## Crates: games, apps, widgets — and the SDK underneath

**Crates** is the installable project catalogue. A Crates game joins the ordinary Games library, an app joins Apps, and a compatible widget appears on system screens. It isn't another isolated launcher.

The experimental catalogue already includes things like **Pocket Golf**, **Micro Rally**, Pocket Artillery, Pong, Snake Arena, Light Cycles, Brick Tanks and more.

Pocket Golf has actual 3D greens, ball physics, shared TrainerOS characters and supported online matches. Micro Rally somehow grew from a small racer into a driving/combat game with suspension, weapons, arena battles, Battle Royale and even a long Nordschleife finale. Yes, the name is still *Micro*. 🤣

The **TrainerOS SDK** lets other developers connect their own games or apps to the shared avatar, Lobby, admitted multiplayer channels, match scorecards and widgets. Games keep their own engine and gameplay — they don't need to rebuild the surrounding social and platform infrastructure.

## Where this could go

I'm also designing **Bazaar**: shared spaces where players could meet, show off characters and items, take part in activities and jump into games together. That's a direction I'm building toward, **not a feature included in this alpha**.

What keeps me interested is the combination: games, people, avatars, achievements and little activities all becoming part of one gaming environment instead of separate utilities.

## The first public alpha

**The first installer targets compatible handhelds running ArmadaOS.** It installs over that Linux environment; it is **not an Android APK**, a universal handheld firmware image, or a SteamOS/Bazzite installer. Broader Linux installers are planned separately.

This is an **experimental alpha**. Several real game/device scenarios have been tested, but others are early integrations. I'd love reports about specific handhelds, games, controls and networking setups — **successful launches are useful reports too**.

TrainerOS is free, and the source is available. If you enjoy this slightly ridiculous project, you can help by testing, reporting bugs, joining the community or sharing the project.

**Alpha:** [ALPHA_RELEASE_URL]  
**Source:** https://github.com/EriArk/TrainerOS  
**Discord:** https://discord.gg/xBN9DXt8Q  
**Support:** https://www.patreon.com/AbyssTail/membership

Development disclosure: I use Codex/AI-assisted tools as part of the development workflow, with project design decisions and device testing guided by me.

Have fun breaking things — just please tell me how you did it! 😁
