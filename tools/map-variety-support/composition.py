"""Complete render composition for a map-variety revision.

The Blender builder must reproduce the *revised authority*, not just the new
props: every retained walkable deck, ramp, ceiling, wall, equipment piece,
window and authored building mesh is emitted, plus the new authored 3D classes.
Surfaces already removed in the authority (the six replaced abyssal roofs) are
therefore absent, and their substitutes come from ``layout.parts``.

All coordinates are source-frame; ``author.py`` converts once at the Blender
boundary. Physics is owned by the JSON authority independently; this only
guarantees render/physics congruence.
"""
import math

import geometry as g


def _triangle_key(vertices, indices):
    return frozenset(tuple(round(c, 6) for c in vertices[i]) for i in indices)


def _covered_by_art(arena):
    covered = set()
    for mesh in arena.get('art', {}).get('meshes', []):
        covered.update(_triangle_key(mesh['vertices'], face) for face in mesh['triangles'])
    return covered


def _original_reefs(reefs):
    """Traceable nine authority reefs: tapered spire and branching coral arms."""
    result = []
    for index, reef in enumerate(reefs):
        x, y, z = (reef[k] for k in ('x', 'y', 'z'))
        radius, height = reef['radius'], reef['height']
        result.append(g.pipe_spec('reef-%d-escarpment' % index,
                                  [(x, y - 10, z), (x + 2, y + height * .65, z - 2)],
                                  radius, 'navy', 'reef', sides=8))
        for arm in range(5):
            start = (x, y + arm * height / 7, z)
            end = (x + math.cos(arm * 2.1 + index) * radius * 1.8,
                   y + height * (.6 + arm * .09), z - 3 - math.sin(arm) * 4)
            result.append(g.pipe_spec('reef-%d-branch-%d' % (index, arm),
                                      [start, end], .4 + arm * .08,
                                      'coral' if arm % 2 else 'copper', 'reef'))
            result.append(g.pipe_spec('reef-%d-tip-%d' % (index, arm),
                                      [end, (end[0] + 2, end[1] + 2, end[2] - 1)],
                                      .18, 'ivory', 'reef'))
    return result


def _abyssal_author_detail(arena):
    """Source-authored fittings/background from the accepted blender_author.py.

    These have no JSON collision counterparts, but are part of the established
    visual authority; use source metres and exact material IDs throughout.
    """
    if arena.get('id') != 'abyssal-pressureworks':
        return []
    result = []

    def box(name, x, y, z, w, h, d, material, sector='legacy-detail'):
        result.append(g.box_mesh_src(name, (x, y, z), (w, d, h), 0, material, sector, bevel=.008))

    def beam(name, a, b, radius, material, sector='legacy-detail'):
        result.append(g.pipe_spec(name, [a, b], radius, material, sector, sides=8))

    core = next(p for p in arena['art']['pieces'] if p['id'] == 'pressure-equalizer-core')
    cx, cy, cz = (core[k] for k in ('x', 'y', 'z'))
    for level in range(5):
        for sign in (-1, 1):
            box('equalizer-band-front-%d-%d' % (level, sign), cx, cy - 8 + level * 4, cz + sign * 3.012, 5.8, .28, .025, 'ivory')
            box('equalizer-band-side-%d-%d' % (level, sign), cx + sign * 3.012, cy - 8 + level * 4, cz, .025, .28, 5.8, 'ivory')
    for sign in (-1, 1):
        box('equalizer-pressure-gauge-%d' % sign, cx + sign * 1.4, cy - 6, cz - 3.03, .8, 1.5, .05, 'cyan' if sign < 0 else 'amber')
    for r in [s for s in arena['structures'] if 'silhouette' in s]:
        x, y, z, w, d, h = (r[k] for k in ('x', 'y', 'z', 'w', 'd', 'h'))
        name = r['id']
        outline = [(x-w/2+7,z-d/2),(x+w/2-7,z-d/2),(x+w/2,z-d/2+7),
                   (x+w/2,z+d/2-7),(x+w/2-7,z+d/2),(x-w/2+7,z+d/2),
                   (x-w/2,z+d/2-7),(x-w/2,z-d/2+7)]
        for level in (7.6, h - .3):
            for i, a in enumerate(outline):
                b = outline[(i + 1) % 8]
                beam(f'{name}-pressure-ring-{level}-{i}', (a[0], y+level, a[1]), (b[0], y+level, b[1]), .24, 'copper')
        for i, (px, pz) in enumerate(outline):
            beam(f'{name}-external-load-rib-{i}', (px, y, pz), (px, y+h, pz), .4, 'ivory')
            beam(f'{name}-bedrock-anchor-{i}', (px, -14, pz), (px, y-.15, pz), .75, 'navy')
        for side, port in r['ports'].items():
            for n, end in enumerate((port['a'], port['b'])):
                for level in (1, 2.5, 4, 5.5):
                    box(f'{name}-{side}-locking-dog-{n}-{level}', end[0], y+level, end[1], .7, .5, .7, 'ivory')
            a, b = port['a'], port['b']
            beam(f'{name}-{side}-inner-seal', (a[0], y+7.15, a[1]), (b[0], y+7.15, b[1]), .16, 'copper')
        for sign in (-1, 1):
            beam(f'{name}-service-return-{sign}', (x-8, y+h-.7, z+sign*(d/2-3)), (x+8, y+h-.7, z+sign*(d/2-3)), .2, 'copper')
            for key in range(6):
                box(f'{name}-console-key-{sign}-{key}', x+sign*10-1.5+key*.5, y+1.53, z-10.6, .16, .06, .16, 'amber')
            for stripe in range(3):
                box(f'{name}-equipment-vent-{sign}-{stripe}', x+sign*11, y+.6+stripe*.4, z+8.49, 2.8, .12, .03, 'copper')
            box(f'{name}-bay-door-{sign}', x+sign*11, y+1.2, z+6.19, 2.4, 2.1, .05, 'navy')
            box(f'{name}-bay-status-{sign}', x+sign*11+1.65, y+1.7, z+6.18, .18, .5, .04, 'cyan')
            if r['district'] == 'terraced-laboratories':
                for instrument in range(3):
                    box(f'{name}-specimen-{sign}-{instrument}', x+sign*11-1.25+instrument*1.25, y+3, z+8.48, .65, 2, .06, 'cyan')
            elif r['district'] == 'pump-energy':
                for pipe in range(3):
                    beam(f'{name}-pump-feed-{sign}-{pipe}', (x+sign*11-1.25+pipe*1.25,y+1,z+8.45),
                         (x+sign*11-1.25+pipe*1.25,y+3.5,z+8.45), .15, 'copper')
            else:
                for bunk in range(2):
                    box(f'{name}-bunk-reveal-{sign}-{bunk}', x+sign*11,y+.65+bunk,z+8.48,3.3,.65,.04,'ivory')
            color = 'cyan' if r['district'] == 'terraced-laboratories' else 'amber'
            box(f'{name}-deck-lane-{sign}', x, y+.018, z+sign*3, 14, .018, .12, color)
        for n in range(-3, 4):
            box(f'{name}-deck-seam-{n}', x+n*4, y+.006, z, .035, .009, d-14, 'copper')
    for i in range(8):
        x = -112 + i * 32
        verts = [(x-20,-24,-105),(x+20,-24,-105),(x+23,-18,100),(x-16,-18,100),
                 (x-18,-10,-105),(x+17,-8,-105),(x+18,3,100),(x-13,6,100)]
        faces = [(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]
        result.append(g.mesh_spec('escarpment-bed-%d' % i, verts, faces, 'navy', 'reef', bevel=0, smooth=False))
    return result


def labels_for_arena(arena):
    labels = list(arena.get('art', {}).get('labels', []))
    if arena.get('id') == 'abyssal-pressureworks':
        labels.extend({'text': r['name'].upper(), 'x': r['x'], 'y': r['y'] + 7.8,
                       'z': r['z'] - r['d'] / 2 + .08, 'size': .78}
                      for r in arena['structures'] if 'silhouette' in r)
    return labels


def compose(arena):
    """Base render plan for a revised authority (no authored layout classes)."""
    specs = []
    covered = _covered_by_art(arena)
    for surface in arena['terrain']['surfaces']:
        remaining = [face for face in surface['triangles'] if _triangle_key(surface['vertices'], face) not in covered]
        if remaining:
            specs.append(g.mesh_spec(surface['id'], surface['vertices'], remaining,
                                     surface['material'], 'base', bevel=0, smooth=False))
    for index, wall in enumerate(arena['terrain']['walls']):
        vertices = wall['vertices']
        if len(vertices) < 3:
            raise ValueError('Render wall needs at least three vertices: ' + str(wall.get('id')))
        faces = [[0, i, i + 1] for i in range(1, len(vertices) - 1)]
        remaining = [face for face in faces if _triangle_key(vertices, face) not in covered]
        if remaining:
            specs.append(g.mesh_spec(wall.get('id', 'wall-%d' % index), vertices, remaining,
                                     wall['material'], 'base', bevel=0, smooth=False))
    art = arena.get('art', {})
    for index, window in enumerate(art.get('windows', [])):
        # Transparent observation glazing is a real render pane; physics is the
        # authority's own non-blocking convention.
        specs.append(g.mesh_spec(window.get('id', 'window-%d' % index), window['vertices'],
                                 [[0, 1, 2], [0, 2, 3]], window.get('material', 'glass'),
                                 'glass', bevel=0, smooth=False))
    for mesh in art.get('meshes', []):
        specs.append(g.mesh_spec(mesh['id'], mesh['vertices'], mesh['triangles'],
                                 mesh['material'], 'base', bevel=0, smooth=False))
    for piece in art.get('pieces', []):
        # abyssal pieces carry a centre (x, y, z) and source size (w, h, d).
        specs.append(g.box_mesh_src(piece['id'], (piece['x'], piece['y'], piece['z']),
                                    (piece['w'], piece['d'], piece['h']), 0.0,
                                     piece['material'], 'base', bevel=0.015))
    specs.extend(_original_reefs(art.get('reefs', [])))
    specs.extend(_abyssal_author_detail(arena))
    return specs


def compose_full(arena, layout_module):
    return compose(arena) + layout_module.parts(arena)
