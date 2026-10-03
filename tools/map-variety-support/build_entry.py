"""Shared Blender composition entry for the map-variety revision builders.

Bridges the pure source plan (``composition.compose`` base geometry +
``layout.parts`` authored classes) into a Blender editable master and a
material-batched GLB. The injected adapter's
``load_materials(root, pack_bindings, with_report=True)`` returns exact
materials, repeat densities and converted-source proof. Preserved map colors
are separately authored from reviewed binding entries. bpy is imported by run.
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
import preserved  # noqa: E402


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
    path = pathlib.Path(path).resolve()
    if not path.is_file():
        raise SystemExit('Material adapter not found: %s. Expected load_materials(root, bindings, with_report=True).' % path)
    # R's adapter imports its sibling material_pack.py as a top-level module.
    if str(path.parent) not in sys.path:
        sys.path.insert(0, str(path.parent))
    spec = importlib.util.spec_from_file_location('map_variety_material_adapter', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    if not hasattr(module, 'load_materials'):
        raise SystemExit('Adapter %s does not expose load_materials(root, bindings, with_report=True).' % path)
    return module


def request_pack_materials(module, root, pack_bindings, output_dir, pack):
    """Invoke R's exact adapter contract only for reviewed surface/team roles."""
    if any(b['role'] not in ('surface', 'team') for b in pack_bindings.values()):
        raise ValueError('Preserved material passed into the Moth adapter')
    materials, density, report = module.load_materials(
        str(root), pack_bindings, output_dir=output_dir, with_report=True)
    if (set(materials) != set(pack_bindings) or set(density) != set(pack_bindings) or
            set(report['materials']) != set(pack_bindings) or
            report['pack']['baseSha256'] != pack.base_sha or
            report['pack']['overlaySha256'] != pack.overlay_sha):
        raise ValueError('Moth adapter returned incomplete keys or different pack provenance')
    return materials, density, report


def _glb_document(path):
    raw = pathlib.Path(path).read_bytes()
    if (len(raw) < 28 or raw[:4] != b'glTF' or int.from_bytes(raw[4:8], 'little') != 2 or
            len(raw) != int.from_bytes(raw[8:12], 'little')):
        raise ValueError('Malformed GLB header/length')
    size = int.from_bytes(raw[12:16], 'little')
    if (size % 4 or raw[16:20] != b'JSON' or size + 28 > len(raw) or
            raw[24 + size:28 + size] != b'BIN\x00' or
            int.from_bytes(raw[20 + size:24 + size], 'little') != len(raw) - size - 28):
        raise ValueError('Malformed GLB chunk layout')
    doc = json.loads(raw[20:20 + size])
    blob = raw[size + 28:]
    if doc.get('buffers') and doc['buffers'][0].get('byteLength', 0) > len(blob):
        raise ValueError('GLB BIN buffer shorter than declared')
    return doc, blob


def _glb_material_images(path):
    doc, blob = _glb_document(path)

    def image_bytes(index):
        view = doc['bufferViews'][doc['images'][doc['textures'][index]['source']]['bufferView']]
        start = view.get('byteOffset', 0)
        return blob[start:start + view['byteLength']]

    result = {}
    for material in doc.get('materials', []):
        pbr = material.get('pbrMetallicRoughness', {})
        base = pbr.get('baseColorTexture')
        rough = pbr.get('metallicRoughnessTexture')
        normal = material.get('normalTexture')
        result[material['name']] = {'color': image_bytes(base['index']) if base else None,
                                    'normal': image_bytes(normal['index']) if normal else None,
                                    'roughness': image_bytes(rough['index']) if rough else None}
    return result


def verify_png_pixels(source, embedded, decode, *, srgb):
    """Compare decoded channels; Blender may re-encode PNG bytes losslessly."""
    if not embedded:
        raise ValueError('Missing embedded PBR image')
    width, height, original = decode(source)
    out_width, out_height, exported = decode(embedded)
    if (width, height) != (out_width, out_height) or len(original) != len(exported):
        raise ValueError('Moth image dimensions changed in GLB')
    for index, value in enumerate(original):
        if srgb and index % 4 != 3:
            linear = value / 255
            encoded = 12.92 * linear if linear <= .0031308 else 1.055 * linear ** (1 / 2.4) - .055
            expected = round(encoded * 255)
        else:
            expected = value
        if abs(expected - exported[index]) > 1:
            raise ValueError('Embedded %s channel differs from immutable Moth source at pixel channel %d' %
                             ('sRGB baseColor' if srgb else 'linear normal', index))
    return len(original) // 4


def verify_roughness_pixels(source, embedded, decode):
    """glTF ORM roughness is G; R's source scalar is linear red."""
    if not embedded:
        raise ValueError('Missing embedded glTF metallicRoughness texture')
    width, height, original = decode(source)
    ew, eh, exported = decode(embedded)
    if (width, height) != (ew, eh) or len(original) != len(exported):
        raise ValueError('Roughness image dimensions changed')
    for pixel in range(0, len(original), 4):
        if abs(original[pixel] - exported[pixel + 1]) > 1:
            raise ValueError('Embedded roughness G differs from immutable source R at pixel %d' % (pixel // 4))
    return len(original) // 4


def packed_image_count(images):
    """Count all FILE images; fail if any reopened master would need disk bytes."""
    file_images = [image for image in images if image.source == 'FILE']
    if not file_images:
        raise ValueError('No pack-backed Blender images in materialized master')
    missing = [image.name for image in file_images
               if not getattr(image, 'packed_file', None) and not getattr(image, 'packed_files', ())]
    if missing:
        raise ValueError('Master retains external images: ' + ', '.join(sorted(missing)))
    return len(file_images)


def triangulate_export_batches(batches):
    """Triangulate baked copies for complete glTF tangents; leave editable source intact."""
    import bmesh
    removed = {}
    for batch in batches:
        mesh = batch.data
        if not mesh.uv_layers.get('MothLocal'):
            raise ValueError('Export batch lost MothLocal before triangulation: ' + batch.name)
        bmesh_data = bmesh.new()
        try:
            bmesh_data.from_mesh(mesh)
            bmesh.ops.triangulate(bmesh_data, faces=list(bmesh_data.faces))
            # Font conversion can yield collinear zero-area glyph triangles.
            # Remove only mathematically invisible export faces, record every
            # removal, and retain a strict cap rather than hiding bad geometry.
            zero = [face for face in bmesh_data.faces if face.calc_area() <= 1e-12]
            if zero:
                if batch.get('kit_sector') != 'signage' or len(zero) > 64:
                    raise ValueError('Non-signage/too many zero-area export triangles: %s (%d)' %
                                     (batch.name, len(zero)))
                bmesh.ops.delete(bmesh_data, geom=zero, context='FACES_ONLY')
                removed[batch.name] = len(zero)
            bmesh_data.to_mesh(mesh)
        finally:
            bmesh_data.free()
        mesh.update()
        invalid = [(index, len(face.vertices), face.area) for index, face in enumerate(mesh.polygons)
                   if len(face.vertices) != 3 or face.area <= 1e-12]
        if invalid and batch.get('kit_sector') == 'signage' and len(invalid) + removed.get(batch.name, 0) <= 64 and all(n == 3 and area <= 1e-12 for _, n, area in invalid):
            # Blender's float mesh conversion can collapse near-collinear font
            # slivers that had nonzero double-precision BMesh area.
            bm = bmesh.new()
            try:
                bm.from_mesh(mesh)
                bm.faces.ensure_lookup_table()
                bmesh.ops.delete(bm, geom=[bm.faces[i] for i, _, _ in invalid], context='FACES_ONLY')
                bm.to_mesh(mesh)
            finally:
                bm.free()
            mesh.update()
            removed[batch.name] = removed.get(batch.name, 0) + len(invalid)
            invalid = [(index, len(face.vertices), face.area) for index, face in enumerate(mesh.polygons)
                       if len(face.vertices) != 3 or face.area <= 1e-12]
        if not mesh.uv_layers.get('MothLocal') or invalid:
            raise ValueError('Triangulated batch invalid: %s (%d faces, sample %r)' %
                             (batch.name, len(invalid), invalid[:8]))
    return removed


def glb_triangle_counts(document, max_batches, evaluated_triangles):
    """Account for *every* GLB primitive, including unsupported modes/indices."""
    meshes = document.get('meshes', [])
    primitives = [primitive for mesh in meshes for primitive in mesh['primitives']]
    if not primitives or len(primitives) > max_batches:
        raise ValueError('GLB primitive count outside material-batch cap')
    accessors = document['accessors']
    counts = []
    for primitive in primitives:
        if primitive.get('mode', 4) != 4 or 'indices' not in primitive:
            raise ValueError('Unsupported or unindexed GLB primitive')
        index = primitive['indices']
        if type(index) is not int or not 0 <= index < len(accessors):
            raise ValueError('GLB indices accessor missing')
        count = accessors[index]['count']
        if type(count) is not int or count <= 0 or count % 3:
            raise ValueError('GLB triangle index count invalid')
        counts.append(count // 3)
    if sum(counts) != evaluated_triangles:
        raise ValueError('GLB triangle count differs from evaluated export batches: %d != %d' %
                         (sum(counts), evaluated_triangles))
    return len(primitives), sum(counts)


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
    parser.add_argument('--max-total-triangles', type=int, default=150000)
    # Blender retains its own CLI flags and `--` in sys.argv. Parse only the
    # builder portion (also support explicit argv in source tests).
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if argv is None and '--' in sys.argv else argv)

    import bpy
    layout = config['layout']
    authority = json.loads(pathlib.Path(args.authority).read_text())
    bindings = json.loads(pathlib.Path(args.bindings).read_text())['materials']
    adapter_path = args.adapter if pathlib.Path(args.adapter).is_absolute() else args.root / args.adapter
    module = _load_adapter(adapter_path)
    pack = manifest.load_pack(args.root)
    resolved = pack.bindings_plan(bindings)
    pack_bindings, preserved_bindings = preserved.split_bindings(bindings, config['id'])

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

    materials, density, adapter_report = request_pack_materials(
        module, args.root, pack_bindings,
        pathlib.Path(args.report).resolve().parent / 'converted' / config['id'], pack)
    authored, authored_density = preserved.make_materials(bpy, preserved_bindings)
    if set(materials) & set(authored):
        raise ValueError('Moth and authored preserved materials overlap')
    materials.update(authored)
    density.update(authored_density)
    if set(materials) != set(bindings) or set(density) != set(bindings):
        raise ValueError('Incomplete exact reviewed material registry')
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
    removed_degenerate = triangulate_export_batches(batches)
    evaluated_triangles = sum(sum(len(poly.vertices) - 2 for poly in batch.data.polygons) for batch in batches)
    if args.max_total_triangles < 1:
        raise ValueError('Total triangle target must be positive')
    triangle_target_exceeded = evaluated_triangles > args.max_total_triangles

    cameras = _emit_cameras(bpy, review, layout.PROBE_CAMERAS)
    signage = [batch for batch in batches if batch.get('kit_sector') == 'signage']
    if labels and (not signage or sum(len(batch.data.polygons) for batch in signage) == 0):
        raise ValueError('Route labels absent from export batches')

    # Editable meshes remain accessible in the master. Hide them in both the
    # viewport and render to prevent duplicate silhouettes on reopen; only the
    # baked export collection is visible and explicitly selected for glTF.
    source.hide_render = True
    source.hide_viewport = True
    review.hide_render = True
    export.hide_render = False
    bpy.ops.file.pack_all()
    packed_images = packed_image_count(bpy.data.images)
    bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    master_bytes = pathlib.Path(args.blend).read_bytes()
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
    from material_pack import linear_rgba, srgb_png
    document, _ = _glb_document(args.glb)
    primitive_count, actual_triangles = glb_triangle_counts(document, args.max_batches, evaluated_triangles)
    report_materials = {}
    for name, binding in bindings.items():
        entry = {'role': binding.get('role')}
        if binding.get('role') == 'preserve':
            entry.update({'colorSrgb': binding['colorSrgb'], 'alpha': binding['alpha'],
                          'metallic': binding['metallic'], 'roughness': binding['roughness'],
                          'emissionStrength': binding['emissionStrength'],
                          'tilesPerMeter': binding['tilesPerMeter']})
        else:
            # Independently verify decoded exported pixels, rather than equating
            # hashes of linear source PNG and derived sRGB glTF PNG containers.
            color = embedded.get(name, {}).get('color')
            normal = embedded.get(name, {}).get('normal')
            roughness = embedded.get(name, {}).get('roughness')
            if name in used:
                immutable_color = pathlib.Path(resolved[name]['albedoFile']).read_bytes()
                if (_sha256(immutable_color) != pack.textures[resolved[name]['albedoKey']]['sha256'] or
                        _sha256(immutable_color) != adapter_report['materials'][name]['sourceColorSha256'] or
                        _sha256(srgb_png(immutable_color)) != adapter_report['materials'][name]['convertedAlbedoSha256']):
                    raise ValueError('Immutable source or adapter derived color changed: ' + name)
                entry['verifiedColorPixels'] = verify_png_pixels(immutable_color, color, linear_rgba, srgb=True)
                if resolved[name]['normalFile']:
                    immutable_normal = pathlib.Path(resolved[name]['normalFile']).read_bytes()
                    if _sha256(immutable_normal) != pack.textures[resolved[name]['normalKey']]['sha256']:
                        raise ValueError('Immutable source normal changed: ' + name)
                    entry['verifiedNormalPixels'] = verify_png_pixels(
                        immutable_normal, normal, linear_rgba, srgb=False)
                roughness_key = pack.material(binding['material'])['channels']['roughness']
                immutable_roughness = pathlib.Path(pack.textures[roughness_key]['_path']).read_bytes()
                if (_sha256(immutable_roughness) != pack.textures[roughness_key]['sha256'] or
                        _sha256(immutable_roughness) != adapter_report['materials'][name]['sourceRoughnessSha256']):
                    raise ValueError('Immutable source roughness changed: ' + name)
                entry['verifiedRoughnessPixels'] = verify_roughness_pixels(
                    immutable_roughness, roughness, linear_rgba)
            entry.update({'sourceColorSha256': pack.textures[resolved[name]['albedoKey']]['sha256'],
                          'sourceNormalSha256': pack.textures[resolved[name]['normalKey']]['sha256'] if resolved[name]['normalKey'] else None,
                          'sourceColorEncoding': 'linear PNG (immutable)',
                          'embeddedColorEncoding': 'glTF sRGB baseColor (derived by adapter)',
                          'embeddedColorSha256': _sha256(color) if color else None,
                          'embeddedNormalSha256': _sha256(normal) if normal else None,
                          'embeddedRoughnessSha256': _sha256(roughness) if roughness else None,
                          'sourceRoughnessSha256': adapter_report['materials'][name]['sourceRoughnessSha256'],
                          'adapterConvertedColorSha256': adapter_report['materials'][name]['convertedAlbedoSha256'],
                          'adapterSourceColorSha256': adapter_report['materials'][name]['sourceColorSha256'],
                          'tilesPerMeter': resolved[name]['tilesPerMeter'],
                          'teamColorSource': resolved[name]['teamColorSource']})
        report_materials[name] = entry
    report = {'id': authority['id'], 'layoutRevision': authority['layoutRevision'],
               'geometryHash': authority['geometryHash'], 'mothManifestSha256': pack.manifest_sha,
               'masterSha256': _sha256(master_bytes), 'masterBytes': len(master_bytes),
               'packedImages': packed_images,
               'glbSha256': _sha256(glb_bytes), 'glbBytes': len(glb_bytes),
               'baseSpecs': len(composition.compose(authority['arena'])), 'authoredSpecs': len(layout.parts(authority['arena'])),
               'sourceTriangleEstimateBeforeLabelsAndModifiers': source_triangle_estimate(specs),
               'exportBatches': len(batches), 'exportTriangles': evaluated_triangles,
               'removedZeroAreaSignageTriangles': removed_degenerate,
               'maxTotalTriangles': args.max_total_triangles,
               'triangleTargetExceeded': triangle_target_exceeded,
               'glbPrimitives': primitive_count, 'glbTriangles': actual_triangles,
               'signageBatches': len(signage), 'probeCameras': cameras, 'labels': labels,
              'composition': 'complete revised authority + authored classes; physics independent JSON',
              'materials': report_materials}
    pathlib.Path(args.report).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'status': 'built-pending-native-acceptance', 'report': str(args.report)}))
