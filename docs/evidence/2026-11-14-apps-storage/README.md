# Apps lifecycle and removable libraries — 14 November 2026

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

## Verification in progress

- Python Apps lifecycle: 19 tests passed locally.
- Initial native Apps test passed. New card-switch/cache/restart and cancelled-scan
  tests passed. The wider Library suite exposed a stale pre-existing expectation
  of a generic notice instead of the current game-repair result; the test now
  verifies the selected game, disabled Play and explanatory result text.
- Final native/ARM builds and installed-device checks are pending.
- No public release or physical card-swap acceptance is claimed.
