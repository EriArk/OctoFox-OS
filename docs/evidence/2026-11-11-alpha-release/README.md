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

Local checks: StorageGuard 4, SoftwareSetupUi 7 and SoftwareInstallation 38 passed.
Actual final archive installation, wizard, screenshots and public assets pending.
