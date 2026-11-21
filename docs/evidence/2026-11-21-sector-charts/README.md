# Sector charts at the helm

| Cockpit view | What the pilot can do |
| --- | --- |
| [Lantern Reach](local.jpg) | Preview Table Isle from the berth, see its range and check whether it has a landing pad. The mint arrow marks the pilot. |
| [Prism Shoal](arrival-chart.jpg) | Select the Prism relay in advance. The dotted leg starts at the sector entry, and the range beside the beacon is the remaining distance after the jump. |
| [Plotted course](plotted.jpg) | Review or clear the selected arrival waypoint, check fuel or start the drive. |
| [Arrival at Prism](arrival.jpg) | Fly towards the selected relay using the canopy and the NAV readout. |

Captured from Ship Home revision `a439dfbc2e348d9a` on Odin 2 in the mobile renderer with software-generated gamepad and touch events. The flight check browses an island while another course is active, selects a local target, plots and clears a remote course, then jumps to the relay. It obtains separate permission to dock at Prism Anchorage. On the return leg it selects Echo Orchard before charging the drive and checks that the island becomes the landing destination after the jump. Touch checks cover the chart tabs, map marks, previous-contact button and route confirmation.

A [native-resolution detail from Odin](lettering.png) shows the same lettering before (top) and after (bottom) reducing the phosphor halo's radius. The terminal bezel keeps its own illumination.
