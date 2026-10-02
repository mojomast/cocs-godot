"""Run only after explicit heavy-slot grant. No primitive replacement/proxy mesh.
blender --background --threads 1 --python <this-file> -- <workspace-root>
"""
import bpy
import sys
import json
import hashlib
from pathlib import Path

root = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
source = root / 'port/native-multiplayer-worlds/worlds/helix-conservatory.json'
recipe = json.loads(source.read_text())
out = root / 'godot/multiplayer_worlds/art/helix-conservatory'
out.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
colors = {'ceramic': (.76, .79, .66, 1), 'stone': (.37, .43, .38, 1),
          'verdigris': (.075, .40, .35, 1), 'gold': (.94, .57, .12, 1),
          'botanical': (.11, .31, .10, 1), 'glass': (.40, .82, .79, .20)}
materials = {}
for name, color in colors.items():
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = color
    bsdf.inputs['Roughness'].default_value = .38 if name == 'verdigris' else .72
    bsdf.inputs['Metallic'].default_value = .6 if name in ('gold', 'verdigris') else 0
    if name == 'glass':
        bsdf.inputs['Alpha'].default_value = .20
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

scene = bpy.context.scene
scene['map_id'] = recipe['id']
scene['source_lock'] = '515daf'
scene['reviewed_derivative'] = '0326'
scene['collision_note'] = 'Use reviewed recipe triangles, never auto-convex GLB collision.'
bpy.ops.wm.save_as_mainfile(filepath=str(out / 'helix-conservatory.blend'))
bpy.ops.export_scene.gltf(filepath=str(out / 'helix-conservatory.glb'), export_format='GLB',
                          export_extras=True, export_yup=True, export_apply=False)
report = {'recipeSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
          'vertices': sum(len(b['vertices']) for b in batches.values()),
          'triangles': sum(len(b['faces']) for b in batches.values()),
          'meshBatches': len(batches), 'materials': len(materials),
          'files': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.suffix in ('.blend', '.glb')}}
(out / 'helix-conservatory-art-report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report))
