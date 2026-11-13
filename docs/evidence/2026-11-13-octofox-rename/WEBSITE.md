# OctoFox OS public rename — 13 November 2026

Owner requested renaming TrainerOS on GitHub, the website and Discord, including an announcement. This changes public branding; existing Alpha 7 binaries, signed update identities and installer filenames are preserved.

## Website delivery

- Main project card, project page, header/footer wordmarks, descriptive copy and ten locale catalogs now use OctoFox OS.
- Canonical route: `/en/projects/octofox-os` (and the other nine locales). `/projects/traineros` and localized old routes retain redirects with query parameters.
- GitHub links use `EriArk/OctoFox-OS`. `TrainerOS-Full-Setup.tar`, `Install TrainerOS.sh` and the installed recovery-entry name still match the released artifact.
- Deployed 76 explicitly selected files from the live source baseline. No unrelated local WIP or database changes were included.
- Build, typecheck and 126 tests across 18 suites passed. Lint: 0 errors, 174 warnings in existing/generated navigation. All 150 localized pages passed the translation check.
- Desktop and mobile native browser renders inspected. Public page returns 200; old English route returns 308 to the new route. All ten origin project pages and homepages, neighbouring projects, Studio and P.O.S.S checked after activation. Public installer download returns 200, 1,864,847,360 bytes.
- Database container identity, private environment hash and neighbouring page hashes remained unchanged; runtime logs showed a normal start.

Activated at `2026-11-13T11:34:27Z`. Image: `sha256:7ad6aee0827d4cf3efc455dfdee39421520c9181f04cccff3394516a4e9e66f2`.
Server staging and rollback: `/mnt/batocera-share/abyssdeck-backup/site-octofox-rename-20261113-final`. Local before snapshot and changed-file list: `backups/octofox-rename-20261113/`. Existing dirty working tree was preserved; no combined site repository commit was made.
