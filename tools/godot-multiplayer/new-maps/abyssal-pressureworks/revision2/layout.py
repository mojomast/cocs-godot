"""Abyssal revision-2 authored geometry layout (pure Python, no bpy).

`parts(authority)` yields neutral op specs consumed by ``author.py`` and by the
bounded source tests. Every op maps 1:1 to a reviewed ``blender_kit.Kit`` helper;
materials are exact binding names, never guessed. Coordinates are Blender Z-up
metres converted from the source Y-up arena: (sx, sy, sz) -> (sx, sz, -sy).
"""
import math

MAP_ID = 'abyssal-pressureworks'
LAYOUT_REVISION = 2

# class id -> (variants, hero?) for the source tests and the material report.
CLASSES = {
    'pressure-vault': (3, True),
    'manifold-valve-tree': (3, True),
    'wet-service-cave': (2, False),
    'pipe-bridge': (4, False),
    'observation-blister': (3, True),
    'equalizer-crown': (1, True),
    'reef-buttress': (5, False),
}

# Before/after probe cameras: accepted inspection views plus the new district
# forms. Source Y-up metres; author.py converts to Blender.
PROBE_CAMERAS = {
    'overview': ((-178, 182, 174), (0, 10, 0)),
    'terraced-labs': ((-70, 10, 60), (-30, 12, 40)),
    'pump-energy': ((-20, 16, 5), (20, 20, -5)),
    'residential': ((-70, 26, -70), (-30, 28, -80)),
    'service-terrace-sw': ((-94, 8, -86), (-94, 7, -101)),
    'equalizer-crown': ((23, 12, -11), (44, 24, 8)),
    'reef-window': ((-94, 8, -70), (-94, 9, -101)),
}


# Longest-prefix classifier used by the bounded Python source test.
CLASS_PREFIX = (
    ('equalizer', 'equalizer-crown'),
    ('service-cave', 'wet-service-cave'),
    ('pipe-bridge', 'pipe-bridge'),
    ('manifold', 'manifold-valve-tree'),
    ('valve-', 'manifold-valve-tree'),
    ('blister', 'observation-blister'),
    ('reef', 'reef-buttress'),
    ('vault', 'pressure-vault'),
    ('pressure-rib', 'pressure-vault'),
    ('vessel-cap', 'pressure-vault'),
    ('cap-collar', 'pressure-vault'),
    ('ridge-beam', 'pressure-vault'),
    ('habitat', 'pressure-vault'),
    ('hab-vent', 'pressure-vault'),
    ('hab-crown', 'pressure-vault'),
)


def classify(name):
    for prefix, cls in CLASS_PREFIX:
        if prefix in name:
            return cls
    raise ValueError('Unclassified layout part: ' + name)


def _z(sx, sy, sz):
    """Source Y-up -> Blender Z-up."""
    return (sx, sz, -sy)


def _poly8(x, y, z, w, d, c=7.0, scale=1.0):
    ring = [[x + a, y, z + b] for a, b in (
        (-w / 2 + c, -d / 2), (w / 2 - c, -d / 2), (w / 2, -d / 2 + c), (w / 2, d / 2 - c),
        (w / 2 - c, d / 2), (-w / 2 + c, d / 2), (-w / 2, d / 2 - c), (-w / 2, -d / 2 + c))]
    if scale != 1.0:
        ring = [[x + (a - x) * scale, y, z + (b - z) * scale] for a, b, _ in ring]
    return [_z(*p) for p in ring]


def _facets(base, top):
    return [[base[i], base[(i + 1) % len(base)], top[(i + 1) % len(top)], top[i]] for i in range(len(base))]


def _poly_mesh(polygons):
    """Deduplicated vertices/faces from a list of source-frame polygons."""
    vertices, faces, lookup = [], [], {}
    for polygon in polygons:
        face = []
        for point in polygon:
            key = tuple(round(c, 5) for c in point)
            if key not in lookup:
                lookup[key] = len(vertices)
                vertices.append(point)
            face.append(lookup[key])
        if len(set(face)) >= 3:
            faces.append(face)
    return vertices, faces


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
        if index % 3 == 0:  # splayed observation vault, broad crown and raised ridge
            base, crown = _poly8(x, y + h, z, w, d), _poly8(x, y + h + 4.5, z, w, d, scale=0.62)
            out.append(_poly(f'{room["id"]}.vault', _facets(base, crown), 'oxidized-iron', sector))
            out.append(_poly(f'{room["id"]}.vault-crown', [crown], 'ceramic-enamel', sector))
            out.append(_prism(f'{room["id"]}.ridge-beam', _z(x, y + h + 4.9, z), (w * 0.5, 0.55, 0.55), 'copper-patina', sector))
        elif index % 3 == 1:  # tall ribbed pressure vessel
            for level, radius in ((h + 1.0, min(w, d) * 0.46), (h + 4.0, min(w, d) * 0.40), (h + 6.5, min(w, d) * 0.24)):
                out.append(_rib(f'{room["id"]}.pressure-rib.{level}', _z(x, y + level, z), radius - 0.22, radius, 1.6, 0.0, math.tau, 'oxidized-iron', sector))
            out.append(_prism(f'{room["id"]}.vessel-cap', _z(x, y + h + 7.4, z), (min(w, d) * 0.42, 1.2, min(w, d) * 0.42), 'ceramic-enamel', sector))
            out.append(_rib(f'{room["id"]}.cap-collar', _z(x, y + h + 6.7, z), min(w, d) * 0.24, min(w, d) * 0.30, 0.8, 0.0, math.tau, 'copper-patina', sector))
        else:  # low faceted habitat with authored vents
            base, crown = _poly8(x, y + h, z, w, d), _poly8(x, y + h + 1.8, z, w, d, scale=0.82)
            out.append(_poly(f'{room["id"]}.habitat', _facets(base, crown), 'cast-seams', sector))
            for vent in (-1, 1):
                out.append(_bay(f'{room["id"]}.hab-vent.{vent}', _z(x + vent * w * 0.28, y + h + 1.0, z - d / 2 + 0.4),
                                3.2, 3.0, 0.5, 'cast-seams', 'oxidized-iron', sector, arch=True))
            out.append(_prism(f'{room["id"]}.hab-crown', _z(x, y + h + 2.2, z), (w * 0.4, 0.6, d * 0.4), 'cast-seams', sector))
    # 2. Near-player manifold valve trees beside three pump rooms.
    pumps = [r for r in _rooms(authority) if r.get('district') == 'pump-energy']
    for index, room in enumerate(pumps[:3]):
        x, y, z = room['x'], room['y'], room['z']
        node = _z(x + 13, y + 1.0, z - 7)
        out.append(_pipe(f'{room["id"]}.manifold', [node, _z(x + 13, y + 4.5, z - 7), _z(x + 18, y + 5.5, z - 2), _z(x + 18, y + 1.2, z + 3)],
                         0.35, 'copper-patina', 'pump-energy'))
        out.append(_prism(f'{room["id"]}.valve-body', _z(x + 18, y + 5.5, z - 2), (1.4, 1.4, 1.4), 'oxidized-iron', 'pump-energy'))
        out.append(_rib(f'{room["id"]}.valve-wheel', _z(x + 18, y + 6.4, z - 2), 0.55, 0.9, 0.18, 0.0, math.tau, 'ceramic-enamel', 'pump-energy', segments=16))
    # 3. Wet service cave detail at the two new terraces.
    for index, (cx, cz, y) in enumerate(((-94, -96, 6), (91, -90, 0))):
        out.append(_poly('service-cave.%d.ledge' % index,
                         [[_z(cx - 16, y + 2.4, cz - 4), _z(cx + 16, y + 2.4, cz - 4), _z(cx + 16, y + 2.4, cz - 1), _z(cx - 16, y + 2.4, cz - 1)]],
                         'salt-limestone', 'service-cave'))
        for fin in range(6):
            out.append(_prism('service-cave.%d.drip.%d' % (index, fin), _z(cx - 12 + fin * 5, y + 1.2, cz - 2.5), (0.22, 2.4, 0.3), 'deep-silt', 'service-cave'))
    # 4. Pipe bridges above four galleries.
    for index, room in enumerate([r for r in _rooms(authority) if r.get('district')][:4]):
        x, y, z, w = room['x'], room['y'], room['z'], room['w']
        out.append(_pipe(f'pipe-bridge.{index}', [_z(x - w * 0.3, y + 6.4, z), _z(x, y + 6.9, z), _z(x + w * 0.3, y + 6.4, z)], 0.28, 'copper-patina', 'pump-energy'))
        for side in (-1, 1):
            out.append(_prism(f'pipe-bridge.{index}.hanger.{side}', _z(x + side * w * 0.22, y + 6.6, z), (0.24, 0.6, 0.24), 'oxidized-iron', 'pump-energy'))
    # 5. Observation blisters on row 0/1 rooms.
    for index, room in enumerate([r for r in _rooms(authority) if r['id'].startswith(('vessel-0', 'vessel-1'))][:3]):
        x, y, z, d = room['x'], room['y'], room['z'], room['d']
        out.append(_bay(f'blister.{index}', _z(x, y + 1.2, z - d / 2 - 0.3), 4.2, 4.4, 0.8, 'copper-patina', 'ceramic-enamel', 'terraced-laboratories', arch=True))
    # 6. Equalizer crown (single hero).
    out.append(_prism('equalizer.crown-core', _z(34, 21.5, 8), (6.0, 6.0, 6.0), 'copper-patina', 'pump-energy'))
    for level in range(5):
        out.append(_rib(f'equalizer.band.{level}', _z(34, 18.5 + level * 1.6, 8), 3.05, 3.3, 0.22, 0.0, math.tau, 'oxidized-iron', 'pump-energy', segments=20))
    out.append(_prism('equalizer.cap', _z(34, 24.8, 8), (7.0, 0.8, 7.0), 'ceramic-enamel', 'pump-energy'))
    # 7. Irregular reef buttresses outside the dry hull (non-traversal background).
    outline = ((-9, -6), (-2, -9), (7, -4), (9, 5), (1, 9), (-8, 4))
    for index, (rx, rz) in enumerate(((-118, -96), (-118, 96), (118, -30), (118, 60), (0, 118))):
        h = 14 + (index % 3) * 5
        base = [_z(rx + a, -12, rz + b) for a, b in outline]
        top = [_z(rx + a * 0.6, -12 + h * (0.75 + 0.06 * i), rz + b * 0.6) for i, (a, b) in enumerate(outline)]
        polygons = [[base[i], base[(i + 1) % 6], top[(i + 1) % 6], top[i]] for i in range(6)] + [top]
        out.append(_poly(f'reef.{index}', polygons, 'basalt-strata' if index % 2 else 'deep-silt', 'reef'))
    return out


def _poly(name, polygons, material, sector):
    vertices, faces = _poly_mesh(polygons)
    return {'op': 'mesh', 'name': name, 'material': material, 'sector': sector, 'args': (vertices, faces)}


def _prism(name, center, size, material, sector):
    return {'op': 'prism', 'name': name, 'material': material, 'sector': sector, 'args': (center, size)}


def _rib(name, center, inner, outer, depth, start, stop, material, sector, segments=24):
    return {'op': 'curved_rib', 'name': name, 'material': material, 'sector': sector,
            'args': (center, inner, outer, depth, start, stop), 'kwargs': {'segments': segments}}


def _pipe(name, points, radius, material, sector):
    return {'op': 'pipe', 'name': name, 'material': material, 'sector': sector, 'args': (points, radius)}


def _bay(name, origin, width, height, depth, frame, trim, sector, arch=False):
    return {'op': 'framed_bay', 'name': name, 'material': frame, 'sector': sector,
            'args': (origin, width, height, depth), 'kwargs': {'frame': frame, 'trim': trim, 'arch': arch}}
