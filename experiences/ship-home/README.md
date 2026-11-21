# Ship Home — development preview

**Handheld entry, 15 November 2026:** Software 48 adds the upper saucer button
on both Odin and Flip, retaining their current Bazaar shell. Enter directly from
that icon; Apps remains an alternative. [Device checks](../../docs/evidence/2026-11-15-ship-header/README.md).

The bow cockpit opens directly into a studio inside the 10.6 × 12.4 metre saucer.
Curved ceiling panels surround an illuminated orbital dial. Portholes light the dinette, and an inlaid runner crosses the timber deck. An enamel landscape of Echo Orchard hangs above the quilt. A berth is recessed into the aft liner between two illuminated display shelves.
Bent walnut surrounds the two retractable terminals. A narrow brass lip catches the light around each glass face. The same walnut and dark woven grille flank the sleeping alcove. A shielded wall lamp grazes the weave, a reading lamp lights the pillow, and the aquarium casts slow ripples on the deck.
Opposite the galley, a lounge chair and a curved-backed banquette share one movable
table by the aquarium. The galley stool sits below the breakfast ledge. A clear
central aisle connects the cockpit, lift and berth. The earlier warm interior shipped as preview `34aa5da8b7518ad3`.

### Shore fishing and the ship aquarium

Land at Echo Orchard or Table Isle, leave by the lower lift and follow the fishing pier sign from the landing circle. Press **A / F** at the end of the pier to take out the SDK rod.

| Action | Handheld | Keyboard |
| --- | --- | --- |
| Charge and release a cast | Hold and release RT | Hold and release Space |
| Set the hook when the float dips | LT | R |
| Reel and ease off | Squeeze or release RT | Hold or release Space |
| Angle the rod against a run | Right stick | Q / E |
| Keep or release the catch | A / Y | F / Y |
| Put the rod away | B | Esc |

A short cast finds glassfins. Casting farther reaches copper loaches at Echo Orchard and ribbon rays at Table Isle. A running fish takes line. Sustained overload snaps it, and slack lets the hook slip. The model adapts the MIT-licensed [Tidewater fight](https://github.com/dgreenheck/tidewater/blob/4811ba48d795197de5621985f404e765c0b7c0ef/src/game/CatchMinigame.js).

The livewell holds 24 fish. At the cabin aquarium, browse with the shoulders and press **A** to move one of your catches into or out of the eight-fish display. **X** offers to release a livewell specimen. The ship saves its ID, species and shore with the current local profile. Length and colour follow the same ID.

A shell and backend with the fishing inventory extension also offer **Y** to transfer a livewell fish to Profile Inventory. An interrupted transfer can be retried with the original ID. Profile inventory fish, including purchased specimens, can be selected for display at the same tank. Listing a server fish for sale clears its display placement. The development backend admits up to 24 offline-reported specimens per account per rolling 24 hours. Catching and the local aquarium work offline.

### Ship station references

Warframe’s Arsenal inspired the standing character preview, the outfit list and the
colour swatches. OctoFox uses its existing profile wardrobe, printed inventory and
pigment cartridges. Ordinary dyes retain the garment surface's authored metal response.
[Arsenal and frame selection](https://www.warframe.com/en/patch-notes/pc/37-0-0) ·
[Official colour picker screenshot](https://www-static.warframe.com/uploads/a370a469ad2348e9f83db978934e27ca.PNG) ·
[Artist guide to tint masks and materials](https://www.warframe.com/en/steamworkshop/texturing-guide) ·
[Voidshell materials](https://www.warframe.com/en/patch-notes/pc/31-5-0).

### Using the fabricator and fitting booth

When you walk within reach of a station, a small bubble shows its action and button. Inside the station the lower-right legend follows the selected item, available actions and last input device. The fabricator, for example, offers collection when the selected print is ready.

Approach the fabricator and press **A / F** to open its catalogue. Up/down selects
a reusable set blueprint. Left/right selects an individual piece. Each blueprint
covers all four pieces; the table shows the requirements for the selected piece.
**LB / RB** or **[ / ]** switches to cartridges and the sets that use them.
Buttons also support pointer selection. **B / Esc** returns to the ship.

On a connected shell the fabricator displays the profile's stored inventory lots
and the current server recipe. Select a piece to see its print time, then press **A** to start. Materials are charged at start. The server records the deadline, including time spent offline. Return to the part and select **Collect part** to put the finished item in your profile inventory. Different parts and additional copies can print in parallel.
Listed lots are reserved for sale. An offline station shows a dash for unknown balances.
The layout draws
on the [Warframe Foundry](https://support.warframe.com/hc/en-us/articles/38385820873741-Foundry-and-Crafting-FAQ).
The garment plates are rendered from the ship's THREAD models.
[Fabricator screenshots](../../docs/evidence/2026-11-20-ship-fabricator/README.md).

At the circular fitting platform press **A / F**. Browse your current look, saved
outfits and the Traveller, Mage and Merchant collections with the D-pad or **LB / RB**.
Turn the character with the right stick. Browsing previews an outfit behind the
pleated screens. **A** on a saved look equips it through the profile wardrobe.
**X** on a saved look, or **A** on the equipped look, opens its individual pieces.
Choose the slot and garment, then **Save and wear** to update that outfit. **B**
discards the preview. Saved looks require a shell with the Ship Looks capability.

**A** on a THREAD collection opens its printed pieces. **Y** also opens the colour
studio. Choose a piece and an authored material channel, then move through the swatch
grid to preview the finish. A check mark identifies an unlocked colour. Activate a
cartridge once to add a permanent colour, then apply it to an owned piece. **B**
returns to the outfit you were browsing. The inventory and marketplace retain
each item's own finish. [Fitting station screenshots](../../docs/evidence/2026-11-20-ship-workshop/README.md#примерочная).

Stand on the illuminated floor lift and press **A / F** to descend through
the shaft. The smaller circular service room has walking space around the lift.
The same control takes the character back up. After landing, cross the service room to the amber platform marked **DOCK LIFT**. Press **A / F** to descend to Lantern Station or Echo Orchard. Walk back to that platform and press **A / F** on **Board ship** to return to the service deck. [Studio views](../../docs/evidence/2026-11-20-ship-studio/README.md).

### Flying the Egregore

Walk up behind the seat and press **A / F** to board. Press it again to launch. The pilot sits forward and above the chair rails, with both feet on the pedals. The left hand follows the throttle and the right follows the stick. Turn your head with the right stick or mouse to see the controls.

| In flight | Gamepad | Keyboard |
| --- | --- | --- |
| Pitch and roll | Left stick | W/S and A/D |
| Yaw and lift | D-pad left/right and up/down | Q/E and R/C |
| Lateral thrust | Left/right triggers | Z/X |
| Decrease / increase throttle | LB / RB | [ / ] |
| Brake to a stop | Hold X | Hold Tab |
| Select the contact nearest the nose | Tap Y | Tap Y |
| Look at contacts / ship systems / chart / power | Hold Y + D-pad left / right / up / down | Hold Y + corresponding arrow |
| Inspect the centre scope | Click right stick | V |
| Select a console entry / return | A / B | F / Esc |
| Land on the selected pad | A | F |

The bridge instruments are mounted inside the cockpit. The left and right screens slide out of side cassettes on request. Tap NAV for contacts or SYS for power routing. The SYSTEMS tab remains on the same right-hand drawer. You can also use the four helm chords above. Tap Y or touch STOW to return directly to the forward view from any page. The brow carries speed, drive mode, selected destination and distance. During final approach it shows the outstanding landing condition. Fuel, shields, hull and power allocation are available in the systems drawer. The scope marks stations with diamonds, signals with dots, ships with rectangles and armed contacts with triangles. Stems show relative height and moving contacts carry a heading stroke. A selected vessel’s orbital track is also visible through the canopy.

Open the full-screen **Egregore atlas** with **Y + D-pad up**, or tap **CHART** on the navigation terminal. Orbit with the right stick and zoom with the triggers. On a touch screen, drag to rotate, pinch or use +/− to zoom. On a desktop, drag and use the scroll wheel. LB/RB select a cluster. **Explore cluster** opens its islands, stations and sensor contacts. Left/right selects a contact and A tracks it locally or plots an intercluster route. B returns to the wider field and Y stows the atlas.

Lantern Reach, Prism Shoal and Cinder Drift are concentrations of pseudo-matter in the ring around the Source. The map uses a schematic scale for cluster positions and the flight coordinates in metres inside each cluster. Islands show their shoreline and terrain as you zoom in. Only clusters within drive range are linked. From Lantern, Cinder requires a stop in Prism. Each leg costs 22 fuel and needs a separate charge. The atlas shows the next cluster, the leg cost and the fuel for the remaining route. Clear the local mass shadow, stow hardpoints, align with the course diamond and charge the drive. After the final jump the selected arrival waypoint appears on the glass.

Within a cluster, islands are separated by kilometres of cruise. Echo Orchard to Table Isle is about 27 km, just under three minutes at full cruise before braking. Range and full-cruise ETA appear on the chart and the forward navigation readout. Table Isle and Cinder Garden have open pads. Crown Isle, Twin Spurs, Glass Atoll and Ember Isle are flyby destinations.

At Prism select the anchorage under Contacts and request pad 01 within 850 m. Leave cruise, level the ship within 8 m of the pad, slow below 2.5 m/s and press **A / F** to land. Echo Orchard accepts a direct approach. The ship console supplies fuel and repairs at all three stations. The latest safe berth, fuel, power allocation and enabled components belong to the active profile. A mid-flight exit restores the departure checkpoint.

The bow glass carries a heading tape, banked pitch ladder and target bearing in flight. A circle with wings shows the actual velocity vector when it lies in the forward field. Near a selected landing site the glass shows vertical speed and signed height relative to the pad. The projection goes dark at the berth and while reading a side instrument.

Six pips are shared between SYS, ENG and WEP. On the right display, select a row and press left or right to release or draw one unit. A adds one unit, and the minus and plus controls accept touch. Each bus accepts up to four units. More SYS improves shield recovery and resistance. ENG recharges boost, and WEP recharges the gun capacitor. On the right console you can switch off individual systems or extend the two hull emitters. In communications range a courier answers a hail. [Bridge instruments and flight captures](../../docs/evidence/2026-11-21-captains-bridge/README.md).

### Fire control

Deploy hardpoints from the right Ship panel. Select Prism Warden in Contacts and choose **Target lock** to enable tracking. In forward view **L3 / G** cycles weapons, **Y + L3 / Y + G** switches between fixed and gimballed guns, and **A / F** fires. These settings are also on the right panel under **Fire control**.

- The pulse cannon fires a travelling bolt. Amber corners mark the ship. The mint circle labelled **LEAD** marks where the patrol will be when that bolt arrives. With a fixed gun, steer the split sight over the circle. A gimbal follows it while the lock is inside the forward tracking arc.
- The laser's open cross marks its beam. It hits immediately. With either gun you can fire straight ahead without a lock.
- The seeker rack has three rounds. Keep the locked ship inside the forward arc until the brackets close and **LOCK** appears. Station service replenishes the rack.
- An **INBOUND** countdown warns of an incoming missile. Use **Y + A / Y + F** for point defence, or choose it on the Fire control panel. The six-second recharge starts after an interception.

The cannon sight follows the Leading option in [Frontier’s Elite Dangerous manual](https://hosting.zaonce.net/elite/website/assets/ELITE-DANGEROUS-GAME-MANUAL.pdf).

Echo Orchard lies 600 metres from Lantern Station. A sea several times the area of the land surrounds its ridgeline, inlets and offshore stacks. Fly into the cloud banks at the edge of the sea’s atmosphere. Visibility drops briefly, then opens onto the daylight sky above the ocean. Departing through the bank returns you to the Egregore. [Flight through the clouds](../../docs/evidence/2026-11-21-island-seas/README.md) · [Art sources](assets/islands/SOURCE.md).

Outside cameras see the saucer’s painted hull, smoked canopy and two engines carried on a raised aft wing. Four emitters around the underside rim send successive luminous rings towards the landing pad. The streams shorten in cruise, while the aft exhaust brightens with forward throttle. The owner's view switches as the boarding lift crosses the hatch in either direction. Furniture, fittings and the pilot camera stay aboard. To display another ship, instance [exterior.tscn](exterior.tscn) at its pose and call `set_propulsion(hover, forward_thrust)` with normalized values. Full hover extends the rings to the pad. The exterior uses a baked hull and two instanced effects and runs independently of the owner's cabin and profile. Ship Home currently runs a local flight session.

The Egregore's informational field and islands of pseudo-matter follow the project's [cosmology](https://github.com/EriArk/AbyssWorldGame/blob/main/docs/COSMOLOGY.md). The three navigable clusters and their six berths are original to Ship Home. Pitch, roll, independent thrust and assisted flight take their cue from [Frontier's pilot manual](https://hosting.zaonce.net/elite/website/assets/ELITE-DANGEROUS-GAME-MANUAL.pdf). [Seating](../../docs/evidence/2026-11-21-ship-flight/seat.jpg) · [Pilot view](../../docs/evidence/2026-11-21-ship-flight/forward.jpg) · [Hand controls](../../docs/evidence/2026-11-21-ship-flight/controls.jpg).

## Run on a development computer

Use the tested Godot **4.7.x** Linux runtime with Vulkan. The project defaults
to the **Mobile** renderer, checked on Odin/Flip with Turnip. Compatibility
produced camera-dependent black patches on Odin and is not the accepted handheld
path. Earlier software-renderer screenshots remain historical design evidence.
From the repository root:

```sh
python3 experiences/ship-home/sync_sdk.py
/path/to/godot --headless --path experiences/ship-home --editor --import --quit
/path/to/godot --path experiences/ship-home
```

For the header button and Apps catalogue, install the preview for the current
user. This does not download Godot or alter system packages:

```sh
python3 experiences/ship-home/install-dev.py --godot /absolute/path/to/godot
```

The executable must remain at that path. `--data-home /temporary/directory`
installs into an isolated XDG prefix for validation. The installer imports a
versioned copy before publishing its desktop entry. Re-running it with the same
source is idempotent. Old development copies are retained for deliberate cleanup;
no personal saves are deleted. This is **not yet part of Setup/OTA packaging**.

In the updated shell, use the saucer icon beside the profile. On Home, move Up
from the lobby row or screenshot collage to reach it with the controller.
The bottom notification bell still opens the inbox. The game uses the existing
Apps supervisor and stable desktop identity, so its launch/return requests go
through the same path as other native applications. Apps launch and the game’s Save and exit were checked on both handhelds.
Native Home/minimize/return acceptance with the handheld compositor is still pending.

## Controls

| Action | Controller | Keyboard / mouse |
| --- | --- | --- |
| Walk / look | Left / right stick | WASD / mouse |
| Run | L3 | Shift |
| Decorate | X | Tab |
| Place | A | Enter / left click |
| Choose furniture | LB / RB | `[` / `]` |
| Rotate | D-pad left / right | Q / E |
| Move a nearby piece | Y | Y |
| Cancel / menu | B / Start | Esc / P |
| Interact / sit / stand up | A; B also stands up | F; Esc also stands up |
| Undo / remove / exit | Pause menu | Pause menu; Z also undoes |

Seven starter furniture types can be placed, moved, rotated and removed. A
translucent green preview means placement is valid; red means it overlaps a
solid object or blocks a protected route. An older save that still matches the original starter arrangement opens with the new furniture layout. Custom arrangements retain their saved coordinates. Changes save immediately. Undo restores
the previous arrangement. The menu releases the mouse; losing focus pauses
movement and caps rendering at 10 fps. Foreground rendering is capped at 60 fps.
The chase camera retracts against walls. At very short distances, the character
presentation is hidden until the camera clears it, avoiding an inside-head view.

## Identity, saves and resources

The three preview garments are bundled in `assets/outfits`. The game consumes `sdk/godot/avatar_client.gd` and `avatar_presenter.gd`, plus `avatar_locomotion.gd` and its animation dependency; run
`sync_sdk.py` after SDK updates. The host provides the active profile's checked
model descriptor. The character body comes from the host. Same-owner
appearance refreshes preserve furniture; a revoked/disconnected identity clears
the character and returns to a separate guest home. A basic guest figure is
available when the host is absent.

Layouts live under Godot's custom user folder, normally
`$XDG_DATA_HOME/octofox-ship-home/homes/studio-v1/<profile-hash>.json` (or
`~/.local/share/octofox-ship-home/homes/studio-v1`). Saves use a bounded schema, temporary
file and atomic replacement. Invalid files remain untouched/read-only.
The studio uses a separate `studio-v1` layout namespace because the earlier
coordinates no longer fit. Earlier arrangements are retained in `homes/saucer-v2/` and `homes/`;
they are not automatically migrated or deleted. Each profile starts a new studio
arrangement. This is a development-preview boundary, not a production migration. The Linux
launcher keeps a single-instance lock through `exec`, retaining the process ID
tracked by Apps. Start failures are logged under
`$XDG_STATE_HOME/octofox-ship-home/launch-error.txt`, with a desktop dialog when
KDialog or Zenity is available.

Idle, walking and running use the shared [Godot SDK locomotion](../../sdk/LOCOMOTION.md)
module and its attributed CC0 animation pack.
Cadence follows actual travel after collisions. The ship owns its compact-deck
controller, pilot camera and seated inverse kinematics; it no longer poses a private walk.
The animator is replaced along with the avatar and stops while seated. Fixed room meshes are batched by shared material; movable furniture stays separate.
Geometry, materials, islands and sky are original code. Two small procedural
noise textures add subtle wood grain and textile variation; no downloaded
texture sheets or third-party room models are bundled. Ceiling meshes batch
separately so the inspection cutaway still hides the complete roof and fixtures. All project code is GPL-3.0-or-later; the host's avatar assets keep their
existing [separate licensing](../../assets/avatar/README.md).

## Verification

```sh
/path/to/godot --headless --path experiences/ship-home --script res://tests/checks.gd
SHIP_CAPTURE_DIR=/tmp/ship-tour /path/to/godot --path experiences/ship-home --script res://tests/tour.gd
```

`checks.gd` covers replacement/reload, profile isolation, corrupt-save protection,
placement and undo, all starter furniture footprints, walking across the open studio, curved-hull/seat collisions, camera retraction/close-avatar hiding and
triangle preservation when batching indexed and unindexed meshes, including
ceiling-fixture ownership under the hideable roof.
`tests/flight.gd` flies both legs using gameplay input, saves each berth, checks docking limits and verifies the hand contacts at full deflection when `SHIP_TEST_DESCRIPTOR` is supplied.
`tests/boarding.gd` walks between both lifts, disembarks at each berth, walks on the station and island, reboards, and checks the flight interlock and profile reset.
`pilot_checks.gd` exercises keyboard/controller entry and exit, eye-camera
selection, fixed seated position, bounded look, pause/focus loss, blocked exit
and identity loss. The headless display cannot capture a pointer; `pilot_tour.gd`
checks SDK idle/walk/run selection, captured mouse input and same-profile appearance refresh in a graphical
session and captures first-person views.
`design_tour.gd` captures architecture views and a roof cutaway of the
actual deck, with the avatar and HUD hidden. `tour.gd` retains the gameplay camera
and character for a separate visual check.
`live_avatar.gd` is driven by the native `shipConsumesLiveHostAvatar` test against
an actual PlatformBinding host; set `OCTOFOX_SHIP_TEST_GODOT` and
`OCTOFOX_SHIP_TEST_PROJECT` when running `trainer_interaction_tests`. It checks
shared mesh/rig loading, locomotion posing, appearance refresh and revocation.
An optional `SHIP_TEST_DESCRIPTOR` lets the screenshot tour show a locally
resolved development character; it is not a production identity override.

[Initial development evidence and screenshots](../../docs/evidence/2026-11-14-ship-home/README.md).
The initial preview was host-only; later handheld acceptance is recorded separately.

[Earlier Orbit interior study and screenshots](../../docs/evidence/2026-11-14-ship-redesign/README.md).

[Compact layout iteration and screenshots](../../docs/evidence/2026-11-14-ship-compact/README.md).

[Earlier cockpit, seating and device evidence](../../docs/evidence/2026-11-14-ship-pilot/README.md).

[Warm interior and lighting — earlier host evidence](../../docs/evidence/2026-11-14-ship-warm/README.md).

[Current warm handheld deployment and renderer evidence](../../docs/evidence/2026-11-14-ship-warm-devices/README.md).
