"""Helix Conservatory revision-3 Blender builder entry point (grant-only).

    blender -b -t 1 --python-exit-code 1 --python asset_author.py -- plan
    blender -b -t 1 --python-exit-code 1 --python asset_author.py -- build --adapter=material_adapter
    blender -b -t 1 --python-exit-code 1 --python asset_author.py -- reopen-export

`plan` is pure Python and runs without Blender/ bpy. `build`/`reopen-export`
require the explicit heavy-slot grant and the delivered Sol material adapter; no
accepted master, generated JSON or runtime GLB is overwritten.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
MAP_ID = 'helix-conservatory'
REVISION = 3
AUTHORITY = ROOT / f'port/new-maps/{MAP_ID}/variety/revision-{REVISION}/authority.json'
BINDINGS = HERE / 'variety_bindings.json'
MASTER = HERE / f'masters/revision-{REVISION}/{MAP_ID}.blend'
EXPORT = ROOT / f'port/new-maps/{MAP_ID}/variety/revision-{REVISION}/{MAP_ID}.glb'
REPORT = ROOT / f'port/new-maps/{MAP_ID}/variety/revision-{REVISION}/asset-report.json'
MAX_TRIANGLES = 24000

sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/map_variety'))


def plan(max_triangles=MAX_TRIANGLES, out=None):
    import kit_expander
    authority = json.loads(AUTHORITY.read_text())
    bindings = json.loads(BINDINGS.read_text())
    result = kit_expander.plan(authority['arena']['art']['kit'], set(bindings['materials']), max_triangles)
    shell = kit_expander.shell_plan(authority['arena'])
    summary = dict(result['summary'])
    summary['authorityShellTriangles'] = shell['authorityTriangles']
    summary['nonTriangleWalls'] = shell['nonTriangleWalls']
    summary['expectedMaster'] = str(MASTER.relative_to(ROOT))
    summary['expectedGlb'] = str(EXPORT.relative_to(ROOT))
    summary['maxTrianglesPerBatch'] = max_triangles
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
