#pragma once

namespace trainer {
// Imported packs require a deliberate future selection; installed legacy files
// alone must never override the owner's original-art presentation policy.
enum class ArtSource { Original, Imported };
}
