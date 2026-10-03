"""Stormglass revision-2 authored coastal relief (pure Python, no bpy).

Every form is authored in the **source Y-up** frame and validated by
``geometry.validate_spec``. All scenery is non-traversal and sits outside the
14 m barrier; the 28 m road and its race/navigation are never touched.
"""
import math

import geometry as g

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


def _across(anchor, distance):
    angle = anchor['heading'] + math.pi / 2
    return anchor['x'] + distance * math.cos(angle), anchor['z'] + distance * math.sin(angle)


def _out(anchor, distance):
    return _across(anchor, distance if anchor['lateral'] >= 0 else -distance)


def parts(authority):
    scenery = authority['art']['revision2']['scenery']
    out = []
    # 1. Seawall retaining modules, five distinct heights with optional buttress.
    for a in scenery['seawalls']:
        h = a['height']
        out.append(g.box_mesh_src(a['id'], (a['x'], (h - 5) / 2, a['z']), (26, 2.6, h + 5), a['heading'], 'quay-damp-horizontal', 'seawall'))
        out.append(g.box_mesh_src(a['id'] + '.coping', (a['x'], h + 0.3, a['z']), (27, 3.4, 0.6), a['heading'], 'salt-limestone', 'seawall'))
        if a['buttress']:
            out.append(g.box_mesh_src(a['id'] + '.buttress', (a['x'], (h - 1) / 2, a['z']), (3.0, 6.0, h + 4), a['heading'], 'basalt-strata', 'seawall'))
    # 2. Terrace grandstands: stepped tiers with canopy, four sizes.
    for a in scenery['grandstands']:
        for tier in range(a['tiers']):
            ox, oz = _out(a, (tier + 1) * 2.4)
            out.append(g.box_mesh_src('%s.tier.%d' % (a['id'], tier), (ox, (tier + 1), oz), (18 + tier, 2.4, (tier + 1) * 2.0), a['heading'], 'timber-weather' if tier % 2 else 'cobble-sett', 'grandstand'))
        ox, oz = _out(a, (a['tiers'] + 1) * 2.4)
        out.append(g.box_mesh_src(a['id'] + '.canopy', (ox, a['tiers'] * 2 + 0.35, oz), (20, 8, 0.7), a['heading'], 'slate-shingle', 'grandstand'))
    # 3. Cliff stair switchbacks: alternating flights stepping down.
    for a in scenery['cliffs']:
        for flight in range(a['flights']):
            ox, oz = _out(a, flight * 3.5)
            out.append(g.box_mesh_src('%s.flight.%d' % (a['id'], flight), (ox, -a['drop'] + flight * 2.0 + 1.0, oz), (12, 3.0, 2.0), a['heading'] + (math.pi / 2 if flight % 2 else 0), 'basalt-strata', 'cliff-stair'))
    # 4. Three distinct checkpoint arches over the existing gates.
    for a in scenery['gates']:
        for side in (-1, 1):
            ox, oz = _across(a, side * 16.6)
            out.append(g.box_mesh_src('%s.column.%d' % (a['id'], side), (ox, 6.5, oz), (2.4, 3.0, 13), a['heading'], 'salt-limestone', 'checkpoint-arch'))
        out.append(g.arch_mesh_src('%s.arch' % a['id'], (a['x'], a['z']), 13.0, 15.5, 2.0, 4.0, a['heading'], 'oxidized-iron', 'checkpoint-arch'))
        if a['variant'] == 0:
            out.append(g.box_mesh_src(a['id'] + '.lintel', (a['x'], 14, a['z']), (33, 4.0, 2.0), a['heading'], 'oxidized-iron', 'checkpoint-arch'))
        elif a['variant'] == 1:
            for side in (-1, 1):
                ox, oz = _across(a, side * 8.5)
                out.append(g.box_mesh_src('%s.gable.%d' % (a['id'], side), (ox, 15.0, oz), (17, 4.0, 4.0), a['heading'] + side * 0.45, 'timber-weather', 'checkpoint-arch'))
        else:
            for step in range(3):
                out.append(g.box_mesh_src('%s.step.%d' % (a['id'], step), (a['x'], 13.7 + step * 1.4, a['z']), (34 - step * 7, 4.0 - step * 0.6, 1.4), a['heading'], 'ceramic-enamel', 'checkpoint-arch'))
        out.append(g.box_mesh_src(a['id'] + '.gantry', (a['x'], 16.4, a['z']), (34, 1.2, 1.2), a['heading'], 'ceramic-enamel', 'checkpoint-arch'))
    # 5. Lighthouse hero (horizontal gallery ring).
    a = scenery['lighthouse']
    out.append(g.box_mesh_src('lighthouse.base', (a['x'], -1, a['z']), (9, 9, 6), a['heading'], 'salt-limestone', 'lighthouse'))
    out.append(g.box_mesh_src('lighthouse.tower', (a['x'], 2 + a['height'] / 2, a['z']), (5.5, 5.5, a['height']), a['heading'], 'salt-limestone', 'lighthouse'))
    out.append(g.box_mesh_src('lighthouse.tower-upper', (a['x'], 2 + a['height'] * 0.8, a['z']), (4.0, 4.0, a['height'] * 0.4), a['heading'], 'ceramic-enamel', 'lighthouse'))
    out.append(g.ring_mesh_src('lighthouse.gallery', (a['x'], 2 + a['height'] + 0.6, a['z']), 3.2, 4.2, 0.8, 'oxidized-iron', 'lighthouse'))
    out.append(g.box_mesh_src('lighthouse.lamp', (a['x'], 2 + a['height'] + 2.9, a['z']), (3.0, 3.0, 3.4), a['heading'], 'harbour-glass', 'lighthouse'))
    # 6. Dockside quay cranes: portal, cantilever, rail gantry.
    for a in scenery['cranes']:
        for side in (-1, 1):
            ox, oz = _across(a, side * 5.0)
            out.append(g.box_mesh_src('%s.leg.%d' % (a['id'], side), (ox, 7.0, oz), (1.2, 1.2, 14), a['heading'], 'oxidized-iron', 'quay-crane'))
        out.append(g.box_mesh_src(a['id'] + '.beam', (a['x'], 14.7, a['z']), (12, 2.0, 1.4), a['heading'], 'oxidized-iron', 'quay-crane'))
        out.append(g.box_mesh_src(a['id'] + '.boom', (a['x'], 15.3, a['z']), (a['boom'], 1.4, 1.2), a['heading'] + math.pi / 2, 'ceramic-enamel', 'quay-crane'))
        out.append(g.box_mesh_src(a['id'] + '.counterweight', (a['x'], 11.5, a['z']), (3.0, 2.4, 3.0), a['heading'], 'basalt-strata', 'quay-crane'))
    # 7. Varied terminal facades replacing the repeated street-edge modules.
    for a in scenery['facades']:
        height = 10 + a['variant'] * 3
        out.append(g.box_mesh_src(a['id'], (a['x'], height / 2, a['z']), (16 + a['bays'] * 3, 12, height), a['heading'], 'cobble-sett' if a['variant'] % 2 else 'quay-damp-horizontal', 'terminal-facade'))
        out.append(g.box_mesh_src(a['id'] + '.cornice', (a['x'], height + 0.35, a['z']), (17 + a['bays'] * 3, 13, 0.7), a['heading'], 'salt-limestone', 'terminal-facade'))
        out.append(g.box_mesh_src(a['id'] + '.roof-machinery', (a['x'], height + 2.2, a['z']), (5, 4, 3), a['heading'], 'oxidized-iron', 'terminal-facade'))
    return out
