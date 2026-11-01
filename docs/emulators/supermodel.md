# Supermodel — Model 3 Cabinet Link

## Contract, 1 November 2026

`runtime.supermodel.link.v1` binds native linked arcade cabinets to the existing
Online/Lobby flow: select game → prepare → seats/Ready → host Start → original
game's linked mode → Game Options/Home/Exit. Each device emulates one cabinet.
The integration supports 2–4 seats; the game's own cabinet/player limits still
apply. Enter the original service menu to select compatible cabinet roles/IDs
(often Master for P1 and Slave for the others). With the fresh SDL gamepad
defaults, left-stick press is Test, right-stick press is Service, Start is Start,
Select is Coin. Existing custom controls take precedence.

TrainerOS sets network addresses automatically. It reuses the existing authenticated
ICE/DTLS reliable `cabinet` carrier and Lobby signaling, including local/direct
internet connectivity. No new relay, VPN, router administration or emulator
synchronization protocol. Each emulator's native TCP ring runs inside a private
network namespace; its ports are not exposed to the LAN. Native upstream remains
lockstep and expects low latency: this does not certify arbitrary WAN latency or
solve difficult NAT. Loss closes the forwarding sockets and wakes native Receive,
while the game stays open. Recovery/relaunch is deliberate, never forced by presence.

There is no TrainerOS tested-title allowlist. The pinned native GameLoader validates
the actual ZIP set and required parent ROMs/CRCs. The read-only capability probe
uses the same `CSimNetBoard::LinkType` predicate as the emulator. Boardless/unsupported
sets and incomplete archives do not advertise Cabinet Link. ZIPs with arbitrary
filenames remain eligible when the native loader recognizes them. A local one-player
metadata field does not hide an independent-cabinet mode. Exact archive/parent
digests, native protocol revision and settings must match between participants;
equivalent differently packaged ZIPs are conservatively treated as different builds.

## Ownership and persistence

S06 owns Lobby membership/seats/Start; S03 owns the native invocation and Home/exit;
S07 owns existing signaling and authenticated transport. The endpoint accepts only
the assigned next/previous ring stream and validates each guest's source seat.
Framing/queues are bounded; extra native connections, forged seats and malformed
frames revoke forwarding. Local connection material is private and removed by the
existing coordinator. No peer-supplied executable, host address or filesystem path.

S08 keeps personal settings separate. A per-content lock protects
`TrainerOS/model3-link/<content SHA>/seatN`. First use seeds NVRAM only from that
device's ordinary NVRAM; later starts retain that cabinet's own progress and role.
Config is copied from the owner's current settings, or fresh packaged defaults.
The ordinary config/NVRAM is never overwritten, and no peer save is copied.
This is native per-seat NVRAM persistence, not a semantic save adapter or a rollback
of every native write. Changing seat intentionally selects another cabinet's local
settings; it does not silently overwrite the earlier seat.

## Provenance, build, update and rollback

Upstream: [trzy/Supermodel, pinned revision](https://github.com/trzy/Supermodel/tree/036af1c8d6640c5a60709c1f99144635ed82a184).
Reviewed `Src/Model3/{SimNetBoard,NetBoardLink}`, `Src/Network/{NetServer,TCPConnection}`,
`Src/OSD/SDL/{Main,SDLInputSystem}`, `Src/OSD/Unix/FileSystemPath` and `Config/Games.xml`.
The maintained upstream already supplies ARM64 compilation, TCP ring networking
and normalized SDL gamepad input. This closes the missing TrainerOS launch/binding
capability without adopting a separate emulator fork or implementing game protocols.
Supermodel uses OpenGL; this integration does not change the shell/other emulators'
Vulkan preferences or claim a portable performance result.

The bounded [patch](../../packaging/emulators/supermodel/native-inspect.patch)
extracts the existing native supported-family predicate and adds a read-only
`TRAINEROS_SUPERMODEL_INSPECT=1` branch after ROM loading, before graphical/runtime
initialization. It does not alter emulation, network timing or game-specific NVRAM.
The helper ties the native inspector's Linux process lifetime to its own: cancelling
a library scan cannot leave a detached ROM reader running.

[Build recipe](../../packaging/emulators/supermodel/build.sh) stages the exact source,
applies the patch, builds Supermodel and the Qt endpoint, and bundles private
SDL2_net/GLU dependencies. The supplied `stream_transport` must be the already
reviewed common carrier. Keep Supermodel's license, the installed SDL2_net license
and the collected Mesa GLU source notices with the private dependency binaries.
[bundle.py](../../packaging/emulators/supermodel/bundle.py)
seals all nine runtime/config/helper files and records the owner's existing ordinary
config/NVRAM locations. Ordinary launch is registered as `supermodel`, platform
`model3`, ZIP, with `-no-net`; multiplayer explicitly overrides networking in the
private working directory. Package code and defaults are replaceable; own per-seat
NVRAM is outside it. No game/BIOS content is included.

On update, rebase the small native patch, review LinkType/CLI/path contracts, bump
the source/protocol/settings identity as needed, rebuild all supported architectures,
and repeat native ring/loss, package admission and personal-data checks. Local
artifact hashes may differ by architecture; network compatibility binds the pinned
native source/settings. Do not mix arbitrary native builds under that identity.
Roll back the shell/package from its delivery backup; preserve new per-seat NVRAM
and ordinary saves. Remove the new launcher only if it still points to this package.

## Evidence

[Model 3 checks and delivery](../evidence/model3-link-20261101/README.md) distinguish
source/build, native transport, installation and game acceptance. A working native
ring is not proof of every game's race/match or different-network gameplay.
