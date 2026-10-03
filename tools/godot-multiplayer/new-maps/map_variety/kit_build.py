"""Grant-only Blender scene assembly shared by the three map-variety builders.

Consumes a source authority revision plus that map's role bindings; never edits
accepted masters, generated JSON or runtime GLBs. Material binding is delegated
to the Sol-owned adapter (see ADAPTER_CONTRACT.md). This module imports bpy only
inside functions, so the source tests can import it without Blender.
"""
import hashlib
import json
import math
import sys
from pathlib import Path

import kit_expander


def _sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _place(obj, at, rot):
    obj.location = (float(at[0]), float(at[1]), float(at[2]))
    obj.rotation_euler = (0.0, 0.0, float(rot))


def _create_op(kit, op):
    if op['op'] == 'prism':
        return kit.prism(op['name'], (0, 0, 0), op['size'], op['material'], sector=op['sector'], bevel=op['bevel'])
    if op['op'] == 'framed_bay':
        return kit.framed_bay(op['name'], (0, 0, 0), op['width'], op['height'], op['depth'],
                              frame=op['material'], trim=op['trimMaterial'], sector=op['sector'], arch=op['arch'])
    if op['op'] == 'curved_rib':
        return kit.curved_rib(op['name'], (0, 0, 0), op['inner'], op['outer'], op['depth'],
                              op['start'], op['stop'], op['material'], sector=op['sector'], segments=op['segments'])
    if op['op'] == 'pipe':
        return kit.pipe(op['name'], op['points'], op['radius'], op['material'], sector=op['sector'], sides=op['sides'])
    if op['op'] == 'mesh':
        return kit.mesh(op['name'], op['vertices'], op['faces'], op['material'], sector=op['sector'],
                        bevel=op['bevel'], smooth=op['smooth'])
    raise ValueError('Unhandled op: ' + str(op['op']))


def _labels(export_collection, materials, labels):
    import bpy
    created = []
    for index, label in enumerate(labels):
        material = materials.get(label.get('material'))
        if material is None:
            continue
        curve = bpy.data.curves.new('wayfinding-' + str(index), 'FONT')
        curve.body = label['text']
        curve.align_x = 'CENTER'
        curve.size = label.get('size', 1)
        curve.resolution_u = 3
        obj = bpy.data.objects.new('wayfinding-' + str(index), curve)
        export_collection.objects.link(obj)
        obj.location = (float(label['x']), float(-label['z']), float(label['y']))
        obj.rotation_euler = (0, 0, 0) if label.get('floor') else (math.pi / 2, 0, -label.get('yaw', 0))
        curve.materials.append(material)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.ops.object.convert(target='MESH')
        obj.select_set(False)
        created.append(obj)
    return created


def build(root, authority_path, bindings_path, master_path, export_path, report_path,
          adapter_name='material_adapter', max_triangles=24000, include_labels=True):
    root = Path(root)
    sys.path.insert(0, str(root / 'tools/map-variety-pipeline'))
    from material_adapter_contract import load_adapter
    adapter = load_adapter(adapter_name)
    import bpy
    from blender_kit import Kit

    authority = json.loads(Path(authority_path).read_text())
    arena = authority['arena']
    bindings = json.loads(Path(bindings_path).read_text())
    materials, density = adapter.load_materials(root, bindings)
    expected = set(bindings['materials'])
    missing = sorted(name for name in expected if name not in materials or name not in density)
    if missing:
        raise ValueError('Adapter did not return every reviewed binding: ' + ', '.join(missing))

    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    scene = bpy.context.scene
    scene['map_id'] = authority['id']
    scene['geometry_hash'] = authority['geometryHash']
    scene['recipe_hash'] = authority['recipeHash']
    scene['art_revision'] = bindings.get('revision')
    source = bpy.data.collections.new('SOURCE - authority and map-variety kit')
    export = bpy.data.collections.new('EXPORT - sector/material batches')
    scene.collection.children.link(source)
    scene.collection.children.link(export)
    kit = Kit(source, export, materials, density)

    shell = kit_expander.shell_plan(arena)
    for material, bucket in sorted(shell['surfaces'].items()):
        kit.mesh('authority.surface.' + material, bucket['vertices'], bucket['faces'], material, sector='authority', bevel=0.0, smooth=False)
    for material, bucket in sorted(shell['walls'].items()):
        kit.mesh('authority.wall.' + material, bucket['vertices'], bucket['faces'], material, sector='authority', bevel=0.0, smooth=False)
    structures = kit_expander.structure_plan(arena)
    for material, bucket in sorted(structures['buckets'].items()):
        kit.mesh('authority.block.' + material, bucket['vertices'], bucket['faces'], material, sector='authority', bevel=0.0, smooth=False)
    pieces = kit_expander.piece_plan(arena)
    for material, bucket in sorted(pieces['buckets'].items()):
        kit.mesh('authority.piece.' + material, bucket['vertices'], bucket['faces'], material, sector='authority', bevel=0.0, smooth=False)
    water = arena.get('art', {}).get('water')
    if water and 'water' in materials:
        x, y, z, w, d = water['x'], water['y'], water['z'], water['w'], water['d']
        vertices = [(x - w / 2, -(z - d / 2), y), (x - w / 2, -(z + d / 2), y), (x + w / 2, -(z + d / 2), y), (x + w / 2, -(z - d / 2), y)]
        kit.mesh('authority.water', vertices, [(0, 1, 2, 3)], 'water', sector='authority', bevel=0.0, smooth=False)

    result = kit_expander.plan(arena['art']['kit'], expected, max_triangles)
    for op in result['ops']:
        _place(_create_op(kit, op), op['at'], op['rot'])

    batches = kit.build_export_batches(max_triangles=max_triangles)
    label_objects = _labels(export, materials, arena.get('art', {}).get('labels', []) if include_labels else [])

    master_path = Path(master_path)
    master_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(master_path))

    export_path = Path(export_path)
    export_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in list(export.objects):
        obj.select_set(True)
    if export.objects[:]:
        bpy.context.view_layer.objects.active = export.objects[0]
    bpy.ops.export_scene.gltf(filepath=str(export_path), export_format='GLB', use_selection=True, export_yup=True, export_extras=True)

    report = {
        'id': authority['id'], 'revision': bindings.get('revision'),
        'geometryHash': authority['geometryHash'], 'recipeHash': authority['recipeHash'],
        'moth': bindings.get('pack'),
        'materials': sorted(expected),
        'authorityShellTriangles': shell['authorityTriangles'],
        'structureBoxes': structures['boxes'],
        'structureTriangles': structures['triangles'],
        'pieceCount': pieces['pieces'],
        'pieceTriangles': pieces['triangles'],
        'kitTriangles': result['summary']['triangles'],
        'kitOps': result['summary']['ops'], 'kitBatches': result['summary']['batches'],
        'exportBatches': len(batches), 'labels': len(label_objects),
        'nonTriangleWalls': shell['nonTriangleWalls'],
        'intended': {'master': str(master_path.relative_to(root)), 'glb': str(export_path.relative_to(root)), 'maxPrimitives': 64},
        'files': {str(master_path.relative_to(root)): _sha256(master_path), str(export_path.relative_to(root)): _sha256(export_path)},
        'sizes': {str(master_path.relative_to(root)): master_path.stat().st_size, str(export_path.relative_to(root)): export_path.stat().st_size},
        'nativeAcceptance': 'pending; editable master/GLB not yet imported or rendered',
    }
    Path(report_path).write_text(json.dumps(report, indent=2) + '\n')
    return report


def reopen_export(root, master_path, export_path, report_path, authority_path):
    import bpy
    root = Path(root)
    bpy.ops.wm.open_mainfile(filepath=str(master_path))
    authority = json.loads(Path(authority_path).read_text())
    scene = bpy.context.scene
    assert scene['geometry_hash'] == authority['geometryHash'], 'Stale master geometry hash'
    export = bpy.data.collections['EXPORT - sector/material batches']
    bpy.ops.object.select_all(action='DESELECT')
    for obj in list(export.objects):
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(export_path), export_format='GLB', use_selection=True, export_yup=True, export_extras=True)
    report = {'reopened': bpy.data.filepath, 'geometryHash': scene['geometry_hash'],
              'exportBatches': len(export.objects), 'glbSha256': _sha256(export_path)}
    Path(report_path).write_text(json.dumps(report, indent=2) + '\n')
    return report
