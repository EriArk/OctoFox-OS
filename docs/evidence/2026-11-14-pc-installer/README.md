# Windows installer and handheld housekeeping — 14 November 2026

## Follow-up: bounded exit fix

The owner requested fixing the close issue without extensive game-specific
investigation. A temporary status-only trace on Odin established that the primary
UMU/Proton process exited **0**, while one adopted child exited **255**. The old
supervisor incorrectly promoted that child status to the whole session's result.
The instrumentation was removed after diagnosis; Quill itself was not modified.

Commit `c6728a74` uses the primary runner's result for Proton, which is explicitly
launched with `waitforexitandrun`. It still waits/reaps all children. Nonzero
runner exits remain failures; native detached-child failures and cancellation
keep their previous semantics. No exception for a specific game or code 255.
Proton output now has a 64 KiB retained tail and one private last-session log per
prefix, with concise UI failure text. This avoids both raw driver-log popups and
unbounded diagnostic files. Log-write failure does not alter the game result.

Installed `/var/opt/traineros/pc/launch.py` on **Odin and Flip**, SHA-256
`903a8fe8eda3f8abf79b955dc38a05f67ec8d7047302226562ce071610d13f3e`.
Retained the original helper and recorded the replacement in Flip's managed
session ownership journal. This is an installed **system integration patch**;
the signed Software shell remains sequence 36, and no new public installer,
bootstrap bundle or Software sequence was published. Source Setup will include
the helper on its next packaging; reinstalling the old published Setup can
restore its older helper. Reserve sequence 37+ as before.

Validation: 21 PC session tests passed locally and against the installed helper
on each handheld. They cover helper failure both before/after the runner,
nonzero primary status with noisy output, bounded/private logs, detached native
failure, cancellation and isolated prefix behavior. The 21 Apps helper tests
also passed locally. On Odin, actual library launch reached Quill's main menu;
Home → Exit → Leave returned to the library **without an error notice** and no
remaining PC session. The final 6,568-byte log recorded `runtimeExit: 0`,
`childFailure: 255`, `sessionExit: 0`, with mode 0600. This supersedes the earlier
Quill close failure below, not the other pending acceptance items.

Temporary test folders, status tracing and remote screenshots were removed from
both devices. Original helper rollback and the small bounded runtime log remain.
No deep Quill/FEX investigation, game patch, suspend test or compatibility-wide
claim. Full standalone Windows installer acceptance on Flip remains separate.


## Delivered change

On Odin, starting a Windows installer on sequence 35 hid the shell before Wine
had created a window. Slow microSD prefix preparation left the last frame visible
and made Cancel unreachable. Apps now retains the shell/input until it discovers
an owned installer window, then performs its existing foreground transition.
Unrelated windows and exited/reused process identities cannot trigger activation.
The existing between-window installer lifetime is unchanged. All 21 Apps helper
tests passed, including delayed first-window and exited-root cases.

Private Software sequence **36**, source `f318474d316ad0fa1dbc27b682830c24daae9a9d`,
version `0.1.0-alpha.8-device.f318474d`, is installed on **both Odin and Flip**.

- Manifest identity: `495d71b03a73ce29a834c9c1aeb8baa1d45875f1347cde716220f4856d2adbeb`.
- Apps helper SHA-256: `a9e4464245155cae57a07583a773c62dd8959e27a20a218162914145671690b7`.
- ELF SHA-256: `c9206a460e8ba251cb5f63385c65d744a8728880900e292440c37ddd7b5eb107`.
  This Python-only fix deliberately reuses sequence 35's tested ARM binary from
  `7b7050ec`; it is not a new C++ compilation.
- Flip has `first-frame-confirmed`, with sequence 35 retained as previous.
  Its old session left a boot fence after desktop transition; a normal systemd
  reboot cleared it before activation. The fence was not bypassed/deleted.
- Odin retains its in-place installation and verified sequence-35 backup.
- Running helper and executable hashes matched on both. SQLite quick_check was
  `ok`; game registrations ended at 543 on Odin (one new Quill) and 356 on Flip.
  Both Apps journals were empty; no test game session was left running.
- No Armada/kernel/UFS update, suspend test or public release. Next signed
  candidate must use sequence **37 or later**.

## Quill installation and launch on Odin

The owner requested a small free itch.io Windows game. Downloaded
[Quill by PlayMek](https://play-mek.itch.io/quill), its actual Windows NSIS setup,
using the public author download. Original filename: `quill Setup.exe`;
49,955,732 bytes; SHA-256
`726e71f16ed2ec32f280c9ed5354b4a15c7b0005233759b8b0b4e4c00f64d0c1`.
No game binary/artwork/profile screenshot is included in this repository.

The first microSD attempt exposed the missing-window bug above. It was cancelled
and discarded through the recovered UI; the owned incomplete SD destination was
verified absent. The source download and unrelated games were preserved.

On sequence 36, Games → PC → Add → Install → file picker → Internal storage →
Start installer retained the shell during preparation. GE-Proton11-5-aarch64
through UMU 1.4.4 installed the game and automatically launched it. Main menu and
first playable room rendered. After a normal owned-window close, the supervisor
returned code 255. OctoFox kept the files and offered **Inspect files**; through
that UI, `quill.exe` was selected, the name changed to Quill with the shared
keyboard, and **Add to Games** created the registration. No database injection,
manual copying of game files or hand-created registration was used.

The candidate list also showed updater/elevation/uninstall executables. It does
not yet rank the likely game executable first. The code-255 screen included raw
Gamescope output and is not an acceptable polished error presentation.

From the new library card, launch reached the main menu. Home → Minimize returned
to an active shell; Quick Apps displayed the running/minimized game and restored
the **same** managed session (PID 609770/start 10220921). Home → Exit → Leave
ended that session and returned to the shell. However, the resulting notification
again exposed raw Gamescope output. Therefore launch/minimize/return passed, but
a clean, error-free close journey is **not** accepted. The issue reproduced on a
second launch; no global Wine kill or forced application termination was used.

These checks used the actual handheld UI via ownership-checked XTest and its
active InputPlumber Home lease. They are not a physical controller/touch pass,
a sustained gameplay/FPS benchmark or a universal Windows compatibility claim.
The installer-autolaunched game was closed with WM_DELETE_WINDOW; its physical
Home chord and pointer mapping were not independently exercised in this pass.

## Runtime/settings check

The imported game selected GE-Proton11-5-aarch64, its own Wine prefix, and the
runtime's generated FEX app configuration. Compatibility → Esync/Fsync → Disabled
→ Apply & save persisted. A fresh UI launch actually inherited both
`PROTON_NO_ESYNC=1` and `PROTON_NO_FSYNC=1` in the Proton/FEX process environment.
The setting was then restored through the UI; persisted `sync` was verified as
`auto`. This does not establish NTSync disablement or a performance difference.
No renderer/runtime migration, extra Windows component installation or dedicated
FEX configuration UI was tested. Steam settings remain Steam-owned.

Flip's standalone installer/runtime acquisition is still unvalidated: its prior
audit found no separate OctoFox GE-Proton/UMU installation, and the observed Games
platform list did not expose an empty PC entry. Its earlier Steam Dead Cells
result remains separate evidence, not proof of this standalone installer path.

## Internal storage cleanup

The owner's recurring housekeeping preference is recorded in AGENTS.md for both
handhelds. Inventoried explicit project-owned targets, checked process/file/mount
references and preserved active data and one working rollback. Removed obsolete
build trees, old delivered binary copies, retired staging/runtime copies and
completed download/extraction staging. Preserved current runtimes, current and
previous managed versions, profiles, games, saves, BIOS and kernel recovery.
No blanket cache deletion or removal of the user's Steam installations.

Initial cleanup freed 5.57 GiB on Odin and 10.85 GiB on Flip. After sequence 36
validation, its archive/preparation cache, temporary device captures and copied
Quill source installers were removed on both. Quill remains installed on Odin;
its runtime and prefix are working data. Local private test evidence is retained.

Final free internal space: **10.11 GiB Odin**, **22.74 GiB Flip**, versus initial
4.13 and 11.86 GiB. These are live filesystem readings; reflinks/deferred frees
mean summing apparent directory sizes is not equivalent to bytes recovered.
Private deletion manifests/readbacks remain in each device's
`~/.cache/octofox-housekeeping-20261114/`.

## Remaining work

Investigate the PC supervisor's exit status (it currently aggregates adopted
child failures), separate useful failure text from driver logs, and improve
executable selection. Do not suppress genuine failures merely because a close
was requested. Complete standalone runtime/installer acceptance on Flip and
physical controller acceptance. Sacred-specific focus/clipping, physical card
replacement and broader application compatibility remain as recorded in the
[previous Apps/storage pass](../2026-11-14-apps-storage/README.md).
