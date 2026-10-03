"""Abyssal revision-2 authored geometry layout (pure Python, no bpy).

Every spec is authored in the **source Y-up** frame and validated by
``geometry.validate_spec`` (faces are outward index tuples, arches/rings have
explicit orientation). ``author.py`` converts once to Blender Z-up.
"""
import math

import geometry as g

MAP_ID = 'abyssal-pressureworks'
LAYOUT_REVISION = 2

CLASSES = {
    'pressure-vault': (3, True),
    'manifold-valve-tree': (3, True),
    'wet-service-cave': (2, False),
    'pipe-bridge': (4, False),
    'observation-blister': (3, True),
    'equalizer-crown': (1, True),
    'reef-buttress': (5, False),
}

PROBE_CAMERAS = {
    'overview': ((-178, 182, 174), (0, 10, 0)),
    'terraced-labs': ((-70, 10, 60), (-30, 12, 40)),
    'pump-energy': ((-20, 16, 5), (20, 20, -5)),
    'residential': ((-70, 26, -70), (-30, 28, -80)),
    'service-terrace-sw': ((-94, 8, -86), (-94, 7, -101)),
    'equalizer-crown': ((23, 12, -11), (44, 24, 8)),
    'reef-window': ((-94, 8, -70), (-94, 9, -101)),
}

CLASS_PREFIX = (('equalizer', 'equalizer-crown'), ('service-cave', 'wet-service-cave'),
                ('pipe-bridge', 'pipe-bridge'), ('manifold', 'manifold-valve-tree'),
                ('valve-', 'manifold-valve-tree'), ('blister', 'observation-blister'),
                ('reef', 'reef-buttress'), ('vault', 'pressure-vault'),
                ('pressure-rib', 'pressure-vault'), ('vessel-cap', 'pressure-vault'),
                ('cap-collar', 'pressure-vault'), ('ridge-beam', 'pressure-vault'),
                ('habitat', 'pressure-vault'), ('hab-vent', 'pressure-vault'),
                ('hab-crown', 'pressure-vault'))


def classify(name):
    for prefix, cls in CLASS_PREFIX:
        if prefix in name:
            return cls
    raise ValueError('Unclassified layout part: ' + name)


def _poly8(x, y, z, w, d, c=7.0, scale=1.0):
    """Octagon in the source XZ plane at height y; scale preserves centre and W:D."""
    ring = [[x + a, y, z + b] for a, b in (
        (-w / 2 + c, -d / 2), (w / 2 - c, -d / 2), (w / 2, -d / 2 + c), (w / 2, d / 2 - c),
        (w / 2 - c, d / 2), (-w / 2 + c, d / 2), (-w / 2, d / 2 - c), (-w / 2, -d / 2 + c))]
    if scale != 1.0:
        ring = [[x + (px - x) * scale, py, z + (pz - z) * scale] for px, py, pz in ring]
    return ring


def _poly_spec(name, polygons, material, sector, bevel=0.05):
    vertices, faces, lookup = [], [], {}
    for polygon in polygons:
        face = []
        for point in polygon:
            key = tuple(round(c, 5) for c in point)
            if key not in lookup:
                lookup[key] = len(vertices)
                vertices.append(tuple(point))
            face.append(lookup[key])
        if len(set(face)) >= 3:
            faces.append(face)
    return g.mesh_spec(name, vertices, faces, material, sector, bevel=bevel, smooth=False)


def _rooms(authority):
    return [r for r in authority['structures'] if r.get('silhouette')]


def parts(authority):
    out = []
    rooms = {r['id']: r for r in _rooms(authority)}
    hosts = [rooms[h] for h in authority['art']['revision2']['replacedRoofHosts'] if h in rooms]
    # 1. Three distinct district pressure vaults cycled across the six hosts.
    for index, room in enumerate(hosts):
        x, y, z, w, d, h = (room[k] for k in ('x', 'y', 'z', 'w', 'd', 'h'))
        sector = ['terraced-laboratories', 'pump-energy', 'residential-operations'][index // 2]
        if index % 3 == 0:  # splayed observation vault
            base, crown = _poly8(x, y + h, z, w, d), _poly8(x, y + h + 4.5, z, w, d, scale=0.62)
            facets = [[base[i], base[(i + 1) % 8], crown[(i + 1) % 8], crown[i]] for i in range(8)]
            out.append(_poly_spec(room['id'] + '.vault', facets, 'oxidized-iron', sector))
            out.append(_poly_spec(room['id'] + '.vault-crown', [crown], 'ceramic-enamel', sector))
            out.append(g.box_mesh_src(room['id'] + '.ridge-beam', (x, y + h + 4.9, z), (w * 0.5, 0.6, 0.6), 0.0, 'copper-patina', sector))
        elif index % 3 == 1:  # tall ribbed pressure vessel: horizontal bands
            for level, radius in ((h + 1.0, min(w, d) * 0.46), (h + 4.0, min(w, d) * 0.40), (h + 6.5, min(w, d) * 0.24)):
                out.append(g.ring_mesh_src(room['id'] + '.pressure-rib.%d' % int(level * 10), (x, y + level, z), radius - 0.22, radius, 1.6, 'oxidized-iron', sector))
            out.append(g.box_mesh_src(room['id'] + '.vessel-cap', (x, y + h + 7.4, z), (min(w, d) * 0.42, min(w, d) * 0.42, 1.2), 0.0, 'ceramic-enamel', sector))
            out.append(g.ring_mesh_src(room['id'] + '.cap-collar', (x, y + h + 6.7, z), min(w, d) * 0.24, min(w, d) * 0.30, 0.8, 'copper-patina', sector))
        else:  # low faceted habitat with authored vents
            base, crown = _poly8(x, y + h, z, w, d), _poly8(x, y + h + 1.8, z, w, d, scale=0.82)
            facets = [[base[i], base[(i + 1) % 8], crown[(i + 1) % 8], crown[i]] for i in range(8)]
            out.append(_poly_spec(room['id'] + '.habitat', facets, 'cast-seams', sector))
            out.append(g.box_mesh_src(room['id'] + '.hab-crown', (x, y + h + 2.2, z), (w * 0.8, d * 0.8, 0.6), 0.0, 'cast-seams', sector))
            for vent in (-1, 1):
                vx = x + vent * w * 0.28
                out.append(g.box_mesh_src('%s.hab-vent.%d.jamb-l' % (room['id'], vent), (vx - 1.6, y + h + 1.0, z - d / 2 + 0.4), (0.34, 0.5, 3.4), 0.0, 'cast-seams', sector))
                out.append(g.box_mesh_src('%s.hab-vent.%d.jamb-r' % (room['id'], vent), (vx + 1.6, y + h + 1.0, z - d / 2 + 0.4), (0.34, 0.5, 3.4), 0.0, 'cast-seams', sector))
                out.append(g.box_mesh_src('%s.hab-vent.%d.lintel' % (room['id'], vent), (vx, y + h + 3.2, z - d / 2 + 0.4), (3.6, 0.5, 0.6), 0.0, 'oxidized-iron', sector))
    # 2. Near-player manifold valve trees beside three pump rooms.
    pumps = [r for r in _rooms(authority) if r.get('district') == 'pump-energy']
    for index, room in enumerate(pumps[:3]):
        x, y, z = room['x'], room['y'], room['z']
        out.append(g.pipe_spec(room['id'] + '.manifold', [(x + 13, y + 1.0, z - 7), (x + 13, y + 4.5, z - 7), (x + 18, y + 5.5, z - 2), (x + 18, y + 1.2, z + 3)], 0.35, 'copper-patina', 'pump-energy'))
        out.append(g.box_mesh_src(room['id'] + '.valve-body', (x + 18, y + 5.5, z - 2), (1.4, 1.4, 1.4), 0.0, 'oxidized-iron', 'pump-energy'))
        out.append(g.ring_mesh_src(room['id'] + '.valve-wheel', (x + 18, y + 6.4, z - 2), 0.55, 0.9, 0.18, 'ceramic-enamel', 'pump-energy'))
    # 3. Wet service cave detail at the two new terraces (ledge + drip fins).
    for index, (cx, cz, y) in enumerate(((-94, -96, 6), (91, -90, 0))):
        out.append(g.box_mesh_src('service-cave.%d.ledge' % index, (cx, y + 2.4, cz - 2.5), (32, 3, 0.4), 0.0, 'salt-limestone', 'service-cave'))
        for fin in range(6):
            out.append(g.box_mesh_src('service-cave.%d.drip.%d' % (index, fin), (cx - 12 + fin * 5, y + 1.2, cz - 2.5), (0.22, 0.3, 2.4), 0.0, 'deep-silt', 'service-cave'))
    # 4. Pipe bridges above four galleries.
    for index, room in enumerate([r for r in _rooms(authority) if r.get('district')][:4]):
        x, y, z, w = room['x'], room['y'], room['z'], room['w']
        out.append(g.pipe_spec('pipe-bridge.%d' % index, [(x - w * 0.3, y + 6.4, z), (x, y + 6.9, z), (x + w * 0.3, y + 6.4, z)], 0.28, 'copper-patina', 'pump-energy'))
        for side in (-1, 1):
            out.append(g.box_mesh_src('pipe-bridge.%d.hanger.%d' % (index, side), (x + side * w * 0.22, y + 6.6, z), (0.24, 0.24, 0.6), 0.0, 'oxidized-iron', 'pump-energy'))
    # 5. Observation blisters on row 0/1 rooms (jambs + lintel + sill).
    for index, room in enumerate([r for r in _rooms(authority) if r['id'].startswith(('vessel-0', 'vessel-1'))][:3]):
        x, y, z, d = room['x'], room['y'], room['z'], room['d']
        face_z = z - d / 2 - 0.3
        out.append(g.box_mesh_src('blister.%d.jamb-l' % index, (x - 1.9, y + 2.2, face_z), (0.4, 0.8, 4.4), 0.0, 'copper-patina', 'terraced-laboratories'))
        out.append(g.box_mesh_src('blister.%d.jamb-r' % index, (x + 1.9, y + 2.2, face_z), (0.4, 0.8, 4.4), 0.0, 'copper-patina', 'terraced-laboratories'))
        out.append(g.box_mesh_src('blister.%d.lintel' % index, (x, y + 4.6, face_z), (4.2, 0.8, 0.6), 0.0, 'ceramic-enamel', 'terraced-laboratories'))
        out.append(g.box_mesh_src('blister.%d.sill' % index, (x, y + 0.2, face_z), (4.2, 0.9, 0.5), 0.0, 'ceramic-enamel', 'terraced-laboratories'))
    # 6. Equalizer crown: core, five horizontal compression bands, cap.
    out.append(g.box_mesh_src('equalizer.crown-core', (34, 21.5, 8), (6.0, 6.0, 6.0), 0.0, 'copper-patina', 'pump-energy'))
    for level in range(5):
        out.append(g.ring_mesh_src('equalizer.band.%d' % level, (34, 18.5 + level * 1.6, 8), 3.05, 3.3, 0.22, 'oxidized-iron', 'pump-energy'))
    out.append(g.box_mesh_src('equalizer.cap', (34, 24.8, 8), (7.0, 7.0, 0.8), 0.0, 'ceramic-enamel', 'pump-energy'))
    # 7. Irregular reef buttresses outside the dry hull (non-traversal background).
    outline = ((-9, -6), (-2, -9), (7, -4), (9, 5), (1, 9), (-8, 4))
    for index, (rx, rz) in enumerate(((-118, -96), (-118, 96), (118, -30), (118, 60), (0, 118))):
        h = 14 + (index % 3) * 5
        base = [(rx + a, -12, rz + b) for a, b in outline]
        top = [(rx + a * 0.6, -12 + h * (0.75 + 0.06 * i), rz + b * 0.6) for i, (a, b) in enumerate(outline)]
        polygons = [[base[i], base[(i + 1) % 6], top[(i + 1) % 6], top[i]] for i in range(6)] + [top]
        out.append(_poly_spec('reef.%d' % index, polygons, 'basalt-strata' if index % 2 else 'deep-silt', 'reef'))
    return out
