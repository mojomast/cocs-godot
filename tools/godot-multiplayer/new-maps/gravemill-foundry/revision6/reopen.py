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
    values=tuple(corners)
    order=min(range(3),key=lambda i:tuple(tuple(round(x,4) for x in p) for p,uv in values[i:]+values[:i]))
    rotated=values[order:]+values[:order]
    return tuple(tuple(round(x,4) for x in p) for p,uv in rotated),rotated
expected=collections.defaultdict(list)
for (role,cs),count in planned_inventory(plan).items():
    k,raw=signature([(c[0],c[3]) for c in cs]);expected[role,k].extend([raw]*count)
count=0;max_position_error=0;max_uv_error=0
for obj in bpy.data.objects:
    if obj.name not in names:continue
    uv=obj.data.uv_layers['MothLocal']
    for face in obj.data.polygons:
        corners=[]
        for loop in face.loop_indices:
            v=obj.matrix_world@obj.data.vertices[obj.data.loops[loop].vertex_index].co
            u,t=uv.data[loop].uv;corners.append(((v.x,v.z,-v.y),(u,1-t)))
        k,raw=signature(corners);role=obj.data.materials[face.material_index].name
        matches=expected[role,k]
        errors=[(max(abs(x-y) for (a,_),(b,_) in zip(raw,want) for x,y in zip(a,b)),
                 max(abs(x-y) for (_,a),(_,b) in zip(raw,want) for x,y in zip(a,b))) for want in matches]
        index=next((i for i,(pos,uv) in enumerate(errors) if pos<=1e-5 and uv<=1e-5),None)
        assert index is not None,('Packed-master corner mismatch',role,k,errors)
        pos,uv_error=errors[index];max_position_error=max(max_position_error,pos);max_uv_error=max(max_uv_error,uv_error)
        matches.pop(index);count+=1
assert not any(expected.values()),'Missing packed-master triangles'
assert all(i.packed_file for i in bpy.data.images if i.source=='FILE')
sources=[o for o in bpy.data.objects if o.type=='MESH' and o.name not in names and o.get('shape_id')]
assert len(sources)==270 and all(o.hide_render for o in sources)
write(HERE/'reopen-report.json',{'visualRevision':6,'masterSha256':sha(path.read_bytes()),'editableTriangleRolesAndUVMatch':True,
    'editableGeometrySources':len(sources),'sourceCollectionHiddenFromRender':True,'exportMeshObjects':len(names),
    'packedImages':sum(bool(i.packed_file) for i in bpy.data.images if i.source=='FILE'),
    'triangles':count,'geometryHash':plan['geometryHash'],'maxPositionError':max_position_error,'maxUVError':max_uv_error,
    'comparison':'Oriented per-corner raw error <=1e-5; avoids false inequality across decimal rounding boundaries; multiplicity retained',
    'nativeVisualAcceptance':'pending'})
