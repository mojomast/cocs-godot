"""Deterministic Blackwater Reclamation Horde arena authoring source.

Run from repository root: python3 tools/godot-horde/blackwater.py
The Blender master/export pass consumes the same block/surface inventory. No
game/source file is generated or changed by this authoring script.
"""
import hashlib
import json
from pathlib import Path

OUT = Path('godot/horde_maps/generated/blackwater-reclamation.json')
NAME = 'Blackwater Reclamation'
ID = 'blackwater-reclamation'
blocks = []
surfaces = []
nav = []


def box(label, x, z, w, d, top, bottom=0, material='shell'):
    blocks.append(dict(id=label, x=x, z=z, w=w, d=d, h=top, baseY=bottom, material=material))


def floor(label, x0, x1, z0, z1, y=0, material='floor'):
    surfaces.append(dict(id=label, material=material, walkable=True,
                         vertices=[[x0, y, z0], [x0, y, z1], [x1, y, z1], [x1, y, z0]],
                         triangles=[[0, 1, 2], [0, 2, 3]]))


def ramp(label, x0, x1, z0, z1, low, high):
    surfaces.append(dict(id=label, material='cut', walkable=True,
                         vertices=[[x0, low, z0], [x0, low, z1],
                                   [x1, high, z1], [x1, high, z0]],
                         triangles=[[0, 1, 2], [0, 2, 3]]))


def ramp_z(label, x0, x1, z0, z1, low, high):
    surfaces.append(dict(id=label, material='cut', walkable=True,
                         vertices=[[x0, low, z0], [x0, high, z1],
                                   [x1, high, z1], [x1, low, z0]],
                         triangles=[[0, 1, 2], [0, 2, 3]]))


def canonical(v):
    if isinstance(v, float) and v.is_integer():
        v = int(v)
    if isinstance(v, list):
        v = [json.loads(canonical(x)) for x in v]
    if isinstance(v, dict):
        v = {k: json.loads(canonical(x)) for k, x in v.items()}
    return json.dumps(v, sort_keys=True, separators=(',', ':'), ensure_ascii=False)


def digest(v):
    return hashlib.sha256(canonical(v).encode()).hexdigest()


# Five reachable ground districts: intake, distribution, settling tanks,
# switching hall and the final spillway bowl. Long axial doors, four side
# routes, and two overhead loops prevent the axial route becoming a kill box.
floor('continuous-drainage-deck', -218, 218, -188, 188)
for name, x in [('intake', -170), ('distribution', -82), ('switchyard', 0),
                ('settling', 82), ('spillway', 170)]:
    for side in [-1, 1]:
        z = side * 142
        box(f'{name}-outer-wall-{side}', x, z, 68, 5, 10, 0, 'enamel')
        box(f'{name}-service-gallery-{side}', x, side * 116, 48, 8, 3.2, 0, 'cut')
    # Hollow machinery court: the diagonal approaches remain open and walkable.
    for side in [-1, 1]:
        box(f'{name}-pump-bank-{side}', x + side * 22, 36, 12, 23, 4, 0, 'shell')
        box(f'{name}-transformer-{side}', x + side * 29, -48, 14, 14, 5.5, 0, 'accent')
    box(f'{name}-control-kiosk', x - 15, -112, 15, 13, 4.2, 0, 'enamel')

# Borders include physical breaks for the northern/southern drainage bypasses.
for x in [-216, 216]:
    box(f'perimeter-x-{x}', x, 0, 4, 374, 12)
for z in [-186, 186]:
    box(f'perimeter-z-{z}', 0, z, 432, 4, 12)
for x in [-126, -42, 42, 126]:
    for side in [-1, 1]:
        box(f'bulkhead-{x}-{side}', x, side * 111, 5, 95, 11, 0, 'enamel')
    box(f'bulkhead-{x}-central-left', x, -28, 5, 34, 11, 0, 'enamel')
    box(f'bulkhead-{x}-central-right', x, 28, 5, 34, 11, 0, 'enamel')

# Sheltered perimeter service tunnels, with roof above player clearance. The
# roof is a real world collider but is not a source floor: no invisible second
# story can alter floorAt or strand NPCs beneath it.
for side in [-1, 1]:
    z = side * 169
    box(f'drainage-tunnel-roof-{side}', 0, z, 410, 16, 10.5, 8.5, 'cut')
    for x in [-204, -156, -108, -60, -12, 36, 84, 132, 180, 204]:
        box(f'drainage-tunnel-column-{side}-{x}', x, side * 177, 1.5, 1.5, 8.5, 0, 'trim')

# Repeating reservoirs use substantial playable piers and walk-around channels.
for x in [-170, -82, 0, 82, 170]:
    for z in [-82, 78]:
        box(f'pier-{x}-{z}-east', x + 24, z, 6, 30, 2.5, 0, 'trim')
        box(f'pier-{x}-{z}-west', x - 24, z, 6, 30, 2.5, 0, 'trim')

# Upper service gantries are genuine source walkable decks and Godot colliders.
# Their ends meet shallow sloped walkable ramps; nav points sample each surface.
for i, x in enumerate([-170, -82, 0, 82, 170]):
    floor(f'gantry-{i}', x - 28, x + 28, -16, -8, 5.0, 'cut')
    ramp(f'gantry-ramp-west-{i}', x - 48, x - 28, -16, -8, 0, 5)
    ramp(f'gantry-ramp-east-{i}', x + 28, x + 48, -16, -8, 5, 0)
    ramp_z(f'gantry-crossing-south-{i}', x - 4, x + 4, -36, -16, 0, 5)
    ramp_z(f'gantry-crossing-north-{i}', x - 4, x + 4, -8, 12, 5, 0)
    # Avoid invisible blocking legs under the deck: posts are narrow and skirted.
    for px in [x - 27, x + 27]:
        box(f'gantry-post-{i}-{px}', px, -12, 1.2, 1.2, 5.0, 0, 'trim')
    for edge in [-16, -8]:
        for side in [-1, 1]:
            box(f'gantry-guard-{i}-{edge}-{side}', x + side * 16.5, edge, 23, 0.3, 7.0, 5.0, 'accent')
    height = 18 + i * 3
    for side in [-1, 1]:
        box(f'{i}-tower-{side}', x + side * 38, 104, 5, 5, height, 0, 'shell')
    for z in [-57, -5, 57]:
        for side in [-1, 1]:
            box(f'{i}-arch-{z}-{side}', x + side * 34, z, 2, 2, 11, 0, 'trim')
    for side in [-1, 1]:
        for z in [-82, 78]:
            box(f'{i}-settling-tank-{side}-{z}', x + side * 34, z, 14, 14, 4.2, 0, 'shell')

for i, (start, end) in enumerate([(-142, -110), (-54, -28), (28, 54), (110, 142)]):
    floor(f'gantry-link-{i}', start, end, -16, -8, 5.0, 'cut')
    for edge in [-16, -8]:
        box(f'gantry-link-guard-{i}-{edge}', (start+end)/2, edge, end-start, 0.3, 7.0, 5.0, 'accent')

for key, x, z in [('north', -170, 78), ('south', -82, -78), ('pump', 0, 78), ('valve', 170, -82)]:
    for side in [-1, 1]:
        box(f'{key}-mount-{side}', x + side * 7, z, 2, 2, 3.4, 0, 'accent')

# Source automatically supplies its sparse 6 m nextGen navigation grid. Extra
# hints are needed only at ramp lips and mission anchors, rather than doubling
# the graph across a 440 × 380 playable floor.
for x in [-170, -82, 0, 82, 170]:
    for offset in [-48, -42, -36, -30, -28, -22, -16, -10, -4, 2, 8, 14, 20, 26, 28, 32, 38, 44, 48]:
        nav.append([x + offset, -12])
    for z in range(-36, 13, 3):
        nav.append([x, z])
nav.extend([[-170, 78], [-82, -78], [0, 78], [170, -82]])

spawns = [[-183, 0], [-179, 18], [-179, -18]]
stage = [
    dict(id='A', arrival=dict(minX=-207, maxX=-146, minZ=-26, maxZ=26),
         humanSpawns=spawns, enemySpawns=[[-200, 58], [-144, 55], [-202, -70], [-160, -95], [-177, 104]]),
    dict(id='B', arrival=dict(minX=-25, maxX=25, minZ=-25, maxZ=25),
         humanSpawns=[[-12, 1], [12, 1]], enemySpawns=[[-32, 60], [34, 64], [-32, -67], [34, -67], [0, 97]]),
    dict(id='C', arrival=dict(minX=151, maxX=193, minZ=-30, maxZ=30),
         humanSpawns=[[166, 0], [182, 0]], enemySpawns=[[150, 55], [190, 55], [140, -65], [205, -65], [170, 105]]),
]
gates = [dict(id='floodgate-west', x=-42, z=0, w=5, d=20, h=12, baseY=0, material='accent'),
         dict(id='floodgate-east', x=126, z=0, w=5, d=20, h=12, baseY=0, material='accent')]
plan = dict(version=1, initialStage='A', stages=stage, gates=gates, transitions=[
    dict(afterWave=3, **{'from':'A'}, to='B', open=['floodgate-west'], close=[]),
    dict(afterWave=6, **{'from':'B'}, to='C', open=['floodgate-east'], close=[]),
])
arena = dict(id=ID, name=NAME, bounds=dict(minX=-220, maxX=220, minZ=-190, maxZ=190),
             voidY=-16, ceilingY=38, raised=False, nextGen=True, spawns=spawns,
             teamSpawns={'0':spawns, '1':stage[0]['enemySpawns']}, navNodes=nav,
             pickups=[['health', -180, -35], ['armor', -173, 42], ['ammo', -89, 0],
                      ['health', 0, -39], ['armor', 0, 46], ['ammo', 84, 0],
                      ['health', 171, 42], ['rocket', 172, -42]],
             blocks=blocks, terrain=dict(maxSlope=0.7, surfaces=surfaces, walls=[]),
             hordeStagePlan=plan)
document = dict(schemaVersion=1, id=ID, name=NAME, mode='horde', arena=arena,
                palette=['263b48', '456579', 'c9a463', 'e6e8d6'], art=[], routes=[], cameras=[],
                landmarks=[], presentation={'stages':{'A':'INTAKE','B':'SWITCHYARD','C':'SPILLWAY'}},
                provenance={'author':'Horde expansion','generator':'tools/godot-horde/blackwater.py'},
                planHash=digest(plan), geometryHash=digest(arena))
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(document, separators=(',', ':')) + '\n')
print(f'{ID}: {len(blocks)} colliders, {len(surfaces)} surfaces, {len(nav)} nav hints; {OUT}')
