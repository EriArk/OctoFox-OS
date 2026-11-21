#pragma once

namespace trainer {
// Call once per SDL game-controller subsystem lifetime, on its owning thread.
void loadPackagedControllerMappings();
}
