"""Pack offline mesh renders into tightly framed cards; requires Pillow.
GPL-3.0-or-later. Run after render-crates.py.
"""
from pathlib import Path
import sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]/'assets/crates/low-poly'
for key in (sys.argv[1:] or ('new','workshop','adventure','arcade','strategy','tools')):
 frames=[Image.open(ROOT/f'{key}-{i}.png').convert('RGBA') for i in range(6)]
 assert all(f.size==(512,448) for f in frames)
 packed=[]
 for frame in frames:
  # Remove the space reserved above a closed lid. Opening gradually pulls back
  # to keep the whole lid in view; every pose shares a centred bottom baseline.
  crop=frame.crop(frame.getchannel('A').getbbox())
  crop.thumbnail((488,296),Image.Resampling.LANCZOS)
  canvas=Image.new('RGBA',(512,320))
  canvas.paste(crop,((512-crop.width)//2,308-crop.height))
  packed.append(canvas)
 atlas=Image.new('RGBA',(1536,160))
 for i,f in enumerate(packed):atlas.paste(f.resize((256,160),Image.Resampling.LANCZOS),(256*i,0))
 packed[0].save(ROOT/f'{key}.png',optimize=True)
 atlas.save(ROOT/f'{key}-opening.png',optimize=True)
 for i in range(6):(ROOT/f'{key}-{i}.png').unlink()
