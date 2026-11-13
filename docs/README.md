# OctoFox OS documentation

English · [Russian technical index](README_RU.md)

## Install and use OctoFox OS

- [Alpha 7 download and release notes](https://github.com/EriArk/OctoFox-OS/releases/tag/v0.1.0-alpha.7).
- [Installation, accounts, recovery and known limitations](alpha-release/publications/GITHUB_RELEASE.md) — English; [Russian version](alpha-release/publications/GITHUB_RELEASE_RU.md).
- [Tester guide and bug reports](alpha-release/publications/TESTER_GUIDE.md) — English; [Russian version](alpha-release/publications/TESTER_GUIDE_RU.md).
- [Current handheld screenshots](alpha-release/publications/screenshots/alpha-7/README.md) — English captions; [Russian captions](alpha-release/publications/screenshots/alpha-7/README_RU.md).

## Build and extend OctoFox OS

[Build and run from source](DEVELOPMENT.md) · [Contributing](../CONTRIBUTING.md) · [Start an external game, app or widget](../sdk/README.md).

The SDK is a v1 preview; see [implementation and remaining contracts](PLATFORM_SDK.md). Public installation and tester guides above are in English. Many engineering contracts and historical records below are still in Russian or mixed languages; they are not required to install the release.

## Maintainer entry points

| Question | Document |
| --- | --- |
| Working rules | [AGENTS](../AGENTS.md), [development workflow](DEVELOPMENT_WORKFLOW.md) |
| Product direction | [Product architecture (Russian)](PRODUCT_ARCHITECTURE_RU.md), [screen decisions](PRODUCT_SPEC.md), [design language](DESIGN_LANGUAGE.md) |
| Feature ownership and integration | [Structure map (Russian)](STRUCTURE_MAP_RU.md): entry/exit contracts, dependencies, lifecycles and code |
| Readiness and outstanding acceptance | [Feature readiness](FEATURE_READINESS.md), [current tasks](CURRENT_TASKS.md) |
| Tested games and known problems | [Multiplayer game verification](MULTIPLAYER_TESTED_GAMES.md) |
| Delivered work | [Project status (Russian)](../PROJECT_STATUS.md) |
| Change history | [Changelog (Russian)](../CHANGELOG.md), [main commits](https://github.com/EriArk/OctoFox-OS/commits/main/) |
| Feature requirements | [GitHub issues](https://github.com/EriArk/OctoFox-OS/issues) |
| Implementation and builds | [Architecture](ARCHITECTURE.md), [development setup](DEVELOPMENT.md) |

[Requirements coverage (Russian)](REQUIREMENTS_COVERAGE_RU.md) maps 256 issues, with the 24 October #257–259 addition, to stable readiness R-IDs, S-owners and F-flows. Superseded decisions and open acceptance conditions remain separate from actual implementation.

A current contract takes precedence over an old report; the owner's latest explicit decisions take precedence over a conflicting issue. PRODUCT_SPEC contains a short supersession table. Source implementation, installed builds and actual acceptance are different levels of evidence.

## Technical references — read for the task at hand

These references retain Russian and mixed-language engineering text.

- Launch: [platform register](LAUNCH80_PLATFORM_REGISTER.md), [launcher audit](LAUNCH80_LAUNCHER_AUDIT.md), [emulator standard](EMULATOR_STANDARD.md), [multiplayer matrix](EMULATOR_MULTIPLAYER_MATRIX.md), [emulator maintenance](emulators/README.md).
- Data: [data model](DATA_MODEL.md), [persistence](LOCAL_PERSISTENCE.md), [save lineage](SAVE_LINEAGE.md), [backups](SAVE_BACKUPS.md), [exiting an adventure](ADVENTURE_EXIT.md).
- Adapters: [knowledge registry](adapters/README.md), [framework boundaries](UX_FRAMEWORK.md).
- Communication: [Social](SOCIAL.md), [Fluxer capabilities (Russian)](FLUXER_CAPABILITIES_RU.md), [Lobby](LOBBY.md), [account-free Local Lobby](OFFLINE_LOBBY.md), [Remote Play](REMOTE_PLAY_TRANSPORT.md).
- Apps: [Files](FILES68_IMPLEMENTATION.md), [Browser](BROWSER71_IMPLEMENTATION.md), [Crates installer](CRATES76_INSTALLER.md), [catalogue](CRATES77_CATALOGUE.md).
- Device: [Armada platform](ARMADA_PLATFORM.md), [diagnostics](DEVICE_DIAGNOSTICS.md), [performance](PERFORMANCE72.md), [display scaling](DISPLAY_SCALING.md), [input profiles](INPUT_PROFILES.md), [per-game performance and runtime cache](GAME_PERFORMANCE.md).
- Release engineering: [earlier installer contract (Russian)](EARLY_BETA_INSTALLER_RU.md), [public readiness](PUBLIC_READINESS.md), [licensing](../LICENSING.md), [third-party notices](../THIRD_PARTY_NOTICES.md). Use the Alpha 7 guide above for installation.

Dated technical records preserve specific checks, hashes, limitations and recovery details. Their old next-step proposals are not the current work queue. Links to `blob/<commit>/…` are immutable historical evidence, not current contracts. Intermediate screen plans, issue copies and earlier queues were removed from active documentation on 18 October and remain in Git history. The historical AGENTS archive is retained; removed intermediate plans are not restored.

## Agreed future contracts

- [Account and economy (Russian)](TRAINEROS_ACCOUNT_ECONOMY_RU.md), [Backend (Russian)](TRAINEROS_BACKEND_PLAN_RU.md), [Crates storage (Russian)](CRATES_SERVER_STORAGE_RU.md).
- [Bazaar](BAZAAR.md), #262–264: the catalogue and colorful future-world placeholders are included in Alpha 7. Purchases and rentals remain disabled until worlds exist; prepared economy, rights and settings are preserved. World admission, hosting and trading remain unfinished.
- SDK #235–244, PC #246–251 and Picker #252–254 are tracked in their current issues. An agreed target does not imply an installed feature.
