"""Future granted fresh-process reopen; writes only revision output evidence."""
import sys
if '--slot-granted' not in sys.argv:
    raise SystemExit('Explicit heavy-slot grant required')
import bpy
import json
import hashlib
from pathlib import Path

out=Path(__file__).resolve().parent/'output'
manifest=json.loads((out/'asset-manifest.json').read_text())
master=out/'parallax-observatory.blend'
assert Path(bpy.data.filepath).resolve()==master.resolve()
assert bpy.context.scene['candidateHash']==manifest['candidateHash']
assert bpy.context.scene['geometryHash']==manifest['geometryHash']
assert hashlib.sha256(master.read_bytes()).hexdigest()==manifest['blendSha256']
assert len(bpy.data.collections['EXPORT - seven material batches'].objects)==7
report={'candidateHash':manifest['candidateHash'],'geometryHash':manifest['geometryHash'],
        'blendSha256':manifest['blendSha256'],'editableObjects':len(bpy.data.collections['EDITABLE - authority and architectural craft'].objects),
        'reopened':str(master),'status':'fresh candidate master reopened'}
(out/'master-reopen.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
