"""Run ONLY with the granted Blender slot. Editable masters stay outside godot.
blender --background --threads 1 --python tools/godot-vehicle-assets/build.py -- ROOT
"""
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'asset-production'))
from moth_finish import finish_scene


def build(root, kind, lod):
    recipe_path = root / 'tools/godot-vehicle-assets/generated' / f'{kind}-lod{lod}.json'
    raw = recipe_path.read_bytes()
    recipe = json.loads(raw)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material)
    mats = {}
    for name, (color, roughness, metallic) in recipe['palette'].items():
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get('Principled BSDF')
        rgb = [int(color[i:i+2], 16) / 255 for i in (0, 2, 4)]
        # Palette is sRGB; glTF factors and Blender node colors are linear.
        rgb = [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb]
        bsdf.inputs['Base Color'].default_value = (*rgb, 1)
        bsdf.inputs['Roughness'].default_value = roughness
        bsdf.inputs['Metallic'].default_value = metallic
        mats[name] = mat
    assembly = bpy.data.objects.new(f'{kind}_lod{lod}', None)
    bpy.context.collection.objects.link(assembly)
    assembly['recipe_sha256'] = hashlib.sha256(raw).hexdigest()
    assembly['source_axes'] = '+Y up; +Z forward; metres; attachment-local geometry'
    assembly['collision'] = 'none; Node source OBB authority only'
    # One mesh per rigid attachment, <= eight material surfaces per joint.
    for joint in recipe['joints']:
        vertices, faces, materials = [], [], []
        for part in recipe['parts']:
            if part['joint'] != joint:
                continue
            offset = len(vertices)
            vertices.extend((x, -z, y) for x, y, z in part['vertices'])
            faces.extend(tuple(offset + i for i in face) for face in part['faces'])
            materials.extend([list(mats).index(part['material'])] * len(part['faces']))
        if not all(math.isfinite(v) for point in vertices for v in point):
            raise ValueError('Non-finite geometry')
        mesh = bpy.data.meshes.new(joint)
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        if mesh.validate(verbose=True):
            raise ValueError(f'{kind}/{joint}: invalid mesh repaired; reject export')
        obj = bpy.data.objects.new(joint, mesh)
        bpy.context.collection.objects.link(obj)
        obj.parent = assembly
        x, y, z = recipe['joints'][joint]
        obj.location = (x, -z, y)
        for material in mats.values():
            mesh.materials.append(material)
        for polygon, material in zip(mesh.polygons, materials):
            polygon.material_index = material
        if lod == 0:
            bevel = obj.modifiers.new('Machined edge highlights', 'BEVEL')
            bevel.width = .004
            bevel.segments = 1
            bevel.limit_method = 'ANGLE'
        # Actual evaluated geometry budget, after bevel and triangulation.
        evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
        evaluated.calc_loop_triangles()
        count = len(evaluated.loop_triangles)
        obj['evaluated_triangles'] = count
        obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
    for name, position in [(f"seat_{s['name']}", s['position']) for s in recipe['seats']] + [
            (f'muzzle_{i}', p) for i, p in enumerate(recipe['muzzles'])]:
        marker = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(marker)
        marker.parent = assembly
        x, y, z = position
        marker.location = (x, -z, y)
        marker.empty_display_type = 'ARROWS'
        marker.empty_display_size = .08
        marker['contract'] = 'Source neutral anchor, not native authority'
    total = sum(o.get('evaluated_triangles', 0) for o in bpy.context.scene.objects)
    cap = [100000, 36000, 16000][lod]
    if total > cap:
        raise ValueError(f'{kind} LOD{lod}: {total} > {cap} triangles')
    masters = root / 'tools/godot-vehicle-assets/masters'
    output = root / 'godot/vehicle_assets/generated'
    masters.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    finish_scene(root, 'vehicles')
    bpy.ops.wm.save_as_mainfile(filepath=str(masters / f'{kind}-lod{lod}.blend'))
    bpy.ops.export_scene.gltf(filepath=str(output / f'{kind}-lod{lod}.glb'),
                              export_format='GLB', export_yup=True,
                              export_apply=True, export_extras=True,
                              export_animations=False, export_cameras=False,
                              export_lights=False)
    report = {'kind': kind, 'lod': lod, 'triangles': total,
              'recipe_sha256': hashlib.sha256(raw).hexdigest(),
              'blender': bpy.app.version_string, 'materials': len(mats),
              'attachments': len(recipe['joints'])}
    (masters / f'{kind}-lod{lod}-report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('VEHICLE_BUILD', json.dumps(report))


if __name__ == '__main__':
    root = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
    for kind in ('puma', 'titan', 'scout'):
        for lod in range(3):
            build(root, kind, lod)
