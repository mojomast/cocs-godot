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
import geometry as g


def compose(arena):
    """Base render plan for a revised authority (no authored layout classes)."""
    specs = []
    for surface in arena['terrain']['surfaces']:
        specs.append(g.mesh_spec(surface['id'], surface['vertices'], surface['triangles'],
                                 surface['material'], 'base', bevel=0, smooth=False))
    for index, wall in enumerate(arena['terrain']['walls']):
        vertices = wall['vertices']
        if len(vertices) < 3:
            raise ValueError('Render wall needs at least three vertices: ' + str(wall.get('id')))
        faces = [[0, i, i + 1] for i in range(1, len(vertices) - 1)]
        specs.append(g.mesh_spec(wall.get('id', 'wall-%d' % index), vertices, faces,
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
    return specs


def compose_full(arena, layout_module):
    return compose(arena) + layout_module.parts(arena)
