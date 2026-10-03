"""Blender-only: load saved master and independently export its baked collection."""
import argparse
import hashlib
import json
from pathlib import Path
import sys


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument('--blend', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args(argv)
    report = json.loads(args.report.read_text())
    if hashlib.sha256(args.blend.read_bytes()).hexdigest() != report['masterSha256']:
        raise ValueError('Master bytes differ before reexport')
    import bpy
    bpy.ops.wm.open_mainfile(filepath=str(args.blend.resolve()))
    export = bpy.data.collections.get('02 EXPORT material batches')
    if export is None or len(export.objects) != report['exportBatches']:
        raise ValueError('Missing/changed saved export batch collection')
    batches = list(export.objects)
    if any(obj.type != 'MESH' or obj.hide_render or not obj.data.uv_layers.get('MothLocal')
           for obj in batches):
        raise ValueError('Saved export batch mesh, UV, or visibility changed')
    triangles = sum(len(obj.data.polygons) for obj in batches)
    if triangles != report['exportTriangles']:
        raise ValueError('Saved mesh triangle count differs from first export')
    bpy.ops.object.select_all(action='DESELECT')
    for batch in batches:
        batch.hide_set(False)
        batch.select_set(True)
    bpy.context.view_layer.objects.active = batches[0]
    if {obj.name for obj in bpy.context.selected_objects} != {obj.name for obj in batches}:
        raise ValueError('Selection not exactly reexport batches')
    bpy.ops.export_scene.gltf(filepath=str(args.output), export_format='GLB', use_selection=True,
                              export_yup=True, export_apply=False, export_extras=True,
                              export_tangents=True, export_materials='EXPORT')
    if hashlib.sha256(args.blend.read_bytes()).hexdigest() != report['masterSha256']:
        raise ValueError('Reexport modified saved master')
    print(json.dumps({'reopenedExportBatches': len(batches), 'savedTriangles': triangles,
                      'reexportSha256': hashlib.sha256(args.output.read_bytes()).hexdigest()}))


if __name__ == '__main__':
    main(sys.argv[sys.argv.index('--') + 1:])
