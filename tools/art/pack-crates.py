"""Pack the offline Blender frames; no runtime 3D or image synthesis.
GPL-3.0-or-later. Run after render-crates.py (requires Pillow).
"""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]/'assets/crates/low-poly'
for key in ('new','workshop','adventure','arcade','strategy','tools'):
 frames=[Image.open(ROOT/f'{key}-{i}.png').convert('RGBA') for i in range(6)]
 assert all(f.size==(512,448) for f in frames)
 atlas=Image.new('RGBA',(1536,224))
 for i,f in enumerate(frames):atlas.paste(f.resize((256,224),Image.Resampling.LANCZOS),(256*i,0))
 frames[0].save(ROOT/f'{key}.png',optimize=True)
 atlas.save(ROOT/f'{key}-opening.png',optimize=True)
 for i in range(6):(ROOT/f'{key}-{i}.png').unlink()
