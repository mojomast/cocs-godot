"""Shared Blender composition entry for the map-variety revision builders.

Bridges the pure source plan (``composition.compose`` base geometry +
``layout.parts`` authored classes) into a Blender editable master and a
material-batched GLB. Requires the injected adapter
``load_materials(root, bindings) -> (materials, density)``; unknown material is a
hard error. This module imports bpy only inside ``run``.
"""
import argparse
import hashlib
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import composition  # noqa: E402
import geometry  # noqa: E402
import manifest  # noqa: E402


def _sha256(data):
    return hashlib.sha256(data).hexdigest()


def source_triangle_estimate(specs):
    """Pre-modifier estimate; labels and bevel subdivisions are measured after build."""
    return sum(sum(len(face) - 2 for face in spec['faces']) if spec['op'] == 'mesh'
               else (len(spec['points']) - 1) * spec.get('sides', 12) * 2
                    + 2 * (spec.get('sides', 12) - 2)
               for spec in specs)


def _load_adapter(path):
    import importlib.util
    if not pathlib.Path(path).is_file():
        raise SystemExit('Material adapter not found: %s. Expected load_materials(root, bindings) -> (materials, density).' % path)
    spec = importlib.util.spec_from_file_location('map_variety_material_adapter', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    if not hasattr(module, 'load_materials'):
        raise SystemExit('Adapter %s does not expose load_materials(root, bindings).' % path)
    return module


def _glb_document(path):
    raw = pathlib.Path(path).read_bytes()
    if raw[:4] != b'glTF' or len(raw) != int.from_bytes(raw[8:12], 'little'):
        raise ValueError('Malformed GLB header/length')
    size = int.from_bytes(raw[12:16], 'little')
    doc = json.loads(raw[20:20 + size])
    blob = raw[size + 28:]
    return doc, blob


def _glb_material_images(path):
    doc, blob = _glb_document(path)

    def image_sha(index):
        view = doc['bufferViews'][doc['images'][doc['textures'][index]['source']]['bufferView']]
        start = view.get('byteOffset', 0)
        return _sha256(blob[start:start + view['byteLength']])

    result = {}
    for material in doc.get('materials', []):
        base = material.get('pbrMetallicRoughness', {}).get('baseColorTexture')
        normal = material.get('normalTexture')
        result[material['name']] = {'color': image_sha(base['index']) if base else None,
                                    'normal': image_sha(normal['index']) if normal else None}
    return result


def _emit_cameras(bpy, review, cameras):
    import mathutils
    created = 0
    for name, (eye, target) in cameras.items():
        eye_bl, target_bl = geometry.source_to_blender(eye), geometry.source_to_blender(target)
        camera = bpy.data.objects.new('probe.' + name, bpy.data.cameras.new(name))
        review.objects.link(camera)
        camera.location = mathutils.Vector(eye_bl)
        # Target-tracking basis: -Z forward, +Y up after conversion. Never a flat
        # Euler that ignores target height.
        camera.rotation_euler = (mathutils.Vector(target_bl) - mathutils.Vector(eye_bl)).to_track_quat('-Z', 'Y').to_euler()
        created += 1
    return created


def _emit_labels(bpy, source, labels, materials, density):
    """Make route signs source meshes before batching, with reviewed UV lineage."""
    if labels and ('amber' not in materials or 'amber' not in density):
        raise ValueError('Route signs require an exact amber material and UV density')
    created = 0
    for index, label in enumerate(labels):
        curve = bpy.data.curves.new('route-sign-%d' % index, 'FONT')
        curve.body = label['text']
        curve.size = label.get('size', 0.9)
        curve.extrude = 0.008
        curve.align_x = 'CENTER'
        obj = bpy.data.objects.new(curve.name, curve)
        source.objects.link(obj)
        obj.location = geometry.source_to_blender((label['x'], label['y'], label['z']))
        obj.rotation_euler = (1.57079632679, 0, -label.get('heading', 0.0))
        curve.materials.append(materials['amber'])
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.convert(target='MESH')
        obj.select_set(False)
        mesh = obj.data
        if not mesh.polygons:
            raise ValueError('Empty route sign: ' + label['text'])
        if len(mesh.materials) != 1 or mesh.materials[0] != materials['amber']:
            raise ValueError('Route sign lost reviewed amber material')
        uv = mesh.uv_layers.get('MothLocal') or mesh.uv_layers.new(name='MothLocal')
        uv.active_render = True
        for face in mesh.polygons:
            for loop in face.loop_indices:
                point = mesh.vertices[mesh.loops[loop].vertex_index].co
                uv.data[loop].uv = (point.x * density['amber'], point.y * density['amber'])
        obj['kit_sector'] = 'signage'
        obj['kit_material'] = 'amber'
        obj['kit_source'] = 'route-sign-%d' % index
        created += 1
    return created


def run(config, argv=None):
    parser = argparse.ArgumentParser(description=config['description'])
    parser.add_argument('--root', required=True, type=pathlib.Path)
    parser.add_argument('--authority', default=str(config['directory'] / 'candidate.json'))
    parser.add_argument('--bindings', default=str(config['directory'] / 'materials.bindings.json'))
    parser.add_argument('--adapter', default='tools/map-variety-pipeline/material_adapter.py')
    parser.add_argument('--blend', default=str(config['directory'] / (config['id'] + '-revision2.blend')))
    parser.add_argument('--glb', default=str(config['directory'] / (config['id'] + '-revision2.glb')))
    parser.add_argument('--report', default=str(config['directory'] / 'material-report.json'))
    parser.add_argument('--max-batches', type=int, default=64)
    parser.add_argument('--max-triangles', type=int, default=12000)
    args = parser.parse_args(argv)

    import bpy
    layout = config['layout']
    authority = json.loads(pathlib.Path(args.authority).read_text())
    bindings = json.loads(pathlib.Path(args.bindings).read_text())['materials']
    adapter_path = args.adapter if pathlib.Path(args.adapter).is_absolute() else args.root / args.adapter
    module = _load_adapter(adapter_path)
    pack = manifest.load_pack(args.root)
    resolved = pack.bindings_plan(bindings)

    specs = composition.compose_full(authority['arena'], layout)
    used = {spec['material'] for spec in specs}
    missing = used - set(bindings)
    if missing:
        raise SystemExit('Composition uses unreviewed materials: ' + ', '.join(sorted(missing)))
    for spec in specs:
        geometry.validate_spec(spec)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    source = bpy.data.collections.new('01 EDITABLE %s revision-2' % config['id'])
    export = bpy.data.collections.new('02 EXPORT material batches')
    review = bpy.data.collections.new('03 REVIEW probe cameras')
    bpy.context.scene.collection.children.link(source)
    bpy.context.scene.collection.children.link(export)
    bpy.context.scene.collection.children.link(review)

    materials, density = module.load_materials(str(args.root), bindings)
    from blender_kit import Kit
    kit = Kit(source, export, materials, density)

    for spec in specs:
        name, material, sector = spec['name'], spec['material'], spec['sector']
        if spec['op'] == 'mesh':
            kit.mesh(name, [geometry.source_to_blender(v) for v in spec['vertices']], spec['faces'],
                     material, sector=sector, bevel=spec.get('bevel', 0.035), smooth=spec.get('smooth', True))
        elif spec['op'] == 'pipe':
            kit.pipe(name, [geometry.source_to_blender(p) for p in spec['points']], spec['radius'],
                     material, sector=sector, sides=spec.get('sides', 12))
        else:
            raise SystemExit('Unreviewed spec op: ' + spec['op'])

    labels = _emit_labels(bpy, source, composition.labels_for_arena(authority['arena']), materials, density)
    batches = kit.build_export_batches(max_triangles=args.max_triangles)
    if not batches or len(batches) > args.max_batches:
        raise SystemExit('Export batch count outside reviewed cap: %d' % len(batches))

    cameras = _emit_cameras(bpy, review, layout.PROBE_CAMERAS)
    signage = [batch for batch in batches if batch.get('kit_sector') == 'signage']
    if labels and (not signage or sum(len(batch.data.polygons) for batch in signage) == 0):
        raise ValueError('Route labels absent from export batches')

    bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    bpy.ops.object.select_all(action='DESELECT')
    for batch in batches:
        batch.select_set(True)
    bpy.context.view_layer.objects.active = batches[0]
    if {obj.name for obj in bpy.context.selected_objects} != {batch.name for batch in batches}:
        raise ValueError('GLB selection is not exactly the export batches')
    bpy.ops.export_scene.gltf(filepath=args.glb, export_format='GLB', use_selection=True,
                              export_yup=True, export_apply=False, export_extras=True,
                              export_tangents=True, export_materials='EXPORT')

    glb_bytes = pathlib.Path(args.glb).read_bytes()
    embedded = _glb_material_images(args.glb)
    document, _ = _glb_document(args.glb)
    primitive_counts = [document['accessors'][p['indices']]['count'] // 3
                        for mesh in document.get('meshes', []) for p in mesh['primitives']
                        if p.get('mode', 4) == 4 and 'indices' in p]
    actual_triangles = sum(primitive_counts)
    if actual_triangles <= 0 or not primitive_counts:
        raise ValueError('Exported GLB has no indexed triangle primitives')
    report_materials = {}
    for name, binding in bindings.items():
        entry = {'role': binding.get('role')}
        if binding.get('role') != 'preserve':
            entry.update({'sourceColorSha256': pack.textures[resolved[name]['albedoKey']]['sha256'],
                           'sourceNormalSha256': pack.textures[resolved[name]['normalKey']]['sha256'] if resolved[name]['normalKey'] else None,
                           'sourceColorEncoding': 'linear PNG (immutable)',
                           'embeddedColorEncoding': 'glTF sRGB baseColor (derived by adapter)',
                          'embeddedColorSha256': embedded.get(name, {}).get('color'),
                          'embeddedNormalSha256': embedded.get(name, {}).get('normal'),
                          'tilesPerMeter': resolved[name]['tilesPerMeter'],
                          'teamColorSource': resolved[name]['teamColorSource']})
        report_materials[name] = entry
    report = {'id': authority['id'], 'layoutRevision': authority['layoutRevision'],
              'geometryHash': authority['geometryHash'], 'mothManifestSha256': pack.manifest_sha,
              'glbSha256': _sha256(glb_bytes), 'glbBytes': len(glb_bytes),
               'baseSpecs': len(composition.compose(authority['arena'])), 'authoredSpecs': len(layout.parts(authority['arena'])),
               'sourceTriangleEstimateBeforeLabelsAndModifiers': source_triangle_estimate(specs),
               'exportBatches': len(batches), 'exportTriangles': sum(sum(len(poly.vertices)-2 for poly in b.data.polygons) for b in batches),
               'glbPrimitives': len(primitive_counts), 'glbTriangles': actual_triangles,
               'signageBatches': len(signage), 'probeCameras': cameras, 'labels': labels,
              'composition': 'complete revised authority + authored classes; physics independent JSON',
              'materials': report_materials}
    pathlib.Path(args.report).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'status': 'built-pending-native-acceptance', 'report': str(args.report)}))
