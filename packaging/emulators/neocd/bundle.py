# SPDX-License-Identifier: GPL-3.0-or-later
from pathlib import Path
import hashlib
import json
import sys

root = Path(sys.argv[1])
manifest = {
    "protocol": 1,
    "source": "b1e04c738cb48a1dae0574b8877f6a116d270ca1",
    "settings": "neocd-two-pad-private-bios-aslr-v1",
    "core": hashlib.sha256((root / "core.so").read_bytes()).hexdigest(),
}
(root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
