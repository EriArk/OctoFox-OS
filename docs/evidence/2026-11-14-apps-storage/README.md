# Apps lifecycle and removable libraries — 14 November 2026

Follow-up: [sequence 36, real Windows installer and housekeeping](../2026-11-14-pc-installer/README.md)
supersedes the installed sequence and pending installer statements below.

## Implementation

Apps uses the existing XRes-verified window owner and InputPlumber Home lease.
Normal game windows no longer require WM_DELETE_WINDOW to be discovered;
closing still requests that protocol and never escalates to a process kill.
Native application Minimize returns to the shell after a short window-transition
grace period. Restoration maps parents before dialogs and preserves windows the
application hid itself. Replacement windows are journaled even when app IDs do
not change. A stopped helper reconnects up to three times; thirty seconds of
healthy operation resets that budget. Known running entries remain in Quick Apps
until the recovered helper reconciles their identities.

Launch environments select Xwayland for Qt, GTK, SDL and Firefox. A program that
explicitly forces native Wayland still needs compositor integration; this work
is not a claim of universal third-party compatibility. Save dialogs and refused
close requests remain under the application's control.

Steam desktop shortcuts route to the existing LaunchPreparation/Steam adapter,
not an unmanaged Steam child process. Running Steam, local PC and Crates games
appear in Quick Apps and resume the existing game session. Game Home retains its
existing presentation and protected exit path. Non-installed shortcuts report an
error instead of leaving an unmanaged launch behind.

The Apps helper is installed under share/traineros/integrations in the signed
Software payload. The shell prefers that matching helper; shared session/input
primitives remain in the installed system integration. Software rollback restores
the Apps helper with the binary, without replacing root-owned session helpers.

LibraryMountWatcher checks the removable-mount topology once a second. It queues
availability refresh through the existing storage worker, coalesces repeated
changes, and discovers mounted Emulation/roms, roms and batocera/roms libraries,
including readable read-only cards. On Linux it reads mountinfo before probing
folders: dormant automounts and network shares do not become automatic ROM scan
targets. Availability, ROM scans and launch preparation reject disconnected
removable paths before stat calls can reactivate a missing-card automount. ROM and Steam discovery wait for existing
game, app and library operations to become idle. A topology change invalidates an
in-flight ROM scan before it can publish stale results.

SQLite registrations remain the catalogue source. A version-2 shared artwork
snapshot retains entries from all scanned roots, reads the old selected-root
snapshot on first use, and does not clear other cards during a scan. Reconnection
reuses existing IDs, metadata and history; discovery fills in new files in the
background. No card formatting, save migration or library-wide ROM hashing.
Mounted storage is required: this does not create new system automount policy.

## Build and test verification

- Python Apps lifecycle: 19 tests passed locally.
- Native Qt 6.11.2 and ARM release builds passed for source `7b7050ec`.
- Twelve focused CTest suites ran: Apps, Apps service, Library, storage, process,
  interactions, Steam library, overlay helper, overlay transport, Crates SDK
  launch and Apps/Crates QML smoke. Eleven passed on that run. Library exposed
  stale expectations for game-repair presentation and an absent GameHub page;
  corrected assertions retain the selected game, disabled Play, explanation and
  actual next navigation destination. The final Library run passed 34/34.
- Card A → B → A cache, restart and cancelled-scan cases passed on the host.
  This is not a physical microSD-swap result.
- Additional PC audit: `pc_games`, `pc_import_ui`, `pc_session`,
  `game_performance` and `pc_runtime_downloads` passed (5/5, native host).
  This verifies the existing automated checks, not installation of a real game.

## Installed delivery

Both devices run private Software sequence **35**, source
`7b7050ecd08a13d1efa5a924120d84692dade78c`, version
`0.1.0-alpha.8-device.7b7050ec`. This is not a public Alpha 8 release.

- ELF SHA-256: `c9206a460e8ba251cb5f63385c65d744a8728880900e292440c37ddd7b5eb107`.
- Apps helper SHA-256: `6d96c6bb91fb7024e6ef72abff99e5d4a9033d8b93cff1d688a48c05460c6d53`.
- Signed manifest ID: `7d67947237ea10b48c82e03bed6fb4c5b2ad68d5e153d736b31c355fe7a59b3c`.
- Flip uses its managed Software slot, with `first-frame-confirmed` receipt and
  sequence-34 previous slot. Odin retains its existing in-place installation.
- Final readback on both matched the ELF/helper hashes; SQLite quick_check was
  `ok`. Registrations remained 356 on Flip and 542 on Odin. Shared catalogue v2
  contained 355 entries/one root and 363 entries/two roots respectively.
- Separate profiles, saves and rollback copies were retained. This increment
  did not update Armada, kernel or UFS configuration. Public Alpha 7 is unchanged.
  Sequence 36 or later is required for another signed candidate.

## Real-device observations

Tests used the actual session UI through ownership-checked XTest and the active
InputPlumber lease. They establish compositor/process behavior, not a physical
button or touch acceptance pass. Private captures remain outside the repository
because they contain personal profiles and third-party game artwork.

| Case | Flip | Odin |
| --- | --- | --- |
| Ark launch → Home → Minimize → Quick Apps → same-process return → Close | Passed | Passed |
| KWrite unsaved test document → Close → Cancel preserves document | Passed | Passed |
| KWrite Minimize → Quick Apps → same-process return → discard test text | Passed, including parent and open save dialog | Passed |
| Steam Dead Cells launch → main menu → Home → Minimize → Quick Apps → same-process return → confirmed Exit | Passed | Blocked by two real installations in separate Steam libraries |

Only an untitled document containing `octofox test` was edited and discarded;
no personal document was opened. Final Apps journals were empty on both devices.
Flip's Dead Cells PID/start identity survived minimize/return and disappeared
after the UI exit confirmation. Its actual environment selected CachyOS Proton
11 ARM64, SteamLinuxRuntime_4-arm64 and Armada's generated FEX app config.

Odin's two Dead Cells locations have different device/inode identities; this is
not a duplicate path alias. Neither installation was deleted or chosen silently.

## Windows runtimes and remaining acceptance

- Odin's local Sacred 2 Gold uses GE-Proton11-5-aarch64 through UMU. It reached
  the main menu. Home and the compatibility/runtime screens opened. After
  Minimize, the shell was mapped but the game retained the active X window and
  remained visible. Main-menu captures also showed clipping/scale problems.
  Quick Apps restored the same managed session during the earlier settings
  round trip, but the final minimize/close chain did **not** pass.
- The Sacred session ended before an operator graceful-close request could be
  sent; the identity guard refused that stale request. Shell return displayed a
  long raw Gamescope log in its error notice. Do not claim a successful normal
  exit. Concise failure presentation and the focus issue remain to investigate.
- The owner stopped further Sacred testing and will supply a small free Windows
  game. A real Windows installer journey remains pending; host fixtures do not
  substitute for installing that game through Games → PC → Add.
- Imported PC games expose per-game runtime selection, DXVK/WineD3D and
  Esync/Fsync choices, plus Components and Windows settings. Changes affecting
  compatibility apply on the next launch. No runner/prefix migration or setting
  change was performed during this audit.
- Odin's runtime picker offered GE-Proton and explicitly disabled the installed
  system Proton lacking the required host-native Wine executable. Flip has the
  Steam runtime but no separate local-PC GE-Proton/UMU installation in OctoFox's
  runtime store. Steam success does not establish standalone installer readiness.
- FEX is supplied/configured by Armada/Proton; OctoFox has no dedicated FEX
  settings UI. Steam compatibility selection remains Steam-owned. The generic
  compatibility description currently calls non-PC-local games emulator-managed,
  which is misleading for Steam and remains a UI wording gap.
- Still open: physical microSD replacement, the replacement Windows game's
  installer and lifecycle, FEX/settings application acceptance, native
  Wayland-only applications, and wider third-party compatibility. No multiplayer,
  gameplay-performance or universal-app claim follows from these tests.
