# Shell resources during games — 13 November 2026

## Behavior

The main shell window releases its scene graph and graphics resources after it
has remained hidden for one second. A quick hide/show cancels that work. Showing
it restores Qt's normal persistent caching. Live QML/controller objects, profile
state, navigation, saves, game process ownership and networking remain alive.
The QML engine collects unreachable objects and trims unused component cache.
Separate game overlay windows remain independent and available. On glibc Linux,
a deferred `malloc_trim(0)` after scene-graph invalidation returns unused allocator
pages to the OS. It does not run while the main window is visible.

Avatar/wardrobe/prize previews and the Home companion follow the visibility of
their own window, in addition to their page. A hidden main window no longer
keeps these 3D instances alive merely because a game overlay activates the
application. Return recreates their presentation from existing model state.
The colorful game Home layout and artwork are unchanged.

Ordinary browser tab switching retains the existing 15-second freeze and DOM
preservation. During a running, non-minimized game, safe background pages freeze
immediately and can be discarded after five seconds, **only** if Chromium's
`recommendedState` permits discarding. Discarded tabs reload when visited, not
merely when the game ends. Forms and other protected pages retain the lifecycle
recommended by Chromium. Shared-keyboard focus and editable context actions also
protect the tab: Chromium did not recognize our real IME edit in an input outside
a form during testing. That guard follows the document; cancelled/failed navigation
retains it, while a successful new document can become eligible again. The shared
profile continues to own downloads.

This follows Qt's [window resource contract](https://doc.qt.io/qt-6.11/qquickwindow.html#releaseResources)
and [browser lifecycle contract](https://doc.qt.io/qt-6/qml-qtwebengine-webengineview.html#recommendedState-prop).
No new service manager, process suspension, cache/data deletion, rendering-quality
reduction or emulator environment override was introduced.

## Reproduction and limits

Base: `303078ab`, same Fedora 44 / Qt 6.11.2 native Release build, Quick3D and
WebEngine enabled, Xvfb 1280×720 and Mesa software OpenGL. The baseline binary
contains only the opt-in resource harness, with the original application code.
Each run completes the disposable first-run wizard and opens a real 3D profile.
Three controlled child-process cycles sample foreground, hidden shell, an
independent visible overlay and return. `/proc/self/smaps_rollup` reports shell
RSS/PSS/private dirty memory; `/proc/self/stat` reports CPU ticks. Renderer/child
process memory and hardware GPU allocation are outside that shell-only sample.

Run `traineros --first-run-smoke-test --screenshot-dir <directory>` with
`TRAINEROS_RESOURCE_PROBE=1`, isolated XDG directories and `trainer_process_probe`
beside the binary. Resource sampling uses six-second stages. The harness checks
normal child exit, window/overlay rendering, preserved profile/navigation and
absence of new QML warnings. `returnFrameMs` measures the first swapped frame,
not completion of every asynchronous texture upload.

Browser validation uses `trainer_browser_probe`, `PROBE_MODE=lifecycle`, the
production `BrowserEngine.qml`, `tests/ui/BrowserLifecycleProbe.qml` and the
loopback-only `tests/browser_fixture.py`. No external accounts or web pages.

These are native host tests with content-free child processes, not emulator
FPS, physical-controller, ARM64, Vulkan or Flip/Odin acceptance. No device
installation or new signed release is part of this source verification.

## OpenGL measurements

| Shell state (median of 3 cycles) | Baseline RSS | Optimized RSS |
| --- | ---: | ---: |
| Hidden during child process | 724.6 MiB | 450.2 MiB |
| Hidden with independent overlay | 724.6 MiB | 450.3 MiB |
| Returned profile | 724.6 MiB | 707.9 MiB |

Hidden RSS fell by **274.4 MiB / 37.9%** in this fixture. Median hidden PSS
fell from 699.5 MiB to 429.8 MiB. The optimized hidden samples were
429.3 / 450.2 / 455.9 MiB; returned samples were 706.7 / 707.9 / 710.7 MiB.
This short run is not a long-session leak guarantee. Hidden idle CPU stayed
approximately 0.2% of one core in the settled overlay interval; no FPS or idle
CPU speedup is claimed. The first returned frame changed from 28–35 ms to
223–285 ms on software OpenGL, reflecting resource reconstruction.

An intermediate implementation released objects but left freed allocator arenas
resident: returned RSS rose to approximately 1 GiB across three cycles. It was
rejected. Returning unused allocator pages after render-thread cleanup fixed
that measured regression; no allocator tuning is exported to emulators.

Raw results: [baseline](baseline.json), [optimized](optimized.json).
The [returned profile](profile-return.png) shows the reconstructed 3D preview.

## Verification

- Release native application and browser probe build successfully.
- Three profile → controlled child → overlay → profile cycles pass on both
  software OpenGL and software Vulkan (Lavapipe). [Vulkan record](vulkan.json).
  The avatar preview exists in foreground/return samples and is absent while
  the main window is hidden. Vulkan first frames were 222–361 ms; this run was a
  functional backend check, not a matched hardware performance comparison.
- Browser lifecycle reaches stage 14: lazy creation, ordinary freeze/DOM resume,
  12 MiB download pause/resume/completion in the background, closed-view removal,
  game-time discard, no unsolicited wakeup, reload on visit, shared-keyboard
  input preservation and fresh-document eligibility. [Receipt](browser-lifecycle.json).
- Wardrobe equipment/pose checks and hidden-window preview destruction/recreation
  pass with zero QML warnings. [Receipt](wardrobe.json).
- The companion fixture passes package selection/removal/reinstallation, Feed,
  presentation unload/reload and actual window hide/show, with zero QML warnings.
  [Receipt](companion-lifecycle.txt). Run with `TRAINEROS_HOME_RESOURCE_PROBE=1`
  and `traineros --persistence-smoke-test library-home --data-dir <empty directory>
  --screenshot-dir <directory>`. This fixture waits for the real store, creates a
  disposable owner and exercises the existing widget stages; it does not claim
  the older full navigation tour passed.
- Seven focused native groups pass: browser, home_companion, avatar_scene,
  process, adventure_exit, adventure_exit_presentation and
  adventure_overlay_transport. [Initial run](native-tests.txt) and
  [avatar rerun](avatar-test.txt). The first avatar run had no X display;
  supplying Xvfb fixed that test environment, without a code change.

The browser test runs as root in a network-isolated container with Chromium's
sandbox disabled **for that fixture only**. It has no external websites or real
accounts. Missing container audio/D-Bus/VDPAU services are not device results.
The probe's initial extension selected an unvisited blank tab and had no current
view; the fixture now explicitly selects the visited tab. Later checks use the
actual shared-keyboard input path and a real document navigation.

## Existing failures kept open

The broad legacy UI smoke is **not green**: the same 47 assertion messages occur
with baseline and optimized binaries. The two old persistence process scenarios
also fail their navigation/profile setup on both binaries; the optimized run
adds no new failure messages. [Baseline UI](baseline-legacy-ui.txt),
[current UI](legacy-ui.txt), [baseline persistence](baseline-persistence.txt),
[current persistence](legacy-persistence.txt).

The full `library-home` tour also stalls at its old Quick Apps geometry wait,
after `header-notifications.png`, on both binaries. Its existing waits/assertions
were not removed or relabelled as passing. Resource-specific companion checks
have a separate opt-in fixture using the same real widget/controller; broad
navigation/persistence repair remains a separate task. Emulator gameplay, real
save acceptance, actual game Home input and long-session device behavior remain
unverified by this host-only work.


## Handheld follow-up

The owner resumed installation and real-device checks on 13 November. Both
handhelds were reachable through the existing SSH server. Alpha 7 was measured
before replacement. The first private signed candidate (sequence 32, source
`13a63d1f`, ELF SHA-256
`3a60fc29a0b07e661db77f6eab558537d0f282277127a1ddff3816c112b479e9`)
started successfully on both, preserved SQLite table counts and passed integrity
checks; Flip confirmed its first frame and retained the UFS workaround.

That candidate **failed game launch**: the internal rename changed the exact
header of existing `traineros-ordinary-v1.cfg` / generic v1 files. Repeating the
launch did not resolve it. The compatibility correction preserves the legacy
bytes (including moved-save digest names), accepts the exact renamed header,
and continues rejecting changed settings, trailing data and symlinks. It never
rewrites an existing file. This was found through real UI launch, not a synthetic
successful process probe. Final corrected-device results follow below.

The corrected sequence 33 launched Advance Wars on both devices and completed
Home → minimize → return with the same emulator PID. However, repeated Home
openings exposed retained overlay graphics: shell RSS rose from 569 to 713 MiB
on Odin and 491 to 637 MiB on Flip over this short sequence. Thus the first
lower sample alone is not the acceptance result. The next correction applies
the same delayed hidden-window cleanup to the existing independent overlay
windows as well. Visible overlays remain untouched; each releases only after
it has been hidden for one second. Controller/session objects are retained.
