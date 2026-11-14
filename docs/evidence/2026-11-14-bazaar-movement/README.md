# Bazaar movement and presentation — 14 November 2026

Source implementation on `codex/bazaar-entry-device-20261114`: shared optional
Godot motor/locomotion SDK and an official card using the actual Festival Park
render. The Bazaar game vendors those modules; no host capability or paid feature
is enabled. See [SDK integration](../../../sdk/LOCOMOTION.md).

Host checks: [14 motor checks](motor.txt), [seven animation states](locomotion.json)
over 360 frames each, original bind/skin/joint lengths preserved. The SDK's own
project was imported and tested separately from the Bazaar project. Visual review
and world/layout/service checks live in the Crates Bazaar movement evidence.

## Delivered on Flip 2 and Odin 2

Private Software **45**, source `884e9a87e425ad3e98ba38a824f3bf3f232fec27`,
is installed on both devices. [Package fingerprint](package.json).
Signed identity: `f3b7de187d18fbf3dfdde64e20adc4ee962ad882a435ed918b9bf679aaa3c564`.
Sequence 44 was superseded before installation; reserve **46+** next.
Only the shell binary changed from the previous sequence 43 payload. Flip's
managed receipt reports `first-frame-confirmed`; Odin used its existing legacy
in-place update path. Sequence 43 is retained for recovery on both.

Bazaar **0.0.8**, source `020635ada03063e8826c671fa190954815bc686b`, is installed
on both alongside retained 0.0.7 rollback. **Online → Bazaar → Festival Park**
opens the game; normal Leave Bazaar returns to the selected card. The source
counter-front correction is included: model +X faces the aisle independently
of the seller's +Z forward axis. It is also visible in the updated cover.

Native shell checks passed: 8 Bazaar tests and 20 Apps tests, plus
[light/dark/size UI scenarios](shell-ui.json) with zero warnings.
[Fixture catalogue screenshot](catalogue.png) contains synthetic profile data.
Native and ARM64 builds passed. Game Linux x86_64/ARM64 and Windows exports passed;
Windows gameplay was not tested.

On both handhelds, actual screens and remote XTest input confirmed the new HUD,
personal avatar, counter fronts, run, crouch, jump, menu and normal return.
Sprint was additionally sampled on Odin. Logs contained no script/resource errors
or exit warnings after normal Leave. No live game process remained (defunct child
entries were observed). These are remote-input checks, not physical pad/touch
acceptance or a sustained frame-time benchmark. Full two-foot terrain IK remains
outside this increment. A forced desktop export shutdown did emit fountain-audio
resource warnings; the normal handheld Leave path did not.

Database quick checks and profile/owner/adventure row counts passed on both;
Bazaar preferences remained byte-identical (Flip FOV 90°, Odin 75°). Odin volume
remains zero. Task staging, archives, helper scripts and capture caches were
removed, retaining profile backups, install records and verified rollback.
Internal free bytes before staging / after cleanup: Flip 24,164,429,824 /
23,881,474,048; Odin 8,732,372,992 / 8,531,267,584. The installed game and rollback
account for retained storage. Personal-device captures remain private and untracked.

No branch merge, public release, new host capability or paid feature activation.
