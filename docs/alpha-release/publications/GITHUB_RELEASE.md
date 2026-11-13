# OctoFox OS Alpha — a home for your handheld games

Formerly TrainerOS. Alpha 7 binaries, installer labels and filenames still use the original name.

English · [Russian version](https://github.com/EriArk/OctoFox-OS/blob/main/docs/alpha-release/publications/GITHUB_RELEASE_RU.md)

OctoFox OS is a gaming shell for ArmadaOS handhelds: your game library, emulators, character profile, apps and conversations in one controller-friendly interface.

This early Alpha is for **AYN Odin 2 and Retroid Pocket Flip 2 running ArmadaOS**. You can already explore the main screens; game and network compatibility still need testing together with the community. This installer does not support installation over Android or a general-purpose Linux distribution.

In this build:

- Updated settings, a clearer System page and the Alpha update channel.
- Minimize apps through Home and return to them through Quick Apps. The browser has controller-driven pointer navigation.
- Chats keeps the conversation list beside the conversation, with a separate navigation rail.
- A short first-run wizard covers connectivity, library, character, appearance and optional accounts. QR codes let you open registration on your phone.
- Import games and BIOS through the interface, launch emulators, use Lobby and try experimental network modes.
- Bazaar has illustrated previews of future worlds. **The worlds are not available yet, and Bazaar purchases are disabled.**

[Odin 2 and Flip 2 screenshots](https://github.com/EriArk/OctoFox-OS/tree/main/docs/alpha-release/publications/screenshots/alpha-7) show the actual build, with captions.

On Flip 2, a single-launch installation, automatic sign-in to the system session, the complete wizard and an ordinary reboot were checked. Odin 2 received an in-place application update with its existing profile preserved. Game launch and normal exit were checked on both devices; this verification did not include a shared multiplayer game session.

## How to install

1. Download **[TrainerOS-Full-Setup.tar](https://github.com/EriArk/OctoFox-OS/releases/download/v0.1.0-alpha.7/TrainerOS-Full-Setup.tar)**. The other large archives with `Sources` in their names are source code for developers; you do not need them to install OctoFox OS.
2. In Armada, switch to **Desktop** and extract the entire archive. Keep the `TrainerOS-Setup` folder intact.
3. Open **Install TrainerOS.sh** as your normal user. If prompted how to open the file, choose to run it. Do not run the entire installer as root.
4. Select **Alpha**, confirm installation and enter your system password in the standard authorization dialogs. Internet access is required: some emulators and dependencies are downloaded from their official sources.
5. Wait for installation to finish. OctoFox OS opens automatically and takes you through its first-run wizard. After the first installation, it becomes the default session; Desktop and Steam remain available.

Allow about **4 GB** for downloading and extracting the archive, plus at least **20 GB of free space on the system drive** for the application, emulators, downloads and recovery. Installation time depends on your connection and storage. Do not interrupt writes or turn off the device during installation.

**Games, BIOS, console firmware and keys are not included.** Add your own files through Import. OctoFox OS emulators use their own data and settings; an existing EmuDeck installation is not replaced.

[Download the English installation guide as plain text](https://github.com/EriArk/OctoFox-OS/releases/download/v0.1.0-alpha.7/INSTALL-EN.txt).

## Accounts

You can skip sign-in for local games. Fluxer provides the online profile, conversations and invitations; RetroAchievements provides achievements; ScreenScraper provides artwork and descriptions, as well as recommended multiplayer metadata. Without ScreenScraper, you can still manually mark a game as multiplayer and check it for Lobby.

## What is still experimental

- A game appearing in the library or a room appearing in Lobby does not mean every game supports network play. Emulator versions, game content and participant settings must be compatible. Compatibility with every platform and network is not claimed.
- Vita3K and RPCS3 open as emulators; installing games inside them remains part of their own interfaces.
- Bazaar previews planned worlds. Visiting worlds, trading and paid places are not enabled yet.
- Beta and Stable are not available yet.
- On stock Armada 20261110 with kernel 7.2.6, Setup applies a narrowly scoped workaround for an observed UFS freeze on Flip 2. This is a temporary kernel-issue workaround, not a new kernel build; its power-consumption impact has not been measured separately. The older Iris video-encoder patch is not included in the stock kernel.

## If something goes wrong

Setup shows an error and the log path. After an interrupted installation, open **TrainerOS Setup and Recovery** and choose to continue or return to the previous installation. Use the same screen for normal removal: personal games, profiles and saves are preserved. Do not manually delete working directories to attempt recovery.

Report problems in [Issues](https://github.com/EriArk/OctoFox-OS/issues). Include your device, Armada and OctoFox OS versions, the screen and a few steps leading to the error. A screenshot is more useful than a long retelling; do not attach passwords, tokens, ROMs, BIOS or private conversations. See the [tester guide](https://github.com/EriArk/OctoFox-OS/blob/main/docs/alpha-release/publications/TESTER_GUIDE.md).

OctoFox OS source code, emulator changes, source code for distributed dependencies and license notices are attached to the release. Checksums for the original release files are in `SHA256SUMS`; GitHub also provides a SHA-256 digest for each release asset.
