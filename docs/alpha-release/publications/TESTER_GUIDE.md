# OctoFox OS Alpha — Tester Guide

> **OctoFox OS Alpha is experimental.** This release is for people to explore the system on real devices, try their own games and setups, and report what works or breaks. You don't need development skills or a long test checklist.

English · [Russian](TESTER_GUIDE_RU.md)

**Download Alpha 7, installation instructions and known limitations:** see the [official release](https://github.com/EriArk/OctoFox-OS/releases/tag/v0.1.0-alpha.7). This release supports Odin 2 and Flip 2 running ArmadaOS. The [installation guide](GITHUB_RELEASE.md#how-to-install) is available in English. Avoid third-party mirrors.

## Just try what you care about

Install using the instructions for your device, open OctoFox OS and explore Games, controls, Crates, Home, Social, Lobby or widgets. If you're interested in multiplayer, invite a friend and try a game. Some platforms, games and connection methods are still experimental. Successful unusual setups are useful feedback, too.

## What makes a helpful bug report?

A few sentences are enough: **what you tried → what happened → what you expected**. Device model and game/platform names are the most useful details. All other information is optional.

- **System/UI:** device and OS, OctoFox OS version if known, screen or button, reproduction steps.
- **Game:** title/platform/region or edition if known; audio, visuals, controls, launch, saves or exit problem.
- **Multiplayer:** game and edition, NetPlay / native LAN / Remote Play / Local Lobby, number of players, host vs guest, **same Wi-Fi vs different internet connections**, and where it failed (Lobby, Ready, Start, game menu or actual gameplay).
- **Crates:** package name, Download / Update / Play / Remove, exact error if shown.

Screenshots, short clips and logs are welcome, **not required**.

### Copyable report

```text
Device / OS:
TrainerOS version (if known):
Feature / game / platform:
Steps:
What happened:
What I expected:
Reproducible? (always / sometimes / once):
Multiplayer (if relevant): host/guest, player count, same Wi-Fi or separate networks
Screenshot / short video / log (optional):
```

## Where to send it

- [OctoFox OS GitHub Issues](https://github.com/EriArk/OctoFox-OS/issues) — best for reproducible bugs and tracking fixes.
- [Community Discord](https://discord.gg/xBN9DXt8Q) — best for quick help and discussing a reproduction.

If an issue already exists, add your exact device/steps there rather than opening a duplicate.

## Privacy and save safety

**Please do not upload** ROMs/ISOs/BIOS, commercial game files, account tokens, passwords, private keys, private chat logs or personal save files. Remove sensitive paths, addresses and credentials before posting diagnostics.

Back up important saves before experimenting with imports, updates, removal or multiplayer save operations. You do not need to risk personal data just to file a report. If you suspect save loss, stop repeated attempts and report what happened.

## Especially valuable experiments

The highest-value everyday scenarios are installation, controller behavior, launching a game and exiting safely, Crates and playing together. More adventurous experiments—different ISPs/NAT types, uncommon devices, unusual controllers, rejoining an interrupted session, mixed platforms—are very welcome **after release**, not release requirements.

One clear report with reproducible steps can make a big difference.
