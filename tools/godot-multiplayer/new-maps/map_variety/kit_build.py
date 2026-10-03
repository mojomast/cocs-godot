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
from triangle_policy import triangle_advisory


def _sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _place(obj, at, rot, tilt=0):
    obj.location = (float(at[0]), float(at[1]), float(at[2]))
    obj.rotation_euler = (float(tilt), 0.0, float(rot))


def create_assembly(kit, op):
    """Kit compound calls need not return every created object (framed_bay)."""
    before = set(kit.source.objects)
    _create_op(kit, op)
    created = [obj for obj in kit.source.objects if obj not in before]
    if not created:
        raise ValueError('Kit operation created no objects: ' + op['name'])
    for obj in created:
        _place(obj, op['at'], op['rot'], op.get('tilt',0))
        if op.get('profiled'):
            for modifier in list(getattr(obj,'modifiers',[])):
                if modifier.type == 'BEVEL':
                    obj.modifiers.remove(modifier)
        elif 'bevelSegments' in op:
            for modifier in getattr(obj,'modifiers',[]):
                if modifier.type == 'BEVEL':
                    modifier.segments = op['bevelSegments']
                    modifier.name = f"Reviewed edge chamfer · {op['bevelSegments']} segment(s)"
    return created


def emit_buckets(kit, prefix, buckets, cap):
    for material, bucket in sorted(buckets.items()):
        for index, chunk in enumerate(kit_expander.mesh_chunks(bucket, cap)):
            kit.mesh(f'{prefix}.{material}.{index:03d}', chunk['vertices'], chunk['faces'],
                     material, sector='authority', bevel=0, smooth=False)


def camera_specs(arena):
    art = arena.get('art', {})
    views = art.get('cameras') or art.get('inspectionViews') or []
    if not views:
        # Helix previously lacked stored inspection views. Keep authored views
        # in its recipe; this fallback is intentionally an error.
        raise ValueError('Candidate requires authored inspection cameras')
    return views


def restore_cameras(scene, arena):
    import bpy
    from mathutils import Vector
    collection = bpy.data.collections.new('Inspection cameras')
    scene.collection.children.link(collection)
    for view in camera_specs(arena):
        data = bpy.data.cameras.new(view['id'])
        obj = bpy.data.objects.new(view['id'], data)
        collection.objects.link(obj)
        obj.location = kit_expander.to_blender(view['eye'])
        target = Vector(kit_expander.to_blender(view['target']))
        obj.rotation_euler = (target-obj.location).to_track_quat('-Z', 'Y').to_euler()
        data.lens = view.get('lens', 38 if view['id'] == 'overview' else 23)
        data.clip_end = 2000
        if scene.camera is None:
            scene.camera = obj
    light = bpy.data.lights.new('Inspection sun','SUN')
    light.energy = 3
    sun = bpy.data.objects.new('Inspection sun',light)
    collection.objects.link(sun)
    sun.rotation_euler = (.5,-.5,-.6)


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


def _labels(export_collection, materials, density, labels):
    import bpy
    created = []
    for index, label in enumerate(labels):
        material = materials.get(label.get('material'))
        if material is None:
            raise ValueError('Unbound wayfinding material: ' + str(label.get('material')))
        curve = bpy.data.curves.new('wayfinding-' + str(index), 'FONT')
        curve.body = label['text']
        curve.align_x = 'CENTER'
        curve.size = label.get('size', 1)
        curve.resolution_u = 3
        curve.extrude = label.get('extrude',0)
        obj = bpy.data.objects.new('wayfinding-' + str(index), curve)
        export_collection.objects.link(obj)
        obj.location = (float(label['x']), float(-label['z']), float(label['y']))
        obj.rotation_euler = (0, 0, 0) if label.get('floor') else (math.pi / 2, 0, -label.get('yaw', 0))
        curve.materials.append(material)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.ops.object.convert(target='MESH')
        # Helix labels intentionally use its reviewed gold PBR, so converted
        # fonts need the same explicit UV channel/tangent basis as Kit meshes.
        uv = obj.data.uv_layers.get('MothLocal') or obj.data.uv_layers.new(name='MothLocal')
        uv.active_render = True
        repeat = density[label['material']]
        for loop in obj.data.loops:
            point = obj.data.vertices[loop.vertex_index].co
            uv.data[loop.index].uv = (point.x*repeat, point.y*repeat)
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
    class OrientedKit(Kit):
        def mesh(self, name, vertices, faces, material, **kwargs):
            return super().mesh(name, vertices, kit_expander.outward_faces(vertices,faces), material, **kwargs)

    authority = json.loads(Path(authority_path).read_text())
    arena = authority['arena']
    bindings = json.loads(Path(bindings_path).read_text())
    from export_audit import validate_bindings
    validate_bindings(bindings)
    from map_materials import load_reviewed_materials, assert_packed_materials
    materials, density, material_receipt = load_reviewed_materials(adapter, root, bindings, Path(master_path).parent/'textures')
    expected = set(bindings['materials'])
    if set(materials) != expected or set(density) != expected:
        raise ValueError('Adapter must return exactly the reviewed material and density keys')

    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    scene = bpy.context.scene
    scene['map_id'] = authority['id']
    scene['geometry_hash'] = authority['geometryHash']
    scene['recipe_hash'] = authority['recipeHash']
    scene['art_revision'] = bindings.get('revision')
    scene['material_bindings'] = json.dumps(bindings)
    scene['material_receipt'] = json.dumps(material_receipt)
    source = bpy.data.collections.new('SOURCE - authority and map-variety kit')
    export = bpy.data.collections.new('EXPORT - sector/material batches')
    scene.collection.children.link(source)
    scene.collection.children.link(export)
    kit = OrientedKit(source, export, materials, density)

    shell = kit_expander.shell_plan(arena)
    emit_buckets(kit, 'authority.surface', shell['surfaces'], max_triangles)
    emit_buckets(kit, 'authority.wall', shell['walls'], max_triangles)
    structures = kit_expander.structure_plan(arena)
    emit_buckets(kit, 'authority.block', structures['buckets'], max_triangles)
    pieces = kit_expander.piece_plan(arena)
    emit_buckets(kit, 'authority.piece', pieces['buckets'], max_triangles)
    decorative = kit_expander.decorative_plan(arena)
    emit_buckets(kit, 'art.decorative', decorative['buckets'], max_triangles)
    from base_craft import base_craft_plan
    craft = base_craft_plan(arena, root)
    emit_buckets(kit, 'art.accepted-craft', craft['buckets'], max_triangles)
    water = arena.get('art', {}).get('water')
    if water and 'water' in materials:
        x, y, z, w, d = water['x'], water['y'], water['z'], water['w'], water['d']
        vertices = [(x - w / 2, -(z - d / 2), y), (x - w / 2, -(z + d / 2), y), (x + w / 2, -(z + d / 2), y), (x + w / 2, -(z - d / 2), y)]
        kit.mesh('authority.water', vertices, [(0, 1, 2, 3)], 'water', sector='authority', bevel=0.0, smooth=False)

    result = kit_expander.plan(arena['art']['kit'], expected, max_triangles)
    for op in result['ops'] + kit_expander.infrastructure_plan(arena):
        create_assembly(kit, op)

    batches = kit.build_export_batches(max_triangles=max_triangles)
    label_objects = _labels(export, materials, density, arena.get('art', {}).get('labels', [])+craft['labels'] if include_labels else [])
    restore_cameras(scene, arena)
    # Save editable sources and evaluated export together without rendering
    # coincident duplicate geometry. Source collection remains available to edit.
    source.hide_render = True
    source.hide_viewport = True
    evaluated_triangles = sum(sum(len(p.vertices)-2 for p in obj.data.polygons) for obj in export.objects)
    evaluated_advisory = triangle_advisory(evaluated_triangles, 'evaluated-scene')
    expected_export_materials=sorted({obj.data.materials[p.material_index].name for obj in export.objects for p in obj.data.polygons})
    scene['export_materials']=json.dumps(expected_export_materials)
    scene['export_triangles']=evaluated_triangles

    master_path = Path(master_path)
    master_path.parent.mkdir(parents=True, exist_ok=True)
    assert_packed_materials(materials.values())
    bpy.ops.wm.save_as_mainfile(filepath=str(master_path))

    export_path = Path(export_path)
    export_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in list(export.objects):
        obj.select_set(True)
    if export.objects[:]:
        bpy.context.view_layer.objects.active = export.objects[0]
    bpy.ops.export_scene.gltf(filepath=str(export_path), export_format='GLB', use_selection=True, export_yup=True, export_extras=True, export_normals=True, export_tangents=True)
    from export_audit import audit_glb
    export_audit = audit_glb(export_path, root, bindings, expected_materials=expected_export_materials, expected_triangles=evaluated_triangles)

    report = {
        'id': authority['id'], 'revision': bindings.get('revision'),
        'geometryHash': authority['geometryHash'], 'recipeHash': authority['recipeHash'],
        'moth': bindings.get('pack'),
        'materials': sorted(expected),
        'authorityShellTriangles': shell['authorityTriangles'],
        'floorUnion': shell['floorUnion'],
        'structureBoxes': structures['boxes'],
        'structureTriangles': structures['triangles'],
        'pieceCount': pieces['pieces'],
        'pieceTriangles': pieces['triangles'],
        'decorativeMeshes': len(decorative['lineage']),
        'decorativeTriangles': decorative['triangles'],
        'baseCraftParts': len(craft['lineage']),
        'baseCraftTriangles': craft['triangles'],
        'baseCraftSourceSha256': craft.get('sourceSha256'),
        'baseCraftCandidateCuts': craft.get('candidateCutLineage',[]),
        'evaluatedSceneTriangles': evaluated_triangles,
        'evaluatedTriangleAdvisory': evaluated_advisory,
        'exportAudit': export_audit,
        'materialReceipt': material_receipt,
        'kitTriangleMeasurement': 'unmodified-source-estimate',
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
    from map_materials import assert_packed_materials
    assert_packed_materials(bpy.data.materials)
    export = bpy.data.collections['EXPORT - sector/material batches']
    bpy.ops.object.select_all(action='DESELECT')
    for obj in list(export.objects):
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(export_path), export_format='GLB', use_selection=True, export_yup=True, export_extras=True, export_normals=True, export_tangents=True)
    from export_audit import audit_glb
    bindings = json.loads(scene['material_bindings'])
    verified = audit_glb(export_path, root, bindings, expected_materials=json.loads(scene['export_materials']), expected_triangles=scene['export_triangles'])
    report = {'reopened': bpy.data.filepath, 'geometryHash': scene['geometry_hash'],
              'exportBatches': len(export.objects), 'glbSha256': _sha256(export_path), 'exportAudit': verified}
    Path(report_path).write_text(json.dumps(report, indent=2) + '\n')
    return report
