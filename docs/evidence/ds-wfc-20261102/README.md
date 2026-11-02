# DS WFC — local source/build evidence, 2 November 2026

Subsequent [ARM64/group preparation](../ds-groups-preparation-20261102/README.md)
supersedes the ARM64-build-next and four-wireless-unimplemented statements below:
both are now prepared and checked off-device. This original report remains the
Windows/source evidence; neither pass installed these new packages on handhelds.

Scope: R043, S03/S06/S08; owner explicitly requested this pass **without
handhelds**. No device access, installation, user-ROM launch, server registration
or live WFC match was performed. Existing main/core `b4399f49` includes
`51140203` catalogue performance work and remains the base of this increment.

## Native engine

Pinned source/dep revisions and the single MAC-registration patch are maintained
in [the recipe](../../../packaging/emulators/melonds-wfc/build.py) and
[feature record](../../emulators/melonds-wfc.md). The recipe completed on Windows
x86_64, GCC 16.1.0, CMake/Ninja, Release, JIT enabled, software rendering.
The staged DLL SHA-256 is:

`3932e7ab26ded7bb415c853fd1aa94b49a8a68da6efeaa27c13bb70b14a6c607`

`check.py` ran the actual staged core with `libretro.py==0.12.0`, using a generated
minimal cartridge containing two infinite-branch instructions. No Nintendo ROM,
BIOS, firmware dump or user save was used. Two separate frontend processes ran
300 frames each. Assertions checked generated firmware/AP, Kaeru DNS, WFC CRC,
SLIRP initialization, the selected MAC in native logs, synthetic WFC ID after
reopen, and unchanged cartridge bytes. The result is a native preparation and
persistence check, **not packet-path/gameplay or service availability proof**.

Before the patch, the MAC assertion failed with the shared firmware default
`00:09:BF:11:22:33`; source inspection found an unused address parser and an empty
option list. Registering its values fixed the actual native check. The network
stack was reused unchanged. The probe starts a new process for each session,
matching production; unloading/reloading this core within the same Python
process encountered an access violation and is not claimed as a supported path.

## TrainerOS checks

Built `trainer_core`, `trainer_process_probe`, `trainer_standalone_tests`,
`trainer_runtime_multiplayer_tests`, `trainer_save_backup_tests` with Qt 6.11.1
on Windows. Relevant coverage:

- Arbitrary NDS/SRL and ZIP/7z share decoded-content identity; DSi-only rejected,
  DS-enhanced accepted in DS mode; no tested-title allowlist.
- Stable distinct owner MACs, separate own progress, no peer-save disclosure,
  no inherited RetroArch host/client, and duplicate-owner session lock.
- Normal SRAM+WFC return/reopen, crash retention, missing prior SRAM, stale
  external writes, corrupted envelope and changed package all fail safely.
- Both DS modes remain available under one game row; WFC is excluded from local
  Lobby. Exact mode/build matching and assigned-seat ready packets are enforced.
- Native Online launch is not a matchmaking-success report. Lobby loss keeps
  the running game; there is no automatic rejoin launch.

Final runtime/Lobby suite: **108 passed, 0 failed**. Final focused WFC suite:
**3 passed, 0 failed** (init, complete WFC scenario, cleanup).
Protected-save suite: **33 passed, 0 failed**.

Broader standalone run: **82 passed, 2 failed, 10 skipped**. Failures are
`nativeLanGroupMaterialBindsEverySeatAndDistinctEdge` and
`gameCubeLanUsesNativeBbaAndIsolatedSaves`: the unchanged `NativeLanConnection`
reader rejects this Windows host's group/other permission bits despite the test's
owner-only `QFile::setPermissions`. This Unix-socket/permission route is not used
by WFC. Its tests and security checks were not weakened or marked as passed.
An isolated Qt/Core probe against the unchanged reader confirmed
`valid_input=1 owner_permissions_set=1 windows_group_other_bits=1 admitted=0`.
Ten platform/package-dependent skips remain explicit. WFC's test passed in that
run; its final focused rerun includes the final no-peer-sharing assertion.

Adapter registry and reproducible runtime source export were updated and checked.
No acceptance for ARM64, other platforms, real game service/NAT behavior, or
device input/performance follows from these results. R043 remains partial;
four-machine deterministic DS wireless is a different unfinished mechanism.

Next: build the ARM64 bundle and deliver through the normal preserved-state
installation path after the owner makes the handhelds available.
