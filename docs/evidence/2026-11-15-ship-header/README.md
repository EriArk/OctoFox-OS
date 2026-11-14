# Ship header entry — 15 November 2026

Private **Software 48** brings the saucer entry to **Odin and Flip**, integrated
with the installed Software 47 Bazaar shell. The previous standalone ship delivery
left the upper bell in place; Apps-only access did not fulfil the requested entry.
The saucer now replaces that upper bell. The footer notification inbox stays.

Source: `eacc8d5c57eaec73407185308d359ff4e95d1cf9`, on
`codex/ship-home-20261114`. The merge retains the current official and personal
Bazaar cards, launch routes, covers and shared SDK locomotion. The signed payload
comparison against Software 47 has exactly one changed file: `bin/traineros`.
No public release or OTA feed changed. Reserve **49+** for another private build.

## Real-device checks

- Both live shell executables match the [package hash](package.json).
- On Flip, clicking the upper saucer launched the installed warm ship with Mika.
- On Odin, Up → Up from the main play selection focused the saucer and displayed
  **Enter ship**; Confirm launched the ship with Ren. Down returns from the
  saucer to the dashboard. Input here was remote keyboard/pointer.
- Both used **Save and exit** and returned to the same shell process. The Apps
  ownership journal cleared. Both retained the ship's Vulkan Mobile renderer;
  the final game logs contained no errors. Exited Godot child records were zombies
  under the compositor reaper, not running game processes.
- The lower bell opened the notification inbox on each device; Back closed it.
- Ship and Bazaar installed assets were retained. No kernel/system update,
  reboot, sleep test or personal-state replacement was performed.

| Device | Header | Ship opened from header | Retained inbox |
| --- | --- | --- | --- |
| Odin | [Entry](odin-header.png), [directional focus](odin-focus.png) | [Ren](odin-ship.png) | [Inbox](odin-inbox.png) |
| Flip | [Entry](flip-header.png) | [Mika](flip-ship.png) | [Inbox](flip-inbox.png) |

## Installation and recovery

Both shells exited through Start → Switch → Desktop before activation and
returned through the normal session control. Flip used managed Software activation;
Odin kept its existing legacy installation and runtime libraries. Software 47
is the retained rollback. Profiles and libraries were backed up and checked.

Odin again stalled while preparing the full archive on microSD. The preparation
process was terminated and exited; the shell binary was instead transferred
through RAM, checked against the signed release, then atomically replaced.
The signed package comparison established that every other payload file was
unchanged. This is delivery evidence, not a fix for Odin's storage behaviour.

## Build checks and cleanup status

ARM production and native builds passed. Native suites: **10 Bazaar, 20 Apps
and 62 interaction tests passed**, zero failures. The optional live-Godot avatar
fixture was skipped because its test-only engine paths were not supplied; real
avatars were observed on both devices instead. The ship navigation/launch/modal
interaction test passed. [Test summary](native-checks.txt).

[Odin verification](odin-verification.json) and
[Flip verification](flip-verification.json) record live hashes, profile-table
preservation, rollback and cleanup. Flip staging was removed. Odin's RAM install
copy was removed, but deletion of its microSD staging directory was still blocked
in `inode_wait_for_writeback` at the final check. The scoped cleanup process was
left to finish; the device was not rebooted. Old Software 46 was removed while
Software 47 remains available for recovery. This microSD cleanup is **pending**,
not claimed complete. During the final read-only check the owner had already
opened a Bazaar world on Odin; it was left running.

## Limits

Physical gamepad/touch, Home/minimize/Quick Apps return and sustained performance
remain separate acceptance. This change completes the header entry, not those
broader standalone-game lifecycle or performance tasks.
