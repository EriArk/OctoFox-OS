# Alpha 9 release candidate for Armada ARM64

Revision `dcdb2cbacaf5ee5eacd18290d67e64cf2e2773bc`, version `0.1.0-alpha.9`, Software and runtime sequence 63. The public Alpha feed still points to Alpha 8 (49). The Alpha 9 feed, release manifest, Software payload, Full Setup, corresponding source, installation instructions, notices and checksums were prepared as a single candidate.

The shell and game-capture targets were built and installed with CMake 4.3.0, Ninja 1.13.2, Clang 22.1.8, an AArch64 Fedora 44 sysroot and Qt 6.11.2. The cross-build image ID was `sha256:f209c526296bc71a8de199c4673261716b54e8b56f862dc5333750a05318f2b0`. The installed executable and compiled output have the same ELF build ID. The incorporated avatar pack has 56 validated resources. Software uses the established release verification key. The public software archive and release manifest used as the upgrade baseline matched the two published GitHub asset digests for Alpha 8.

## Upgrade and recovery on Flip 2

In a separate installation directory, the existing updater read the exact signed Alpha 9 feed and manifest, downloaded and verified Software, applied 49 → 63, reported the new version as current, rolled back to 49, then reapplied 63. The test save survived. The production managed launcher received its first-frame acknowledgement from the candidate ARM shell. HTTPS requests for the three future release URLs were routed to private staging for this check. The payload and signatures were identical to the candidate assets. The running personal installation was left at 62. System update notifications and actions also passed the native controller and QML scenarios. A second discovery check used each device’s installed Software 62 updater, trusted key, channel history and actual profile schema, with a temporary copy of channel state. Both returned `available` for 63. The current and legacy raw GitHub feed URLs returned identical signed Alpha 8 metadata. Public discovery and anonymous downloads of Alpha 9 can be verified after publication.

## Full Setup

Checking the old signed emulator media uncovered a removed KDE 6.11 commit. RetroArch on Flip 2 uses this runtime, while Dolphin uses KDE 6.10. All eight pinned upstream emulator downloads passed a complete byte-count and SHA-256 check. The replacement KDE 6.11 commit is `2466a2e0700664d03fbe6a105c7fc198bea32618787154f1f2262d23fa1c0284`. Flathub signatures and commit identities were verified. The archive no longer contains Alpha 7’s redundant Software payload and manifest inside `runtimes.tar`; Setup loads its software from `offline/`.

On Flip 2, the full archive was downloaded, checked against SHA-256, and extracted. A new home and an empty installation tree were used on internal storage. The actual graphical Alpha channel selection, confirmation, and progress dialog ran on the device. Setup downloaded the pinned dependencies, built the offline Python environments, deployed the emulators and committed both Software and runtime receipts. The installer and runtime audits passed, all 12 managed Flatpak refs matched their recorded commits, and the private Software launcher received the first-frame acknowledgement. RetroArch from the newly installed Flatpak reported 1.22.2. The privileged runtime helper wrote to an isolated system tree, and the final desktop registration and session handoff were suppressed to preserve the personal installation. A factory-fresh boot and automatic switch on physical hardware were outside this run. The redundant download to Odin’s slow microSD was stopped. The temporary test installations were removed from both devices; Flip reported 16.6 GiB free after cleanup. The private pre-release HTTPS endpoint and tunnels were stopped.

All 14 [GitHub draft](https://github.com/EriArk/OctoFox-OS/releases/tag/untagged-0d8551e91628312b0d9a) assets reached the uploaded state. GitHub reported the expected byte length and SHA-256 for every file, including the full installer (1,892,894,720 bytes) and the Software archive (235,784,652 bytes). English and Russian installation instructions, release notes, dependency sources, notices and checksums accompany the binaries.

## Other checks

Verified 19 packaging, installer, recovery, channel, dependency and Crates suites (230 test cases), including the three OSTree transaction tests rerun in an environment with GPG and Flatpak. Twelve native suites passed, including updates, first run, lobby, netplay, controller profiles, game preparation, browser and files. The graphical update scenario and 24 additional desktop/session supervisor tests passed. The live Crates catalogue verified at revision 51 with 95 packages and returned an unchanged response on the next sync. The account backend readiness endpoint returned ready.

The full installer contains the current compositor configuration. Software OTA updates the signed application payload. Existing older desktop integration can be updated through Setup and Recovery. The unchanged managed Remote Play helper scripts match this revision line for line. The runtime set retains the previous game-capture executable (the subsequent source change renames its PipeWire stream); the Software payload carries the current build. Ship Home and Bazaar use their own Crates packages.

## Full regression run

A native build of the candidate ran all 132 registered CTest suites. The first pass completed with 114 passes and 18 failures. Six suites passed after providing their test dependencies: OpenSSL, a named Unix test user for the installer and visudo tests, and FFmpeg with an X11/OpenGL display for video preview. Six more passed after correcting test navigation to use the current Games launcher, persistent library selection, Home button, Online profile route, Pokémon adapter and achievements menu. Only the test sources changed. The signed release binaries remain pinned to the revision above.

The following six suites are still open:

| Suite | Result |
| --- | --- |
| `netplay_relay` | The mixed ARM/x86 emulator fixture expects different binary identities to join. Both the candidate and the Alpha 8 baseline reject this pair. The two ARM handhelds’ verified two-to-four-player results concern another configuration. |
| `qml_smoke`, `pokedex_qml_smoke` | The candidate and the Alpha 8 baseline reported identical sets of 45 and 119 failed assertions, respectively, in these legacy controller journeys. |
| `persistence_process` | The aggregate test timed out on both builds. The isolated executable produced the experience captures. Its Home scenario reported badge bounds and Journey focus assertions. The 960×540 Home and Journey captures showed all eight badges. |
| `hall_qml_smoke`, `diagnostics_qml_smoke` | Both end-to-end suites failed to complete successfully on both builds. Alpha 8 diagnostics exited with a segmentation fault in the comparison environment. The candidate produced a failed diagnostics report. The separate Hall and diagnostics controller suites passed. |

The combined result is 126 of 132 suites after the environment and test corrections. The six outstanding results remain part of the release decision. Draft asset checks and the physical installer and OTA tests above passed independently.
