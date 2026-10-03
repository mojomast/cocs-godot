"""Vesper Viaduct urban-v2 Blender builder entry point (grant-only).

    blender -b -t 1 --python-exit-code 1 --python asset_author.py -- plan
    blender -b -t 1 --python-exit-code 1 --python asset_author.py -- build --adapter=material_adapter
    blender -b -t 1 --python-exit-code 1 --python asset_author.py -- reopen-export

`plan` is pure Python and runs without Blender/bpy. `build`/`reopen-export`
require the explicit heavy-slot grant and the delivered Sol material adapter.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
HERE = Path(__file__).resolve().parent
MAP_ID = 'vesper-viaduct'
REVISION = 'urban-v2'
AUTHORITY = ROOT / f'port/new-maps/{MAP_ID}/variety/{REVISION}/authority.json'
BINDINGS = HERE / 'variety_bindings.json'
MASTER = HERE / f'masters/{MAP_ID}.blend'
EXPORT = ROOT / f'port/new-maps/{MAP_ID}/variety/{REVISION}/{MAP_ID}.glb'
REPORT = ROOT / f'port/new-maps/{MAP_ID}/variety/{REVISION}/asset-report.json'
MAX_TRIANGLES = 24000

sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/map_variety'))


def plan(max_triangles=MAX_TRIANGLES, out=None):
    import kit_expander
    authority = json.loads(AUTHORITY.read_text())
    bindings = json.loads(BINDINGS.read_text())
    result = kit_expander.plan(authority['arena']['art']['kit'], set(bindings['materials']), max_triangles)
    shell = kit_expander.shell_plan(authority['arena'])
    structures = kit_expander.structure_plan(authority['arena'])
    pieces = kit_expander.piece_plan(authority['arena'])
    summary = dict(result['summary'])
    summary['authorityShellTriangles'] = shell['authorityTriangles']
    summary['structureBoxes'] = structures['boxes']
    summary['structureTriangles'] = structures['triangles']
    summary['pieceCount'] = pieces['pieces']
    summary['pieceTriangles'] = pieces['triangles']
    summary['nonTriangleWalls'] = shell['nonTriangleWalls']
    summary['expectedMaster'] = str(MASTER.relative_to(ROOT))
    summary['expectedGlb'] = str(EXPORT.relative_to(ROOT))
    if out:
        Path(out).write_text(json.dumps(result, indent=2) + '\n')
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['plan', 'build', 'reopen-export', 'inspect'])
    parser.add_argument('--adapter', default='material_adapter', help='Sol-owned adapter module name')
    parser.add_argument('--max-triangles', type=int, default=MAX_TRIANGLES)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
    if args.action == 'plan':
        print(json.dumps(plan(args.max_triangles), indent=2))
        return
    import kit_build
    if args.action == 'build':
        report = kit_build.build(ROOT, AUTHORITY, BINDINGS, MASTER, EXPORT, REPORT, adapter_name=args.adapter, max_triangles=args.max_triangles)
    elif args.action == 'reopen-export':
        report = kit_build.reopen_export(ROOT, MASTER, EXPORT, REPORT, AUTHORITY)
    else:
        import bpy
        bpy.ops.wm.open_mainfile(filepath=str(MASTER))
        report = {'geometryHash': bpy.context.scene.get('geometry_hash'), 'opened': str(MASTER)}
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
