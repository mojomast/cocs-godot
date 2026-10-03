"""Pinned X Parallax three-corner successor; pure source checks, no artifact IO."""
import copy
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/map_variety'))
sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/botanical-post-x'))
from glb_geometry import EmbeddedGlb
from uv_basis import basis, solve, dot, cross, norm

SOURCE = ROOT / 'tools/godot-multiplayer/new-maps/botanical-correction/runs/x-03/parallax-observatory/parallax-observatory.glb'
SOURCE_SHA = '6356cf895c65cec181e1c6c077118b98f3ee80cb567955b37835433971342422'
MASTER = ROOT / 'tools/godot-multiplayer/new-maps/botanical-correction/runs/x-03/parallax-observatory/masters/parallax-observatory.blend'
MASTER_SHA = '9957ca8cc3e4e7f2bca00f7b82a48ed88d031e9e3949259ebf5603f584141051'
GEOMETRY = '3a5800e89876ebcc741381802def24415d5050651c0d3b831ea8b9ec3b77b4f9'
VERTICES = (24049, 24050, 24051)
TANGENT = (1., 0., 0., -1.)
REVISION = 'parallax-districts-v4-tangent-v1'

def sha(raw): return hashlib.sha256(raw).hexdigest()

def pinned():
    raw = SOURCE.read_bytes()
    if sha(raw) != SOURCE_SHA or sha(MASTER.read_bytes()) != MASTER_SHA:
        raise ValueError('X GLB/master dependency identity changed')
    return raw

def encode(doc, blob):
    header = json.dumps(doc, separators=(',', ':'), allow_nan=False).encode()
    header += b' ' * (-len(header) % 4)
    return (struct.pack('<III', 0x46546c67, 2, 28 + len(header) + len(blob)) +
            struct.pack('<I4s', len(header), b'JSON') + header +
            struct.pack('<I4s', len(blob), b'BIN\0') + bytes(blob))

def stream(g, index, shape, components=(5126,)):
    _, count, layout = g.accessor(index, shape, components, shape)
    return list(g.values(count, layout))

def source_face(g):
    parts, triangles, _ = g.geometry()
    if triangles != 155553 or len(parts) != 39 or len(g.doc['materials']) != 14:
        raise ValueError('X scene inventory changed')
    mesh = g.doc['meshes'][9]
    if mesh['name'] != 'art.accepted-craft.saltstone.001' or len(mesh['primitives']) != 1:
        raise ValueError('Reviewed mesh changed')
    p = mesh['primitives'][0]
    if p['attributes']['TANGENT'] != 48 or g.doc['materials'][p['material']]['name'] != 'saltstone':
        raise ValueError('Reviewed accessor/material changed')
    material = g.doc['materials'][p['material']]
    slot = material.get('normalTexture')
    if not isinstance(slot, dict) or slot.get('texCoord', 0) != 0 or slot.get('extensions'):
        raise ValueError('Normal-map UV semantics changed')
    nodes = [n for n in g.doc['nodes'] if n.get('mesh') == 9]
    if len(nodes) != 1 or any(k in nodes[0] for k in ('matrix', 'translation', 'rotation', 'scale')):
        raise ValueError('Reviewed mesh must be untransformed and unique')
    if [(mi, pi) for mi, m in enumerate(g.doc['meshes']) for pi, q in enumerate(m['primitives'])
        if q['attributes'].get('TANGENT') == 48] != [(9, 0)]:
        raise ValueError('Shared tangent accessor')
    positions = stream(g, p['attributes']['POSITION'], 'VEC3')
    normals = stream(g, p['attributes']['NORMAL'], 'VEC3')
    uv = stream(g, p['attributes']['TEXCOORD_0'], 'VEC2')
    tangents = stream(g, 48, 'VEC4')
    indices = [x[0] for x in stream(g, p['indices'], 'SCALAR', (5121, 5123, 5125))]
    if len(indices) % 3 or indices[11823 * 3:11823 * 3 + 3] != list(VERTICES):
        raise ValueError('Reviewed face changed')
    if positions[VERTICES[0]] != (68.77897644042969, 24., -66.25537872314453):
        raise ValueError('Reviewed face position changed')
    return positions, normals, uv, tangents, indices

def repair(raw):
    if sha(raw) != SOURCE_SHA: raise ValueError('Exact X input GLB required')
    g = EmbeddedGlb(raw)
    positions, normals, uv, tangents, indices = source_face(g)
    blob = bytearray(g.binary)
    _, _, layout = g.accessor(48, 'VEC4', (5126,), 'TANGENT')
    allowed = set()
    for corner, vertex in enumerate(VERTICES):
        incidents = [i // 3 for i in range(0, len(indices), 3) if vertex in indices[i:i+3]]
        if incidents != [11823] or tangents[vertex] != ((0., 0., 0., 1.) if corner == 0 else (1., 0., 0., 1.)):
            raise ValueError('Corner incident/source tangent drift')
        derived = basis([positions[i] for i in VERTICES], [uv[i] for i in VERTICES], normals[vertex], corner)
        if solve([derived]) != TANGENT or abs(derived['area'] - .09058172586082947) > 1e-8 or abs(derived['uvJacobian'] + .04529086293041473) > 1e-8:
            raise ValueError('Reviewed UV derivative changed')
        offset = layout[0] + vertex * layout[1]
        span = set(range(offset, offset + 16))
        if allowed & span: raise ValueError('Aliased tangent corners')
        allowed |= span
        struct.pack_into('<4f', blob, offset, *TANGENT)
    changed = {i for i, (a, b) in enumerate(zip(g.binary, blob)) if a != b}
    if len(allowed) != 48 or len(changed) != 5 or not changed <= allowed:
        raise ValueError('Change exceeds reviewed 48-byte storage / five-byte delta')
    for ai, accessor in enumerate(g.doc['accessors']):
        if ai == 48: continue
        _, count, (start, stride, fmt) = g.accessor(ai, accessor['type'], (5121, 5123, 5125, 5126), 'other stream')
        width = struct.calcsize(fmt)
        if any(0 <= off - start and (off - start) // stride < count and (off - start) % stride < width for off in changed):
            raise ValueError('Repair aliases another accessor')
    for image in g.doc['images']:
        start, length = g._view(g.doc['bufferViews'][image['bufferView']])
        if any(start <= off < start + length for off in changed): raise ValueError('Repair aliases embedded image')
    doc = copy.deepcopy(g.doc)
    doc['asset'].setdefault('extras', {}).update({'visualRevision': REVISION, 'tangentSuccessorOf': SOURCE_SHA,
        'tangentPolicy': 'Only three reviewed exclusive corners of face 11823; no other BIN changes'})
    for node in doc['nodes']:
        node.setdefault('extras', {})['visualRevision'] = REVISION
    result = encode(doc, blob)
    return result, {'sourceSha256': SOURCE_SHA, 'artifactSha256': None, 'masterSha256': None,
        'geometryHash': GEOMETRY, 'revision': REVISION, 'face': 11823, 'vertices': VERTICES,
        'repairedTangent': TANGENT, 'allowedBytes': len(allowed), 'changedBytes': len(changed),
        'allOtherBinBytesIdentical': True, 'nativeAcceptance': 'pending'}

def verify(raw, output):
    canonical, proof = repair(raw)
    actual = EmbeddedGlb(output)
    want = EmbeddedGlb(canonical)
    if actual.doc != want.doc or actual.binary != want.binary or output != canonical:
        raise ValueError('Output differs from canonical reviewed successor')
    positions, normals, uv, tangents, indices = source_face(actual)
    for corner, vertex in enumerate(VERTICES):
        derived = basis([positions[i] for i in VERTICES], [uv[i] for i in VERTICES], normals[vertex], corner)
        t = tangents[vertex]
        if t != TANGENT or abs(norm(t[:3]) - 1) > 1e-6 or abs(dot(t[:3], derived['normal'])) > 1e-6 or dot(cross(derived['normal'], t[:3]), derived['b']) > -1 + 1e-8:
            raise ValueError('Repaired basis failed UV orientation')
    checked = 0
    for mesh in actual.doc['meshes']:
        for p in mesh['primitives']:
            for t in stream(actual, p['attributes']['TANGENT'], 'VEC4'):
                if (any(not math.isfinite(x) for x in t) or abs(norm(t[:3]) - 1) > .001 or
                    t[3] not in (-1., 1.)):
                    raise ValueError('Undefined/invalid source tangent; no zero waiver')
                checked += 1
    return {**proof, 'finiteUnitTangents': checked, 'zeroWaivers': 0}
