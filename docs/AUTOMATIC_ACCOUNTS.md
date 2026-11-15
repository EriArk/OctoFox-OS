# Automatic OctoFox OS accounts

After Fluxer signs in or restores its saved session, the shell automatically
connects the matching OctoFox OS profile. This also upgrades existing installations
whose users previously connected chat without a Backend account. No second browser
login is required. Identity is the verified Fluxer subject, never a display name.

New players get a temporary `Fox-…` nickname. First-run Accounts offers the nickname
and the existing avatar editor; both may be completed later. The profile page edits
the OctoFox nickname independently of Fluxer's chat display name. For a linked
Fluxer account, the account action refreshes synchronization; sign-out belongs to
Fluxer, which also revokes the OctoFox device session. Returning users
restore their own server name/avatar before local edits can be uploaded, along
with the existing progression, inventory and rewards synchronization. Local game
saves are not uploaded by this feature.

A C++ callback connects the existing Social worker and Backend account owner.
The session credential never enters QML properties/signals, SDK or persistent
Backend storage. The Backend independently verifies the provider session and
compares it to the attempt's expected subject before resolving the player.
Responses from an old local owner/account are discarded. Network failures back
off automatically; secure-storage and rejected-credential failures stay visible.

Server migration and API are documented in [the Backend contract](../services/backend/accounts.md). Existing OAuth return flows and
refresh recovery remain supported. Alpha 8 is published; public OTA succeeded on Odin and Flip. Odin restored the
same Ren account automatically from its saved Fluxer session after an OS-only
signout on Software 48. Flip's provider session was already signed out; a normal
official browser sign-in and device handoff automatically restored the same Mika
player on Software 49. No second OS sign-in or duplicate player was needed. See [delivery and limits](evidence/2026-11-15-alpha8/README.md).
