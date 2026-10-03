"""Future grant: fresh packed-master reopen, per-corner role/UV geometry proof."""
import collections
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from finish import HERE,read,write,sha
from verify import planned_inventory
import bpy

assert '--authorized-r6-build' in sys.argv
path=HERE/'gravemill-foundry-revision6.blend';report=read(HERE/'build-report.json')
assert sha(path.read_bytes())==report['masterSha256']
bpy.ops.wm.open_mainfile(filepath=str(path))
plan=read(HERE/'finish-plan.json');names={r['node'] for r in plan['assignments']}
def signature(corners):
    values=tuple(tuple(round(x,4) for x in p+uv) for p,uv in corners)
    return min(values[i:]+values[:i] for i in range(3))
expected=collections.Counter()
for (role,cs),count in planned_inventory(plan).items():
    expected[role,signature([(c[0],c[3]) for c in cs])]+=count
actual=collections.Counter()
for obj in bpy.data.objects:
    if obj.name not in names:continue
    uv=obj.data.uv_layers['MothLocal']
    for face in obj.data.polygons:
        corners=[]
        for loop in face.loop_indices:
            v=obj.matrix_world@obj.data.vertices[obj.data.loops[loop].vertex_index].co
            u,t=uv.data[loop].uv;corners.append(((v.x,v.z,-v.y),(u,1-t)))
        actual[obj.data.materials[face.material_index].name,signature(corners)]+=1
assert actual==expected,'Packed-master finish differs from planned GLB (1e-4 corner precision)'
assert all(i.packed_file for i in bpy.data.images if i.source=='FILE')
write(HERE/'reopen-report.json',{'visualRevision':6,'masterSha256':sha(path.read_bytes()),'editableTriangleRolesAndUVMatch':True,
    'triangles':sum(actual.values()),'geometryHash':plan['geometryHash'],'nativeVisualAcceptance':'pending'})
