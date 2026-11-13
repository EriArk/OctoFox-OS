# OctoFox OS branding and compatibility

The project was renamed from TrainerOS to OctoFox OS on 13 November 2026.
The native interface, wizard, sign-in pages, notifications, desktop/session
entries, Setup and recovery messages use the new public name.

Newly generated installers use `OctoFox-OS-Setup`, `Install OctoFox OS.sh`,
`OctoFox-OS-Full-Setup.tar` and `OctoFox-OS-Setup.tar.gz`. Download kits use
`OctoFox-OS-Download` and `Download OctoFox OS.sh`. Candidate bundles retain
their `CANDIDATE` suffix. The archive reader accepts either the new or original
Setup root, but rejects archives mixing both roots and still enforces traversal,
symlink, integrity and existing-file protections.

Published Alpha 7 archives, signatures and checksums are unchanged. Follow the
filenames in that release's instructions when installing Alpha 7. Its screenshots
and historical engineering evidence accurately retain the previous branding.
The source rename is not a new signed release or an installed device update.

## Stable identities

The following are compatibility identifiers, not names to show in product UI:

- Qt application/organization `TrainerOS`, desktop ID `org.traineros.TrainerOS`,
  QML module/resource namespace `TrainerOS`, executable `traineros`, and existing
  session/system service IDs and `TRAINEROS_*` environment variables.
- Existing data/configuration/cache roots, emulator input profiles, keychain
  services `TrainerOS.Backend` / `TrainerOS.Fluxer`, and Steam ownership markers.
- Exact RetroArch ordinary-launch v1 config headers and moved-save filename
  digests. Legacy and renamed headers are accepted only with identical protected
  settings; existing configs are never rewritten to implement branding.
- Package/schema IDs, trusted signing keys, source inventory records, save-lineage
  and avatar encryption domains, SDK contracts, emulator bridge messages and
  multiplayer discovery/session markers, including virtual controller names.
- ScreenScraper's registered `softname`, external account verification code
  format, and download-cache identities needed to resume interrupted downloads.

Changing those names would require a separately tested migration. Keeping them
lets renamed builds read existing profiles, resume downloads, retain logins and
communicate with installed versions. Do not manually rename these directories.
New window titles are accepted alongside legacy game-return titles by the overlay
helper. Crates accepts both `EriArk/OctoFox-OS` and legacy `EriArk/TrainerOS`
release URLs while retaining its exact repository allowlist.

The backend's additive `0020_octofox_brand.sql` migration changes only the
first-party shop publisher label. Prior migrations, offer/application identities,
prices, receipts, purchased rights and third-party labels remain intact. Deploying
that backend change requires the normal migration/deployment workflow; source
verification alone does not change the running service.
