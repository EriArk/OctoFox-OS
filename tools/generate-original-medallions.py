"""Reproducible original abstract league tokens; no game artwork is used."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1] / "assets/badges"
PALETTES = ["#71c5c6", "#e6a16e", "#a89edc", "#dd899f",
            "#8fbf87", "#7bafdc", "#d2b96e", "#94a6bd"]
# These independent geometric glyphs do not follow the in-game badge shapes.
GLYPHS = [
    '<path d="M96 48 124 76 96 104 68 76Z M68 92 96 120 124 92"/>',
    '<path d="M63 61H84V82H63Z M108 61H129V82H108Z M85 103H107V125H85Z"/>',
    '<circle cx="96" cy="85" r="29"/><path d="M96 44V61 M96 109V126 M55 85H72 M120 85H137"/>',
    '<path d="M62 69 96 50 130 69 96 88Z M62 88 96 107 130 88 M62 107 96 126 130 107"/>',
    '<path d="M62 58H91V87H62Z M101 93H130V122H101Z M107 58H130V81 M62 99V122H85"/>',
    '<path d="M62 109V71L96 51 130 71V109L96 129Z M79 100V80L96 70 113 80V100L96 110Z"/>',
    '<path d="M62 105 96 55 130 105Z M62 75 96 125 130 75Z"/>',
    '<path d="M67 60H125V118H67Z M82 45V60 M110 118V133 M52 103H67 M125 75H140 M83 76H109V102H83Z"/>',
]

def main():
    old = json.loads((ROOT / "legacy-manifest.json").read_text(encoding="utf-8"))
    images = []
    for i, (color, glyph) in enumerate(zip(PALETTES, GLYPHS), 1):
        pips = "".join(f'<circle cx="{68+j*8}" cy="151" r="2.6" fill="{color if j<i else "#496063"}"/>' for j in range(8))
        svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192" viewBox="0 0 192 192">
<!-- Original TrainerOS abstract medallion {i}; GPL-3.0-or-later. -->
<defs><linearGradient id="rim" x2="0.7" y2="1"><stop stop-color="#f4e8c8"/><stop offset=".46" stop-color="#b6c9bd"/><stop offset="1" stop-color="#547d80"/></linearGradient>
<linearGradient id="glass" x2=".8" y2="1"><stop stop-color="#385c62"/><stop offset="1" stop-color="#163238"/></linearGradient></defs>
<circle cx="96" cy="99" r="81" fill="#10282c" opacity=".22"/>
<circle cx="96" cy="95" r="81" fill="url(#rim)"/>
<circle cx="96" cy="95" r="73" fill="url(#glass)" stroke="#112f35" stroke-width="2"/>
<path d="M36 70A65 65 0 0 1 121 36" fill="none" stroke="#fff9df" stroke-opacity=".5" stroke-width="3" stroke-linecap="round"/>
<g fill="none" stroke="{color}" stroke-width="6" stroke-linejoin="round" stroke-linecap="round">{glyph}</g>
{pips}</svg>
'''
        name = f"original-{i:02}.svg"
        (ROOT / name).write_text(svg, encoding="utf-8", newline="\n")
        images.append((name, hashlib.sha256(svg.encode()).hexdigest()))
    manifest = {"author": "TrainerOS contributors", "license": "GPL-3.0-or-later",
                "source": "tools/generate-original-medallions.py",
                "description": "Original abstract ordinal medallions; semantic badge identities are retained separately.", "sets": {}}
    for key, value in old["sets"].items():
        manifest["sets"][key] = {"badges": [
            {"id": badge["id"], "name": badge["name"], "image": image, "sha256": digest}
            for badge, (image, digest) in zip(value["badges"], images)]}
    (ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8", newline="\n")

if __name__ == "__main__":
    main()
