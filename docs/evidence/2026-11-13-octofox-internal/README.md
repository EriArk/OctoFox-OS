# OctoFox OS internal rename — 13 November 2026

The owner requested the same public rename inside the application. The native
shell, first-run wizard, account actions and login pages, settings, notifications,
game-return windows, session/desktop entries and Setup/recovery messages now use
OctoFox OS. New Setup/download artifacts use the new name.

The implementation retains stored application identities, package/signature
contracts, keychain services, multiplayer/SDK protocols and existing paths.
[Compatibility details](../../BRANDING.md) list the intentional legacy names.
No profile, game, BIOS, save or credential migration is needed for these changes.

## Verification

- Full Linux x86_64 Release build with Qt Quick 3D and WebEngine enabled, using
  the existing `traineros-browser-ci:20261110` builder in an isolated work folder.
- Backend: **188 tests passed**, including the additive publisher migration,
  third-party exclusion, unchanged offer IDs/prices/receipts and repeatability.
  [Test output](backend-tests.txt). No running backend or production database was
  changed during this verification.
- Packaging: 21 isolated Python test modules, 251 tests; three environment skips
  in the real Flatpak-repository suite. One process-environment timing failure in
  runtime maintenance passed on the complete isolated rerun (27 tests). A native
  container rerun passed all 27 tests. The initial combined-process
  attempt was discarded because Crates and Software both import `installer`;
  suites must run in separate processes. Disk-space tests used a disk-backed
  temporary folder, since the workstation's `/tmp` had less than 2 GiB free.
- Additional focused checks: 28 overlay-helper tests, 8 Steam-shortcut tests and
  the legacy desktop-shortcut upgrade test passed. Legacy and new archive roots
  are accepted; mixed roots, traversal, symlinks and modified files are rejected.
  Legacy Steam entries keep AppID/ownership, game history and user tags.
- Native regression groups: **12 groups passed**, including focused reruns after
  correcting stale expectations. [Initial output](native-tests-initial.txt),
  [corrected test rerun](native-recheck.txt). Groups cover software updates, backend accounts, social/lobby,
  runtime multiplayer, standalone launch, storage, first run, game exit and overlay
  behavior. Two old test expectations were corrected to match existing Home
  behavior: a confirmed launch selects the Home game, and modern per-game
  navigation supersedes legacy face aliases. Production navigation was not changed.
  The native builder lacks the `openssl` command, so packaging tests were run on
  the workstation instead; the backend test image was also suitable for the
  runtime-installation suite but lacks the full Setup test prerequisites.
- Generated backend contracts and adapter knowledge/export checks passed. The
  portable runtime source snapshot was refreshed to the current implementation;
  this also brings its previously stale runtime-isolation copies up to date.
- Native GUI scenarios for first run, settings and software updates all exited
  successfully under Xvfb/OpenGL, with no QML warnings reported by the scenarios.
  [Scenario exit codes](visual-result.txt). Installer/system actions use fixtures;
  this is not a real OTA application, live login or handheld installation.

## Rendered screens

These are the actual newly built native application with disposable test data,
not handheld captures or a published release. The update version/download values
are explicit fixtures. Welcome, compact dark/large-text accounts and update
confirmation were visually checked for readable, unclipped branding.

- [Welcome, 960×540](screenshots/wizard-welcome.png).
- [Accounts, dark/large text, 800×480](screenshots/wizard-accounts-dark-large.png).
- [Software updates, 960×540](screenshots/software-updates.png).
- [Restart confirmation, 960×540](screenshots/update-confirmation.png).

## Delivery boundary

Source/build verification only. No handheld was contacted or modified, no kernel
or Armada package was installed, and no live server deployment or database
migration was performed. Published Alpha 7 assets, their signatures/checksums and
existing device builds are unchanged. A new signed installer/OTA release and
physical device acceptance remain separate delivery work.
