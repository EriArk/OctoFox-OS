# Installed Home widgets, v1

An app package may contribute up to eight declarative Home widgets in
`home-widgets.json` at its content-addressed package root:

```json
{"schema":1,"app":"home-companion","widgets":[
  {"id":"pet","title":"Companion","renderer":"avatar-care-v1","assets":"assets"}
]}
```

`app` must equal its installed Crates package ID. Local IDs are unique lowercase
letters/digits/hyphens (max 64); titles are nonempty and at most 64 characters.
`assets` names one direct directory of the package. The host validates the active
receipt, content-addressed object identity, bounded manifest, canonical paths,
asset presence and renderer before offering a choice. No downloaded QML, native
plugin, arbitrary file URL or script executes inside the shell. Unknown renderers
require a future host update; there is no silent fallback to a different widget.

Home contributors are Home-only by default. The host omits `ui.start.widget`
from their SDK handshake and rejects `widget.put` with `home_only_app`. Inventory
changes remove any already registered Start contributions from those apps.
A package with a genuinely separate text-only Start contribution may explicitly
set top-level `"allowStartWidgets":true`. Apps without a Home contribution keep
the existing Start contract. Companion 0.1.0 needs no package replacement: its
existing manifest already uses the Home-only default. This is a surface policy,
not OS process authentication or a sandbox.

The initial trusted renderer is `avatar-care-v1`. Its asset contract contains
three backgrounds (`backgrounds/cozy-room.png`, `sunny-garden.png`,
`evening-nook.png`), `furniture-kit/loungeChair.glb`, and six `food-kit/` GLBs:
apple, banana, burger, cookie-chocolate, cup-tea, cupcake. Models must be
self-contained. The shell owns avatar resolution, care, game time and inbox
navigation. State is per profile and separate from replaceable package assets.

The stable choice is `crates:<package>:<local-id>`. Inventory updates revalidate
the contribution and switch asset roots. Removal hides it immediately, stops its
renderer/timer and retains the saved selection and care state. Reinstall makes
that selection available again. Installing alone never replaces the user's Home
selection. **Open** in Crates selects its first contribution through host routing.

The avatar-care presentation is created only on the active, unobstructed Home.
Leaving Home, opening Start/drawers/keyboard, or deactivating the shell destroys
the complete widget, its 3D scene, animation timers and owned geometry. Returning
creates one instance from the current profile. Care, queued achievements and
verified gameplay accounting stay in their lightweight host services; unloading
is not the Rest action and grants no energy. Render-driver caches need not cause
process RSS to fall immediately when a presentation is destroyed.

## Optional SDK activation

Hosts advertise `ui.home.widget:1` only when the selector is bound. After a user
opens the installed app, it may call:

```json
{"id":"2","method":"home.widget.select","params":{"id":"pet","revision":"17"}}
```

Only the authenticated app's installed contributions are eligible. As elsewhere
in the local SDK, app names are logical namespaces, not an OS security sandbox.
The current profile and context revision are required. Success returns
`{"id":"pet"}`; errors include `unsupported_method`, `no_profile`,
`stale_context`, `invalid_widget`, `widget_unavailable`, and `session_busy`.
No game is ended or minimized to satisfy a request. Clients must not retry after
a context change without a new user action. Python: `client.select_home_widget("pet")`.

The contribution stays installed when the app disconnects. This is separate from
ephemeral Start widgets (`widget.put/remove`). Packages remain ordinary `app`
records, so older catalogues/installers continue to validate signed snapshots.
Older shells require an explicit software update to display Home contributions;
the app launcher reports that dependency rather than claiming success.
