# Combined Alpha delivery — 11 November 2026

Work in progress: source merge and packaging are not device acceptance/publication.

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
Actual final archive installation, wizard, screenshots and public assets pending.

The first device attempt reached the administrator dialog but an added 45-second
timeout expired while inspecting screens. No payload was activated. The error stayed
visible. Removed that timeout: user authorization follows the same cancellation
behavior as the existing installer helpers. Added a regression for waiting and
post-authorization validation. Final acceptance will use the rebuilt archive.

## Prepared final media and source delivery

Final package: Software 30 / runtime 29, source
`f4feb4945b32ffb72e8159678720a17e492062dd`, version `0.1.0-alpha.7`.
The ARM64 Release/WebEngine application was compiled from the combined merge;
subsequent changes only affect Setup/storage protection. All compiled inputs are
unchanged. See [build provenance](source-and-build.json), [package](package.json)
and [uploaded asset inventory](release-assets.json). These records retain their
pre-publication state until the device run and publication complete.

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
30 file list matches Software 29 installed on Odin exactly; only Setup's
administrator-dialog timeout changed afterward. Odin retains its legacy install
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
Actual final installation, first-run screens and reboot acceptance remain pending
while the ordinary Setup downloads and activates its dependencies.

The Software 30 clean run failed at managed session integration: the new
`traineros-storage.conf` was absent from the ownership allowlist. The persistent
error and private log identified the failure; Software/runtime activation was
retained for ordinary recovery. Added the exact path, with a regression that
checks all literal system destinations in the real installer against ownership
and removal, while rejecting an unrelated neighboring drop-in. SessionDesktop
12 and StorageGuard 4 pass. This failed attempt is not clean acceptance; the
fixed release will be packaged and checked separately.
