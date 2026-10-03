"""Pure planar clearance against every actual authority road triangle."""
import math

# 28 m road, then a 4 m camera/barrier clearance for all low forms.
PLACEMENT_MARGIN = 4.0
VERTICAL_BAND = (-1.0, 6.0)


def _cross2(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def road_polygons(authority):
    return [[(surface['vertices'][i][0], surface['vertices'][i][2]) for i in face]
            for surface in authority['terrain']['surfaces'] if surface['id'].startswith('road-')
            for face in surface['triangles']]


def point_in_quad(point, quad):
    signs = [_cross2(quad[i], quad[(i + 1) % len(quad)], point) for i in range(len(quad))]
    return all(s >= -1e-9 for s in signs) or all(s <= 1e-9 for s in signs)


def point_in_poly(point, polygon):
    inside = False
    n = len(polygon)
    for i in range(n):
        a, b = polygon[i], polygon[(i + 1) % n]
        if (a[1] > point[1]) != (b[1] > point[1]):
            x = (b[0] - a[0]) * (point[1] - a[1]) / (b[1] - a[1]) + a[0]
            if point[0] < x:
                inside = not inside
    return inside


def segment_intersect(p1, p2, p3, p4):
    d1, d2 = _cross2(p3, p4, p1), _cross2(p3, p4, p2)
    d3, d4 = _cross2(p1, p2, p3), _cross2(p1, p2, p4)
    if ((d1 > 1e-9 and d2 < -1e-9) or (d2 > 1e-9 and d1 < -1e-9)) and ((d3 > 1e-9 and d4 < -1e-9) or (d4 > 1e-9 and d3 < -1e-9)):
        return True
    return any(abs(_cross2(a, b, p)) < 1e-9 and min(a[0], b[0])-1e-9 <= p[0] <= max(a[0], b[0])+1e-9 and min(a[1], b[1])-1e-9 <= p[1] <= max(a[1], b[1])+1e-9
               for a, b, p in ((p1, p2, p3), (p1, p2, p4), (p3, p4, p1), (p3, p4, p2)))


def _point_segment_distance(point, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    span = dx * dx + dz * dz
    if span < 1e-12:
        return math.hypot(point[0] - a[0], point[1] - a[1])
    t = max(0.0, min(1.0, ((point[0] - a[0]) * dx + (point[1] - a[1]) * dz) / span))
    return math.hypot(point[0] - a[0] - dx * t, point[1] - a[1] - dz * t)


def point_quad_distance(point, quad):
    if point_in_quad(point, quad):
        return 0.0
    return min(_point_segment_distance(point, quad[i], quad[(i + 1) % len(quad)]) for i in range(len(quad)))


def rectangle(cx, cz, half_along, half_across, heading):
    al = (math.sin(heading), math.cos(heading))
    ac = (math.cos(heading), -math.sin(heading))
    return [(cx + al[0] * sx * half_along + ac[0] * sz * half_across,
             cz + al[1] * sx * half_along + ac[1] * sz * half_across)
            for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def form_conflict(corners, quads, margin=PLACEMENT_MARGIN):
    edges = [(corners[i], corners[(i + 1) % len(corners)]) for i in range(len(corners))]
    for quad in quads:
        qedges = [(quad[i], quad[(i + 1) % len(quad)]) for i in range(len(quad))]
        for corner in corners:
            if point_quad_distance(corner, quad) < margin:
                return True
        for qcorner in quad:
            if point_in_poly(qcorner, corners):
                return True
        for a, b in edges:
            for c, d in qedges:
                if segment_intersect(a, b, c, d):
                    return True
                if margin and min(_point_segment_distance(a, c, d), _point_segment_distance(b, c, d),
                                  _point_segment_distance(c, a, b), _point_segment_distance(d, a, b)) < margin:
                    return True
    return False


def safe_place(anchor, half_along, half_across, quads, margin=PLACEMENT_MARGIN, limit=320.0):
    """Push the form outward along its across frame until its footprint clears all
    corridor segments. Returns (x, z); raises when no clear placement exists."""
    heading = anchor['heading']
    # The source recipe's positive lateral is (-cos heading, +sin heading).
    sign = -1.0 if anchor['lateral'] >= 0 else 1.0
    ac = (math.cos(heading), -math.sin(heading))
    for step in range(0, 1400):
        distance = step * 0.5
        cx = anchor['x'] + sign * ac[0] * distance
        cz = anchor['z'] + sign * ac[1] * distance
        if abs(cx) > limit or abs(cz) > limit:
            break
        corners = rectangle(cx, cz, half_along, half_across, heading)
        if not form_conflict(corners, quads, margin):
            return cx, cz
    raise ValueError('No road-clear placement for ' + str(anchor.get('id')))


def triangle_conflicts_corridor(triangle_xz, quads, margin=0.0):
    """True when an emitted triangle's XZ projection touches any corridor quad."""
    return form_conflict(triangle_xz, quads, margin)


def low_geometry_conflicts(spec, road, margin=PLACEMENT_MARGIN):
    """Faces intersecting the driving/camera height band, including swept edges."""
    if spec['op'] != 'mesh':
        raise ValueError('Scenic road-check expects mesh faces')
    for face in spec['faces']:
        vertices = [spec['vertices'][i] for i in face]
        if max(v[1] for v in vertices) < VERTICAL_BAND[0] or min(v[1] for v in vertices) > VERTICAL_BAND[1]:
            continue
        for i in range(1, len(face)-1):
            if triangle_conflicts_corridor([(v[0], v[2]) for v in (vertices[0], vertices[i], vertices[i+1])], road, margin):
                return True
    return False
