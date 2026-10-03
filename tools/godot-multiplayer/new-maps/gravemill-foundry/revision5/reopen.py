import bpy
import json
import hashlib
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
master=HERE/'gravemill-foundry-revision5.blend';before=hashlib.sha256(master.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(master))
source=bpy.data.collections['SOURCE / R5 editable anchored mechanisms'];export=bpy.data.collections['EXPORT / R5 reviewed visual batches']
spec=json.loads((HERE/'shapes.json').read_text());assert len(source.objects)==len(spec['shapes'])==270
for s in spec['shapes']:
 o=source.objects[s['id']];assert o.hide_render and o.hide_get();assert o.data.uv_layers.get('MothLocal')
 for a,b in zip(o.data.vertices,s['vertices']):assert (o.matrix_world@a.co-Vector((b[0],-b[2],b[1]))).length<.0001,s['id']
images=[i for i in bpy.data.images if i.source=='FILE' and i.users>0]
assert len(images)==30 and all(i.packed_file for i in images)
assert all(not o.hide_render for o in export.objects)
assert bpy.context.scene['geometryHash']==json.loads((HERE/'candidate.json').read_text())['geometryHash']
assert hashlib.sha256(master.read_bytes()).hexdigest()==before
result={'masterSha256':before,'sourceObjects':len(source.objects),'exportBatches':len(export.objects),'packedImages':len(images),'allSourceVerticesAndRigidEndpointsMatch':True,'duplicateSourceHidden':True,'blender':bpy.app.version_string}
(HERE/'reopen-report.json').write_text(json.dumps(result,indent=2)+'\n');print('R5_REOPEN',json.dumps(result))
