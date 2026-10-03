"""Compare a future editable master export to the complete pinned X export."""
import collections
import math
import sys
from contract import EmbeddedGlb, ROOT, SOURCE_SHA, sha, stream, source_face

# Reuse the frozen R7 semantic material/pixel/sampler/emission policy, not a
# Foundry material inventory or Foundry-only geometry gate.
sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/gravemill-foundry/revision7'))
from material_contract import compare_materials

def world(node):
    if 'matrix' in node or node.get('children'):
        raise ValueError('Matrix/parented editable nodes require separate transform audit')
    t = node.get('translation', [0., 0., 0.]); s = node.get('scale', [1., 1., 1.]); q = node.get('rotation', [0., 0., 0., 1.])
    if (len(t), len(s), len(q)) != (3, 3, 4) or not all(math.isfinite(x) for x in (*t, *s, *q)) or min(s) <= 0 or abs(sum(x*x for x in q)-1) > 1e-5:
        raise ValueError('Invalid editable TRS')
    x, y, z, w = q
    def rotate(v):
        u = (x, y, z)
        cross = (u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0])
        twice = (2*cross[0], 2*cross[1], 2*cross[2])
        other = (u[1]*twice[2]-u[2]*twice[1], u[2]*twice[0]-u[0]*twice[2], u[0]*twice[1]-u[1]*twice[0])
        return tuple(v[i] + w*twice[i] + other[i] for i in range(3))
    def position(p): return tuple(a+b for a,b in zip(t, rotate(tuple(p[i]*s[i] for i in range(3)))))
    def normal(n):
        v = rotate(tuple(n[i]/s[i] for i in range(3)))
        length = math.sqrt(sum(x*x for x in v))
        if length < 1e-10: raise ValueError('Undefined editable normal')
        return tuple(x/length for x in v)
    return position, normal

def faces(g):
    g.geometry()
    if len(g.doc['meshes']) != 39 or len(g.doc['materials']) != 14:
        raise ValueError('Editable scene inventory differs from X')
    nodes = [n for n in g.doc['nodes'] if 'mesh' in n]
    if len(nodes) != 39 or {n['mesh'] for n in nodes} != set(range(39)):
        raise ValueError('Missing/instanced editable mesh')
    for node in nodes:
        transform_position, transform_normal = world(node)
        mesh = g.doc['meshes'][node['mesh']]
        for primitive in mesh['primitives']:
            a = primitive['attributes']
            positions = stream(g, a['POSITION'], 'VEC3')
            normals = stream(g, a['NORMAL'], 'VEC3')
            uv = stream(g, a['TEXCOORD_0'], 'VEC2')
            ix = [x[0] for x in stream(g, primitive['indices'], 'SCALAR', (5121, 5123, 5125))]
            role = g.doc['materials'][primitive['material']]['name']
            if len(ix) % 3: raise ValueError('Incomplete editable triangle')
            for start in range(0, len(ix), 3):
                face = [(transform_position(positions[i]), transform_normal(normals[i]), uv[i]) for i in ix[start:start + 3]]
                if any(any(not math.isfinite(x) for x in component) for corner in face for component in corner):
                    raise ValueError('Nonfinite editable corner')
                # Cyclic rotations preserve winding; mirror reversal is forbidden.
                rotations = [face[i:] + face[:i] for i in range(3)]
                canonical = min(rotations, key=lambda cs: tuple(round(v, 4) for c in cs for v in c[0]))
                key = (role, tuple(tuple(round(v, 4) for v in c[0]) for c in canonical))
                yield key, canonical

def audit(raw, baseline):
    if sha(baseline) != SOURCE_SHA: raise ValueError('Editable audit needs pinned X input')
    old, new = EmbeddedGlb(baseline), EmbeddedGlb(raw)
    source_face(old)  # full original scene/face pin before any comparisons
    expected = collections.defaultdict(list)
    for key, corner in faces(old): expected[key].append(corner)
    count = 0
    maximum = [0., 0., 0.]
    for key, corner in faces(new):
        choices = expected[key]
        match = None
        for i, wanted in enumerate(choices):
            errors = [max(abs(x-y) for a, b in zip(corner, wanted) for x, y in zip(a[j], b[j])) for j in range(3)]
            if errors[0] <= 1e-5 and errors[1] <= 1e-4 and errors[2] <= 1e-5:
                match = i
                maximum = [max(a, b) for a, b in zip(maximum, errors)]
                break
        if match is None: raise ValueError('Editable geometry/normal/UV/material role or winding drift')
        choices.pop(match)
        count += 1
    if count != 155553 or any(expected.values()): raise ValueError('Editable triangle multiplicity changed')
    compare_materials(old, new)
    return {'triangles': count, 'maxPositionNormalUVError': maximum,
        'allMaterialsDecodedPixelsSamplersEmissionMatch': True, 'orientedFaceMultiplicity': 'exact'}
