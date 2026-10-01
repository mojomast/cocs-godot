"""Static recipe-to-export audit; safe to run while Godot is reserved elsewhere."""
import json
import math
import struct
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RECIPES = ROOT / 'godot/campaign/generated'
ASSETS = ROOT / 'godot/campaign/art/structures'
IDS = ('rootfall-verge', 'siltwake-crossing', 'emberline-ascent', 'crown-array')


def style(index, name):
    if index == 0:
        return 'relay' if 'Fallen relay' in name or 'gate' in name else 'outpost'
    if index == 1:
        return 'abutment' if name.startswith('bridgeworks') else 'pump'
    if index == 2:
        return 'uplink' if name.startswith('basalt') else 'refinery'
    return 'receiver' if name.startswith('crown') else 'gate'


def glb_cost(path):
    with path.open('rb') as f:
        assert f.read(4) == b'glTF', path
        f.read(8)
        length, _ = struct.unpack('<II', f.read(8))
        scene = json.loads(f.read(length))
    assert 3 <= len(scene['materials']) <= 5, path
    triangles = sum(scene['accessors'][primitive['indices']]['count'] // 3
                    for mesh in scene['meshes'] for primitive in mesh['primitives'])
    return len(scene['materials']), triangles


for map_id in IDS:
    recipe = json.loads((RECIPES / f'{map_id}.json').read_text())
    terrain = recipe['arena']['terrain']['surfaces']
    cell = round(terrain[0]['vertices'][1][2] - terrain[0]['vertices'][0][2])
    assert cell in (2, 4)
    bounds = recipe['arena']['bounds']
    heights = {(round(x), round(z)): y for surface in terrain for x, y, z in surface['vertices']}

    def height_at(x, z):
        ix = min(math.floor((x-bounds['minX'])/cell)*cell+bounds['minX'], bounds['maxX']-cell)
        iz = min(math.floor((z-bounds['minZ'])/cell)*cell+bounds['minZ'], bounds['maxZ']-cell)
        u, v = (x-ix)/cell, (z-iz)/cell
        a, b = heights[ix, iz], heights[ix, iz+cell]
        c, d = heights[ix+cell, iz+cell], heights[ix+cell, iz]
        return a+(c-b)*u+(b-a)*v if v >= u else a+(d-a)*u+(c-d)*v

    groups = set()
    used = Counter()
    segments_total = 0
    max_forest_height = 0
    for block in recipe['arena']['blocks']:
        if block['material'] == 'rock':
            continue
        kind = style(recipe['campaign']['index'], block['id'])
        exposed = min(block['h']-block['baseY'], max(1, block['h']-height_at(block['x'], block['z'])+.35))
        count = 1 if kind in ('relay', 'outpost') else max(1, math.ceil(exposed/5))
        if kind in ('relay', 'outpost'):
            max_forest_height = max(max_forest_height, exposed)
        for i in range(count):
            profile = 'top' if i == count-1 else 'base' if i == 0 else 'shaft'
            used[kind, profile] += 1
            cell_x, cell_z = math.floor(block['x']/48), math.floor(block['z']/48)
            for lod in (0, 1):
                groups.add((kind, profile, lod, cell_x, cell_z))
            segments_total += 1
    source_keys = {(kind, profile, lod) for kind, profile, lod, _, _ in groups}
    material_counts = {}
    for kind, profile, lod in source_keys:
        path = ASSETS / f'{kind}-{profile}-{lod}.glb'
        assert path.is_file(), f'{map_id} missing {path}'
        material_counts[kind, profile, lod] = glb_cost(path)
    batch_count = sum(material_counts[kind, profile, lod][0] for kind, profile, lod, _, _ in groups)
    source_triangles = sum(cost[1] for cost in material_counts.values())
    assert batch_count < 240, (map_id, batch_count)
    assert source_triangles < 32000, (map_id, source_triangles)
    assert max_forest_height < 5.0, (map_id, max_forest_height)
    print(map_id, 'styles/profiles=', sorted(used.items()), 'segments=', segments_total,
          'two-LOD-groups=', len(groups), 'estimated-material-batches=', batch_count,
          'source-keys=', len(source_keys), 'loaded-source-tris=', source_triangles)
