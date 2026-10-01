"""Read-only Blackwater GLB/collision recipe budget and ground alignment checks."""
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[2]
glb = root / 'godot/horde_maps/art/blackwater-reclamation.glb'
master = root / 'tools/godot-horde/masters/blackwater-reclamation.blend'
recipe = json.loads((root / 'godot/horde_maps/generated/blackwater-reclamation.json').read_text())
b = glb.read_bytes()
assert b[:4] == b'glTF' and struct.unpack_from('<I', b, 4)[0] == 2
assert struct.unpack_from('<I', b, 8)[0] == len(b)
chunk_size, kind = struct.unpack_from('<I4s', b, 12)
assert kind == b'JSON'
d = json.loads(b[20:20 + chunk_size])
assert len(d['materials']) == 5 and len(d['meshes']) == 5
assert set(m['name'] for m in d['meshes']) == {
    'Blackwater_' + key for key in ['steel', 'oxidized', 'concrete', 'hazard', 'lamp']}
triangles = 0
extent = [float('inf'), float('inf'), float('inf')]
maximum = [float('-inf'), float('-inf'), float('-inf')]
for mesh in d['meshes']:
    assert len(mesh['primitives']) == 1
    p = mesh['primitives'][0]
    assert p.get('mode', 4) == 4 and p['material'] < len(d['materials'])
    vertices = d['accessors'][p['attributes']['POSITION']]
    indices = d['accessors'][p['indices']]
    assert indices['count'] % 3 == 0 and vertices['count'] > 20
    triangles += indices['count'] // 3
    extent = [min(a, b) for a, b in zip(extent, vertices['min'])]
    maximum = [max(a, b) for a, b in zip(maximum, vertices['max'])]
arena = recipe['arena']
assert arena['bounds'] == dict(minX=-220, maxX=220, minZ=-190, maxZ=190)
assert -220 <= extent[0] < -160 and 160 < maximum[0] <= 220
assert -190 <= extent[2] < -80 and 80 < maximum[2] <= 190
assert -0.01 <= extent[1] <= 0.01 and 20 <= maximum[1] <= 38
assert 10000 < triangles < 25000 and len(arena['blocks']) < 300
assert 20 <= len(arena['terrain']['surfaces']) <= 60
assert master.exists() and 100_000 < master.stat().st_size < 30_000_000
assert len(b) < 4_000_000
print(json.dumps(dict(ok=True, glb_bytes=len(b), master_bytes=master.stat().st_size,
                      meshes=len(d['meshes']), materials=len(d['materials']), triangles=triangles,
                      bounds=[extent, maximum], colliders=len(arena['blocks']),
                      walkable_surfaces=len(arena['terrain']['surfaces']), nav_hints=len(arena['navNodes']))))
