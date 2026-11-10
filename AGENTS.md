# TrainerOS — active agent / developer contract

**Owner combined Alpha release, 11 November (latest):** merge the prepared Bazaar branch, apply the combined build on Flip and Odin, validate the installer and walk the wizard on Flip. Capture the wizard on Flip and other screens, including Lobby/multiplayer, on Odin; store them beside the repository post drafts. Publish Alpha with a human-readable description and installation instructions after verification. This resumes device installation and supersedes the historical separate-branch/no-merge Bazaar boundary; paid Bazaar features remain disabled. Preserve personal data and recovery.

**Owner handheld resumption, 10 November (latest):** the owner explicitly resumed
real-device verification and asked to update Armada on both Odin and Flip. This
supersedes the preparation-only/no-handheld-install boundaries below for the
authorized validation pass. Preserve profiles, games, saves and boot recovery;
no suspend/lid tests or Bazaar merge. Record source/package/device acceptance
separately in [device validation](docs/evidence/2026-11-10-device-validation/README.md).

**Owner Setup completion, 10 November (latest):** successful installation must
switch automatically into TrainerOS, including resumed finalization. Failure must
remain visible with a useful explanation and a private log; never treat a vanished
window as success. Preserve desktop logout refusal and normal recovery.

**Owner Odin update, 10 November (latest):** leave Flip's running Setup alone;
update the existing Odin installation by the previous in-place method, retaining
its profile, games and settings. This is not clean Setup or managed OTA acceptance.

**Owner wizard correction, 10 November (latest):** remove the mandatory button
exam; integrate name/emblem creation into the wizard. Keep Comfort to Light/Dark
and Normal/Large only. Follow with optional TrainerOS/Fluxer, RetroAchievements
and ScreenScraper accounts, explaining each dependency and offline use. Provide
phone-registration QR buttons with official URLs. Preserve shared providers,
profile/PIN resume and the beautiful game Home. See [first run](docs/FIRST_RUN.md).

**Owner popup polish, 10 November (latest):** compact New Collection by its short
choice list; use flat, quiet Power and Apps context menus. Start subpanels replace
its visible dashboard and return to its preserved state. **Keep the existing
beautiful game Home composition, preview and styling**; the owner explicitly
rejected turning it into a compact list. No handheld installs or Bazaar merge.
See [evidence](docs/evidence/2026-11-10-popup-polish/README.md).
**Owner Bazaar placeholders, 10 November (latest, supersedes spending enablement):**
The worlds do not exist yet. Show colorful, full-screen explanatory placeholders
for official and player bazaars with large unmistakable PLACEHOLDER / UNDER
DEVELOPMENT labels and what will be built. Do not let users spend Sparks on
unavailable Bazaar content: disable Bazaar licenses, stalls and new rentals in
both native client and Backend. Preserve previously purchased rights, places and
receipt recovery. Existing 5000/500 prices and commerce implementations below
are prepared future work, not enabled purchases. Remain in the separate branch.

**Owner Bazaar stalls, 10 November (latest):** ordinary trading places cost
**500 Sparks once per place**. Prepare the purchase → owned place → weekly rent
path in the same separate branch. Reuse Shop, durable purchase recovery and the
existing ledger. A created personal bazaar is required; buying a place does not
set its weekly rent or spawn a game world. No free stalls, duplicate charges or
new arbitrary tariffs. Other stall types/functions and goods trading remain later.

**Owner weekly Bazaar rentals, 10 November (latest):** keep rentals minimal.
The place owner sets a price in Sparks for one week. Any player can occupy a
free place by paying; the owner receives the Sparks. The place belongs to that
tenant for seven days from payment, then becomes free; tenant goods are preserved.
This settles duration/pricing direction in the earlier notes. Rental menus and
transactional APIs are now prepared on the separate branch;
see services/backend/bazaar.md. The later 500-Spark purchase increment provisions
places from paid receipts only; trade/custody remains future work. Do not mint
free places or claim goods-return behavior.
Do not invent additional tariffs, commissions or complex rental flows.

**Owner Bazaar cards/access, 10 November (latest):** prepare card cover/badge
preview and owner access controls next, in the same separate branch. Preserve
buy-now/create-later. Reuse native profile identity for selecting a player; owner
moderation is separate from temporary hosting. No fabricated live visitors/kicks
or successful admission before the world runtime exists. The later weekly-rental
contract above supersedes the earlier rental discussion.

**Owner Bazaar purchase correction, 10 November (latest):** buy the permanent
right for 5000 Sparks first, then create the single personal bazaar whenever
convenient, without another charge. Buying must not create a catalogue record or
require a name/settings. Preserve purchased rights across restarts and failed
creation attempts. This supersedes the combined purchase-and-create journey.

**Owner Bazaar foundation, 10 November (latest):** continue Bazaar in its separate
branch, without merging or installing handhelds. Personal creation costs **5000
Sparks**, exactly **one bazaar per player**; reuse Backend account/purchase/ledger
and existing Lobby/SDK boundaries. The owner authorized beginning the server
foundation on the existing SSH server. Persistent owner and temporary peer host
are different roles. Future stalls/functions are separate purchases; trading
places may be rented to other players for Sparks. The weekly-rental contract above
supersedes the earlier deferred rental scope;
do not invent commissions or ownership transfer. See
[the current contract](services/backend/bazaar.md).

**Owner Online / Chats, 10 November (latest):** repair Lobby and Chats in source,
without handheld installs. Bazaar is being prepared in another branch: preserve its
content and do not merge until the owner explicitly resumes that integration.
**Latest correction:** replace the upper Chats tabs with a left icon rail:
Search / divider / Messages / Groups / Communities / divider / Friends.
Keep list and conversation beside each other. Messages now contains personal DMs;
Groups contains ordinary group chats; Friends contains relationships and requests.
Use large native icons, selected labels, unread/request badges and Up/Down on the
rail, A/Right into content, B back. Preserve global X/Y/Home/Start and outer L2/R2.
See [repairs and verification](docs/evidence/2026-11-10-online/README.md).

**Owner Browser / Files repair, 10 November (latest):** optimize the existing
browser and file manager without adding layers. Browser controller navigation uses
a mouse cursor: left stick moves, right stick scrolls, Confirm clicks, R3 opens
context actions, Back returns, Select opens controls. Keep parent navigation and
shared keyboard. Preserve page state and downloads across hiding/freezing; honour
Chromium lifecycle recommendations. Cancel obsolete file listings independently
of copy/move jobs. Preparation only; no handheld installs or Setup replacement.
See [implementation and evidence](docs/evidence/2026-11-10-browser-files/README.md).

**Owner Apps Home correction, 10 November (latest):** native app Home opens
Return / Minimize / Close application, without the permanent upper-corner control.
Minimize returns to the launching shell page/subpage/focus and preserves the app.
Quick Apps must show running/minimized apps, including hidden and overflow favorites,
without duplicate icons; selecting one resumes it. Keep ordinary safe close and
existing input/window ownership. This overrides the historical corner-control and
always-return-to-Apps choices. Current work is preparation only: no handheld installs
until the owner explicitly resumes them. See [implementation and evidence](docs/evidence/2026-11-10-apps-lifecycle/README.md).

**Owner release channels, 10 November (latest):** reserve exactly `alpha`, `beta`,
`stable`. Work on and publish Alpha only for now; Beta/Stable remain unavailable.
Preview is retired from the new contract. Preserve signed identities and previous
recovery sets; do not relabel old signed metadata or equate a renamed source channel
with a published working OTA. This supersedes older Beta/Preview and pre-beta
channel choices below, without cancelling installer/recovery acceptance.

**Owner final installer acceptance, 4 November (latest):** finish the public
installer and release now. The ordinary journey is download -> one installer
launch -> installed usable TrainerOS. A recovered operator run, multiple installer
launches, crashes or manual staging repair cannot count as the clean acceptance.
Prepare the final package, validate that full journey on Flip with personal data
preserved, check recovery, then publish. Do not reopen deferred feature completion
or confuse the unexplained device freeze with a proven Vita3K defect.


**Owner routine cleanup, 4 November (latest):** remove superseded build outputs,
temporary packages and obsolete test/deployment copies after verifying their
replacement. Do not accumulate them on internal storage or merely move the junk
to microSD. Keep the working installation and one verified compatible rollback
set, including its required Software pairing and recovery blobs. Personal games,
BIOS, saves, accounts and original source assets are not disposable build cache.
Before pruning, exclude active/pending generations and live runtime references.

**Owner alpha scope clarification, 3 November (latest):** continue the alpha
delivery with incomplete features explicitly documented. Completing every planned
multiplayer route is not a prerequisite for alpha. Prepare and preserve working
routes in Setup, retain missing features in the readiness register, and distinguish
installed/runtime checks from gameplay acceptance. This supersedes any reading of
the multiplayer-ready requirement as an all-platform feature-completion release
gate; installation/recovery, personal-data protection and distribution obligations
remain required.

**Owner multiplayer-ready Setup, 3 November (latest):** the installer must prepare
all accepted multiplayer families from first launch, preserving working modified
runtimes. Suitable RetroArch replacements or automatic downloads from the original
upstream followed by local configuration are authorized. Pin compatible versions,
cores, protocols and settings; never silently fetch arbitrary latest builds or
weaken multiplayer identity checks. DuckStation may be obtained unchanged directly
from upstream during Setup; PS1 netplay stays PCSX-ReARMed. This supersedes the pending
DuckStation delivery-choice question. Keep actual missing routes explicit and follow
[the release matrix](docs/MULTIPLAYER_RELEASE_MATRIX_RU.md); package presence is not
a multiplayer acceptance result.


**Owner standalone default, 3 November (latest):** the standalone TrainerOS
session is the default after installation, including upgrade of the earlier
managed candidate. Keep Desktop/Steam entry and safe removal/recovery. This
supersedes preserving the host boot default on first managed installation.
Verify actual reboot and service sign-in on Flip; Odin is outside this fresh
installation pass. Later updates must not repeatedly reset an explicit choice.

**Owner parallel emulator installation and fresh Flip journey, 3 November (latest):**
TrainerOS installs its own runtimes, Flatpak repository, cores and emulator data
alongside EmuDeck and existing emulators. Do not adopt, migrate or replace their
installations/configuration. The earlier shared-target migration candidate is
superseded. After the isolated installer is prepared and checked, the owner
authorizes clearing Flip's added software to ordinary Armada and testing the
complete fresh-user journey. Before removal, preserve games and BIOS in a separate
microSD folder and verify backups of saves/profiles. Locate missing BIOS on the
owner's server disk and validate real files, never manufacture readiness marks.
This reset applies to Flip only; preserve Armada, boot recovery and Odin.

**Owner pre-beta release, 3 November (latest):** prepare the public pre-beta now:
GitHub-hosted Software OTA and installer over existing Armada, with an up-to-date
Armada base for the installer/image. This explicitly resumes installer/release
work in main. Handheld checks are authorized; preserve personal data, boot choices
and the original host, with builds/download temporaries on Flip microSD. Never
format or silently migrate devices to demonstrate a clean installation.
Source, staged candidate, published assets, installed build and clean-device
acceptance are distinct. Follow [the release record](docs/PREBETA_RELEASE_RU.md).
Do not label a draft or upstream Armada image as a released TrainerOS pre-beta.

**Owner original-art correction, 3 November (latest):** apply original cuboid
creatures to every adapter surface, including existing installed profiles. Legacy
private packs must not activate merely because they exist on disk. Preserve their
files and choices, but default both illustration and animation providers to original
art; imported mode requires a deliberate future selection. Replace the bundled
game-badge reproductions with original abstract medallions too. Keep semantic
species/form/badge identities, saves and progress. Graphics switches remain later.
This supersedes the older automatic user-pack precedence, not the separate #116 review.

**Owner Emerald workspace correction, 2 November (latest):** adapter-owned categories replace the empty Game spaces peer and long screen sidebar. Emerald uses Team / Field Guide / Center / Trainer, L2/R2 and touch; each category remembers its screen. Games without adapter screens have no empty primary tab. Select opens the chosen adapter without launching; preserve active game context and protected saves. Support light/dark themes and compact layouts. The original cuboid creature fallback remains #161: preserve species names/data, user-pack precedence and #116 review; private installed art is not a shipped fallback. See [implementation/evidence](docs/evidence/2026-11-02-emerald-workspace/README.md).


**Owner on-demand multiplayer and Select, 2 November (latest):** no startup or
background library-wide content hashing. Cached catalogue candidates are not
verified multiplayer profiles; check only a deliberately selected game for a
lobby/invitation, retain cancellation and exact admission/launch/save guards.
Dependency invalidation must not start another bulk read. Allow a local per-game
multiplayer flag and platform-supported mode independently of ScreenScraper;
this expresses user intent, never proof of compatibility. Select uses a compact
game card and Game / Library / View groups, not a long stack of heavy buttons.
See [current implementation and delivery status](docs/evidence/2026-11-02-demand-multiplayer/README.md).

**Owner combined delivery, 2 November (latest):** handheld access resumed.
Profile polish, game preparation and Companion host changes through `5420614a`
are installed together on Flip/Odin with signed Companion 0.1.1. See
[delivery evidence](docs/evidence/2026-11-02-profile-polish/README.md#final-delivery).
Preserve their data and approved avatars. Earlier no-device/no-install notes are
historical. Actual new achievement, physical input and performance acceptance
remain open; whole-process CPU samples were contaminated by startup multiplayer
image verification. Track that separate cost in CURRENT_TASKS, without weakening
exact-content launch/compatibility checks or claiming every tab triggers a scan.

**Current owner-approved direction: 21 October 2026.** This is the short, **active** entrypoint for Codex and other development agents. The previous 84 KB collection of dated requirements was preserved in full (with relative links rebased) in [historical AGENTS archive](docs/archive/AGENTS_2026-10-14.md). It contains valuable implementation evidence and older decisions, but its superseded page names, priorities and button assignments are **not active instructions**.

**Owner direct Home and phone-style notifications, 2 November (latest):** without
an active game, Home returns directly to the Home screen; already there it opens
nothing. Remove the rejected Now/Shell Options modal. With an active/minimized
game, Home still opens that session's existing game menu directly. Start remains
the widget/system panel. Preserve protected editing, input and exit boundaries.

Keep the upper account bell and duplicate it immediately to the right of the
footer clock. Each bell opens the same narrow inbox **beside itself**: below the
upper bell, above the lower bell. Switching bells relocates that same panel.
Ordinary toasts and incoming-call banners always appear at the bottom right.
Toast surfaces follow the shared light/dark paper and divider colors; the owner
rejected the fixed yellow surface and brown border.
A call banner has direct Answer/Decline actions; swipe or Back hides it without
rejecting. The still-ringing call stays in the inbox with direct Answer/Decline.
No intermediate Now menu or implicit microphone consent. Keep state across a
transient reconnect, isolate accounts and reject stale/busy call actions.

Level remains after the name, Sparks under it. The upper bell retains equal
insets. Footer hints stay left; Wi-Fi, battery, clock and bell are on the right
in that order. Wi-Fi opens shared connections above its own icon, with persistent
authentication errors/retry. Drawer ears use the selected controller's glyphs
without round backgrounds; keyboard fallback uses real X/Y shortcuts.
These decisions supersede the earlier clock-rightmost and fixed inbox alignment.
See [current delivery](docs/evidence/2026-11-02-direct-home-calls/README.md).
Companion 0.1.0 is now published in Crates. The owner resumed its delivery:
integrate the prepared host support into current main, install the signed package
and select it on both handhelds. Preserve their profiles, approved avatar packs
and the current Home/notification behavior. Publication alone is not delivery.
The integrated Release shell and signed package are now installed on both:
[delivery evidence](docs/evidence/2026-11-02-companion-delivery/README.md).
Owner corner correction: do not change Companion visuals in this core pass;
the renderer's rectangular clipping is tracked in [Crates #2](https://github.com/EriArk/crates/issues/2).
Its measured animation cost remains unfinished optimization, not accepted performance.

**Owner Home boundary correction, 2 November:** the left Home area belongs to
the shell and the user's selected widget. An active game adapter must not reduce
or replace it. Keep game presentation and achievements inside the game card;
the standard handheld slot fits 4×4 Start cells. Store Home widget selection per
profile, independently of the selected game and Start layout.

## Current working mode — owner correction, 21 October 2026

**Owner primary identity, 1 November (latest):** the verified Fluxer subject is
primary: it identifies the server-side TrainerOS account. Local Trainer names
are offline labels, not competing online identities and never account/commerce
keys. Prefer the connected account in the shell and player profile; preserve
local data and stable server ownership. Matching names do not establish identity.
Keep account-switch protection and distinguish connected chat from a verified
Backend session; do not hide session recovery failures with a renamed local
profile. See [player identity](docs/PLAYER_PROFILE.md#primary-identity).

**Owner offline identity, 2 November:** the last verified server TrainerOS account
remains the primary profile when the internet is unavailable, including after
restart. Preserve its identity and clearly stale presentation of name/progress/
balance; offline cache does not authorize purchases, grants or server writes.
Only explicit sign-out/account change clears that profile, not network loss.

**Owner interface performance, 2 November:** ROM discovery is one pass at
startup when enabled, or an explicit Settings action. The requirement is
single-pass behavior, not merely a visible progress label. Do not schedule
another ROM walk on page/focus changes, Recent or an idle timer. Reuse the
persisted catalogue between sessions; selected-content launch/save checks stay
authoritative. Use Flip for routine verification; Odin's problematic microSD
is not the default stress-test/build device. See
[the performance pass](docs/evidence/2026-11-02-catalogue-performance/README.md).

**Owner support-provider decision, 29 October (latest):** Patreon is the only
support provider. Remove Ko-fi from active requirements and draft contracts;
it is cancelled scope, not unfinished work. Keep historical delivery records
as history. Preserve the approved Patreon tiers and remaining paid-cycle acceptance.

**Owner Patreon setup, 29 October:** prepare real account binding and the creator
tiers in the already signed-in Patreon account. The owner approved Spark / Искра
at **$3/month, ×2 Sparks**, and Supernova / Сверхновая at **$5/month, ×3 Sparks**.
No XP multiplier or monthly currency allowance; preserve earned rewards and
purchases on cancellation. This supersedes the earlier unselected Patreon prices.
Do not silently bind the owner's personal Patreon to handheld test users Ren/Mika.
The owner subsequently chose to leave Patreon unbound for now; do not resume
personal OAuth or a paid-cycle check until requested. Server-side test Sparks
for Ren/Mika are separately authorized and do not activate Patreon support.
See [binding, deployment and remaining acceptance](services/backend/support-binding.md).

**Owner avatar reference, 29 October (latest):** the restored face from the
owner-supplied `painted-face.glb` is now the approved
[canonical reference](assets/avatar/approved/face-2026-10-29/README.md).
Preserve its exact head geometry, normals, UVs and skinning at the approved 0.92
scale. Revision 9 bridge sculpt and `before-front` are rejected references.
Fit clothing and eye layers around the approved head; never sculpt the head to
hide a collision. Run `check_face_reference.py`, `check_eye_layers.py` and
`check_pack_collection.py` before every avatar pack delivery. The owner also
requires lips, brows and lashes to darken continuously as skin gets darker;
this is a material rule, not permission to change the approved face shape.

**Owner rewards/profile discussion, 28 October (latest):** before Patreon,
the owner accepted level clothing rewards, an additional permanent outfit slot
every three levels, first-completion trophies and selected game wearables,
grouped celebrations, a five-item showcase and friend-profile viewing. The subsequent owner continuation authorizes implementation of the shared
awarding mechanism, free slots, collection and presentation. The previous
discussion-only boundary is superseded; friend-profile completion remains open. No new prize models yet. Preserve purchased
slots and current shared wardrobe; distinguish ordinary verified completion from
the existing full-RA-set reward. See [contract and entry/return map](docs/PLAYER_PROFILE.md#согласованный-следующий-блок--награды-и-профиль-друга-28-октября).
The reminder below now follows this block, not the wardrobe delivery immediately.

**Owner saved-look decision, 28 October:** add permanent paid wardrobe slots for
quick switching before or during a game. Each slot stores the **complete look,
including hairstyle**, not clothes alone. Reuse the existing purchase ledger,
Trainer avatar persistence and `avatar.changed`; preserve the free current look
and parallel clothing-model work. The owner chose **100 Sparks per permanent
slot**, without a level requirement; saving and switching are free. After this
block, remind the owner to finish real Patreon binding.
See [saved looks](docs/PLAYER_PROFILE.md) and [purchases](services/backend/purchases.md).

**Owner support-level decision, 28 October:** support has two levels, ×2 and ×3,
with free base earning ×1. This selects multipliers only, not prices or payment
activation. Keep the read-only balance preview distinct from verified membership
and actual retrospective grants; see [progression](services/backend/progression.md).

**Owner profile-purchase decisions, 28 October:** the first three new permanent
profile scenes cost 250 Sparks each; existing appearances remain free. Make
distinct game-like scenes, not palette swaps. Keep the full preview / explicit
purchase / permanent ownership / apply / recovery journey. This authorizes these
three prices only, not supporter tariffs or declaring the whole economy complete.
See [purchase scope and remaining work](services/backend/purchases.md).

**Owner functional-completeness correction, 28 October:** the profile/Online
delivery is partial. The owner explicitly includes experience, account levels,
earning/storing Sparks and the related economic foundation in the intended
functional result. Do not narrow this correction to failing tests, label UI or
one implemented layer complete, or move on while required behavior is missing.
Accounts/Play and unavailable-value profile fields do not implement progression
or a wallet. See [the factual audit and open criteria](docs/PLAYER_PROFILE.md#функциональная-незавершённость--коррекция-28-октября).
Retain #262 constraints and unresolved policy decisions; do not duplicate the
Backend-owned economy in the shell. **Later owner instruction, 28 October:**
choose approximate initial reward amounts and XP thresholds for an ordinary retro
player; the owner will rebalance much later. Version the policy and preserve
already granted rewards. This authorizes those initial numbers, not invented
supporter prices, purchases or trust claims. See [progression policy](services/backend/progression.md).

**Owner Backend correction, 25 October 2026:** prepare the complete shared
server architecture before implementing/polishing individual working scenarios.
Use [Backend architecture v1](docs/TRAINEROS_BACKEND_PLAN_RU.md#architecture-v1):
all module/data/API/SDK/trust/operations boundaries, not a golf-first vertical
slice. Golf is a later integration example. This is a scoped Backend instruction,
not a restored global execution queue. **Later owner correction, 25 October:**
implement, build and test the Backend directly on the existing server; do not
accumulate local databases, downloaded runtimes or build environments. Server
installation is now authorized in this chat. Keep the live Lobby bot independent;
handheld tests and GitHub publication remain outside this increment. Architecture
is not runtime implementation or server acceptance.

**Owner account clarification, 25 October:** sign in through Fluxer, with no
separate TrainerOS username/password. A stable internal TrainerOS ID binds to
the verified Fluxer subject, never its display name. Use a separate OAuth app
named TrainerOS, owned by the owner's permanent account; preserve the existing
Lobby Directory app. Keep provider credentials outside games/SDK. Server source
and isolated provider tests do not prove live owner consent or shell integration.

**Owner login UX correction, 25 October:** OAuth application creation and server
configuration are one-time operator work, never player setup. Ordinary players
sign in through Fluxer and return to TrainerOS; mandatory manual device-code
entry is not the accepted ordinary flow. Preserve secure device/browser binding
when implementing native return. The existing code-confirmation flow is an
interim backend mechanism, not delivered SDK/handheld UX.

Global plans, milestones and mandatory execution queues are withdrawn. Work
by the readiness of individual features, using [the readiness map](docs/FEATURE_READINESS.md).
Keep unfinished requirements and unchecked acceptance; there is no deferred category.
Older sequencing in issues, plans and reports is historical, not an active queue.
Record real dependencies beside the feature. Do not create a replacement global plan.
The owner made both handhelds available again on 21 October 2026. Connections,
bounded runtime checks and delivery to Odin/Flip are authorized. Preserve each
device's profiles/saves/settings; physical and different-network acceptance remain separate.

**Owner structural map, 21 October 2026:** use [STRUCTURE_MAP_RU](docs/STRUCTURE_MAP_RU.md)
as the canonical map of console-owned responsibilities, package roles and cross-system
contracts. Each readiness row links its primary owner and affected systems. Before a
change, identify the owner, entry/exit contract, consumers and lifecycle consequences;
use the map's F01–F12 end-to-end flows and reverse impact table to trace affected paths;
reuse its current implementation. Trace issue coverage through
[REQUIREMENTS_COVERAGE_RU](docs/REQUIREMENTS_COVERAGE_RU.md) and stable readiness R-IDs;
retain superseded decisions separately from unmet requirements. Update the map when ownership/contracts change,
and readiness/evidence when implementation or checks change. This is not a global
execution plan or an instruction to create new managers/microservices. Public SDK,
backend targets and installed built-ins remain distinct evidence levels.

## Read before working

**Owner library size correction, 21 October 2026:** exclude Xbox 360 and PS3
from the current handheld copy and final matched libraries. Stop their transfers
and remove only this job's copied/partial payloads; preserve source files and
personal saves. The active selection is now 314 games across 24 families; the
original 321-entry request remains historical evidence, not the current copy plan.
The owner cancelled the lengthy full SD checksum pass: successful transfer,
file presence and expected sizes are sufficient for this delivery. Do not restart
full disk hashing. The completed old-game comparison is retained; both Sacred
installer copies and the matched library/12 genre collections are now applied.
The owner additionally requested thematic genre covers on both devices. Preserve
the installed library composition and each owner's saves/history while applying art.

1. [Current product](docs/PRODUCT_ARCHITECTURE_RU.md) and [structural map](docs/STRUCTURE_MAP_RU.md) — **what TrainerOS is, which component owns each function, and how they connect**.
2. [Documentation index](docs/README.md) — where to find the appropriate current feature contract, implementation evidence and historical source.
3. [Feature readiness](docs/FEATURE_READINESS.md), [CURRENT_TASKS](docs/CURRENT_TASKS.md) and the **specific GitHub issue** — feature state, task scope and outstanding acceptance.
4. [DEVELOPMENT_WORKFLOW](docs/DEVELOPMENT_WORKFLOW.md) and [DEVELOPMENT](docs/DEVELOPMENT.md) — reproducible builds, review, tests, device and publication rules.
5. Read **only relevant** technical docs for the feature. Examples: [ARCHITECTURE](docs/ARCHITECTURE.md), [DATA_MODEL](docs/DATA_MODEL.md), [DESIGN_LANGUAGE](docs/DESIGN_LANGUAGE.md), [ARMADA_PLATFORM](docs/ARMADA_PLATFORM.md). Read [adapter knowledge](docs/adapters/README.md) and [src/adapters/AGENTS.md](src/adapters/AGENTS.md) before adapter/save work.

The short [PRODUCT_SPEC](docs/PRODUCT_SPEC.md) records accepted screen decisions. Removed long UX/expansion documents remain in Git history; the old [AGENTS](docs/archive/AGENTS_2026-10-14.md) is **dated history**. They provide retained requirements and evidence, not permission to revert newer owner decisions.

**Conflict rule:** newer explicit owner decision and its current feature issue → [current product map](docs/PRODUCT_ARCHITECTURE_RU.md) → feature readiness and dependencies → implementation/evidence of the actual build → historical text. If a recent issue conflicts with the summary, **update the summary**, not the working issue. A newer *target* does not mean it has been implemented. Never silently drop uncompleted acceptance.

## Product identity: an OS-level environment, not a ROM frontend

TrainerOS is a **controller-first native Linux shell / operating environment** with its own UI, games, Social, Apps, files and extensibility. First physical integration is ArmadaOS on supported ARM handhelds, notably Odin 2 / Flip 2; SteamOS/Deck and Bazzite are later target hosts. Do not build a new distro kernel, remove Steam or force ordinary tasks into the KDE maintenance desktop. The source is **not** a publicly released ready-to-flash OS yet.

### Current target navigation

**Exactly five shell primaries:** `Home | Games | GameHub | Online | Apps` (L1/R1).

- **Owner correction, 26 October:** profile through the header avatar uses selected composition A, with Profile / Wardrobe tabs. Recent achievements and Player Journey are information blocks with links to full RA/history/screens, NOT extra tabs. Profile source now reuses the existing controllers; Online relocation is implemented in source as of 28 October; Bazaar worlds and trading remain unavailable. Show account Mastery/Level and **Sparks / Искры** (a golden spark inside a glass coin), including the valid server-backed potential balance/support top-up required by #262. No economy data means unavailable, never demo values. Profile comes before Bazaar implementation; see [the profile/Online contract](docs/PLAYER_PROFILE.md).
- **Games:** collections + platforms. On the root, R3 / Import ROM opens the existing file picker and registers the chosen ROM in place, then checks file/runtime/described firmware readiness. Game setup offers play, repair, recheck and done; unknown native requirements remain explicitly unverified. Reuse LaunchPreparation and native setup window ownership, and keep online console files separate from ordinary play. Inside a game list R3 still changes the view. **GameHub:** game spaces and the selected game's Adapter.
- **Online replaces Social:** Lobby / Bazaar / Chats. Chats retain people, groups, communities, discovery and voice through the existing provider. Communication root B focuses Messages / Communities / Discover; left/right switches, A/down enters; nested Back closes its own level first. L2/R2 stay on the Online faces. Preserve independent lifecycles and route/focus return; do not build replacement services.
- **Apps:** Apps / Crates / Browser / Files. The owner moved the Crates catalogue back to Apps on 9 November; this supersedes the 26 October Online placement. Installed applications remain here. Ordinary Linux apps remain ordinary apps; Crates is a curated opt-in source, not a second package manager.
- **X** globally toggles Quick Apps dock and **Y** globally toggles Recent Games/Favorites in the **shell**; do not steal them in inner pages. Select targets the focused object; Browser/Files toolbar exceptions and long-A context action follow their specific issue contracts.
- Physical **Home** opens the actual running game menu, or returns directly to Home when no game is running. Notifications use the bells. Selected game, live PID/session and foreground/input owner remain separate facts.
- Physical **Start** in the shell is the unified widget dashboard with quick actions, Settings and Power. Native Start during unmodified gameplay belongs to the game. Home → Start opens the same dashboard in-game. Selected-game settings use its context menu; running-game settings use the actual game menu. System Settings/Power belong to Start.
- Opening Home alone is not auto-pause, auto-minimize or Exit. Preserve explicit Minimize/Return, input leases, neutral barriers, a predictable focus return and protected exit/save workflow.
- The **only** ordinary multiplayer destination is **Online Lobby**. Special game-specific semantic interactions can remain in the Adapter; do not create a parallel Social/GameParty or NetPlay/Remote Play UI. Existing route names must migrate safely; this target does not claim new installed navigation.

**Source of truth for these targets:** #111, #168, #170, #179, #206, #207, #216, #224, #227, #233, #234 and their accepted later amendments. Delivery is recorded by build/date in PROJECT_STATUS; SDK targets are not installed API claims.

## Current owner constraints

- **Owner storage correction, 26 October:** keep handheld build sources, object
  files, dependency caches and container build storage on microSD. The internal
  partition is for the installed system and working user data. Check mount/free
  space before building; preserve active jobs, profiles, saves and rollback
  copies during cleanup. See [Armada build storage](docs/ARMADA_PLATFORM.md#build-storage--26-october-2026).
- Picker #252–254 and PC #246–251 retain their unfinished criteria in the readiness map. The completed [library delivery](docs/MULTIPLAYER_SELECTION_DELIVERY.md) is evidence, not a new transfer task.
- Earlier delivery scope, retained as requirements rather than execution order: PC Home/exit without repeating passed checks. Make the two visible libraries identical: the approved selection plus old games confirmed present on both handhelds; copy both supplied Sacred distributions. Replace the old collection views with genre collections while keeping each owner's saves, profile and history. Remove the temporary PC input fixture, its library cards and temporary folders from both devices at the end. Copy verification is not installer integrity or gameplay compatibility.
- Keep one live room and separate scheduled rooms. All Ready enables the host's explicit Start; never auto-launch. Offline Lobby, private PSP and the full pass-controller catalogue remain unfinished features in the readiness map.
- Couch means independent simultaneous pads. Do not manufacture PS2 couch networking with two local game copies. Reuse upstream networking and existing Fluxer signaling.
- First beta is an installer over Armada; images and SteamOS/Bazzite come later. SDK/backend/account targets do not automatically block it.
- Preserve both devices' own profiles/saves/settings. The owner permits removing Steam games and other ROMs when needed for the agreed selection; preserve server originals and record exact removals privately.
- Do not test a sleep cycle: no suspend/resume, Power short-press or lid-close test. Prior Power implementation and untested sleep acceptance remain separate.

## Architecture & engineering rules

- C++20 / Qt Quick / QML / CMake, SQLite behind repositories, platform and emulator behaviors behind service boundaries. Keep the normal UI user-oriented; no distro commands or save offsets in QML.
- **Reuse code and real providers** before introducing abstractions: existing Fluxer worker/Social, Lobby, emulator NetPlay, remote-play transport, Files/File Picker, global Downloads, launch/exit service, device integrations. Avoid second backends, duplicate state ownership and speculative plugin microkernels.
- **Game-specific Experience modules** reside under `src/adapters/<id>/`, composed via `src/core/experience/` rather than scattered title switches in shell/QML. An adapter's presentation compatibility does **not** grant exact-save write authority.
- **Ordinary local games work offline without semantic adapters.** ROM/save/BIOS contents, keys, personal media, private research and credentials must never be committed or silently redistributed. Protect exact-game save writes through existing owner, build, source-revision, backup, atomic replacement and readback gates; no silent mutation while a game owns the save.
- Keep game process, conversation, call, Lobby and Downloads lifecycles independent where the product requires it. Avoid fake support, silent placeholder success or equating passed unit tests with physical player acceptance.
- Device host capabilities are **reported and gated**, not guessed. Respect gamepad, touch, handheld/TV layout, stable focus and short purposeful animations; never make normal use require a mouse/keyboard.
- Prefer fixing a known scope end-to-end rather than replacing stable components with fashionable technology. Respect settled architecture and reuse passed tests unless the change directly affects them.

### Platform SDK / Crates — bounded local API, wider contracts remain targets

Local protocol v1 preview now implements discovery, real context/events and a
host-owned text widget with callback/cleanup; see [author entry](sdk/README.md)
and [evidence/remaining contracts](docs/PLATFORM_SDK.md). Wider SDK/SPI targets
and handheld delivery remain separate. Extend actual owners through this bridge,
not placeholder successful APIs.

Native activity / two-peer reliable record integration now uses the existing
LobbyRuntime and secure record helper; see [the app contract](sdk/NETWORK.md).
Keep local TLS/process evidence separate from live Fluxer accounts, internet/NAT,
offline admission, unreliable channels, five-player and handheld acceptance.

[#235 — TrainerOS Platform SDK & Network Fabric](https://github.com/EriArk/TrainerOS/issues/235) and #236–244 define optional service/contribution contracts for games, apps, media/file providers, tools and system modules. They extend existing #231 (system module SPI), #92/#207 (semantic adapters), #179/#216 (Lobby), #233 (Start), #229 (Files) and #144–152 (Crates); **do not implement parallel systems**.

**Freedom by default:** no mandatory new account, special SDK approval, Crates publication, custom server, large manifest or blanket permission prompt just to run an ordinary Linux program, access one's own data/network or show a normal approved widget. Check real trust boundaries: protected saves, other profiles/private messages, voice/capture, device privilege and irreversible operations. Host owns trusted surfaces; untrusted downloaded QML/native code cannot arbitrarily execute inside shell.

**Network Fabric:** LAN/nearby/direct P2P, existing Fluxer identity/invitations/signaling and **only genuinely supported** provider messaging/relay as selected by workload. [#105](https://github.com/EriArk/TrainerOS/issues/105) owns Fluxer transport research. Do not assume a voice/video connection provides unlimited arbitrary realtime game packets, guarantee connection through difficult NAT or force a centralized packet proxy into each frame. Distinguish low-rate semantic events and realtime gameplay. The system should make a tiny Tetris/Tanks app easy to integrate.

No new SDK epic/child task becomes a blocker for the first early public beta merely because it exists. Keep each release requirement and its actual dependencies in the readiness map.

## Retained owner delivery preferences

- For a **new substantial work increment**, announce the intended user-visible slice and a suitable reasoning-effort recommendation before beginning. Preserve the owner's earlier six-position scheme when explicitly using it: **1/6 Низкое, 2/6 Среднее, 3/6 Высокое, 4/6 Очень высокое, 5/6 Максимум, 6/6 Ультра**. If changing the previously agreed level, explain briefly and wait for the owner's continuation. Do not turn a scope discussion into implementation permission.
- Prefer a **complete useful feature chain** (provider → UI → relevant tests → device → commit) to a pile of isolated internal microtasks.
- When deploying an actual build, update **both Flip 2 and Odin 2 when reachable**, preserve separate user state/boot/session preferences, and report deferred devices. Never claim Windows/Linux host tests as device proof.
- Game/save adapter edits also follow [adapter knowledge](docs/adapters/README.md): update factual per-title evidence and run `tools/export-game-adapters.py` / `tools/check-adapter-knowledge.py` as applicable.
- Respect original [GPL and third-party code/art license boundaries](LICENSING.md), and keep screenshots/reports free of private accounts, downloaded ROMs, saves, keys and unapproved artwork.

## Development delivery loop

1. Confirm task and accepted scope. Questions, informal brainstorming and proposals **do not authorize** new code/issues/repo edits. When explicitly authorized, work on a coherent outcome without repeatedly asking permission for ordinary commit/push.
2. Inspect branch/HEAD, repository state, active issues and relevant **existing** implementation; preserve unrelated user changes. When using a remote GitHub-only editor, check the current file SHA, update carefully and verify the resulting remote content/commit.
3. Implement the **smallest complete usable path**. Preserve existing UI state, saved data, input and backward compatibility. A test/migration/protection is part of that feature, not a separate invented milestone.
4. Verify appropriately: native build/focused tests for code; broader regression for shared input/storage/process behavior; real controller+touch and device screenshots for UI. A mock or local host test **is not proof** of functioning Odin/Flip hardware. Documentation-only changes need reviewed text, links and diff, **not unrelated device deployments**.
5. Update relevant current feature docs, actual evidence and acceptance; for meaningful delivered changes/decisions also update [PROJECT_STATUS](PROJECT_STATUS.md) and [CHANGELOG](CHANGELOG.md), **without rewriting historical dates or reporting planned features as installed**.
6. Commit and push the inspected work; verify the final remote commit. GitHub Actions are deliberately disabled as a release gate — do not recreate workflows or await billing/CI. Report what changed, what was checked and which acceptance conditions remain.
7. If real hardware, extra accounts/networks or a user decision are required, record the precise remaining dependency, complete safe independent work, then stop; don't manufacture tests to appear busy.

Owner reporting preference: end every final report with an explicit
**Доделано / Недоделано** status for the requested scope and what comes next.

Never force-push shared history, destroy others' work, suppress failing tests or expose secret account data, ROMs/BIOS, private saves, copyrighted assets or debug support bundles.

## Documentation discipline

- **README.md is a human-facing product showcase**, not architecture reference, TV advertising copy or a list of internal component names.
- Prefer **one clear active contract per responsibility**, with links from the index and short supersession banners on older still-linked texts. Preserve technical evidence and old build dates in their historical documents.
- Keep **target, source implementation, installed device build, real test and remaining work** separate. A closed issue or screenshot does not prove general compatibility.
- The current product/SDK map is short; feature issues specify behavior; code docs explain *how*. Do not recreate 100 KB specifications or copy the same policy into 20 issue bodies.
- Validate local Markdown links and actual GitHub issue paths where touched. Older literal terminology such as Worlds, OddCrate, Companions/Trainer primaries or an old Start menu must be clearly dated or corrected when presented as the **current target**.

**Historical appendix:** the full original agent memo, including early Android retirement, Pokémon-first UX, deprecated priorities, detailed per-game research and individual hardware reports, remains available at [docs/archive/AGENTS_2026-10-14.md](docs/archive/AGENTS_2026-10-14.md). It is evidence/history rather than an alternate current plan.
