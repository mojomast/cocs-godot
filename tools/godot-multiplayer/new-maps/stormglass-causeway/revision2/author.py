"""Stormglass revision-2 Blender author (run only by the granted heavy owner).

Source-authored, runnable entry point. Builds the editable master and the
material-batched GLB from the revision-2 authority with the shared
`blender_kit.Kit`. It does not select Moth resources: it requires the injected
adapter `load_materials(root, bindings) -> (materials, density)` from
`tools/map-variety-pipeline/material_adapter.py` (or --adapter). Unknown material
is an error, never a fallback to the pinned `moth_finish.py` registry.

Blender 4.5: blender -b -t 1 --python-exit-code 1 --python <this> -- --root <repo>
"""
import argparse
import hashlib
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parents[4] / 'tools' / 'map-variety-pipeline'))
sys.path.insert(0, str(HERE.parents[4] / 'tools' / 'map-variety-support'))
import layout  # noqa: E402


def _sha256(data):
    return hashlib.sha256(data).hexdigest()


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


def _glb_material_images(path):
    raw = pathlib.Path(path).read_bytes()
    size = int.from_bytes(raw[12:16], 'little')
    doc = json.loads(raw[20:20 + size])
    blob = raw[size + 28:]

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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True, type=pathlib.Path)
    parser.add_argument('--authority', default=str(HERE / 'candidate.json'))
    parser.add_argument('--bindings', default=str(HERE / 'materials.bindings.json'))
    parser.add_argument('--adapter', default='tools/map-variety-pipeline/material_adapter.py')
    parser.add_argument('--blend', default=str(HERE / 'stormglass-causeway-revision2.blend'))
    parser.add_argument('--glb', default=str(HERE / 'stormglass-causeway-revision2.glb'))
    parser.add_argument('--report', default=str(HERE / 'material-report.json'))
    parser.add_argument('--max-primitives', type=int, default=48)
    args = parser.parse_args()

    import bpy
    authority = json.loads(pathlib.Path(args.authority).read_text())
    bindings = json.loads(pathlib.Path(args.bindings).read_text())['materials']
    adapter_path = args.adapter if pathlib.Path(args.adapter).is_absolute() else args.root / args.adapter
    module = _load_adapter(adapter_path)

    from manifest import load_pack
    pack = load_pack()
    resolved = pack.bindings_plan(bindings)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    source = bpy.data.collections.new('01 EDITABLE stormglass revision-2')
    export = bpy.data.collections.new('02 EXPORT material batches')
    review = bpy.data.collections.new('03 REVIEW probe cameras')
    bpy.context.scene.collection.children.link(source)
    bpy.context.scene.collection.children.link(export)
    bpy.context.scene.collection.children.link(review)

    materials, density = module.load_materials(str(args.root), bindings)
    from blender_kit import Kit
    kit = Kit(source, export, materials, density)

    def emit(spec):
        op, name, material, sector = spec['op'], spec['name'], spec['material'], spec.get('sector', 'default')
        kwargs = spec.get('kwargs', {})
        if op == 'mesh':
            return kit.mesh(name, spec['args'][0], spec['args'][1], material, sector=sector, bevel=kwargs.get('bevel', 0.035))
        if op == 'prism':
            return kit.prism(name, spec['args'][0], spec['args'][1], material, sector=sector, **kwargs)
        if op == 'curved_rib':
            return kit.curved_rib(name, *spec['args'], material, sector=sector, **kwargs)
        if op == 'pipe':
            return kit.pipe(name, spec['args'][0], spec['args'][1], material, sector=sector, **kwargs)
        if op == 'framed_bay':
            return kit.framed_bay(name, *spec['args'], sector=sector, **kwargs)
        raise ValueError('Unreviewed layout op: ' + op)

    built = 0
    for spec in layout.parts(authority['arena']):
        emit(spec)
        built += 1
    batches = kit.build_export_batches(max_triangles=12000)
    if not batches or len(batches) > args.max_primitives:
        raise SystemExit('Export batch count outside reviewed cap: %d' % len(batches))

    bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    bpy.ops.object.select_all(action='DESELECT')
    for batch in batches:
        batch.select_set(True)
    bpy.context.view_layer.objects.active = batches[0]
    bpy.ops.export_scene.gltf(filepath=args.glb, export_format='GLB', use_selection=True,
                              export_yup=True, export_apply=False, export_extras=True,
                              export_tangents=True, export_materials='EXPORT')

    glb_bytes = pathlib.Path(args.glb).read_bytes()
    embedded = _glb_material_images(args.glb)
    report_materials = {}
    for name, binding in bindings.items():
        entry = {'role': binding.get('role')}
        if binding.get('role') != 'preserve':
            entry.update({
                'sourceColorSha256': pack.textures[resolved[name]['albedoKey']]['sha256'],
                'sourceNormalSha256': pack.textures[resolved[name]['normalKey']]['sha256'] if resolved[name]['normalKey'] else None,
                'embeddedColorSha256': embedded.get(name, {}).get('color'),
                'embeddedNormalSha256': embedded.get(name, {}).get('normal'),
                'tilesPerMeter': resolved[name]['tilesPerMeter'],
                'teamColorSource': resolved[name]['teamColorSource'],
            })
        report_materials[name] = entry
    report = {'id': authority['id'], 'layoutRevision': authority['layoutRevision'],
              'geometryHash': authority['geometryHash'], 'mothManifestSha256': pack.manifest_sha,
              'glbSha256': _sha256(glb_bytes), 'glbBytes': len(glb_bytes),
              'builtObjects': built, 'exportBatches': len(batches), 'distinctClasses': len(layout.CLASSES),
              'materials': report_materials}
    pathlib.Path(args.report).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'status': 'built-pending-native-acceptance', 'report': str(args.report)}))


if __name__ == '__main__':
    main()
