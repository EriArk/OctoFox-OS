# Alpha 8 overview — 15 November 2026

## Deliverable

One finished silent MP4, **08:21.1**, **1280×720 / 30 fps / H.264**, with
53 burned-in English explanations and embedded chapter markers.

Owner-local artifact directory:
`/run/media/eriark/Data/Projects/.codex-artifacts/octofox-alpha8-overview-20261115/`

- Final: `delivery/OctoFox-OS-Alpha-8-Overview.mp4` (39,298,458 bytes).
- Editable English text: `delivery/OctoFox-OS-Alpha-8.en.srt`.
- Original recordings: `sources/`; the named two-view composition has its own provenance JSON.
- Reproducible cuts, captions and render/verification scripts: `edit/`.
- Review sheets, full-size frames and decode log: `review/`.
- SHA-256 manifest and machine-readable verification: `delivery/`.

Final SHA-256: `2b4c97866638a865c4c26bc8296f5bc8483de4ef4a3745e98f00bcb389753ad2`.
No MP4, ROM, game save, credential, private message or device support bundle
was added to Git. The movie contains only the approved test profiles and
actual installed interfaces; it is not the HTML demonstration.

## Contents

- **00:00** — Welcome · Make it yours.
- **00:33** — Home & Games.
- **01:17** — Games, apps & the desktop around them.
- **02:16** — Friends & one shared Lobby.
- **03:58** — My Story · Remember the session.
- **04:18** — Pokémon · Beyond the emulator.
- **05:42** — One character · Many experiences.
- **06:10** — Crates · Discover and play.
- **06:51** — Bazaar · Spaces for players.
- **07:34** — Ship Home · Between adventures.
- **08:12** — OctoFox OS · Alpha 8.

The tour shows persisted color changes and Dark Mode; four library views,
collections, Recent/Favorites and Mario Kart 64; Steam launching Dead Cells,
Home → Minimize → Quick Apps → the same running Steam process; Start widgets,
Files and Browser; test-account messages, invitations, game proposals/voting,
Ready and manual organizer Start; a real paired NES Pong match; My Story and
screenshots; Pokémon adapter sections and a real save edit; wardrobe/Companion;
Crates and a real Pocket Golf putt; Festival Park, NPCs and a personal Bazaar
preview; Ship Home walking, pilot first-person view and decoration preview.
The paired gameplay insert synchronizes two real captures by wall-clock start;
it does not fabricate a second player.

## Source changes and acceptance

Public Alpha 8 / Software 49 remains unchanged. The capture branch is
`codex/alpha8-overview-20261115`; the real private installation used Software 50
for restored palettes and Software 51 for the netplay correction.

- `e0517bf3`: restored Turquoise, Red, Green, Blue, Orange and Dark selection
  in Personalization, retaining stored settings rather than a recording-only switch.
- `c05da204`: removed the space from the generated emulator session nickname.
  `OctoFox OS-…` violated the protocol token validator and rejected Start;
  `OctoFox-…` is valid. Added a regression through the real session-start path.
- Native build and ARM build completed. LibraryTests: **35 passed**;
  FirstRunTests: **20 passed**; final RuntimeMultiplayerTests: **118 passed, 0 failed**.
- Both devices ran the signed Software 51 binary
  `b3d7151bc192e7307290d10d5295df1bd4d6f8d5394997564d09ff04d9660781`.
- Actual NES netplay joined the second player and produced matching scores,
  timer and independent paddle input. The first guest attempt exited; the
  normal Rejoin action succeeded. This is not a claim that every connection
  or emulator route was revalidated.
- Dead Cells ran through the installed Steam integration. Minimize and
  Quick Apps returned to the same game process (PID 71276 during the capture).
- Input used XTest against the real UI and the production game-Home interception
  path. This is not an additional physical gamepad acceptance claim.

## Data and capture preservation

The Emerald party edit swapped the first two party members. Linoone became the
first slot both in the adapter and in the actual running game. After normal
exit, the original save was restored byte-for-byte and rechecked:
`3fca83edc8bb3d69f5627a6ecec820069ca7fac8699676ecade2fd748ea47c7a`.
The original and edited demonstration copies remain private on the device.
Temporary avatar hair and the Ark favorite were restored through the UI.

Capture used a continuous current-focus compositor stream, cutting recording
files without disconnecting the capture producer between games. A previous
per-clip capture disconnect exposed the known Gamescope 3.17 failure on Flip;
recording continued after a normal recovery. Capture was stopped after games
and apps were closed. Odin returned to the shell and passed binary, empty
session journal, capture-process cleanup and database checks. Flip required a
normal reboot after capture teardown. Its former address did not return to
SSH, and a bounded LAN SSH discovery found no replacement. All game/app
sessions were empty before reboot. Post-reboot Flip shell recovery remains
unverified and needs the physical device to be checked; no guard files were
deleted or bypassed. This does not affect the completed recording.

The final MP4 passed a complete ffmpeg decode, exact timeline-duration and
video-format checks. All cut midpoints and important full-size caption frames
were visually reviewed. Source waits and unsuccessful attempts are retained
outside the published edit. No actions are artificially sped up.

## Limits kept explicit

- No earned RetroAchievements detail: the current test profiles had no linked
  account with available earned-achievement data. The integration is mentioned
  on the genuine My Story screen, without inventing an unlock.
- One multiplayer transport was demonstrated. Pokémon Link and a second
  transport were not captured in a verified scenario.
- Participant/voice controls are visible, but no completed voice conversation
  or in-game message exchange is claimed.
- Furniture tools are previewed; actual placement was not demonstrated.
- Bazaar purchases, trading and network visits are explicitly in development.
  The personal world is a local preview. Ship Home is explicitly experimental.
- Pocket Golf's solo round works. Its native networking capability warning in
  the current launch path was not presented as working SDK multiplayer.
