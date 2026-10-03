"""Source-only checks for the map-variety kit expander and builders.

Runs with plain `python3`; no bpy, Blender, Godot or network. Covers the three
candidate authorities when their generated JSON exists, and asserts the shared
adapter hook fails loudly while it is undelivered.
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]

sys.path.insert(0, str(HERE))
import kit_expander  # noqa: E402
from material_adapter_contract import load_adapter, MissingAdapter  # noqa: E402

MAPS = {
    'helix-conservatory': ('port/new-maps/helix-conservatory/variety/revision-3', 'tools/godot-multiplayer/new-maps/helix-conservatory/variety_bindings.json'),
    'parallax-observatory': ('port/new-maps/parallax-observatory/variety/districts-v3', 'tools/godot-multiplayer/new-maps/parallax-observatory/revisions/districts-v3/variety_bindings.json'),
    'vesper-viaduct': ('port/new-maps/vesper-viaduct/variety/urban-v2', 'tools/godot-multiplayer/new-maps/vesper-viaduct/revisions/urban-v2/variety_bindings.json'),
}


def check(map_id, out_dir, bindings_path):
    authority_path = ROOT / out_dir / 'authority.json'
    if not authority_path.is_file():
        print('SKIP', map_id, '(no generated authority)')
        return
    authority = json.loads(authority_path.read_text())
    arena = authority['arena']
    bindings = json.loads((ROOT / bindings_path).read_text())
    allowed = set(bindings['materials'])

    shell = kit_expander.shell_plan(arena)
    assert shell['nonTriangleWalls'] == 0, f'{map_id}: untriangulated wall'
    for wall in arena['terrain']['walls']:
        assert len(wall.get('vertices', [])) == 3, f'{map_id}: wall not a triangle'

    result = kit_expander.plan(arena['art']['kit'], allowed)
    assert result['summary']['withinBudget'], f'{map_id}: kit over triangle budget'
    for entry in result['ops']:
        assert entry['material'] in allowed, f'{map_id}: unbound {entry["material"]}'
        assert all(abs(c) < 1e6 for c in entry['at']), f'{map_id}: wild coordinate'

    structures = kit_expander.structure_plan(arena)
    pieces = kit_expander.piece_plan(arena)
    for bucket in list(structures['buckets']) + list(pieces['buckets']):
        assert bucket in allowed, f'{map_id}: unbound structure material {bucket}'
    total = kit_expander.scene_summary(arena, allowed)['sourceSceneTriangles']
    print('OK', map_id, 'ops', result['summary']['ops'], 'kitTri', result['summary']['triangles'],
          'shellTri', shell['authorityTriangles'], 'totalTri', total, 'batches', result['summary']['batches'])


def check_unknown_class_rejected():
    try:
        kit_expander.expand_kit([{'id': 'x', 'class': 'nope', 'material': 'm', 'sector': 's', 'at': [0, 0, 0]}], {'m'})
    except ValueError:
        return
    raise AssertionError('unknown kit class was not rejected')


def check_adapter_hook_reports_missing():
    try:
        load_adapter('__deliberately_missing_map_variety_adapter__')
    except MissingAdapter as error:
        assert 'load_materials' in str(error)
        return
    raise AssertionError('adapter hook did not report missing')


def main():
    check_unknown_class_rejected()
    check_adapter_hook_reports_missing()
    for map_id, (out_dir, bindings_path) in MAPS.items():
        check(map_id, out_dir, bindings_path)
    print('map-variety kit source checks passed')


if __name__ == '__main__':
    main()
