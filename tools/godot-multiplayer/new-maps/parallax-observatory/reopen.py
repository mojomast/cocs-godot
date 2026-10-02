"""Run in a fresh, granted Blender process after loading the saved master."""
import bpy
import json
import sys
import hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[4]
data=json.loads((root/'godot/multiplayer_worlds/generated/parallax-observatory.json').read_text())
scene=bpy.context.scene
if '--compress-master' in sys.argv:
    assert '--slot-granted' in sys.argv
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    manifest_path=root/'godot/multiplayer_worlds/art/parallax-observatory/asset-manifest.json'
    manifest=json.loads(manifest_path.read_text())
    manifest['blendSha256']=hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()
    manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
assert scene['geometryHash']==data['geometryHash']
assert scene['recipeHash']==data['recipeHash']
editable=bpy.data.collections['EDITABLE - authority and architectural craft']
export=bpy.data.collections['EXPORT - seven material batches']
assert len(editable.objects)>1000
assert len(export.objects)==7
assert len([o for o in scene.objects if o.type=='CAMERA'])>=8
report={'geometryHash':scene['geometryHash'],'recipeHash':scene['recipeHash'],'editableObjects':len(editable.objects),'exportBatches':len(export.objects),'cameras':len([o for o in scene.objects if o.type=='CAMERA']),'reopened':bpy.data.filepath}
Path('/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002/master-reopen.json').write_text(json.dumps(report,indent=2)+'\n')
print('PARALLAX_MASTER_REOPEN',json.dumps(report))
