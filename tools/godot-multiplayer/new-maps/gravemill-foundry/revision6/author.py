"""Future grant only: Blender 4.5.14 --background --python author.py.

Open the packed R5 master read-only as input; save all results under revision6.
Editable batch polygons retain exact topology; per-face slots store new roles.
"""
import collections
import json
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from finish import HERE, R5, GLB, ROOT, read, write, plan, key, primitives, glb_parts, sha
import bpy
from material_pack import load_materials
from compose import compose

assert bpy.app.version[:3]==(4,5,14),bpy.app.version_string
assert '--authorized-r6-build' in sys.argv,'Future exclusive grant required; source preparation does not authorize execution'
p=plan()
assert p==read(HERE/'finish-plan.json'),'Material direction changed; review and archive a new source plan explicitly'
built_plan=HERE/'evidence/W/finish-plan-built.json';built_plan.parent.mkdir(parents=True,exist_ok=True)
built_plan.write_text(json.dumps(p,separators=(',',':'))+'\n')
bpy.ops.wm.open_mainfile(filepath=str(R5/'gravemill-foundry-revision5.blend'))
bpy.context.preferences.filepaths.save_version=0
bindings=read(HERE/'bindings.json')
mats,_,materials_report=load_materials(ROOT,bindings,HERE/'converted')
for name,mat in mats.items():
    for node in mat.node_tree.nodes:
        if node.type=='NORMAL_MAP':node.inputs['Strength'].default_value=bindings[name]['normalStrength']
source,blob=glb_parts(GLB.read_bytes());lookup={}
for (node,pi,prim,streams,faces),row in zip(primitives(source,blob),p['assignments']):
    slots=collections.defaultdict(list)
    for face,role,ident in zip(faces,row['roles'],row['sourceIds']):
        slots[key([streams['POSITION'][i] for i in face])].append((role,row['uvScale'][role],ident))
    lookup[node['name']]=slots
exports=[o for o in bpy.data.objects if o.type=='MESH' and o.name in lookup]
assert len(exports)==16
for obj in exports:
    # Preserve existing loop UVs and normals. Only positive uniform UV scaling
    # is allowed, so tangent direction/handedness remain the R5 basis.
    uv=obj.data.uv_layers.get('MothLocal');assert uv is not None
    indices={m.name:i for i,m in enumerate(obj.data.materials)}
    for name,mat in mats.items():
        indices[name]=len(obj.data.materials);obj.data.materials.append(mat)
    matched=lookup[obj.name]
    for poly in obj.data.polygons:
        assert len(poly.vertices)==3
        points=[obj.matrix_world@obj.data.vertices[i].co for i in poly.vertices]
        k=key([(v.x,v.z,-v.y) for v in points]);assert matched[k],(obj.name,k)
        role,scale,ident=matched[k].pop()
        poly.material_index=indices[role]
        for loop in poly.loop_indices:
            u,v=uv.data[loop].uv
            # glTF V = 1 - Blender V. Scale about glTF origin so the packed
            # editable master and stream-preserving artifact sample identically.
            uv.data[loop].uv=(u*scale,1-(1-v)*scale)
    assert not any(matched.values()),obj.name
    obj['visualRevision']=6;obj['finish_plan_sha256']=sha(built_plan.read_bytes())
    obj['source_geometry_hash']=p['geometryHash']
bpy.context.scene['revision']=6;bpy.context.scene['visualRevision']=6
bpy.context.scene['geometryHash']=p['geometryHash']
bpy.context.scene['R6_editing']='Export batch polygon material slots own finish; R5 hidden mechanism sources retained as geometry reference.'
bpy.ops.file.pack_all()
master=HERE/'gravemill-foundry-revision6.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(master),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in exports:obj.hide_set(False);obj.select_set(True)
bpy.context.view_layer.objects.active=exports[0]
library=HERE/'material-library.glb'
bpy.ops.export_scene.gltf(filepath=str(library),export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_tangents=True)
art=ROOT/'godot/multiplayer_worlds/art/revisions/gravemill-foundry-r6.glb';art.write_bytes(compose(p,library.read_bytes()))
write(HERE/'build-report.json',{'visualRevision':6,'geometryHash':p['geometryHash'],'artHash':sha(art.read_bytes()),
    'masterSha256':sha(master.read_bytes()),'sourceMasterSha256':p['sourceMasterSha256'],'moth':materials_report,
    'nativeVisualAcceptance':'pending','geometryExport':'Exact original POSITION/NORMAL/TANGENT streams, original oriented index triples; material library only from Blender export'})
from verify import verify
write(HERE/'built-verification.json',verify(art.read_bytes(),p))
from prepare_stage import prepare
prepare()
write(ROOT/'godot/tests/new_maps/gravemill_foundry/revision6/art-identity.json',{'visualRevision':6,'geometryHash':p['geometryHash'],
    'artHash':sha(art.read_bytes()),'sourceR5ArtHash':p['sourceGLBSha256'],'acceptance':'pending native visual review'})
assert sha((R5/'gravemill-foundry-revision5.blend').read_bytes())==p['sourceMasterSha256']
