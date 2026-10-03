"""Pure-Python ray contacts for frozen GLB history, corrected art, and authority.

No bpy, Godot, or render. Coordinates are the exported glTF/world Y-up frame.
Supports the indexed float32 POSITION and uint16/uint32 indices actually present
in the immutable T GLB. The first fixture proves the archived P1, not closure.
"""
import json
import math
import pathlib
import struct


HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[4]
T_GLB = ROOT / 'port/finish/map-variety/native-T-20261003/abyssal-pressureworks/abyssal-pressureworks-revision2.glb'


def _component(raw, offset, code, count):
    fmt = {5126: 'f', 5125: 'I', 5123: 'H', 5121: 'B'}[code]
    return struct.unpack_from('<' + fmt * count, raw, offset)


def glb_triangles(path=T_GLB):
    raw = pathlib.Path(path).read_bytes()
    if raw[:4] != b'glTF' or struct.unpack_from('<I', raw, 8)[0] != len(raw):
        raise ValueError('Invalid archived GLB')
    length = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    binary = raw[28 + length:]
    def accessor(index):
        item = doc['accessors'][index]
        view = doc['bufferViews'][item['bufferView']]
        count = {'VEC3': 3, 'SCALAR': 1}[item['type']]
        size = {5126: 4, 5125: 4, 5123: 2, 5121: 1}[item['componentType']]
        offset = view.get('byteOffset', 0) + item.get('byteOffset', 0)
        stride = view.get('byteStride', size * count)
        return [_component(binary, offset + n * stride, item['componentType'], count)
                for n in range(item['count'])]
    for node in doc['nodes']:
        if 'mesh' not in node:
            continue
        if any(key in node for key in ('matrix', 'rotation', 'translation', 'scale')):
            raise ValueError('Archived GLB has unaccounted node transform')
        mesh = doc['meshes'][node['mesh']]
        for primitive in mesh['primitives']:
            if primitive.get('mode', 4) != 4:
                raise ValueError('Nontriangle GLB primitive')
            positions = accessor(primitive['attributes']['POSITION'])
            indices = [v[0] for v in accessor(primitive['indices'])]
            if len(indices) % 3:
                raise ValueError('Unaligned triangles')
            for i in range(0, len(indices), 3):
                yield node['name'], tuple(positions[j] for j in indices[i:i + 3])


def triangles_from_specs(specs):
    for spec in specs:
        if spec['op'] != 'mesh':
            raise ValueError('Collision audit expects closed mesh specs, not pipes')
        for face in spec['faces']:
            for i in range(1, len(face) - 1):
                yield spec['name'], tuple(spec['vertices'][j] for j in (face[0], face[i], face[i + 1]))


def triangles_from_authority(arena):
    for surface in arena['terrain']['surfaces']:
        for triangle in surface['triangles']:
            yield surface['id'], tuple(surface['vertices'][j] for j in triangle)
    for wall in arena['terrain']['walls']:
        vertices = wall['vertices']
        for i in range(1, len(vertices) - 1):
            yield wall['id'], (vertices[0], vertices[i], vertices[i + 1])


def _minus(a, b):
    return tuple(a[i] - b[i] for i in range(3))


def _dot(a, b):
    return sum(a[i] * b[i] for i in range(3))


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def segment_hits(start, end, triangles):
    """Two-sided Möller–Trumbore segment contacts, sorted along the segment."""
    direction = _minus(end, start)
    hits = []
    for name, (a, b, c) in triangles:
        if any(max(start[k], end[k]) + 1e-6 < min(a[k], b[k], c[k]) or
               min(start[k], end[k]) - 1e-6 > max(a[k], b[k], c[k]) for k in range(3)):
            continue
        edge1, edge2 = _minus(b, a), _minus(c, a)
        p = _cross(direction, edge2)
        determinant = _dot(edge1, p)
        if abs(determinant) < 1e-12:
            continue
        inverse = 1 / determinant
        t = _minus(start, a)
        u = _dot(t, p) * inverse
        if u < -1e-8 or u > 1 + 1e-8:
            continue
        q = _cross(t, edge1)
        v = _dot(direction, q) * inverse
        distance = _dot(edge2, q) * inverse
        if v < -1e-8 or u + v > 1 + 1e-8 or distance < -1e-8 or distance > 1 + 1e-8:
            continue
        point = tuple(start[k] + direction[k] * distance for k in range(3))
        if not all(math.isfinite(value) for value in point):
            raise ValueError('Nonfinite contact')
        hits.append((distance, name, point))
    return sorted(hits)
