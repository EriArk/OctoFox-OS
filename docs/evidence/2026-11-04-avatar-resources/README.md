# Avatar resource delivery — 4 November 2026

Implementation: [resource/storage/SDK contract](../../AVATAR_RESOURCES.md).
The approved pack manifest, geometry and appearance schema are unchanged.

Current local evidence:

- Windows: AvatarTests 14 passed; AvatarSceneTests 8 passed; PlatformHostTests
  17 passed / 2 skipped (Linux legacy path and optional full Godot host process).
- Qt SDK card state/revocation: 3 passed. C++ → Godot 4.7.2 TAV1 fixture and malformed
  resource checks passed; real resolved model loads 10 meshes, rig and actions.
- Packaging tests: 3 passed, including LF/CRLF recipe identity; generated pack
  contains 45 TAV1 geometry resources.
- Approved face: 8222 vertices, exact positions/normals; 14 eye styles across 336
  pose/weight checks; 22 wearables, 54 bones and 8 clips retain their pack checks.
- Windows offscreen portrait capture was blank even with a diagnostic cube;
  its previous success exit did not constitute visual proof. The capture probe now
  checks portrait pixels. Linux/Xvfb passes that check; the retained Qt portrait
  and Godot neutral/arms-up frames were visually inspected.
- The unmodified pre-TAV1 Godot presenter consumes a sealed anonymous C++ memfd
  export successfully; the probe verifies its path disappears after cleanup.
- First ARM tests hit the test container’s 256 MiB tmpfs limit while retaining
  many wardrobe variants. The final run uses an isolated microSD test directory
  and the generated incorporated pack: AvatarTests 14, PlatformHostTests 18 and
  AvatarSceneTests 8 passed. One optional external Godot process test was skipped
  on Flip (that consumer path passed separately on the Linux server).

## Final candidate

Source: `7fb9b0ec55df06ccb699a487adcee29227fd00cc` (implementation `49235446`,
canonical manifest correction `7fb9b0ec`). All 31 changed build inputs match the
ARM build tree; the production binary is
`df5be6125f709126344f91b4259823583f1c30f1f6dcb47fcdea9b7229695418`.

The first candidate comparison caught a missing operator ScreenScraper
configuration and CRLF conversion of the avatar manifest. That candidate was
rejected before installation. Final staging includes the same approved application
configuration and exactly the prior installed LF manifest hash
`12b3dc7c4e384cbce7f401660496eb60b1fbd7086930981a6f890a778a15dffa`.
Private credentials/configuration are not included in this evidence directory.

- Software sequence 8, `prebeta-isolated-validation.6`, 251,733,522 bytes;
  SHA-256 `2ee991da600930f1d175c87771e8d5d5e155a03768c902fe62e56b2d6a407962`.
- Runtime media sequence 15, 2,919,700,480 bytes;
  SHA-256 `81bc54bfe8238badb199c47dda5a9e0eb385b3fd3e35f3572e67302c42f2c3c6`.
  Only the corresponding application source changed; emulator binaries did not.
- Full Setup: 3,517,102,080 bytes;
  SHA-256 `c5e7337290ebf051cb07b565008deb8fcd9a58e226780317771dc0c054a68bbd`.
  All 89 regular archive members and 78 bootstrap files were reread/verified.
  Both application source copies match the Software revision and contain no
  separate avatar geometry. The existing pinned upstream DuckStation download
  remains an Internet dependency.

These are operator-signed validation artifacts, not publicly published assets or
an OTA feed. [Setup](setup.json), [archive verification](setup-verification.json),
[runtime media](runtime-media.json), [source](source.json),
[ARM tests](arm/tests.log), [staging](arm/staging-final.json).

## Installation observations

The first GUI attempt correctly stopped before activation because the internal
partition did not meet the full runtime staging/recovery space budget. The active
Software 7/runtime 14 remained selected; no pending activation was created.
The existing cache cleanup operation removed redundant prepared Software copies.
The owner then clarified that obsolete build/test copies should be deleted, not
accumulated on microSD. Cleanup now removes superseded runtime 6/8/12 and redundant
Software generations after excluding active/previous sets, pending transactions,
live symlink targets and required Software pairings. Active/previous media are
verified before deletion. The temporary offload copies are also removed.
The original 31-file personal-data baseline is retained for the retry.

No public release is asserted. Runtime 14/emulator code is unchanged by this work.
External runtime source/notices and public GitHub/OTA delivery remain later tasks.


## Earlier interruption: device access lost (recovered below)

Cleanup completed: runtime 6/8/12, three unneeded Software generations, temporary
offload copies and rejected build inputs were removed. Active runtime 14 and
previous 13 were verified before pruning; their required Software pairings and
recovery blobs remain. Internal free space was 27.6 GiB before the retry.
Generated redundant source archives were also removed from the PC/server; current
Setup and corresponding source remain. [Cleanup](obsolete-cleanup.json),
[intermediates](intermediate-cleanup.json).

The original 31-file personal baseline still matched before the retry. Setup then
passed the space check and reached offline Python environment preparation.
The last screenshot shows `Preparing offline Python: melonds-netplay`. Subsequent
SSH sessions failed to open; later key exchange/banner probes from Windows and
the owner server also timed out. No system reboot or manual activation was forced.
The owner was asked whether the physical UI responds.

Last observed active state: Software 7 / runtime 14, without pending activation.
This is NOT a claim about the inaccessible device's later state. Software 8 /
runtime 15 installation, post-update personal-data comparison, profile/wardrobe
visual checks and standalone Home return remain unverified. The next action is
device recovery and ordinary Setup continuation, followed by those checks;
external source/notices and public release remain after that.
[Pending record](delivery-pending.json), [last Setup frame](setup-before-disconnect.png),
[pre-update profile reference](profile-before-update.png).


## Recovery and installed candidate (not clean-install acceptance)

The owner rebooted Flip. Software 7/runtime 14 were still active without a pending
transaction. No retained panic/OOM/pstore evidence explains the whole-device freeze;
automatic suspend was disabled. The owner's last frame was Vita3K Python preparation.
Vita3K/voice preparation succeeded after reboot. A normal GUI retry then correctly
refused incomplete melonDS/RMG environments: their ready receipts survived but files
were missing. Those inactive staging environments were rebuilt from pinned offline
inputs using the existing preparation function. All six environments then verified.
This operator recovery is explicitly NOT the ordinary first-user acceptance result.

The next GUI run completed Software 8/runtime 15, retained runtime 14 and its valid
Software pairing. Both audits are ready, 76 cores and 19 prior-core recovery blobs
match. No real rollback was executed in this candidate pass. After reboot, three
original baseline files (configuration, commerce cache, chat history) had changed
while Software 7 was still active; the other 28 matched. A fresh 31-file baseline
was taken after normal shell shutdown; all 31 matched after this installation.
This distinction avoids claiming the original pre-hang baseline stayed identical.

The installed Return to TrainerOS entry reached standalone Gamescope, with no Plasma
or running game and first-frame-confirmed health. Profile, wardrobe and animation
frames were visually inspected; the character and Mika balance remained intact.
No outfit change was saved. Odin was not touched.

[Installed audits](installed.json), [session](session.json), [visual](visual.json),
[completed Setup](setup-installed.png), [profile](profile-installed.png),
[wardrobe](wardrobe-installed.png), [Home](home-installed.png).

The final installer must pass a new clean one-launch journey without manual staging
repair, then recovery and publication. Candidate delivery is not that acceptance.
