"""Stormglass revision-2 authored coastal relief (pure Python, no bpy).

Forms are authored in the source Y-up frame in the base road convention:
``heading = atan2(tangent.x, tangent.z)`` so the road tangent is
``u = (sin h, cos h)`` and across is ``a = (cos h, -sin h)``. Box sizes are
``(across, along, height)``. Low decorative masses clear all actual road
triangles; overhead checkpoint arches still frame the existing gates.
"""
import math

import geometry as g
import road

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

# Conservative (half_along, half_across) footprints for corridor-safe placement.
FOOTPRINT = {
    'seawall': (14.0, 3.5),
    'grandstand': (11.0, 21.0),
    'cliff-stair': (7.0, 20.0),
    'checkpoint-arch': (2.0, 18.0),
    'lighthouse': (5.0, 5.0),
    'quay-crane': (7.0, 10.0),
    'terminal-facade': (15.0, 7.0),
}


def classify(name):
    for prefix, cls in CLASS_PREFIX:
        if prefix in name:
            return cls
    raise ValueError('Unclassified layout part: ' + name)


def _across(anchor, distance):
    return (anchor['x'] + distance * math.cos(anchor['heading']),
            anchor['z'] - distance * math.sin(anchor['heading']))


def _out(anchor, distance):
    return _across(anchor, -distance if anchor['lateral'] >= 0 else distance)


def _box(name, cx, cz, base_y, across, along, height, heading, material, sector, bevel=0.05):
    return g.box_mesh_src(name, (cx, base_y + height / 2, cz), (across, along, height),
                          heading, material, sector, bevel=bevel)


def parts(authority):
    scenery = authority['art']['revision2']['scenery']
    quads = road.road_polygons(authority)
    placed = {}

    def place(anchor):
        if anchor['id'] not in placed:
            hx, hz = road.safe_place(anchor, *FOOTPRINT[anchor['cls']], quads)
            placed[anchor['id']] = {**anchor, 'anchorX': anchor['x'], 'anchorZ': anchor['z'], 'x': hx, 'z': hz}
        return placed[anchor['id']]

    out = []
    # 1. Seawall retaining modules, five distinct heights with optional buttress.
    for a in scenery['seawalls']:
        a = place(a)
        h = a['height']
        out.append(_box(a['id'], a['x'], a['z'], -5, 2.6, 26, h + 5, a['heading'], 'quay-damp-horizontal', 'seawall'))
        out.append(_box(a['id'] + '.coping', a['x'], a['z'], h, 3.4, 27, 0.6, a['heading'], 'salt-limestone', 'seawall'))
        if a['buttress']:
            out.append(_box(a['id'] + '.buttress', a['x'], a['z'], -5, 6.0, 3.0, h + 4, a['heading'], 'basalt-strata', 'seawall'))
    # 2. Terrace grandstands: stepped tiers with canopy, four sizes.
    for a in scenery['grandstands']:
        a = place(a)
        for tier in range(a['tiers']):
            ox, oz = _out(a, (tier + 1) * 2.4)
            out.append(_box('%s.tier.%d' % (a['id'], tier), ox, oz, 0, 2.4, 18 + tier, (tier + 1) * 2.0, a['heading'], 'timber-weather' if tier % 2 else 'cobble-sett', 'grandstand'))
        ox, oz = _out(a, (a['tiers'] + 1) * 2.4)
        out.append(_box(a['id'] + '.canopy', ox, oz, a['tiers'] * 2, 8, 20, 0.7, a['heading'], 'slate-shingle', 'grandstand'))
    # 3. Cliff stair switchbacks: alternating flights stepping down.
    for a in scenery['cliffs']:
        a = place(a)
        for flight in range(a['flights']):
            ox, oz = _out(a, flight * 3.5)
            out.append(_box('%s.flight.%d' % (a['id'], flight), ox, oz, -a['drop'] + flight * 2.0, 3.0, 12, 2.0,
                            a['heading'] + (math.pi / 2 if flight % 2 else 0), 'basalt-strata', 'cliff-stair'))
    # 4. Three distinct checkpoint arches (whole gatehouses clear of the corridor).
    for a in scenery['gates']:
        # Columns are offset beyond the barrier/camera corridor; their arched
        # header remains above driving clearance over the true gate centre.
        for side in (-1, 1):
            ox, oz = _across(a, side * 20.5)
            out.append(_box('%s.column.%d' % (a['id'], side), ox, oz, 0, 3.0, 2.4, 13, a['heading'], 'salt-limestone', 'checkpoint-arch'))
        out.append(g.arch_mesh_src('%s.arch' % a['id'], (a['x'], a['z']), 13.0, 19.0, 2.0, 4.0, a['heading'], 'oxidized-iron', 'checkpoint-arch'))
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
    # 5. Lighthouse hero (horizontal gallery ring).
    a = place(scenery['lighthouse'])
    out.append(_box('lighthouse.base', a['x'], a['z'], -4, 9, 9, 6, a['heading'], 'salt-limestone', 'lighthouse'))
    out.append(_box('lighthouse.tower', a['x'], a['z'], 2, 5.5, 5.5, a['height'], a['heading'], 'salt-limestone', 'lighthouse'))
    out.append(_box('lighthouse.tower-upper', a['x'], a['z'], 2 + a['height'] * 0.6, 4.0, 4.0, a['height'] * 0.4, a['heading'], 'ceramic-enamel', 'lighthouse'))
    out.append(g.ring_mesh_src('lighthouse.gallery', (a['x'], 2 + a['height'] + 0.6, a['z']), 3.2, 4.2, 0.8, 'oxidized-iron', 'lighthouse'))
    out.append(_box('lighthouse.lamp', a['x'], a['z'], 2 + a['height'] + 1.2, 3.0, 3.0, 3.4, a['heading'], 'harbour-glass', 'lighthouse'))
    # 6. Dockside quay cranes: portal, cantilever, rail gantry.
    for a in scenery['cranes']:
        a = place(a)
        for side in (-1, 1):
            ox, oz = _across(a, side * 5.0)
            out.append(_box('%s.leg.%d' % (a['id'], side), ox, oz, 0, 1.2, 1.2, 14, a['heading'], 'oxidized-iron', 'quay-crane'))
        out.append(_box(a['id'] + '.beam', a['x'], a['z'], 14, 12, 2.0, 1.4, a['heading'], 'oxidized-iron', 'quay-crane'))
        out.append(_box(a['id'] + '.boom', a['x'], a['z'], 14.6, a['boom'], 1.4, 1.2, a['heading'], 'ceramic-enamel', 'quay-crane'))
        out.append(_box(a['id'] + '.counterweight', a['x'], a['z'], 10, 3.0, 2.4, 3.0, a['heading'], 'basalt-strata', 'quay-crane'))
    # 7. Varied terminal facades replacing the repeated street-edge modules.
    for a in scenery['facades']:
        a = place(a)
        height = 10 + a['variant'] * 3
        out.append(_box(a['id'], a['x'], a['z'], 0, 12, 16 + a['bays'] * 3, height, a['heading'], 'cobble-sett' if a['variant'] % 2 else 'quay-damp-horizontal', 'terminal-facade'))
        out.append(_box(a['id'] + '.cornice', a['x'], a['z'], height, 13, 17 + a['bays'] * 3, 0.7, a['heading'], 'salt-limestone', 'terminal-facade'))
        out.append(_box(a['id'] + '.roof-machinery', a['x'], a['z'], height + 0.7, 4, 5, 3, a['heading'], 'oxidized-iron', 'terminal-facade'))
    intrusions = [spec['name'] for spec in out if road.low_geometry_conflicts(spec, quads)]
    if intrusions:
        raise ValueError('Coastal meshes intrude into driving/camera corridor: ' + ', '.join(intrusions))
    return out
