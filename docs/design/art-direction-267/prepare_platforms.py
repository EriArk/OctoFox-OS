"""Resize downloaded public-domain console photos, keeping transparent pixels.
Usage: python prepare_platforms.py /path/to/downloads
No segmentation, invented detail or image-generation step.
"""
from pathlib import Path
import sys,json,hashlib
from PIL import Image
root=Path(__file__).resolve().parent
source=Path(sys.argv[1]);records=json.loads((source/'platform-sources.json').read_text())
for r in records:
 p=source/(r['id']+'-original.png');assert hashlib.file_digest(p.open('rb'),'sha256').hexdigest()==r['sha256']
 im=Image.open(p).convert('RGBA');box=im.getchannel('A').getbbox();im=im.crop(box);im.thumbnail((640,640),Image.Resampling.LANCZOS)
 out=root/'platforms'/(r['id']+'.png');im.save(out,optimize=True)
 r.update(file='platforms/'+out.name,transform='Trim transparent margins; proportionally resize to at most 640 px; PNG RGBA',output_sha256=hashlib.file_digest(out.open('rb'),'sha256').hexdigest(),checked='2026-11-14')
(root/'platform-sources.json').write_text(json.dumps(records,indent=2)+'\n')
