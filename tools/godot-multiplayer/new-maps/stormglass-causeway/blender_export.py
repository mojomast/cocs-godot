"""Explicit-grant-only authoring. Source recipe vertices are the sole geometry input.

blender -b -t 1 --python tools/godot-multiplayer/new-maps/stormglass-causeway/blender_export.py
blender -b -t 1 <master.blend> --python <this-script> -- --verify-only
"""
import hashlib
import json
import pathlib
import sys
import bpy

ROOT = pathlib.Path(__file__).resolve().parents[4]
ID = 'stormglass-causeway'
DATA = json.loads((ROOT / 'port/native-multiplayer-worlds/worlds' / (ID + '.json')).read_text())
MASTER = ROOT / 'tools/godot-multiplayer/new-maps' / ID / (ID + '.blend')
ART = ROOT / 'godot/multiplayer_worlds/art/worlds' / (ID + '.glb')
COLORS = {'asphalt': (.055,.085,.10,1), 'concrete': (.31,.38,.39,1),
          'salt': (.66,.73,.69,1), 'amber': (.75,.36,.045,1),
          'teal': (.035,.22,.25,1), 'brick': (.27,.13,.085,1),
          'glass': (.07,.34,.43,1), 'steel': (.12,.19,.22,1),
          'ocean': (.02,.075,.105,1)}

if '--verify-only' in sys.argv:
    editable = bpy.data.collections.get('EDITABLE recipe components')
    assert editable and len(editable.objects) == len(DATA['art']['meshes'])
    for source in DATA['art']['meshes']:
        obj = editable.objects[source['id']]
        assert len(obj.data.vertices) == len(source['vertices'])
        for actual, (x, y, z) in zip(obj.data.vertices, source['vertices']):
            assert (actual.co - __import__('mathutils').Vector((x, -z, y))).length < .0001
    print('STORMGLASS_MASTER_REOPEN_OK', len(editable.objects))
else:
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.context.preferences.filepaths.save_version = 0
    materials = {}
    for name, color in COLORS.items():
        material = bpy.data.materials.new(name)
        material.diffuse_color = color
        material.use_nodes = True
        node = material.node_tree.nodes.get('Principled BSDF')
        node.inputs['Base Color'].default_value = color
        node.inputs['Metallic'].default_value = .5 if name == 'steel' else .05
        node.inputs['Roughness'].default_value = .25 if name in ('glass', 'ocean') else .72
        material.use_backface_culling = False
        materials[name] = material
    editable = bpy.data.collections.new('EDITABLE recipe components')
    export = bpy.data.collections.new('EXPORT material batches')
    bpy.context.scene.collection.children.link(editable)
    bpy.context.scene.collection.children.link(export)
    batches = {}
    for source in DATA['art']['meshes']:
        vertices = [(x, -z, y) for x, y, z in source['vertices']]
        mesh = bpy.data.meshes.new(source['id'])
        mesh.from_pydata(vertices, [], source['triangles'])
        mesh.update()
        obj = bpy.data.objects.new(source['id'], mesh)
        obj['source_collision'] = source['collision']
        obj['stable_map_id'] = ID
        mesh.materials.append(materials[source['material']])
        editable.objects.link(obj)
        verts, faces = batches.setdefault(source['material'], ([], []))
        start = len(verts)
        verts.extend(vertices)
        faces.extend([[start + index for index in face] for face in source['triangles']])
    editable.hide_render = True
    editable.hide_viewport = True
    for name, (vertices, faces) in batches.items():
        mesh = bpy.data.meshes.new('batch-' + name)
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        mesh.materials.append(materials[name])
        export.objects.link(bpy.data.objects.new('batch-' + name, mesh))
    # Sign text is bounded native art, above the physical barrier, never collision.
    for index, label in enumerate(DATA['art']['labels']):
        curve = bpy.data.curves.new('route-sign-' + str(index), 'FONT')
        curve.body = label['text']
        curve.size = .9
        curve.extrude = .008
        curve.align_x = 'CENTER'
        obj = bpy.data.objects.new(curve.name, curve)
        export.objects.link(obj)
        obj.location = (label['x'], -label['z'], label['y'])
        obj.rotation_euler = (1.57079632679, 0, -label['heading'])
        curve.materials.append(materials['amber'])
    MASTER.parent.mkdir(parents=True, exist_ok=True)
    ART.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(MASTER))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in export.objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ART), export_format='GLB', use_selection=True,
                              export_yup=True, export_apply=True)
    report = {'id': ID, 'master': str(MASTER), 'glb': str(ART),
              'glbSha256': hashlib.sha256(ART.read_bytes()).hexdigest(),
              'editableMeshes': len(editable.objects), 'materialBatches': len(batches),
              'recipeTriangles': sum(len(p['triangles']) for p in DATA['art']['meshes']),
              'acceptance': 'export only; reopen/native/rendered acceptance still required'}
    (MASTER.parent / 'export-report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))
