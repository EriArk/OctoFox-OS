# DuckStation — ordinary standalone launch

## Owner-authorized direct delivery — later on 3 November 2026

The owner chose automatic original-source download followed by local configuration.
The hybrid runtime now carries a descriptor, not DuckStation's binary. Setup fetches
GitHub release asset `673935636` directly from stenzek/duckstation and verifies its
87,900,416 bytes and SHA-256 before activation. The actual download matched the old
installed AppImage. PS1 multiplayer remains PCSX-ReARMed. This supersedes the pending
choice below, not the author's redistribution restrictions. Managed activation of
the new Setup is still pending. [Evidence](../evidence/2026-11-03-hybrid-runtime/README.md).

## Distribution review — 3 November 2026

The full installer candidate contains the AppImage with embedded commit
`dd4a0eb779296a525f8b10b6d9a45911ad6d088f`. Its exact upstream LICENSE is
CC-BY-NC-ND-4.0; the same revision's README considers preconfigured settings/packages
modifications. Keeping the executable bytes unchanged alone is insufficient to clear
the configured TrainerOS bundle. Owner choice between a separately obtained external
installation and separate permission for the configured bundle is pending. Existing
installations/memory cards and public-candidate composition are unchanged; no message
to upstream was sent. PS1 PCSX-ReARMed remains a distinct supplied route.
[Exact sources, SHA-256 and proposed choices](../evidence/2026-11-03-appimage-provenance/README.md).

## LAUNCH-80 integration, 18 October 2026

TrainerOS reuses the installed DuckStation package without emulator patches.
The common standalone adapter launches CUE/CHD/PBP/M3U/EXE with literal argv
`-batch -fullscreen -- CONTENT`, following the
[upstream CLI](https://github.com/stenzek/duckstation/wiki/Command-Line-Arguments).
Discovery covers native launchers, the usual DuckStation AppImage name and
`org.duckstation.DuckStation`. Explicit profiles retain priority. Existing PS1
RetroArch bindings are not switched; memory cards and user settings stay in
their original locations. No new emulator revision is shipped by this change.

The shared controller bridge and process-owned Home/exit helper are reused.
The helper admits only game-launch flags, not a plain desktop window; normal
window close remains the emulator's graceful shutdown path. Whether the selected
device package asks for confirmation must be checked in the real launch/exit
cycle. Input, game-options capabilities and save acceptance are not inferred
from CLI support. This integration does not provide DuckStation netplay.

After a package update, verify the CLI and runtime executable identity, run the
standalone and overlay regressions, then check launch/Home/return/close using
existing card storage. Rollback restores the previous TrainerOS binary/helper;
do not delete profiles or move cards. No source patch needs rebasing.

Source implementation is not yet an installed delivery. Full evidence and
remaining checks: [LAUNCH-80 audit](../LAUNCH80_LAUNCHER_AUDIT.md).
