# Ship Home · Fire control

The amber corners follow the Prism Warden. The mint circle marked LEAD follows its future position along its orbit for the current bolt travel time. With fixed guns, steer the split sight into the circle. The gimballed cannon moves its sight onto that point automatically while it can track. The beam responds immediately and the seeker uses a separate lock indicator.

| Forward glass | What the pilot sees |
| --- | --- |
| [Fixed pulse cannon](pulse-fixed.jpg) | The gun points straight ahead. The target and its lead cue are to starboard. |
| [Crossing the bow](crossing.jpg) | With the fixed bore on the current hull, the small mint circle is already to port. |
| [Gimballed pulse cannon](pulse-gimbal.jpg) | The tracking sight follows the lead cue to starboard. |
| [Beam laser](beam.jpg) | An open cross follows the contact while the beam is firing. |
| [Seeker](seeker.jpg) | Closing brackets and the filling arc show acquisition progress. |
| [Incoming missile](inbound.jpg) | The glass shows the time to impact while the selected gun remains available. |

These frames were captured on Odin 2 in the Godot mobile renderer with Ship Home revision `51bbc8f39b8f138b`. The flight check uses the ordinary helm and software-generated pad and touch events. In Prism it fires at an orbiting patrol, waits for the bolt to arrive, aims a fixed gun directly at the broadside hull and misses, turns onto the lead cue, then uses the beam and seeker. It also checks point defence, docking, reloading the profile and restocking the rack at the station. The earlier outbound and return navigation and power checks run in the same circuit.

The visual reference is the Leading option described under Gun Sight Mode in the [Elite Dangerous game manual](https://hosting.zaonce.net/elite/website/assets/ELITE-DANGEROUS-GAME-MANUAL.pdf).
