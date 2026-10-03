"""Blender 4.5.14 corrective production. R4 is immutable rejected evidence."""
import hashlib
import json
import re
import sys
from pathlib import Path
import bpy
import bmesh
from mathutils import Matrix,Vector

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[4]
sys.path.insert(0,str(ROOT/'tools/map-variety-pipeline'))
from blender_kit import Kit
from material_pack import load_materials,sha
data=json.loads((HERE/'candidate.json').read_text());spec=json.loads((HERE/'shapes.json').read_text())
old=ROOT/'godot/multiplayer_worlds/art/worlds/gravemill-foundry.glb'
out=ROOT/'godot/multiplayer_worlds/art/revisions/gravemill-foundry-r5.glb'
bindings={
 'GM / soot':{'resource':'forge-steel','role':'surface','metallic':.22},
 'GM / mineral':{'resource':'cast-seams','role':'surface','metallic':0},
 'GM / copper':{'resource':'copper-heat-oxide','role':'surface','metallic':.45},
 'GM / brass':{'resource':'copper-patina','role':'surface','metallic':.5},
 'GM / ore':{'resource':'aggregate','role':'surface','metallic':0},
 'GM / chalk':{'resource':'lime-plaster','role':'surface','metallic':0},
 'GM / cooling-floor':{'resource':'wet-soot','role':'surface','metallic':.05},
 'G4 / ribbed':{'resource':'ribbed-steel','role':'surface','metallic':.4},
 'G4 / timber':{'resource':'timber-weather','role':'surface','metallic':0},
 'G4 / grating':{'resource':'iron-grate','role':'surface','metallic':.45}}
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
materials,density,material_report=load_materials(ROOT,bindings,HERE/'converted')
for name in ['GM / mineral','GM / chalk','GM / ore']:
 for node in materials[name].node_tree.nodes:
  if node.type=='NORMAL_MAP':node.inputs['Strength'].default_value=.35
 material_report['materials'][name]['normalStrength']=.35
baseline_remap={'GM / soot':'GM / chalk'}
def coll(name):
 c=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(c);return c
source=coll('SOURCE / R5 editable anchored mechanisms');export=coll('EXPORT / R5 reviewed visual batches')
kit=Kit(source,export,materials,density)
def to_blender(p):return Vector((p[0],-p[2],p[1]))
proof=[]
for s in spec['shapes']:
 if s['kind']=='strut':
  # Keep editable geometry at local zero; rigid transform owns placement.
  obj=kit.mesh(s['id'],s['localVertices'],s['faces'],s['material'],sector='new-hero',bevel=.018)
  basis=Matrix([to_blender(axis) for axis in s['basis']]).transposed().to_4x4()
  basis.translation=to_blender(s['center']);obj.matrix_world=basis
 else:obj=kit.mesh(s['id'],[to_blender(p) for p in s['vertices']],s['faces'],s['material'],sector='new-hero',bevel=.018)
 # One-segment bevel preserves genuine edge highlights with bounded geometry.
 for mod in obj.modifiers:
  if mod.type=='BEVEL':mod.segments=1
 obj['shape_id']=s['id'];obj['shape_spec_sha256']=sha((HERE/'shapes.json').read_bytes())
 bpy.context.view_layer.update()
 actual=[obj.matrix_world@v.co for v in obj.data.vertices]
 assert all((a-to_blender(b)).length<.0001 for a,b in zip(actual,s['vertices'])),s['id']
 if s['kind']=='strut':
  length=(Vector(s['endpoints'][1])-Vector(s['endpoints'][0])).length
  for sign,end in zip((-1,1),s['endpoints']):assert (obj.matrix_world@Vector((0,0,sign*length/2))-to_blender(end)).length<.0001,s['id']
 proof.append({'id':s['id'],'kind':s['kind'],'vertices':len(actual),'endpointAndBoundsMatch':True})
component_triangles={}
graph=bpy.context.evaluated_depsgraph_get()
for obj in source.objects:
 evaluated=bpy.data.meshes.new_from_object(obj.evaluated_get(graph),preserve_all_data_layers=True,depsgraph=graph)
 evaluated.transform(obj.matrix_world)
 bm=bmesh.new();bm.from_mesh(evaluated);bmesh.ops.triangulate(bm,faces=bm.faces[:]);bm.to_mesh(evaluated);bm.free()
 component_triangles[obj.name]=[[[float(evaluated.vertices[i].co.x),float(evaluated.vertices[i].co.z),float(-evaluated.vertices[i].co.y)] for i in p.vertices] for p in evaluated.polygons]
 bpy.data.meshes.remove(evaluated)
(HERE/'component-triangles.json').write_text(json.dumps(component_triangles,separators=(',',':'))+'\n')
new_batches=kit.build_export_batches(max_triangles=26000)
bpy.ops.object.select_all(action='DESELECT');bpy.ops.import_scene.gltf(filepath=str(old))
baseline=[o for o in bpy.context.selected_objects if o.type=='MESH'];assert len(baseline)==8
for obj in baseline:
 for c in list(obj.users_collection):c.objects.unlink(obj)
 export.objects.link(obj)
 for i,original in enumerate(obj.data.materials):
  name=re.sub(r'\.\d{3}$','',original.name)
  if name=='GM / orange':
   original.name=name # Retain accepted imported principled/emission graph exactly.
  else:obj.data.materials[i]=materials[baseline_remap.get(name,name)]
 uv=obj.data.uv_layers.get('MothLocal') or obj.data.uv_layers.new(name='MothLocal');uv.active_render=True
 for polygon in obj.data.polygons:
  mat=obj.data.materials[polygon.material_index].name
  axes=((1,2),(0,2),(0,1))[max(range(3),key=lambda i:abs(polygon.normal[i]))]
  for loop in polygon.loop_indices:
   p=obj.data.vertices[obj.data.loops[loop].vertex_index].co
   uv.data[loop].uv=tuple(p[i]*density.get(mat,.5) for i in axes)
 obj['source_art_sha256']=sha(old.read_bytes());obj['source_geometry_hash']=data['geometryHash']
for obj in export.objects:
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.triangulate(bm,faces=bm.faces[:]);bm.to_mesh(obj.data);bm.free();obj.data.update()
for obj in source.objects:obj.hide_render=True;obj.hide_set(True)
bpy.context.scene['geometryHash']=data['geometryHash'];bpy.context.scene['revision']=5
bpy.context.scene['shapeSpecSha256']=sha((HERE/'shapes.json').read_bytes())
bpy.ops.file.pack_all()
master=HERE/'gravemill-foundry-revision5.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(master),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in export.objects:obj.hide_set(False);obj.select_set(True)
bpy.context.view_layer.objects.active=next(iter(export.objects))
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_yup=True,
 export_extras=True,export_materials='EXPORT',export_tangents=True)
report={'visualRevision':5,'geometryHash':data['geometryHash'],'authoritySha256':sha((HERE/'candidate.json').read_bytes()),
 'authorityChange':data['arena']['art']['revision5'],'sourceGLBSha256':sha(old.read_bytes()),'moth':material_report,
 'sourceObjects':len(source.objects),'exportBatches':len(export.objects),'newBatches':len(new_batches),
 'master':{'sha256':sha(master.read_bytes()),'bytes':master.stat().st_size},'glb':{'sha256':sha(out.read_bytes()),'bytes':out.stat().st_size},
 'blenderVersion':bpy.app.version_string,'constructionChecks':proof,'nativeAcceptance':'pending',
 'baselineMaterialRoles':{'remap':baseline_remap,'reason':'Accepted runtime uses pale cast architecture; lime-plaster on legacy architectural soot restores that role. New structural steel retains forge-steel. Mineral normal relief .35; source normal bytes unchanged.'}}
(HERE/'export-report.json').write_text(json.dumps(report,indent=2)+'\n')
print('FOUNDRY_R5_EXPORT',json.dumps({k:report[k] for k in ['sourceObjects','exportBatches','master','glb']}))
