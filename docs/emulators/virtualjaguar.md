# VirtualJaguar ARM64 source repair

Upstream: [libretro/virtualjaguar-libretro](https://github.com/libretro/virtualjaguar-libretro),
commit `f9a3c89f58836cb2c45a42ad4edfac047050f30a`, reported version
`v3.6.1 f9a3c89`. Target: Linux ARM64 in TrainerOS's private RetroArch Flatpak
runtime on Flip. The previous binary reported `f9a3c89-dirty`; its unknown diff
was not recovered or silently attributed to this source.

The [candidate recipe](../../packaging/emulators/core-rebuild/jaguar-candidate.json)
pins upstream, source capsule, previous binary, cross compiler arguments and
[identity patch](../../packaging/emulators/core-rebuild/patches/virtualjaguar-source-identity.patch).
The patch adds the known revision when upstream's build-id cannot read `.git`
from a source capsule. It retains normal Git/dirty detection in checkouts and
changes no emulation, graphics, networking or save code. Exact output, toolchain
and source identities are retained in the build/source kit and
[build record](../evidence/2026-11-04-release-source-repair/build.json).

No new default, device identity, per-game override, BIOS or personal save is
introduced. The core is owned by the managed private runtime generation;
other emulator installations and their configuration are not adopted. Existing
TrainerOS protected save/session routing remains responsible for user progress.

QEMU and native Flip ABI checks passed. Upstream `pattern_fill.jag` ran 600 frames
and restored its test state; the replacement also loaded a test state created by
the previous installed core. This is a bounded headless check, not commercial
game, Jaguar CD/BIOS, physical input, audio or netplay acceptance. Those remain
unproven. [Checks and installation record](../evidence/2026-11-04-release-source-repair/README.md).

For updates, pin a new full upstream commit and capsule, inspect build-id and
Makefile changes, rebase or retire the identity patch, and record the actual
cross-toolchain. Use a new build attempt, package the exact sources/patch/logs,
repeat affected ABI and state-compatibility checks, then promote through a new
signed runtime generation. `core_promotion` requires the retained build records
and preserves prior source kits; do not replace an installed `.so` by hand.

Rollback uses the previous signed runtime and retained core blob through normal
Setup/Recovery. Preserve current user saves separately; a successful test-ROM
state restore does not authorize downgrading or overwriting arbitrary user
states. Actual rollback and broader gameplay acceptance must be recorded
separately from the availability of recovery material.
