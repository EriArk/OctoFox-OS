# Avatar resource delivery — 4 November 2026

Implementation: [resource/storage/SDK contract](../../AVATAR_RESOURCES.md).
The approved pack manifest, geometry and appearance schema are unchanged.

Current local evidence:

- Windows: AvatarTests 14 passed; AvatarSceneTests 8 passed; PlatformHostTests
  17 passed / 2 skipped (Linux legacy path and optional full Godot host process).
- Qt SDK card state/revocation: 3 passed. C++ → Godot 4.7.2 TAV1 fixture and malformed
  resource checks passed; real resolved model loads 10 meshes, rig and actions.
- Packaging shape tests: 2 passed; generated pack contains 45 TAV1 geometry resources.
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
  and the generated incorporated pack. Installed-device acceptance is pending.

No public release is asserted. Runtime 14/emulator code is unchanged by this work.
External runtime source/notices and public GitHub/OTA delivery remain later tasks.
