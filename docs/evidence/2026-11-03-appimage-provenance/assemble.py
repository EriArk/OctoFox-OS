from pathlib import Path
import argparse,json,tarfile,hashlib,io
parser=argparse.ArgumentParser(description='Assemble and independently re-read the two-AppImage source supplement')
parser.add_argument('staging',type=Path)
r=parser.parse_args().staging
rows=[json.loads((r/'output'/(n+'.json')).read_text()) for n in ['cemu-appimage','armsx2-appimage']]
files=[]
for row in rows:
 files.extend([(r/'output'/row['file'],'upstream/'+row['file'],row['sha256']),(r/'output'/(row['id']+'.json'),'upstream/'+row['id']+'.json',None)])
files.append((r/'appimage-provenance.json','identities.json',None))
manifest=[]
for p,name,expected in files:
 assert p.is_file() and not p.is_symlink()
 with p.open('rb') as f:sha=hashlib.file_digest(f,'sha256').hexdigest()
 if expected:assert sha==expected
 manifest.append({'path':name,'bytes':p.stat().st_size,'sha256':sha})
record={'schema':1,'sourceCapsules':2,'files':manifest,'completeRuntimeCorrespondingSource':False,'redistributionReviewed':False,'published':False}
archive=r/'TrainerOS-AppImage-Sources-CANDIDATE.tar'
with tarfile.open(archive,'x:') as t:
 b=(json.dumps(record,indent=2)+'\n').encode();m=tarfile.TarInfo('sources.json');m.size=len(b);m.mode=0o644;t.addfile(m,io.BytesIO(b))
 for (p,name,_),row in zip(files,manifest):
  m=tarfile.TarInfo(name);m.size=row['bytes'];m.mode=0o644
  with p.open('rb') as f:t.addfile(m,f)
with tarfile.open(archive) as t:
 assert json.load(t.extractfile('sources.json'))==record
 assert {m.name for m in t}=={'sources.json'}|{row['path'] for row in manifest}
 for row in manifest:
  m=t.getmember(row['path']);assert m.isfile() and m.size==row['bytes']
  with t.extractfile(m) as f:assert hashlib.file_digest(f,'sha256').hexdigest()==row['sha256']
with archive.open('rb') as f:sha=hashlib.file_digest(f,'sha256').hexdigest()
result={'schema':1,'file':archive.name,'bytes':archive.stat().st_size,'sha256':sha,'entries':len(manifest)+1,'allEntriesReadBack':True,'sourceCapsules':2,'sourceArchiveBytes':sum(x['bytes'] for x in rows),'sourceTrees':sum(len(x['trees']) for x in rows),'sourceFiles':sum(x['files'] for x in rows),'completeRuntimeCorrespondingSource':False,'redistributionReviewed':False,'published':False}
(r/'appimage-source-bundle.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
