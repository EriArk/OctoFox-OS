# Combined Alpha delivery — 11 November 2026

Setup 31 passed the one-launch install, wizard and normal reboot on Flip.
Odin runs the identical combined application. Alpha 7 is published; public asset
and feed verification is recorded below.

Bazaar branch through `f4af1d8e` is merged at `9bfadd54`. Its production backend
already runs the guarded preview build; new licenses, stalls and rentals remain
unavailable. Worlds are clearly marked placeholders. Existing rights are retained.

## Flip2 storage guard

After reboot the stock Armada 20261110.066ecdc / 7.2.6 host again had UFS clock
scaling enabled. The previous test disabled it only for one boot. Setup now checks
this exact kernel, ARM64, Armada and Flip2 device-tree identity before preparing
large writes. The ordinary administrator dialog authorizes a fixed sysfs write;
failed authorization or storage checks stop Setup with its persistent error UI.
A managed session drop-in repeats the narrow check before Armada selects its boot
session. It preserves the user's selected session, is a no-op on other hardware
and kernel versions, and is removed through the existing ownership ledger.
No boot image, kernel, suspend policy or clock-rate value is changed. Clock scaling
stays disabled on this affected configuration; power/performance effects have not
been characterized. This is a workaround, not a permanent kernel fix.

The observed lock stacks match the ordering issue described in the
[upstream UFS patch](https://lkml.iu.edu/2610.2/01240.html). This does not establish
that every possible device freeze has the same cause. The Iris video-encoder
patch is independent and remains inactive on the stock kernel.

Local checks: StorageGuard 4, SoftwareSetupUi 8 and SoftwareInstallation 38 passed.
Final device results are recorded below; public publication is tracked separately.

The first device attempt reached the administrator dialog but an added 45-second
timeout expired while inspecting screens. No payload was activated. The error stayed
visible. Removed that timeout: user authorization follows the same cancellation
behavior as the existing installer helpers. Added a regression for waiting and
post-authorization validation. Final acceptance uses a separately rebuilt archive.

## Prepared final media and source delivery

Current candidate: Software 31 / runtime 30, source
`7aa74f29cacdcd2716a4553fffaf376b790bc595`, version `0.1.0-alpha.7`.
The ARM64 Release/WebEngine application was compiled from the combined merge;
subsequent changes only affect Setup/storage protection. All compiled inputs are
unchanged. See [build provenance](source-and-build.json), [package](package.json)
and [uploaded asset inventory](release-assets.json). Package acceptance and public publication are recorded separately.

The five source media prepared on 4 November are retained with their original
hashes, rather than relabelled as new builds. Bundled native/core/remote-play
binaries and Python wheels are unchanged. The four nested modified-runtime
archives differ only in source manifest bindings, as recorded in
[runtime source delta](runtime-source-delta.json). The two bundled file-manager
libraries match the earlier corresponding-source delivery. The new TrainerOS
capsule includes the exact changed application and Setup sources, recipes and
patches. Source presence is not a claim of reproducible upstream binary builds.
[Avatar pack validation](avatar-pack.json) passed with the selected approved
resources; personal ROMs, BIOS, saves and account material are excluded.

Focused checks retained for this combined delivery: backend account, Bazaar,
interaction and Bazaar QML tests passed (4/4); OpenGL Bazaar and Chats smoke
renders each reported zero QML warnings. The merged backend files match the
already-deployed guarded Bazaar preview; no new spending was enabled.

## Odin delivery

[Installed readback](odin-installed.json) confirms the running ELF hash,
all 89 application files, resolved libraries and a healthy SQLite database.
All table counts match the backup, including 542 adventures. The final Software
31 application archive matches Software 29 installed on Odin exactly; only
Setup authorization waiting and bootstrap ownership policy changed afterward. Odin retains its legacy install
layout and its two previously adjusted library search paths. This is an in-place
application update, **not managed OTA or clean Setup acceptance**.

Real UI checks: Home, profile, loaded Wardrobe, Chats navigation, Bazaar catalogue
and placeholder preview, online Lobby listing, local-room creation and exit,
Crates, Browser, Files, appearance settings, System and Date/time. Browser loaded
Wikipedia. Ark launched from Apps and quit through its normal Ctrl+Q command,
returning to Apps. Advance Wars launched from Home into RetroArch and reached
its animated title screen; the normal double-Escape quit returned to Home.
No save manipulation or multiplayer gameplay was involved. These remote pointer/keyboard checks do not establish physical
controller Home/minimize acceptance or multiplayer gameplay.

Selected [post screenshots](../../alpha-release/publications/screenshots/alpha-7/README.md)
are actual Odin captures; the test balance and unfinished Bazaar worlds are
labelled in the captions. Screens containing personal downloads, private
conversations or third-party game cover collections were not selected.

## Flip clean-run preparation

The old Software 21 wizard was completed minimally to leave TrainerOS through
Start → Switch → Desktop and its normal save/exit confirmation. This released
the managed runtime-session marker normally. A prior external session switch
had correctly triggered the orphan-session maintenance guard; it is not counted
as acceptance and no lease or transaction journal was manually cleared.

Final Setup 30 performed its ordinary GUI uninstall of the old owned runtimes,
Software and session integration. Empty receipts, no pending transaction, removed
owned boot drop-in and preserved personal data were read back afterward.
For the owner-authorized fresh-user test, the entire inactive Software root,
profile/data directory and preferences were then retained by reversible rename
under the private `traineros-pre-alpha7-20261111` backup. Its database passed
`quick_check`, retaining all 355 adventures. No game, BIOS or save files were
removed. This preparation is separate from the subsequent one-launch install.

The fresh run began at 01:17 local time from the verified full archive
(SHA-256 in [SHA256SUMS](SHA256SUMS)), selected Alpha and confirmed installation.
It initializes the public GitHub update feeds from the shipped bootstrap.
This was the rejected Software 30 attempt described below, not final acceptance.

The Software 30 clean run failed at managed session integration: the new
`traineros-storage.conf` was absent from the ownership allowlist. The persistent
error and private log identified the failure; Software/runtime activation was
retained for ordinary recovery. Added the exact path, with a regression that
checks all literal system destinations in the real installer against ownership
and removal, while rejecting an unrelated neighboring drop-in. SessionDesktop
12 and StorageGuard 4 pass. This failed attempt is not clean acceptance; the
fixed release was packaged as Software 31 and checked separately below.

To leave the rejected 30 install safely, an operator applied only the exact
`session/ownership.py` from verified Setup 31 and its matching bootstrap file
inventory, retaining the previous file/inventory privately. All other bootstrap
files were checked byte-for-byte. Transaction journals were not edited. Normal
GUI finalization is used after this explicit repair. This recovery remains
separate from clean Setup 31 acceptance.

## Corrected Setup 31 clean run

The repaired 30 session opened the wizard automatically, completed the minimal
offline path and exited normally through Start → Switch → Desktop. Setup 31's
ordinary Uninstall removed the active Software/runtimes, shortcuts and owned
session files. Both receipts are empty, no pending journals remain, and the
storage/default boot drop-ins are absent. The recovery test profile (355 discovered
adventures, healthy SQLite) was archived separately; the original personal backup
remains untouched. Normal inactive Setup download/recovery caches were retained.

At 01:58 local time, the verified Setup 31 archive was launched once from Desktop,
selected Alpha and confirmed installation with 20.5 GiB free. This new pass has
no active TrainerOS installation and a new profile directory. Cache reuse is
explicit; this is not a second cold-network download test. No operator edits are
performed during this acceptance run.


## Accepted Setup 31 result

At 02:17 local time the single-launch ordinary installation completed and entered
TrainerOS Welcome automatically. [Install readback](flip-install.json) confirms
Software 31/runtime 30, exact running binary, first-frame health, correct public
feed configuration and no pending transactions. The acceptance run had no
operator repairs, alternate installer invocation or journal edits. Earlier failed
and repaired runs above remain separate evidence.

The actual wizard was walked on Flip: Welcome, network continuation, existing
SD library, local Trainer creation using the shared on-screen keyboard, Light /
Normal comfort settings, all three optional account panels and their registration
QR screens, then Ready and Home. TrainerOS backend sign-in opened the ordinary
Fluxer browser consent, reused the retained test-account browser session, and
returned automatically with “TrainerOS profile connected”. This tests OAuth
consent/return, not a fresh password-entry login. Separate Fluxer chat handoff was
started and cancelled; completion on another device was not verified.
RetroAchievements and ScreenScraper credentials were unavailable for this pass;
their optional UI and QR routes, not authenticated downloads, were checked.

[Wizard readback](flip-installed.json): one profile, first-run stage complete,
355 existing adventures discovered and SQLite quick_check OK. Advance Wars
launched through Games → Game Boy Advance into the installed RetroArch, reached
the animated title screen and quit normally using its double-Escape confirmation.
TrainerOS returned to the library. Private game captures are not in the public
post gallery. No game save was manually changed.

Start → Power → Restart → Continue performed a normal reboot.
[Reboot readback](flip-reboot.json) has a different boot ID, the same accepted
Software/runtime and a healthy database; TrainerOS autostarted at Home without
repeating the wizard. The owned boot guard ran successfully and UFS scaling was
still disabled on the targeted Flip/kernel. The library contains 356 records after
the launch/re-scan. Personal original profile and emulator-save backups remain
retained separately. No suspend/lid test was performed.

The post folder contains 27 actual 1920 × 1080 captures: 15 Odin shell screens and
12 Flip wizard screens. Temporary handoff codes, OAuth URLs, passwords and private
messages are excluded. Captures and manifest are also copied beside the owner's
existing post drafts in the original worktree.

Remaining acceptance: multiplayer gameplay between devices, physical controller
Home/minimize and audio, the inactive Iris encoder patch, authenticated
RetroAchievements/ScreenScraper and separate Fluxer chat handoff. Public-feed
checks do not prove a later OTA apply/rollback or an available-update notification.

## Public release and channel

[Alpha 7 prerelease](https://github.com/EriArk/TrainerOS/releases/tag/v0.1.0-alpha.7)
is public with 16 assets and human-readable Russian installation instructions.
Anonymous GitHub API access confirmed the release, all asset sizes and SHA-256
digests. An anonymous installer HEAD request returned 200 and the expected
1,864,847,360-byte archive. The public Alpha feed matches the prepared signed
bytes; its signature, referenced manifest hash and manifest signature verified.
See [public asset readback](release-assets.json). Only Alpha is published.

After publication, Flip Settings → System → Software updates → Check for updates
returned **0.1.0-alpha.7 — You have the latest available version for this channel**,
with a new check time. [Actual device screenshot](flip-public-update-check.png).
Background checks remain enabled. This verifies live channel discovery; it is
not an OTA upgrade/rollback or available-update notification test.

After acceptance, the completed archive and extracted Setup staging were removed
from Flip's two owned Alpha 7 staging directories, after checking active receipts,
no pending transactions and no live process references. SD free space rose from
1.5 to 5.0 GiB. Installed bootstrap, runtimes, recovery caches and both personal
backups remain. The server's two superseded Alpha 7 package directories were
removed with their small manifests retained; final Setup 31 and corresponding
sources remain. Odin was checked again and still runs the expected Alpha 7 ELF.
