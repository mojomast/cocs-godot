"""Future authorized Blender build/reopen; no execution during source preparation.

Blender loop tangents are derived/read-only. The packed master carries a recipe
and exact baseline dependency; canonical export validates its editable geometry,
UVs and material pixels before applying the seven-entry patch to that baseline.
"""
import collections
import json
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from tangents import *
sys.path.insert(0,str(ROOT/'tools/map-variety-pipeline'))
from material_pack import linear_rgba
from material_contract import compare_materials

MASTER=HERE/'gravemill-foundry-revision7.blend'
ART=ROOT/'godot/multiplayer_worlds/art/revisions/gravemill-foundry-r7.glb'
BASE_MASTER=R6/'gravemill-foundry-revision6.blend'
BASE_MASTER_SHA='9922b7be04bbc64deda53f0082ec279a2b81f17d5e280d476e74d5b5d12252d8'

def material_pixels(g,mat):
    p=mat.get('pbrMetallicRoughness',{});images={}
    for label,slot in [('albedo',p.get('baseColorTexture')),('normal',mat.get('normalTexture')),('roughnessMetallic',p.get('metallicRoughnessTexture'))]:
        if slot is None:continue
        w,h,pixels=linear_rgba(g.image_bytes(slot))
        if label=='roughnessMetallic':pixels=bytes(v for i,v in enumerate(pixels) if i%4 in (1,2))
        images[label]=(w,h,bytes(pixels))
    return images

def audit_editable_export(raw):
    baseline=gate(SOURCE.read_bytes());draft=gate(raw)
    expected=collections.defaultdict(list);maximum=[0,0,0]
    def ordered(s,face):
        cs=[(s['POSITION'][i],s['NORMAL'][i],s['TEXCOORD_0'][i]) for i in face]
        start=min(range(3),key=lambda j:tuple(tuple(round(v,4) for v in c[0]) for c in cs[j:]+cs[:j]))
        cs=cs[start:]+cs[:start];return tuple(tuple(round(x,4) for x in c[0]) for c in cs),cs
    for _,_,p,s,faces in rows(baseline):
        role=baseline.doc['materials'][p['material']]['name']
        for f in faces:
            k,cs=ordered(s,f);expected[role,k].append(cs)
    count=0
    for _,_,p,s,faces in rows(draft):
        role=draft.doc['materials'][p['material']]['name']
        for f in faces:
            k,cs=ordered(s,f);choices=expected[role,k]
            errors=[[max(abs(x-y) for a,b in zip(cs,want) for x,y in zip(a[j],b[j])) for j in range(3)] for want in choices]
            index=next((i for i,e in enumerate(errors) if e[0]<=1e-5 and e[1]<=1e-4 and e[2]<=1e-5),None)
            if index is None:raise ValueError('Editable master differs from canonical geometry/normal/UV/role')
            maximum=[max(a,b) for a,b in zip(maximum,errors[index])];choices.pop(index);count+=1
    if any(expected.values()) or count!=87566:raise ValueError('Editable master triangle coverage changed')
    compare_materials(baseline,draft)
    return {'triangles':count,'maxPositionNormalUVError':maximum,'allMaterialPixelsAndPBRMatch':True}

def main():
    if '--authorized-r7-build' not in sys.argv:raise RuntimeError('A new explicit exclusive grant is required')
    import bpy
    if bpy.app.version[:3]!=(4,5,14):raise RuntimeError('Pinned Blender 4.5.14 required')
    if sha(BASE_MASTER.read_bytes())!=BASE_MASTER_SHA:raise ValueError('R6 master identity changed')
    recipe={'visualRevision':7,'sourceArtSha256':SOURCE_SHA,'sourceMasterSha256':BASE_MASTER_SHA,'expectedEntries':sorted(EXPECTED),
        'recipeFile':'tangents.py','recipeSha256':sha((HERE/'tangents.py').read_bytes()),'compilerSha256':sha((HERE/'production.py').read_bytes()),
        'policy':'Export editable polygons, validate against immutable baseline, then deterministic seven-entry tangent repair. Plain Blender glTF export is an intermediate, not the final artifact.'}
    reopening='--reopen' in sys.argv
    bpy.ops.wm.open_mainfile(filepath=str(MASTER if reopening else BASE_MASTER))
    bpy.context.preferences.filepaths.save_version=0
    payload=json.dumps(recipe,sort_keys=True)
    if reopening:
        if bpy.context.scene.get('R7_tangent_recipe')!=payload:raise ValueError('Packed master recipe changed')
        if bpy.data.texts['R7_TANGENT_RECIPE.json'].as_string()!=payload:raise ValueError('Packed recipe text changed')
        if bpy.data.texts['R7_TANGENT_REPAIR.py'].as_string()!=(HERE/'tangents.py').read_text():raise ValueError('Packed repair source changed')
    else:
        bpy.context.scene['R7_tangent_recipe']=payload;bpy.context.scene['visualRevision']=7
        text=bpy.data.texts.new('R7_TANGENT_RECIPE.json');text.write(payload)
        text=bpy.data.texts.new('R7_TANGENT_REPAIR.py');text.write((HERE/'tangents.py').read_text())
        bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(MASTER),compress=True)
    source=gate(SOURCE.read_bytes());names={n['name'] for n in source.doc['nodes'] if 'mesh' in n}
    meshes=[o for o in bpy.data.objects if o.type=='MESH' and o.name in names]
    if len(meshes)!=16 or not all(i.packed_file for i in bpy.data.images if i.source=='FILE'):raise ValueError('Packed master inventory changed')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:obj.hide_set(False);obj.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    intermediate=HERE/('reopen-export.glb' if reopening else 'editable-export.glb')
    bpy.ops.export_scene.gltf(filepath=str(intermediate),export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_tangents=True)
    editable=audit_editable_export(intermediate.read_bytes())
    result,_=repair(SOURCE.read_bytes());proof=verify(SOURCE.read_bytes(),result)
    if reopening:
        if result!=ART.read_bytes():raise ValueError('Fresh master canonical re-export differs from actual R7 artifact')
    else:ART.write_bytes(result)
    report={**proof,'scope':'Actual authorized production','artHash':sha(result),'masterSha256':sha(MASTER.read_bytes()),
        'editableReexport':editable,'recipe':recipe,'nativeAcceptance':'pending'}
    (HERE/('reopen-report.json' if reopening else 'build-report.json')).write_text(json.dumps(report,indent=2)+'\n')
    if not reopening:
        from prepare_native import prepare
        prepare(sha(result))
    if sha(BASE_MASTER.read_bytes())!=BASE_MASTER_SHA:raise ValueError('R6 master was overwritten')

if __name__=='__main__':main()
