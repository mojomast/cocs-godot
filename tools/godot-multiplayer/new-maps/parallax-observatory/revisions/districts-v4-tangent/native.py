"""Future isolated Godot readback gate; no native process is started here."""
import collections
import json
import math
import struct
from pathlib import Path
from contract import EmbeddedGlb, ROOT, SOURCE_SHA, VERTICES, TANGENT, sha, stream, verify
from editable import compare_materials

def oriented(cs):
    rotations = [cs[i:] + cs[:i] for i in range(3)]
    return min(rotations, key=lambda row: tuple(v for corner in row for v in corner[0]))

def check_streams(artifact, report, raw):
    if report['artHash'] != sha(artifact): raise ValueError('Native artifact identity changed')
    g = EmbeddedGlb(artifact)
    parts, total, _ = g.geometry()
    if total != 155553 or len(parts) != 39 or report['triangles'] != total or report['meshNodes'] != 39 or len(report['surfaces']) != 39:
        raise ValueError('Native scene multiplicity changed')
    expected = collections.defaultdict(list)
    for mesh_index, mesh in enumerate(g.doc['meshes']):
        for p in mesh['primitives']:
            a = p['attributes']
            streams = {k: stream(g, a[k], shape) for k, shape in
                       (('POSITION', 'VEC3'), ('NORMAL', 'VEC3'), ('TEXCOORD_0', 'VEC2'), ('TANGENT', 'VEC4'))}
            indices = [x[0] for x in stream(g, p['indices'], 'SCALAR', (5121, 5123, 5125))]
            role = g.doc['materials'][p['material']]['name']
            for i in range(0, len(indices), 3):
                cs = [tuple(streams[k][v] for k in streams) for v in reversed(indices[i:i + 3])]
                cs = oriented(cs)
                marked = mesh_index == 9 and i//3 == 11823
                expected[role, tuple(cs[j][0] for j in range(3))].append((cs, marked))
    count = 0
    affected = 0
    maximum = [0., 0., 0.]
    next_offset = 0
    for surface in report['surfaces']:
        size = surface['vertices']; offset = surface['offset']
        if any(type(surface[k]) is not int or surface[k] < 0 for k in ('vertices', 'indices', 'offset')):
            raise ValueError('Invalid native surface bounds')
        if offset != next_offset: raise ValueError('Native surface offsets overlap or omit bytes')
        arrays = []
        for width in (3, 3, 2, 4):
            if offset + size * width * 4 > len(raw): raise ValueError('Truncated native streams')
            arrays.append([struct.unpack_from('<' + 'f'*width, raw, offset + i*width*4) for i in range(size)])
            offset += size*width*4
        if offset + surface['indices']*4 > len(raw) or surface['indices']%3:
            raise ValueError('Truncated native indices')
        indices = struct.unpack_from('<' + 'I'*surface['indices'], raw, offset)
        next_offset = offset + surface['indices']*4
        for start in range(0, len(indices), 3):
            if any(i >= size for i in indices[start:start+3]): raise ValueError('Native index outside vertex array')
            cs = [tuple(a[i] for a in arrays) for i in indices[start:start+3]]
            if any(not math.isfinite(v) for c in cs for component in c for v in component):
                raise ValueError('Nonfinite native basis')
            if any(abs(math.sqrt(sum(v*v for v in c[3][:3]))-1) > .001 or c[3][3] not in (-1., 1.) for c in cs):
                raise ValueError('Undefined/nonunit native tangent; zero waivers')
            cs = oriented(cs)
            choices = expected[surface['material'], tuple(c[0] for c in cs)]
            # Godot's mesh surfaces may round positions; search a small positional
            # tolerance within the same material rather than permitting reversed faces.
            if not choices:
                candidates = [(k, v) for k, v in expected.items() if k[0] == surface['material'] and
                    all(max(abs(x-y) for x,y in zip(a,b)) <= 1e-5 for a,b in zip(k[1], (c[0] for c in cs)))]
                if len(candidates) != 1: raise ValueError('Native oriented face/role not found')
                choices = candidates[0][1]
            match = None
            for i, (want, marked) in enumerate(choices):
                err = [max(abs(x-y) for c,d in zip(cs,want) for x,y in zip(c[j],d[j])) for j in (1,2,3)]
                if err[0] <= .0002 and err[1] == 0 and err[2] <= .0002:
                    match = i; maximum = [max(x,y) for x,y in zip(maximum,err)]
                    if marked: affected += 3
                    break
            if match is None: raise ValueError('Native normal/UV/tangent/handedness drift; no fallback waiver')
            choices.pop(match); count += 1
    if next_offset != len(raw) or any(expected.values()) or count != total or affected != 3:
        raise ValueError('Native face coverage or all three repaired corners missing')
    return {'triangles': count, 'maxNormalUVTangentError': maximum, 'zeroTangentWaivers': 0,
            'repairedCornerMatchesAtLeast': affected}

def check(artifact, report, streams, baseline):
    verify(baseline, artifact)
    proof = check_streams(artifact, report, streams)
    # Reuse R7's decoded source semantics + four-decimal Godot color precision.
    from material_contract import verify_native_materials, pixel_identity
    g = EmbeddedGlb(artifact)
    proof['materialFieldSets'] = verify_native_materials(g, report)
    comparisons = 0
    from material_pack import linear_rgba
    for mat in g.doc['materials']:
        p = mat.get('pbrMetallicRoughness', {})
        for channel, slot, components in (('albedo', p.get('baseColorTexture'), (0,1,2,3)),
               ('normal', mat.get('normalTexture'), (0,1,2)),
               ('roughness', p.get('metallicRoughnessTexture'), (1,2))):
            if slot is None: continue
            image = report['materials'][mat['name']]['images'][channel]
            path = image['path']
            prefix = 'res://tests/new_maps/parallax_tangent/'
            if not path.startswith(prefix) or '..' in Path(path).parts:
                raise ValueError('Native image escaped isolated stage')
            data = ROOT / 'godot' / path.removeprefix('res://')
            if sha(data.read_bytes()) != image['sha256'] or pixel_identity(g.image_bytes(slot),components) != pixel_identity(data.read_bytes(),components):
                raise ValueError('Native decoded PBR channel differs')
            comparisons += 1
    proof.update({'materialChannels': comparisons, 'manualAcceptance': 'pending', 'hostedModes': 'pending'})
    return proof
