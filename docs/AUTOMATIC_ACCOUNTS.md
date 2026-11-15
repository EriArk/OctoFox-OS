# Automatic OctoFox OS accounts

After Fluxer signs in or restores its saved session, the shell automatically
connects the matching OctoFox OS profile. This also upgrades existing installations
whose users previously connected chat without a Backend account. No second browser
login is required. Identity is the verified Fluxer subject, never a display name.

New players get a temporary `Fox-…` nickname. First-run Accounts offers the nickname
and the existing avatar editor; both may be completed later. The profile page edits
the OctoFox nickname independently of Fluxer's chat display name. Returning users
restore their own server name/avatar before local edits can be uploaded, along
with the existing progression, inventory and rewards synchronization. Local game
saves are not uploaded by this feature.

A C++ callback connects the existing Social worker and Backend account owner.
The session credential never enters QML properties/signals, SDK or persistent
Backend storage. The Backend independently verifies the provider session and
compares it to the attempt's expected subject before resolving the player.
Responses from an old local owner/account are discarded. Network failures back
off automatically; secure-storage and rejected-credential failures stay visible.

Server migration and API are documented in `services/backend/accounts.md` on the
matching account-server branch until integration. Existing OAuth return flows and
refresh recovery remain supported. The owner requested a merged Alpha release
and real OTA on both handhelds after publication; source/test results alone are
not that acceptance.
