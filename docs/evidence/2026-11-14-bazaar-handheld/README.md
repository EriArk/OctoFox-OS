# Bazaar 0.0.7 — Flip 2 / Odin 2 installation, 14 November 2026

The owner explicitly authorized handheld installation for hands-on testing.
This supersedes earlier no-device-install notes for this Bazaar build only.
Separate source branches remain unmerged; no public Backend or catalogue release.

## Installed payload

Both devices have **Apps → Bazaar (Alpha 0.0.7)**, a standalone local walkthrough.
Do not confuse it with the pre-existing application named Bazaar.
The ordinary Apps service discovered the desktop entry and launched the game.
Existing TrainerOS shell executables/processes were preserved. No game, save,
profile, account or emulator installation was replaced.

- Game source: Crates `c91598baa2643e6493239c3400822e786eb705b2`.
- Prepared host source: TrainerOS `3d88da6c5dd640ccc37f2a283fa99fdadd77ee53`;
  this host build was **not installed** over the devices' current shells.
- ARM64 archive SHA-256: `e6f813695a572e5d15b39b217da5ccb52edf6f4c4d1702da5e501a27a264a14b`.
- Installed executable SHA-256 on both: `4511ecced5186e90ac299d3487e26906628881fdc672880c62c573d11c98a28b`.
- Isolated payload: `~/.local/share/traineros-development/bazaar/versions/0.0.7/`.
  `current` selects that version; desktop ID `org.traineros.bazaar-preview.desktop`.
- This was the first installation in that development directory. There is no
  fabricated previous Bazaar payload; rollback is removal of this added desktop
  entry and isolated payload, leaving the existing shell untouched.

## Observed on real devices

| Check | Flip 2 | Odin 2 |
| --- | --- | --- |
| Apps entry and launch | Observed | Observed |
| Island, residents, fountain rendered | Observed | Observed |
| Own character via existing avatar SDK | Observed | Observed |
| Short movement and menu via remote keyboard input | Observed | Observed |
| Leave Bazaar returned to Apps | Observed | Observed |
| Renderer | freedreno FD650 | freedreno FD740 |

Godot 4.7.2, OpenGL compatibility, Mesa 26.2.6. First launch spent tens of
seconds loading; this was not a timed benchmark. Runtime logs contained the
engine/renderer banner, with no reported script/shader errors in this bounded run.
Both game processes exited with status 0 (retained zombie records under the
session launcher were inspected; no live game remained). Odin volume was explicitly left at 0. Shell PIDs/executable paths stayed unchanged.
Deployment ZIPs and task-specific remote staging/capture helpers were removed.
Screenshots containing personal profiles remain private and are not committed.

The remote test overshot the delayed game exit with extra navigation and opened
Cemu on Odin and KDE Connect Indicator on Flip. Only those newly opened processes
were closed; no ROM was launched. This is a harness sequencing error, not evidence
of a Bazaar input defect. Later checks must wait for the observed exit before
sending more navigation.

## Remaining acceptance and unavailable services

Physical sticks/buttons/touch, listening, sustained frame rate and longer play
remain the owner's hands-on acceptance. Remote XTest is not physical input proof.
The existing shells provide avatar SDK but **do not advertise `bazaar.read`**.
Service screens therefore remain local previews with honest unavailable-host state;
no live rental directory, trusted checkout or managed catalogue entry is claimed.
Payments, loot custody/transfers and costume delivery remain closed. No Sparks
were spent. The office is STALL OFFICE in Town Square; THREAD is the clothing preview.
