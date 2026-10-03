"""Stormglass revision-2 authored coastal relief (pure Python, no bpy).

`parts(authority)` converts the art-only revision-2 scenic anchors into real 3D
forms consumed by ``author.py`` and the bounded source tests. The road, barriers,
race and navigation are never touched here: every form is non-traversal scenery
outside the 14 m barrier. Source Y-up (x, y, z) -> Blender Z-up (x, z, -y).
"""
import math

MAP_ID = 'stormglass-causeway'
LAYOUT_REVISION = 2

CLASSES = {
    'seawall': (5, False),
    'grandstand': (4, False),
    'cliff-stair': (4, False),
    'checkpoint-arch': (3, True),
    'lighthouse': (1, True),
    'quay-crane': (3, False),
    'terminal-facade': (3, False),
}

PROBE_CAMERAS = {
    'overview': ((-350, 320, -330), (-35, 0, 5)),
    'terminal': ((-108, 3.4, -133), (-5, 9, -120)),
    'freight-bore': ((150, 3.4, 22), (138, 7, 70)),
    'quay-chicane': ((45, 3.4, 145), (-45, 8, 133)),
    'surgeworks': ((-183, 3.4, 101), (-207, 13, 47)),
    'return-gate': ((-118, 3.4, 11), (-72, 13, -28)),
    'seawall-relief': ((30, 9, 120), (140, 3, 120)),
    'checkpoint-arch': ((-160, 12, 60), (-205, 3, 30)),
}

CLASS_PREFIX = (('seawall', 'seawall'), ('grandstand', 'grandstand'), ('cliff', 'cliff-stair'),
                ('checkpoint-arch', 'checkpoint-arch'), ('lighthouse', 'lighthouse'),
                ('quay-crane', 'quay-crane'), ('terminal-facade', 'terminal-facade'))


def classify(name):
    for prefix, cls in CLASS_PREFIX:
        if prefix in name:
            return cls
    raise ValueError('Unclassified layout part: ' + name)


def _z(sx, sy, sz):
    return (sx, sz, -sy)


def _across(anchor, distance):
    angle = anchor['heading'] + math.pi / 2
    return anchor['x'] + distance * math.cos(angle), anchor['z'] + distance * math.sin(angle)


def _out(anchor, distance):
    return _across(anchor, distance if anchor['lateral'] >= 0 else -distance)


def _box(name, x, z, base_y, w, d, h, heading, material, sector, bevel=0.05):
    cos, sin = math.cos(heading), math.sin(heading)
    corners = []
    for sx in (-1, 1):
        for sy in (0, 1):
            for sz in (-1, 1):
                lx, lz = sx * w / 2, sz * d / 2
                corners.append([x + lx * cos - lz * sin, base_y + sy * h, z + lx * sin + lz * cos])

    def at(sx, sy, sz):
        return corners[(0 if sx < 0 else 1) * 4 + sy * 2 + (0 if sz < 0 else 1)]

    faces = [[at(-1, 0, -1), at(-1, 0, 1), at(1, 0, 1), at(1, 0, -1)],
             [at(-1, 1, -1), at(-1, 1, 1), at(1, 1, 1), at(1, 1, -1)],
             [at(-1, 0, -1), at(-1, 0, 1), at(-1, 1, 1), at(-1, 1, -1)],
             [at(1, 0, -1), at(1, 0, 1), at(1, 1, 1), at(1, 1, -1)],
             [at(-1, 0, -1), at(1, 0, -1), at(1, 1, -1), at(-1, 1, -1)],
             [at(-1, 0, 1), at(1, 0, 1), at(1, 1, 1), at(-1, 1, 1)]]
    return {'op': 'mesh', 'name': name, 'material': material, 'sector': sector,
            'args': ([_z(*c) for c in corners], faces), 'kwargs': {'bevel': bevel}}


def _rib(name, center, inner, outer, depth, start, stop, material, sector, segments=24):
    return {'op': 'curved_rib', 'name': name, 'material': material, 'sector': sector,
            'args': (center, inner, outer, depth, start, stop), 'kwargs': {'segments': segments}}


def parts(authority):
    scenery = authority['art']['revision2']['scenery']
    out = []
    # 1. Seawall retaining modules, five distinct heights with optional buttress.
    for index, a in enumerate(scenery['seawalls']):
        h = a['height']
        out.append(_box(a['id'], a['x'], a['z'], -5, 26, 2.6, h + 5, a['heading'], 'quay-damp-horizontal', 'seawall'))
        out.append(_box(a['id'] + '.coping', a['x'], a['z'], h, 27, 3.4, 0.6, a['heading'], 'salt-limestone', 'seawall'))
        if a['buttress']:
            out.append(_box(a['id'] + '.buttress', a['x'], a['z'], -5, 3.0, 6.0, h + 4, a['heading'], 'basalt-strata', 'seawall'))
    # 2. Terrace grandstands: real stepped tiers with canopy, four sizes.
    for a in scenery['grandstands']:
        for tier in range(a['tiers']):
            ox, oz = _out(a, (tier + 1) * 2.4)
            out.append(_box('%s.tier.%d' % (a['id'], tier), ox, oz, 0, 18 + tier, 2.4, (tier + 1) * 2.0, a['heading'], 'timber-weather' if tier % 2 else 'cobble-sett', 'grandstand'))
        ox, oz = _out(a, (a['tiers'] + 1) * 2.4)
        out.append(_box(a['id'] + '.canopy', ox, oz, a['tiers'] * 2, 20, 8, 0.7, a['heading'], 'slate-shingle', 'grandstand'))
    # 3. Cliff stair switchbacks: alternating flights and landings stepping down.
    for a in scenery['cliffs']:
        for flight in range(a['flights']):
            ox, oz = _out(a, flight * 3.5)
            out.append(_box('%s.flight.%d' % (a['id'], flight), ox, oz, -a['drop'] + flight * 2.0, 12, 3.0, 2.0,
                            a['heading'] + (math.pi / 2 if flight % 2 else 0), 'basalt-strata', 'cliff-stair'))
    # 4. Three distinct checkpoint arches over the existing gates (columns clear of
    #    the 28 m road; superstructure starts above 13 m).
    for a in scenery['gates']:
        for side in (-1, 1):
            ox, oz = _across(a, side * 15.5)
            out.append(_box('%s.column.%d' % (a['id'], side), ox, oz, 0, 2.4, 3.0, 13, a['heading'], 'salt-limestone', 'checkpoint-arch'))
        if a['variant'] == 0:
            out.append(_box(a['id'] + '.lintel', a['x'], a['z'], 13, 33, 4.0, 2.0, a['heading'], 'oxidized-iron', 'checkpoint-arch'))
        elif a['variant'] == 1:
            for side in (-1, 1):
                ox, oz = _across(a, side * 8.5)
                out.append(_box('%s.gable.%d' % (a['id'], side), ox, oz, 13, 17, 4.0, 4.0, a['heading'] + side * 0.45, 'timber-weather', 'checkpoint-arch'))
        else:
            for step in range(3):
                out.append(_box('%s.step.%d' % (a['id'], step), a['x'], a['z'], 13 + step * 1.4, 34 - step * 7, 4.0 - step * 0.6, 1.4, a['heading'], 'ceramic-enamel', 'checkpoint-arch'))
        out.append(_box(a['id'] + '.gantry', a['x'], a['z'], 15.8, 34, 1.2, 1.2, a['heading'], 'ceramic-enamel', 'checkpoint-arch'))
    # 5. Lighthouse hero.
    a = scenery['lighthouse']
    out.append(_box('lighthouse.base', a['x'], a['z'], -4, 9, 9, 6, a['heading'], 'salt-limestone', 'lighthouse'))
    out.append(_box('lighthouse.tower', a['x'], a['z'], 2, 5.5, 5.5, a['height'], a['heading'], 'salt-limestone', 'lighthouse'))
    out.append(_box('lighthouse.tower-upper', a['x'], a['z'], 2 + a['height'] * 0.6, 4.0, 4.0, a['height'] * 0.4, a['heading'], 'ceramic-enamel', 'lighthouse'))
    out.append(_rib('lighthouse.gallery', _z(a['x'], 2 + a['height'] + 0.6, a['z']), 3.2, 4.2, 0.8, 0.0, math.tau, 'oxidized-iron', 'lighthouse', segments=24))
    out.append(_box('lighthouse.lamp', a['x'], a['z'], 2 + a['height'] + 1.2, 3.0, 3.0, 3.4, a['heading'], 'harbour-glass', 'lighthouse'))
    # 6. Dockside quay cranes: portal, cantilever, rail gantry.
    for a in scenery['cranes']:
        for side in (-1, 1):
            ox, oz = _across(a, side * 5.0)
            out.append(_box('%s.leg.%d' % (a['id'], side), ox, oz, 0, 1.2, 1.2, 14, a['heading'], 'oxidized-iron', 'quay-crane'))
        out.append(_box(a['id'] + '.beam', a['x'], a['z'], 14, 12, 2.0, 1.4, a['heading'], 'oxidized-iron', 'quay-crane'))
        out.append(_box(a['id'] + '.boom', a['x'], a['z'], 14.6, a['boom'], 1.4, 1.2, a['heading'] + math.pi / 2, 'ceramic-enamel', 'quay-crane'))
        out.append(_box(a['id'] + '.counterweight', a['x'], a['z'], 10, 3.0, 2.4, 3.0, a['heading'], 'basalt-strata', 'quay-crane'))
    # 7. Varied terminal facades replacing the repeated street-edge modules.
    for a in scenery['facades']:
        out.append(_box(a['id'], a['x'], a['z'], 0, 16 + a['bays'] * 3, 12, 10 + a['variant'] * 3, a['heading'], 'cobble-sett' if a['variant'] % 2 else 'quay-damp-horizontal', 'terminal-facade'))
        out.append(_box(a['id'] + '.cornice', a['x'], a['z'], 10 + a['variant'] * 3, 17 + a['bays'] * 3, 13, 0.7, a['heading'], 'salt-limestone', 'terminal-facade'))
        out.append(_box(a['id'] + '.roof-machinery', a['x'], a['z'], 10.7 + a['variant'] * 3, 5, 4, 3, a['heading'], 'oxidized-iron', 'terminal-facade'))
    return out
