# Model 3 Cabinet Link — 1 November 2026

Branch: `codex/model3-link-20261101`, based on current core `883ecaf0` (Steam library).
The older multiplayer branch was not installed over newer handheld work.
[Contract and source pin](../../emulators/supermodel.md).

## Passed

- Pinned Supermodel compiled natively for ARM64 with the bounded content/capability
  patch. No game protocol or timing patch.
- Actual upstream `CNetServer`/`CNetBoardLink`, compiled from that revision, crossed
  the new namespace endpoint and the existing ICE/DTLS reliable carrier for
  2, 3 and 4 cabinets. Ring payloads of 1, 32, 8192, 65536 and 262144 bytes arrived
  unchanged from the previous seat. Carrier loss woke a blocked native Receive;
  all native fixture processes remained alive. These are real networking classes,
  not an emulated match or a separate-network test.
- Python content/preparation tests: **4 passed**. Native identity rather than filename, parent
  digest changes, rejection of unsupported native capability, own-config fallback,
  one-time own-NVRAM seed, persistent per-seat progress, symlink write rejection.
  Killing a scanning helper also kills its native reader; the regression uses
  a real child process and does not rely on a mocked cancellation result.
- Native package/launch integration: all four seat port assignments, host-seat
  agreement, own NVRAM seed and persistence, concurrent-session exclusion and
  modified-package rejection passed with the staged ARM64 native package.
- Owned-window helper tests: 25 passed, including both Supermodel executable
  names and refusal to treat an unrelated desktop window as an owned game.
- Final runtime/lifecycle suite: **104 passed, zero failures/skips** in the
  isolated Flip ARM64 container (Qt 6.11.2). Relay selection now uses a local
  HTTP/TCP fixture rather than a public service during these lifecycle tests.
  The disc-refresh fixture waits for the owned process to reach Running before
  simulating an established party. Earlier environment-dependent runs are
  superseded by this complete result; assertions were retained.
- Other relevant suites: standalone 89 passed / 1 skipped, Lobby 73 passed /
  11 skipped, GameParty 35 passed. The new native package check subsequently
  ran separately with its actual package/content inputs: 3 passed / 0 skipped
  (including setup/cleanup). Existing unavailable external-runtime fixtures were
  not counted as successful checks.
- Odin's existing native ZIP sets: loader admitted `dayto2pe`, `lemans24`,
  `spikeofe`, `von254g`; other present sets did not pass native capability/content
  admission. This is an observation of those files, not a product title allowlist.

## Delivery status

The production ARM64 shell was built with testing disabled and the full avatar
renderer enabled. [Build identity and checks](build.json).

- **Flip installed:** shell SHA256
  `64a0b0f51cb2141ca09f05cd6446391073693d82a5436e1260339e77d1c24f64`,
  native bundle and owned-window helper. The session supervisor reported its
  first rendered frame. An old login-browser window initially held the supervisor
  in its descendant wait; a normal window close allowed the restart, without a
  compositor reboot or terminating Steam.
- [Flip verification](flip.json): existing protected database rows, other emulator
  manifests, avatar, settings and volume retained; zero running game sessions.
  Normal library discovery configured eight Model 3 records. One existing record
  remains unconfigured after historical text-validation failure; its native
  Cabinet Link probe also rejects the present archive. No personal metadata was
  rewritten to force admission. Multiplayer routing uses a copy of the record.
- **Odin not installed:** it stopped answering on its known SSH endpoint before
  delivery began. No package, shell or helper replacement was attempted there.
  The same checked payload is retained for delivery after access returns; recheck
  the current shell identity and concurrent work before installing.

The previous shell `0ea60099b04f543e948a533ac5e81bc47e0559c86da23574ef2cf03d552c91b1`
and private database/settings snapshots are retained in Flip's task delivery
backup on microSD. Runtime code is separate from personal cabinet NVRAM.
Build sources, objects and the independent container store are on microSD.
No game match or universal performance/latency claim is made.

## Preserved scope

Steam library/session integration, avatar pack, saved profiles and other emulator
packages are outside this change. Remote Play, Iris and the paused Sonic/Battlefront
diagnostics were not resumed. Difficult NAT and per-game polishing remain separate.
