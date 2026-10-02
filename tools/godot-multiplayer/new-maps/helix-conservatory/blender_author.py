"""Run only after explicit heavy-slot grant. No primitive replacement/proxy mesh.
blender --background --threads 1 --python <this-file> -- <workspace-root>
"""
import bpy
import sys
import json
import hashlib
import math
from pathlib import Path

root = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
revision2 = '--revision=2' in sys.argv
source = root / 'port/native-multiplayer-worlds/worlds/helix-conservatory.json'
if revision2:
    source = root / 'port/new-maps/helix-conservatory/revision-2/recipe.json'
recipe = json.loads(source.read_text())
revision2 = revision2 or recipe['art'].get('revision') == 2
out = root / 'godot/multiplayer_worlds/art/helix-conservatory'
out.mkdir(parents=True, exist_ok=True)
masters = root / 'tools/godot-multiplayer/new-maps/helix-conservatory/masters'
if revision2:
    # Staged authoring never silently replaces accepted runtime artifacts.
    out = root / 'port/new-maps/helix-conservatory/revision-2/art'
    masters = masters / 'revision-2'
    out.mkdir(parents=True, exist_ok=True)
masters.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
colors = {'ceramic': (.28, .30, .23, 1), 'stone': (.12, .17, .14, 1),
          'verdigris': (.025, .18, .15, 1), 'gold': (.5, .26, .045, 1),
          'botanical': (.025, .13, .018, 1), 'leaflight': (.12, .28, .045, 1),
          'joint': (.04, .065, .055, 1), 'glass': (.15, .36, .32, .08)}
materials = {}
if revision2:
    colors.update({'brick': (.27, .105, .047, 1),
                   'soil': (.065, .043, .022, 1),
                   'solar': (.018, .047, .075, 1)})
    colors = {name: color for name, color in colors.items()
              if name in {part['material'] for part in recipe['art']['meshes']}}
for name, color in colors.items():
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = color
    bsdf.inputs['Roughness'].default_value = .38 if name == 'verdigris' else .72
    bsdf.inputs['Metallic'].default_value = .6 if name in ('gold', 'verdigris') else 0
    if name == 'glass':
        bsdf.inputs['Alpha'].default_value = .08
        mat.surface_render_method = 'DITHERED'
    materials[name] = mat

# Material/authority-class batches cap draw surfaces while retaining named recipe
# elements as mesh metadata in the editable master. Blender Z-up -> GLTF Y-up.
batches = {}
for part in recipe['art']['meshes']:
    key = (part['material'], part['collision'], part['walkable'])
    batch = batches.setdefault(key, {'vertices': [], 'faces': [], 'parts': []})
    base = len(batch['vertices'])
    batch['vertices'].extend((x, -z, y) for x, y, z in part['vertices'])
    batch['faces'].extend(tuple(base+i for i in face) for face in part['triangles'])
    batch['parts'].append({'id': part['id'], 'vertexStart': base, 'vertexCount': len(part['vertices'])})
for (material, collision, walkable), batch in batches.items():
    name = f'{material}-{collision}-walkable-{walkable}'
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(batch['vertices'], [], batch['faces'])
    mesh.materials.append(materials[material])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj['recipe_parts'] = json.dumps(batch['parts'], separators=(',', ':'))
    obj['authority_class'] = collision
    obj['walkable'] = walkable
    obj['recipe_sha256'] = hashlib.sha256(source.read_bytes()).hexdigest()

for i, label in enumerate(recipe['art'].get('labels', [])):
    curve = bpy.data.curves.new(f'wayfinding-{i}', 'FONT')
    curve.body = label['text']
    curve.align_x = 'CENTER'
    curve.size = label['size']
    curve.resolution_u = 3
    obj = bpy.data.objects.new(f'wayfinding-{i}', curve)
    bpy.context.collection.objects.link(obj)
    obj.location = (label['x'], -label['z'], label['y'])
    obj.rotation_euler = (0, 0, 0) if label.get('floor') else (math.pi/2, 0, -label.get('yaw', 0))
    curve.materials.append(materials[label['material']])
    obj['authority_class'] = 'none'
    obj['recipe_label'] = i
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target='MESH')
    obj.select_set(False)

scene = bpy.context.scene
scene['map_id'] = recipe['id']
scene['source_lock'] = '515daf'
scene['reviewed_derivative'] = '0326'
scene['collision_note'] = 'Use reviewed recipe triangles, never auto-convex GLB collision.'
bpy.ops.wm.save_as_mainfile(filepath=str(masters / 'helix-conservatory.blend'))
bpy.ops.export_scene.gltf(filepath=str(out / 'helix-conservatory.glb'), export_format='GLB',
                          export_extras=True, export_yup=True, export_apply=False)
report = {'recipeSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
          'vertices': sum(len(b['vertices']) for b in batches.values()),
          'triangles': sum(len(b['faces']) for b in batches.values()),
          'meshBatches': len(batches), 'materials': len(materials),
          'files': {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [out / 'helix-conservatory.glb', masters / 'helix-conservatory.blend']}}
(out / 'helix-conservatory-art-report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report))
