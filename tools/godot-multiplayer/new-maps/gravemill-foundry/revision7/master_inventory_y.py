"""Read-only inventory of the actual saved R7 packed master."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from tangents import *
import bpy
assert bpy.app.version[:3]==(4,5,14)
master=HERE/'gravemill-foundry-revision7.blend';before=sha(master.read_bytes())
bpy.ops.wm.open_mainfile(filepath=str(master))
export_names={n['name'] for n in gate(SOURCE.read_bytes()).doc['nodes'] if 'mesh' in n}
exports=[o for o in bpy.data.objects if o.type=='MESH' and o.name in export_names]
references=[o for o in bpy.data.objects if o.type=='MESH' and o.name not in export_names]
assert len(exports)==16 and len(references)==270
assert all(o.hide_get() or o.hide_viewport for o in references)
images=[i for i in bpy.data.images if i.source=='FILE'];assert all(i.packed_file for i in images)
recipe=json.loads(bpy.data.texts['R7_TANGENT_RECIPE.json'].as_string())
assert recipe['visualRevision']==7 and bpy.context.scene['visualRevision']==7
assert before==sha(master.read_bytes())
(HERE/'evidence/Y/master-inventory.json').write_text(json.dumps({'masterSha256':before,'exportMeshes':len(exports),
    'hiddenEditableGeometryReferences':len(references),'packedImages':len(images),'recipe':recipe,
    'masterUnchangedByRead':True},indent=2)+'\n')
