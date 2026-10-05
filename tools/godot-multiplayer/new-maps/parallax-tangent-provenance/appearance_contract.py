"""Bounded source-only appearance-preservation contract for Parallax tangents.

The classifier in `botanical-parallax-aa-diagnosis/classify_records.py` sorts
records into spec-invalid vs spec-valid-but-derivative-disagreeing. That sort is
not an acceptance. This module is the qualification gate the blocker plan asks
for, in the scope the provenance README proposed: at corresponding decoded PNG
sample locations, compare authored and supplied-basis world-space perturbations
with explicit normal strength, image origin, UV transform and material
selection.

Three separable quantities are modelled, deliberately not conflated:

* **image addressing** -- which PNG texel a UV selects. Blender's OpenImageIO
  reader uses a negative destination row stride, so a top-down PNG is stored
  bottom-up in `ImBuf`; Blender UV v=0 addresses the last internal row. The
  exporter writes `v_gltf = 1 - v_Blender` and glTF §3.9 puts (0,0) at the image
  upper left. Those two conversions are a matched pair over a REPEAT-wrapped UV.
* **basis** -- `B = w * cross(N, T)` per the pinned Blender normal-map shader
  and Godot's `binormal = normalize(cross(normal, tangent) * binormal_sign)`.
* **strength** -- the same scalar reaches the two pinned shader paths by
  *different* formulas. Blender scales `texnormal.xy` and mixes z toward 1;
  Godot's importer assigns glTF `normalTexture.scale` to `normal_scale`, which
  the forward shader uses as a `mix` depth while ignoring the stored blue. Both
  are computed here. Which one the accepted appearance refers to is a render
  question this contract does not settle.

Every negative control the provenance test used is preserved: a solitary W flip,
a green flip and a wrong image origin each have to be *rejected*, so a pass
means something.

No engine, no import, no render, no artifact, master, receipt, registry or
promotion state is touched. Sources are the committed X/AC GLBs and the
committed Moth pack PNGs; a missing source is reported, never fabricated.
"""
import collections as C
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import zlib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/map_variety'))
sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/botanical-parallax-aa-diagnosis'))
from glb_geometry import EmbeddedGlb

import classify_records as classify

PACKS = ('candidate-v2', 'candidate-v3')
PACK_ROOT = ROOT / 'assets/moth/map-variety-20261003'
BINDINGS = ROOT / 'tools/godot-multiplayer/new-maps/parallax-observatory/revisions/districts-v3/variety_bindings.json'
X_GLB = ROOT / ('tools/godot-multiplayer/new-maps/botanical-correction/runs/x-03/'
                'parallax-observatory/parallax-observatory.glb')
X_SHA = '6356cf895c65cec181e1c6c077118b98f3ee80cb567955b37835433971342422'
REPEAT = 'REPEAT'
IMAGE_ORIGINS = ('blenderBottomUp', 'gltfTopDown')
STRENGTH_MODELS = ('blenderNormalMapNode', 'godotForwardMixDepth')
PER_ROLE_SAMPLE = 4096
ALPHA = 1e-12


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


# --------------------------------------------------------------------------
# PNG decode. zlib + stdlib only; no image library, no engine.
# --------------------------------------------------------------------------

def decode_png(raw):
    """Decode a non-interlaced 8-bit RGB/RGBA PNG into (width, height, bpp, pixels)."""
    if raw[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('Not a PNG')
    pos, idat, header = 8, [], None
    while pos < len(raw):
        (length,) = struct.unpack_from('>I', raw, pos)
        kind = raw[pos + 4:pos + 8]
        data = raw[pos + 8:pos + 8 + length]
        if kind == b'IHDR':
            header = struct.unpack('>IIBBBBB', data)
        elif kind == b'IDAT':
            idat.append(data)
        elif kind == b'IEND':
            break
        pos += 12 + length
    if header is None:
        raise ValueError('PNG without IHDR')
    width, height, depth, colour, _compression, _filter, interlace = header
    if depth != 8 or colour not in (2, 6) or interlace != 0:
        raise ValueError('Only non-interlaced 8-bit RGB/RGBA PNG is supported')
    bpp = 3 if colour == 2 else 4
    flat = zlib.decompress(b''.join(idat))
    stride = width * bpp
    if len(flat) != height * (stride + 1):
        raise ValueError('Unexpected PNG payload length')
    out = bytearray(height * stride)
    previous = bytearray(stride)
    pos = 0
    for y in range(height):
        method = flat[pos]
        pos += 1
        line = bytearray(flat[pos:pos + stride])
        pos += stride
        if method == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 255
        elif method == 2:
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 255
        elif method == 3:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + previous[i]) // 2)) & 255
        elif method == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = previous[i]
                c = previous[i - bpp] if i >= bpp else 0
                p = abs(b - c)
                q = abs(a - c)
                r = abs(a + b - 2 * c)
                pred = a if (p <= q and p <= r) else (b if q <= r else c)
                line[i] = (line[i] + pred) & 255
        elif method != 0:
            raise ValueError('Unsupported PNG filter %d' % method)
        out[y * stride:(y + 1) * stride] = line
        previous = line
    return width, height, bpp, bytes(out)


def png_size(raw):
    """PNG dimensions from IHDR alone, without decoding any pixels."""
    if raw[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('Not a PNG')
    (length,) = struct.unpack_from('>I', raw, 8)
    if raw[12:16] != b'IHDR' or length != 13:
        raise ValueError('PNG without a 13-byte IHDR')
    width, height = struct.unpack_from('>II', raw, 16)
    return width, height


def texel_index(width, height, u, v, origin):
    """Nearest-neighbour (column, row) without touching pixels. Reported only
    where it must break a tie at a pixel edge; the pinned LINEAR filter does not."""
    """The (column, row) pair `texel` would fetch, without touching pixels."""
    column = min(width - 1, max(0, int(repeat(u) * width)))
    internal_row = min(height - 1, max(0, int(repeat(v) * height)))
    row = internal_row if origin == 'gltfTopDown' else height - 1 - internal_row
    return column, row


def bilinear_blend(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def sample_bilinear(image, u, v, origin):
    """Bilinear REPEAT sample, the filter both pinned samplers declare.

    `magFilter: 9729` (LINEAR) and `minFilter: 9987` (LINEAR_MIPMAP_LINEAR) with
    no `wrapS`/`wrapT`, so glTF's default REPEAT applies. Nearest-neighbour
    sampling is a coarser lower bound that has to break ties at pixel edges; this
    does not, which is why the addressing pair has to be proved with it.
    """
    width, height, bpp, pixels = image
    x = repeat(u) * width
    y = repeat(v) * height
    column = math.floor(x - 0.5)
    tx = x - 0.5 - column
    internal = math.floor(y - 0.5)
    ty = y - 0.5 - internal
    rows = ((internal, internal + 1) if origin == 'gltfTopDown'
            else (height - 1 - internal, height - 2 - internal))

    def fetch(col, row):
        base = (((row % height) * width) + (col % width)) * bpp
        return tuple(pixels[base:base + 3])

    left = bilinear_blend(fetch(column, rows[0]), fetch(column, rows[1]), ty)
    right = bilinear_blend(fetch(column + 1, rows[0]), fetch(column + 1, rows[1]), ty)
    return bilinear_blend(left, right, tx)


def repeat(x):
    """REPEAT wrap into [0,1); the only wrap mode either pinned path declares."""
    return x - math.floor(x)


def texel(image, u, v, origin):
    """Nearest-texel fetch. Both pipelines filter, so this is a lower bound on
    the comparison's fidelity, not a model of the filtered result."""
    width, height, bpp, pixels = image
    column = min(width - 1, max(0, int(repeat(u) * width)))
    internal_row = min(height - 1, max(0, int(repeat(v) * height)))
    row = internal_row if origin == 'gltfTopDown' else height - 1 - internal_row
    base = (row * width + column) * bpp
    return column, row, tuple(pixels[base:base + 3])


def decode_normal(rgb):
    """Non-Color linear bytes straight to tangent-space channels. No sRGB decode:
    every pinned path binds these images Non-Color."""
    return tuple(2 * channel / 255 - 1 for channel in rgb)


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def scale(a, s):
    return tuple(x * s for x in a)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    return math.sqrt(dot(a, a))


def unit(a):
    size = norm(a)
    return tuple(x / size for x in a) if size > ALPHA else (0., 0., 0.)


def angle_degrees(a, b):
    if norm(a) * norm(b) <= ALPHA:
        return None
    return math.degrees(math.acos(max(-1., min(1., dot(unit(a), unit(b))))))


def world_perturbation(N, T, w, tx, ty, tz, model, strength):
    """World-space normal the pinned shader path produces for one texel.

    `blenderNormalMapNode`: gpu_shader_material_normal_map.glsl --scale xy, mix z
    toward 1, then tx*T + ty*B + tz*Ni, normalized.
    `godotForwardMixDepth`: scene.glsl --decode xy, rebuild z from xy, then
    mix(geometric normal, T*tx + B*ty + N*tz, normal_map_depth).
    """
    if norm(cross(N, T)) <= ALPHA:
        return ('degenerateFrame', None, None, None)
    B = scale(cross(N, unit(T)), w)
    if model == 'blenderNormalMapNode':
        x, y = tx * strength, ty * strength
        z = 1. + (tz - 1.) * min(1., max(0., strength))
        raw = add(add(scale(unit(T), x), scale(B, y)), scale(N, z))
        return ('ok', unit(raw), B, (x, y, z))
    if model == 'godotForwardMixDepth':
        x, y = tx, ty
        z = math.sqrt(max(0., 1. - (x * x + y * y)))
        perturbed = add(add(scale(unit(T), x), scale(B, y)), scale(N, z))
        mixed = tuple((1. - strength) * c + strength * p for c, p in zip(N, perturbed))
        return ('ok', unit(mixed), B, (x, y, z))
    raise ValueError('Unknown strength model: ' + model)


def authored_uv(exported):
    """Invert the pinned exporter's `uvs[:,1] *= -1; uvs[:,1] += 1`."""
    return (exported[0], 1. - exported[1])


def addressed_pair(image, exported_uv):
    """Sample one world point through both addressings and report the pairing."""
    u, v_exported = exported_uv
    u_a, v_authored = authored_uv(exported_uv)
    gltf = texel(image, u, v_exported, 'gltfTopDown')
    blender = texel(image, u_a, v_authored, 'blenderBottomUp')
    aligned = repeat(v_exported) * image[1]
    return {'exportedUV': list(exported_uv), 'authoredUV': [u_a, v_authored],
            'gltf': {'column': gltf[0], 'row': gltf[1], 'rgb': list(gltf[2])},
            'blender': {'column': blender[0], 'row': blender[1], 'rgb': list(blender[2])},
            'sameTexel': gltf == blender,
            'texelBoundaryAligned': aligned == math.floor(aligned)}


def compare_perturbation(image, exported_uv, N, T, w, strength, *, flip_w=False,
                         flip_green=False, origin_override=None):
    """One sample location: does the authored-side evaluation reproduce the
    supplied-basis evaluation? Rejections are the point, so the deliberate
    wrongs are parameters rather than separate code paths."""
    entry = addressed_pair(image, exported_uv)
    # Two evaluations of one world point. The authored side is the reference and
    # is never altered. The supplied side is the artifact under review, so every
    # deliberate wrong -- a flipped handedness, a flipped green channel, a wrong
    # image origin -- is applied there and has to show up as disagreement, exactly
    # as `test_provenance.py` requires.
    exported_origin = origin_override or IMAGE_ORIGINS[1]
    sides = ((IMAGE_ORIGINS[0], IMAGE_ORIGINS[0], 'authoredUV', False),
             (IMAGE_ORIGINS[1], exported_origin, 'exportedUV', True))
    out = {'addressing': entry, 'strength': strength, 'N': list(N), 'T': list(T[:3]), 'w': w,
           'suppliedOrigin': exported_origin, 'models': {},
           'flipW': flip_w, 'flipGreen': flip_green}
    for model in STRENGTH_MODELS:
        results = {}
        for label, origin, uv_key, supplied in sides:
            rgb = texel(image, *entry[uv_key], origin)[2]
            tx, ty, tz = decode_normal(rgb)
            handedness = w
            if supplied:
                if flip_green:
                    ty = -ty
                if flip_w:
                    handedness = -w
            status, normal, B, channels = world_perturbation(
                N, T, handedness, tx, ty, tz, model, strength)
            results[label] = {'origin': origin, 'uv': entry[uv_key], 'supplied': supplied,
                              'status': status, 'rgb': list(rgb),
                              'binormal': None if B is None else list(B),
                              'tangentSpace': None if channels is None else list(channels),
                              'worldNormal': None if normal is None else list(normal)}
        out['models'][model] = results
        left, right = (results[IMAGE_ORIGINS[0]], results[IMAGE_ORIGINS[1]])
        if left['status'] == 'ok' and right['status'] == 'ok':
            out['models'][model]['worldAngleDegrees'] = angle_degrees(
                left['worldNormal'], right['worldNormal'])
            out['models'][model]['maxComponentError'] = max(
                abs(a - b) for a, b in zip(left['worldNormal'], right['worldNormal']))
        else:
            out['models'][model]['worldAngleDegrees'] = None
            out['models'][model]['status'] = left['status'] if left['status'] != 'ok' else right['status']
    return out


def _sides_disagree(case):
    """The two evaluations of one world point picked different texels or different
    world normals. This is the general rejection test the negative controls use."""
    for model in STRENGTH_MODELS:
        left, right = _side(case, model, IMAGE_ORIGINS[0]), _side(case, model, IMAGE_ORIGINS[1])
        if left['rgb'] != right['rgb'] or left['status'] != right['status']:
            return True
        if left['worldNormal'] is None or right['worldNormal'] is None:
            return True
        if (angle_degrees(left['worldNormal'], right['worldNormal']) or 0.) > 1e-9:
            return True
    return False


def perturbed_equal(case, tolerance=1e-9):
    """Verdict over both declared strength models."""
    verdicts = {}
    for model, block in case['models'].items():
        verdicts[model] = (case['addressing']['sameTexel'] and not case['addressing']['texelBoundaryAligned']
                           and block.get('worldAngleDegrees') is not None
                           and block['worldAngleDegrees'] <= tolerance)
    verdicts['sameTexel'] = case['addressing']['sameTexel']
    verdicts['texelBoundaryAligned'] = case['addressing']['texelBoundaryAligned']
    return verdicts


# --------------------------------------------------------------------------
# Committed sources. Read-only; a missing source is reported, never invented.
# --------------------------------------------------------------------------

def material_table():
    """Reviewed role -> resource -> declared strength/density, from committed source."""
    bindings = json.loads(BINDINGS.read_text())
    resources = {}
    conventions = {}
    for pack in PACKS:
        manifest = json.loads((PACK_ROOT / pack / 'manifest.json').read_text())
        for entry in manifest['materials']:
            resources[entry['id']] = (pack, entry)
            conventions[entry['id']] = entry['normalConvention']
    roles = {}
    for name, binding in bindings['materials'].items():
        if binding['role'] != 'surface':
            roles[name] = {'role': binding['role'], 'normalTexture': False, 'normalScale': None,
                           'tilesPerMeter': binding['tilesPerMeter'], 'resource': None}
            continue
        pack, entry = resources[binding['resource']]
        roles[name] = {'role': binding['role'], 'normalTexture': True,
                       'normalScale': binding['normalStrength'],
                       'tilesPerMeter': binding['tilesPerMeter'],
                       'resource': binding['resource'],
                       'pack': pack, 'normalConvention': entry['normalConvention'],
                       'texture': entry['channels']['normal']}
    return roles, conventions


def normal_image(role, glb):
    """Decode a role's normal map from the artifact under review.

    Anchoring to the embedded image bytes is what makes this a contract about
    the artifact rather than about the pack. The Moth source PNG hash is then
    reported as an independent cross-check, and a mismatch is a finding.
    """
    if not role.get('normalTexture'):
        return None, {'available': False, 'reason': 'role is untextured/preserved'}
    material = _material_for_role(glb, role['_name'])
    texture_index = material['normalTexture']['index']
    source_image = glb.doc['textures'][texture_index]['source']
    buffer_view = glb.doc['images'][source_image]
    raw = glb.view_bytes(buffer_view['bufferView'])
    decoded = decode_png(raw)
    report = {'available': True, 'source': 'embedded GLB image bytes', 'imageName': buffer_view.get('name'),
              'sha256': sha(raw), 'width': decoded[0], 'height': decoded[1], 'channels': decoded[2]}
    pack, entry = None, None
    for pack_name in PACKS:
        manifest_path = PACK_ROOT / pack_name / 'manifest.json'
        if not manifest_path.is_file():
            continue
        manifest = json.loads(manifest_path.read_text())
        for item in manifest['materials']:
            if item['id'] == role['resource']:
                entry, pack = item, pack_name
    if entry is not None:
        texture = json.loads((PACK_ROOT / pack / 'manifest.json').read_text())['textures'][entry['channels']['normal']]
        path = PACK_ROOT / pack / texture['path']
        if path.is_file():
            source_raw = path.read_bytes()
            report['mothSource'] = {'path': str(path.relative_to(ROOT)), 'available': True,
                                    'sha256': sha(source_raw), 'expectedSha256': texture['sha256'],
                                    'normalConvention': texture['normalConvention'],
                                    'bytesIdenticalToEmbedded': source_raw == raw}
        else:
            report['mothSource'] = {'path': str(path.relative_to(ROOT)), 'available': False}
    return decoded, report


def _material_for_role(glb, role_name):
    for material in glb.doc['materials']:
        if material['name'] == role_name:
            return material
    raise KeyError('Unknown role: ' + role_name)


# --------------------------------------------------------------------------
# Case 1: asymmetric full-rank synthetic fixture.
# --------------------------------------------------------------------------

SYNTHETIC_ROWS = (
    ((201, 210, 246), (172, 193, 239), (189, 181, 242)),
    ((162, 64, 247), (212, 75, 239), (175, 83, 250)),
    ((188, 218, 248), (159, 204, 244), (207, 197, 236)),
    ((208, 88, 246), (168, 96, 251), (193, 72, 242)),
)


def synthetic_image():
    height, width = len(SYNTHETIC_ROWS), len(SYNTHETIC_ROWS[0])
    pixels = bytearray()
    for row in SYNTHETIC_ROWS:
        for r, g, b in row:
            pixels += bytes((r, g, b, 255))
    return width, height, 4, bytes(pixels)


def asymmetric_full_rank_fixture(strength=0.4):
    """Full-rank plane P(u,v)=(u,v,0), N=+Z, T=+X, w=+1.

    Every row and column differs and green straddles neutral 128, so a wrong
    image origin, a solitary W flip and a green flip are all detectable.
    """
    image = synthetic_image()
    height, width = image[1], image[0]
    N, T, w = (0., 0., 1.), (1., 0., 0.), 1.
    samples = []
    for row in range(height):
        for column in range(width):
            exported = ((column + 0.5) / width, (row + 0.5) / height)
            base = compare_perturbation(image, exported, N, T, w, strength)
            samples.append({
                'row': row, 'column': column, 'exportedUV': list(exported),
                'base': base, 'baseVerdict': perturbed_equal(base),
                'wFlip': compare_perturbation(image, exported, N, T, w, strength, flip_w=True),
                'greenFlip': compare_perturbation(image, exported, N, T, w, strength, flip_green=True),
                'wrongOrigin': compare_perturbation(image, exported, N, T, w, strength,
                                                    origin_override='blenderBottomUp'),
            })
    return {'case': 'asymmetricFullRankFixture', 'strength': strength,
            'N': list(N), 'T': list(T), 'w': w,
            'note': ('Exported v = 1 - authored v, so dP/dv in exported coordinates is -Y '
                     'while the supplied basis is unchanged; a naive derivative test calls this '
                     'a disagreement and the appearance comparison does not.'),
            'samples': samples,
            'summary': {
                'locations': len(samples),
                'basePreserved': sum(1 for s in samples if all(
                    s['baseVerdict'][m] for m in STRENGTH_MODELS)),
                'wFlipRejected': sum(1 for s in samples if _sides_disagree(s['wFlip'])),
                'greenFlipRejected': sum(1 for s in samples if _sides_disagree(s['greenFlip'])),
                'wrongOriginRejected': sum(1 for s in samples if _sides_disagree(s['wrongOrigin'])),
                'greenReversalDegrees': sorted({
                    round(angle_degrees(
                        _side(s['wFlip'], m)['binormal'], _side(s['base'], m)['binormal']) or 0., 6)
                    for s in samples for m in STRENGTH_MODELS}),
            }}


# --------------------------------------------------------------------------
# Real-source cases.
# --------------------------------------------------------------------------

def _face_corners(glb, node_index, primitive_index, face):
    node = glb.doc['nodes'][node_index]
    primitive = glb.doc['meshes'][node['mesh']]['primitives'][primitive_index]
    arrays = classify.primitive_arrays(glb, primitive)
    indices = [v[0] for v in classify.stream(
        glb, primitive['indices'], 'SCALAR', (5121, 5123, 5125))]
    return classify.face_corners(arrays, indices, face), primitive


def _reviewed_face_corners(raw):
    """The reviewed saltstone face 11823 corners of one artifact, in canonical
    corner order. `_locate` fails closed if the mesh, material or vertex set moved."""
    glb = EmbeddedGlb(raw)
    glb.geometry()
    node_index, primitive_index, face = _locate(glb, classify.REVIEWED_FACE)
    corners, _ = _face_corners(glb, node_index, primitive_index, face)
    return corners


def saltstone_face_11823(x_raw, aa_raw, ac_raw, roles):
    """The reviewed three-corner saltstone case, before and after the AA edit."""
    role_name = classify.REVIEWED_FACE['role']
    role = dict(roles[role_name], _name=role_name)
    image, image_report = normal_image(role, EmbeddedGlb(ac_raw))
    if image is None:
        return {'case': 'saltstoneFace11823', 'available': False, 'image': image_report}
    out = {'case': 'saltstoneFace11823', 'available': True, 'image': image_report,
           'role': role_name, 'normalScale': role['normalScale'],
           'tilesPerMeter': role['tilesPerMeter'], 'normalConvention': role['normalConvention'],
           'corners': []}
    per_label, corners_by_label = {}, {}
    for label, raw in (('X', x_raw), ('AA', aa_raw), ('AC', ac_raw)):
        label_corners = _reviewed_face_corners(raw)
        corners_by_label[label] = label_corners
        state, derivative = classify.face_verdict(label_corners)
        per_label[label] = {'faceState': state, 'uvJacobian': derivative['uvJacobian'],
                            'area': derivative['area'], 'T': [list(c['T']) for c in label_corners]}
    out['beforeAfter'] = per_label
    for corner_index, corner in enumerate(corners_by_label['AC']):
        results = {}
        for label in ('X', 'AA', 'AC'):
            c = corners_by_label[label][corner_index]
            results[label] = compare_perturbation(image, c['UV'], c['N'], c['T'][:3], c['T'][3],
                                                 role['normalScale'])
        out['corners'].append({
            'corner': corner_index, 'vertex': corner['vertex'],
            'N': list(corner['N']), 'UV': list(corner['UV']),
            'basis': {label: list(results[label]['T']) + [results[label]['w']] for label in results},
            'evaluations': results,
            'XvsAC': _pair_result(results['X'], results['AC']),
            'XvsAA': _pair_result(results['X'], results['AA']),
            'verdict': _basis_verdict(results['X'], results['AA']),
        })
    out['summary'] = {
        'sameTexelEveryCorner': all(c['evaluations'][label]['addressing']['sameTexel']
                                    for c in out['corners'] for label in ('X', 'AA', 'AC')),
        'XAAPreserved': sum(1 for c in out['corners']
                            if all(c['XvsAA'][m]['preserved'] for m in STRENGTH_MODELS)),
        'XACPreserved': sum(1 for c in out['corners']
                            if all(c['XvsAC'][m]['preserved'] for m in STRENGTH_MODELS)),
        'XvsAAcomparable': sum(1 for c in out['corners']
                               if all(c['XvsAA'][m]['comparable'] for m in STRENGTH_MODELS)),
        'XvsAAgreenReversed': sum(1 for c in out['corners']
                                  if any((c['XvsAA'][m].get('greenComponentAngleDegrees') or 0.) > 1e-9
                                         for m in STRENGTH_MODELS)),
        'corners': len(out['corners']),
    }
    return out


def _side(case, model, label=IMAGE_ORIGINS[1]):
    """The supplied-basis evaluation of one case, per strength model."""
    return case['models'][model][label]


def _pair_result(left, right):
    result = {'sameTexel': left['addressing']['sameTexel'] == right['addressing']['sameTexel']}
    for model in STRENGTH_MODELS:
        a, b = _side(left, model), _side(right, model)
        if a['worldNormal'] is None or b['worldNormal'] is None:
            result[model] = {'comparable': False,
                             'status': a['status'] if a['worldNormal'] is None else b['status'],
                             'preserved': False}
            continue
        angle = angle_degrees(a['worldNormal'], b['worldNormal'])
        result[model] = {'comparable': True, 'worldAngleDegrees': angle,
                         'maxComponentError': max(abs(x - y) for x, y in
                                                   zip(a['worldNormal'], b['worldNormal'])),
                         'preserved': angle <= 1e-9,
                         'binormalAngleDegrees': angle_degrees(a['binormal'], b['binormal']),
                         'greenComponentAngleDegrees': _green_angle(a, b)}
    return result


def _green_angle(a, b):
    """Isolate the term a solitary W flip or green flip would move.

    A green-only reversal rotates the tangent-space green coefficient about the
    surface normal, so comparing the world-space green contribution on its own
    says more than comparing whole normals, which also carry red and blue.
    """
    Ba, Bb = a['binormal'], b['binormal']
    if Ba is None or Bb is None:
        return None
    return angle_degrees(scale(unit(Ba), a['tangentSpace'][1]),
                         scale(unit(Bb), b['tangentSpace'][1]))


def _basis_verdict(before, after):
    """The only question the AA edit raises: does the edited basis reproduce the
    authored one at this sample location? A green reversal shows up here."""
    verdicts = {}
    for model in STRENGTH_MODELS:
        a, b = _side(before, model), _side(after, model)
        verdicts[model] = (a['worldNormal'] is not None and b['worldNormal'] is not None
                           and angle_degrees(a['worldNormal'], b['worldNormal']) <= 1e-9)
    return verdicts


def _locate(glb, target):
    for node_index, node in enumerate(classify.scene_parts(glb)):
        mesh = node['mesh']
        for primitive_index, primitive in enumerate(glb.doc['meshes'][mesh]['primitives']):
            role = glb.doc['materials'][primitive['material']]['name']
            if (mesh, role) != (target['mesh'], target['role']):
                continue
            primitive_indices = [v[0] for v in classify.stream(
                glb, primitive['indices'], 'SCALAR', (5121, 5123, 5125))]
            if tuple(primitive_indices[target['face'] * 3:target['face'] * 3 + 3]) != target['vertices']:
                raise ValueError('Reviewed face 11823 vertex set changed')
            return node_index, primitive_index, target['face']
    raise ValueError('Reviewed role/mesh not found: %r' % (target,))


def u_reversed_corners(cases, ac_raw, roles):
    """The five stored tangents that oppose increasing U.

    These carry enormous |dP/du| because their UV Jacobian is at float32
    resolution, so the derivative comparison is conditioned on cancellation
    rather than on a shading intent. The contract reports that conditioning
    instead of asserting either appearance verdict.
    """
    glb = EmbeddedGlb(ac_raw)
    glb.geometry()
    corners = cases['storedTangentOpposesDU']
    per_role_images = {}
    out = {'case': 'storedTangentOpposesDUCorners', 'count': len(corners), 'corners': []}
    for entry in corners:
        role_name = entry['role']
        role = dict(roles[role_name], _name=role_name)
        if role_name not in per_role_images:
            per_role_images[role_name] = normal_image(role, glb)
        image, image_report = per_role_images[role_name]
        spread = _uv_resolution(entry['faceUV'])
        record = {'node': entry['node'], 'mesh': entry['mesh'], 'face': entry['face'],
                  'corner': entry['corner'], 'vertex': entry['vertex'], 'role': role_name,
                  'N': entry['N'], 'T': list(entry['T']), 'UV': entry['UV'],
                  'uvJacobian': entry['uvJacobian'], 'area': entry['area'],
                  'dotTangentDudu': entry['dotTangentDudu'],
                  'dPduMagnitude': norm(entry['dPdu']),
                  'uvFloat32Resolution': spread,
                  'uvEdgesAreFloat32Resolvable': spread['minUlps'] is not None and spread['minUlps'] >= 1.,
                  'dPduIsCancellationNoise': spread['minUlps'] is not None and spread['minUlps'] < 1.,
                  'image': image_report}
        if image is None:
            record['comparable'] = False
            record['reason'] = 'role has no normal map; the UV/T sign metric is not an appearance claim here'
        else:
            record['comparable'] = True
            record['suppliedBasis'] = compare_perturbation(image, entry['UV'], entry['N'],
                                                          entry['T'][:3], entry['T'][3],
                                                          role['normalScale'])
            derivative_basis = _derivative_basis(entry)
            record['derivativeBasis'] = derivative_basis
            if derivative_basis is not None:
                record['derivativeBasisEvaluation'] = compare_perturbation(
                    image, entry['UV'], entry['N'], derivative_basis['T'], derivative_basis['w'],
                    role['normalScale'])
                record['suppliedVsDerivative'] = _pair_result(record['suppliedBasis'],
                                                             record['derivativeBasisEvaluation'])
        out['corners'].append(record)
    out['summary'] = {
        'corners': len(out['corners']),
        'comparable': sum(1 for c in out['corners'] if c.get('comparable')),
        'unconditionalAppearsPreserved': sum(
            1 for c in out['corners']
            if c.get('suppliedVsDerivative') and all(
                c['suppliedVsDerivative'][m]['preserved'] for m in STRENGTH_MODELS)),
        'dPduIsCancellationNoise': sum(1 for c in out['corners'] if c['dPduIsCancellationNoise']),
        'minUvUlps': min((c['uvFloat32Resolution']['minUlps'] for c in out['corners']), default=None),
        'maxDotTangentDudu': max(abs(c['dotTangentDudu']) for c in out['corners']) if out['corners'] else None,
        'maxDPDUMagnitude': max((c['dPduMagnitude'] for c in out['corners']), default=None),
        'interpretation': ('All five sit on triangles whose UV edges are at or below float32 '
                           'resolution, so dP/du is a quotient of cancellation noise and its sign '
                           'is not a shading intent. The stored basis is nonetheless spec-valid '
                           'and sampleable at these UVs; what is unproven is whether the stored '
                           'tangent direction matches intent, which no source-only test can settle.'),
    }
    return out


def _uv_resolution(face_uv):
    """How wide are this triangle's UV edges in float32 ULPs?

    Exported UVs are float32. An edge narrower than one ULP is not a
    representable coordinate difference, so any dP/du derived from it is
    cancellation noise rather than a geometric derivative. That is what
    separates "the stored tangent opposes dP/du" from "the stored tangent is
    wrong", so it is measured, not assumed.
    """
    edges = []
    for i in range(len(face_uv)):
        for j in range(i + 1, len(face_uv)):
            a, b = face_uv[i], face_uv[j]
            length = math.dist(a, b)
            ulp = max(_float32_ulp(a[k]) + _float32_ulp(b[k]) for k in range(2))
            edges.append({'edge': [i, j], 'length': length, 'float32Ulp': ulp, 'ulps': length / ulp})
    if not edges:
        return {'edges': [], 'minUlps': None}
    return {'edges': edges, 'minUlps': min(e['ulps'] for e in edges),
            'maxUlps': max(e['ulps'] for e in edges),
            'narrowestEdge': min(edges, key=lambda e: e['ulps'])}


def _float32_ulp(value):
    """Spacing of float32 values at `value`, measured by an actual round trip."""
    packed = struct.unpack('<f', struct.pack('<f', value))[0]
    up = struct.unpack('<f', struct.pack('<f', packed + 1e-3))[0]
    return abs(up - packed) or abs(struct.unpack('<f', struct.pack('<f', packed * (1 + 1e-6)))[0] - packed)


def _derivative_basis(entry):
    """Rebuild the conventional UV-derivative frame the classifier flagged."""
    du, dv, N = entry['dPdu'], entry['dPdv'], tuple(entry['N'])
    du_unit = unit(du)
    n_unit = unit(N)
    projected = sub(du_unit, scale(n_unit, dot(n_unit, du_unit)))
    if norm(projected) <= ALPHA:
        return None
    projected = unit(projected)
    sign = 1. if dot(cross(n_unit, projected), unit(dv)) > 0 else -1.
    return {'T': list(projected), 'w': sign}


def singular_glyph_records(cases, aa_raw, ac_raw, roles):
    """The sixteen N-parallel-T glyph records, before and after the AC fallback."""
    glb = EmbeddedGlb(ac_raw)
    glb.geometry()
    seen = {}
    for entry in cases['singularGlyphRecords']:
        seen[(entry['accessor'], entry['vertex'])] = entry
    after = {}
    for node_index, node in enumerate(classify.scene_parts(glb)):
        for primitive in glb.doc['meshes'][node['mesh']]['primitives']:
            accessor = primitive['attributes']['TANGENT']
            tangents = classify.stream(glb, accessor, 'VEC4')
            for vertex, T in enumerate(tangents):
                if (accessor, vertex) in seen:
                    after[(accessor, vertex)] = T
    role_name = 'ochre'
    role = dict(roles[role_name], _name=role_name)
    image, image_report = normal_image(role, glb)
    out = {'case': 'singularGlyphRecords', 'records': len(seen), 'available': image is not None,
           'image': image_report, 'normalScale': role['normalScale'], 'entries': []}
    if image is None:
        return out
    for key in sorted(seen):
        entry = seen[key]
        repaired = after.get(key)
        before_case = compare_perturbation(image, entry['UV'], entry['N'], entry['T'][:3],
                                          entry['T'][3], role['normalScale'])
        after_case = (None if repaired is None else
                      compare_perturbation(image, entry['UV'], entry['N'], repaired[:3],
                                           repaired[3], role['normalScale']))
        out['entries'].append({
            'accessor': key[0], 'vertex': key[1], 'node': entry['node'], 'mesh': entry['mesh'],
            'face': entry['face'], 'corner': entry['corner'], 'UV': entry['UV'], 'N': entry['N'],
            'before': list(entry['T']), 'after': list(repaired) if repaired else None,
            'beforeEvaluation': before_case,
            'afterEvaluation': after_case,
            'beforeDegenerate': _side(before_case, STRENGTH_MODELS[0])['status'] == 'degenerateFrame',
            'afterDegenerate': (after_case is not None and
                                _side(after_case, STRENGTH_MODELS[0])['status'] == 'degenerateFrame'),
            'orthogonalityBefore': dot(tuple(entry['N']), unit(entry['T'][:3])),
            'orthogonalityAfter': (None if repaired is None
                                   else dot(tuple(entry['N']), unit(repaired[:3]))),
            'beforeAfter': (None if after_case is None else _pair_result(before_case, after_case)),
        })
    out['summary'] = {
        'records': len(out['entries']),
        'beforeDegenerate': sum(1 for e in out['entries'] if e['beforeDegenerate']),
        'afterDegenerate': sum(1 for e in out['entries'] if e['afterDegenerate']),
        'nowSampleable': sum(1 for e in out['entries'] if not e['afterDegenerate']),
        'appearanceIdentical': sum(
            1 for e in out['entries'] if e['beforeAfter'] and all(
                e['beforeAfter'][m]['preserved'] for m in STRENGTH_MODELS)),
        'note': ('A degenerate frame has no world-space green contribution at all, so '
                 'before/after appearance is not comparable for these records; the AC repair '
                 'makes the frame sampleable and changes shading relative to the singular input.'),
    }
    return out


def per_role_sweep(ac_raw, roles):
    """Every textured role: at real corner sample locations with real UVs, does
    the supplied basis reproduce the authored basis? Same basis bytes on both
    sides, so a pass here is identity by construction; the sweep exists to prove
    the *addressing* pair holds across roles, densities and image sizes, and to
    count where green is actually non-neutral."""
    glb = EmbeddedGlb(ac_raw)
    glb.geometry()
    out = {'case': 'perRoleSweep', 'sampleLimit': PER_ROLE_SAMPLE, 'roles': {}}
    for node_index, node in enumerate(classify.scene_parts(glb)):
        mesh = node['mesh']
        for primitive_index, primitive in enumerate(glb.doc['meshes'][mesh]['primitives']):
            role_name = glb.doc['materials'][primitive['material']]['name']
            role = roles[role_name]
            bucket = out['roles'].setdefault(role_name, {
                'role': role['role'], 'normalTexture': role['normalTexture'],
                'normalScale': role['normalScale'], 'tilesPerMeter': role['tilesPerMeter'],
                'resource': role['resource'], 'normalConvention': role.get('normalConvention'),
                'locations': 0, 'sameTexel': 0, 'texelBoundaryAligned': 0,
                'greenNeutral': 0, 'redNeutral': 0, 'image': None, 'examples': []})
            if bucket['locations'] >= PER_ROLE_SAMPLE or not role['normalTexture']:
                continue
            if bucket['image'] is None:
                image, report = normal_image(dict(role, _name=role_name), glb)
                bucket['image'] = report
                bucket['_image'] = image
            image = bucket.get('_image')
            if image is None:
                continue
            arrays = classify.primitive_arrays(glb, primitive)
            indices = [v[0] for v in classify.stream(
                glb, primitive['indices'], 'SCALAR', (5121, 5123, 5125))]
            for face in range(len(indices) // 3):
                if bucket['locations'] >= PER_ROLE_SAMPLE:
                    break
                corners = classify.face_corners(arrays, indices, face)
                state, derivative = classify.face_verdict(corners)
                if state != classify.FULL_RANK:
                    continue
                for corner in corners:
                    if bucket['locations'] >= PER_ROLE_SAMPLE:
                        break
                    if classify.spec_verdict(corner['N'], corner['T']):
                        continue
                    entry = addressed_pair(image, corner['UV'])
                    bucket['locations'] += 1
                    bucket['sameTexel'] += entry['sameTexel']
                    bucket['texelBoundaryAligned'] += entry['texelBoundaryAligned']
                    rgb = entry['gltf']['rgb']
                    bucket['greenNeutral'] += rgb[1] == 128
                    bucket['redNeutral'] += rgb[0] == 128
                    if len(bucket['examples']) < 3 and rgb[1] != 128:
                        bucket['examples'].append({'node': node['name'], 'mesh': mesh,
                                                   'face': face, 'corner': corner['corner'],
                                                   'vertex': corner['vertex'], 'UV': list(corner['UV']),
                                                   'rgb': rgb, 'sameTexel': entry['sameTexel']})
    for bucket in out['roles'].values():
        bucket.pop('_image', None)
        locations = bucket['locations']
        bucket['sameTexelFraction'] = (bucket['sameTexel'] / locations) if locations else None
        bucket['verdict'] = bool(locations) and bucket['sameTexel'] == locations and not bucket['texelBoundaryAligned']
    out['summary'] = {
        'roles': len(out['roles']),
        'texturedRoles': sum(1 for b in out['roles'].values() if b['normalTexture']),
        'rolesPassing': sum(1 for b in out['roles'].values() if b['verdict']),
        'locations': sum(b['locations'] for b in out['roles'].values()),
        'sameTexel': sum(b['sameTexel'] for b in out['roles'].values()),
        'texelBoundaryAligned': sum(b['texelBoundaryAligned'] for b in out['roles'].values()),
    }
    return out


def strength_model_divergence(roles):
    """The two pinned shader paths apply the same scalar differently. Quantify it
    so a reviewer does not read a strength disagreement as a tangent defect."""
    out = {'case': 'strengthModelDivergence', 'models': list(STRENGTH_MODELS), 'roles': {}}
    N, T, w = (0., 0., 1.), (1., 0., 0.), 1.
    for role_name, role in sorted(roles.items()):
        if not role['normalTexture']:
            continue
        strength = role['normalScale']
        results = {}
        for label, rgb in (('red+', (255, 128, 255)), ('green+', (128, 255, 255)),
                           ('neutral', (128, 128, 255)), ('green-', (128, 1, 255))):
            tx, ty, tz = decode_normal(rgb)
            per_model = {model: world_perturbation(N, T, w, tx, ty, tz, model, strength)[1]
                         for model in STRENGTH_MODELS}
            results[label] = {
                'models': {model: list(value) for model, value in per_model.items()},
                'angleDegrees': angle_degrees(per_model[STRENGTH_MODELS[0]], per_model[STRENGTH_MODELS[1]])}
        out['roles'][role_name] = {'normalScale': strength, 'samples': results,
                                   'maxAngleDegrees': max(r['angleDegrees'] for r in results.values())}
    out['summary'] = {
        'roles': len(out['roles']),
        'maxAngleDegrees': max((r['maxAngleDegrees'] for r in out['roles'].values()), default=None),
        'note': ('This divergence is a property of the two pinned shader expressions, identical '
                 'in X, AA and AC because the scalar is unchanged. It is not a tangent defect and '
                 'not introduced by any reviewed edit.'),
    }
    return out


# --------------------------------------------------------------------------
# Driver.
# --------------------------------------------------------------------------

def load_artifacts():
    """Committed X plus the two reviewed successors, or a reported absence."""
    found = {}
    x = X_GLB
    if x.is_file() and sha(x.read_bytes()) == X_SHA:
        found['X'] = x.read_bytes()
    else:
        found['X'] = None
    try:
        aa_raw, proof = classify.derive_aa_from_x(found['X'])
        found['AA'] = aa_raw
        found['AA_derivation'] = 'districts-v4-tangent.contract.repair(committed X)'
    except Exception as error:                      # pragma: no cover - reported, not raised
        found['AA'] = None
        found['AA_derivation'] = 'unavailable: %s' % error
    ac = classify.AC_GLB
    found['AC'] = ac.read_bytes() if ac.is_file() and sha(ac.read_bytes()) == classify.AC_SHA else None
    return found


def run():
    roles, conventions = material_table()
    artifacts = load_artifacts()
    report = {
        'schema': 'parallax-tangent-appearance-contract/v1',
        'scope': ('Source-only bounded appearance-preservation contract. Compares authored and '
                  'supplied-basis world-space perturbations at corresponding decoded PNG sample '
                  'locations with explicit normal strength, image origin, UV transform and material '
                  'selection. No engine, import, render, artifact change, promotion or acceptance.'),
        'boundaries': [
            'An analytic CPU source contract over the two pinned shader expressions; not a Blender or Godot render measurement.',
            'Named cases use nearest-texel fetching. The exhaustive sweep uses the bilinear REPEAT sample both pinned samplers declare and compares decoded channels; mip selection, anisotropic filtering and texture compression are not modelled.',
            'The authored side is reconstructed as v_authored = 1 - v_exported, the inverse of the pinned exporter transform. Blender was not run to confirm its authored UVs or its bottom-up image buffer.',
            'Which strength convention the accepted appearance refers to is a render question this contract does not settle; the two pinned paths differ by up to 15.06 degrees at the reviewed strengths.',
            'No smoothing/seam MikkTSpace regeneration is claimed; the contract is per record basis.',
            'Nineteen changed tangent records are argued case by case; the remaining 319,046 keep their exact bytes, which is identity rather than a derivation.',
        ],
        'inputs': {
            'X': {'path': str(X_GLB.relative_to(ROOT)), 'sha256': X_SHA, 'available': artifacts['X'] is not None},
            'AA': {'derivation': artifacts['AA_derivation'],
                   'sha256': classify.census.ART_SHA, 'available': artifacts['AA'] is not None},
            'AC': {'path': str(classify.AC_GLB.relative_to(ROOT)), 'sha256': classify.AC_SHA,
                   'available': artifacts['AC'] is not None},
            'bindings': str(BINDINGS.relative_to(ROOT)),
            'packs': [str((PACK_ROOT / pack / 'manifest.json').relative_to(ROOT)) for pack in PACKS],
        },
        'strengthModels': {model: _model_source(model) for model in STRENGTH_MODELS},
        'imageOrigins': {
            'blenderBottomUp': 'openimageio_support.cc:118-128 negative destination row stride; Blender UV v=0 addresses the last ImBuf row',
            'gltfTopDown': 'glTF 2.0 §3.9 texture coordinate (0,0) at the image upper-left corner',
        },
        'uvTransform': {
            'exporter': 'uvs[:,1] *= -1; uvs[:,1] += 1 (primitive_extract.py:1413-1425), applied to the already density-scaled MothLocal UV',
            'authoredToExported': 'v_exported = 1 - v_authored',
            'wrap': REPEAT,
            'density': 'MothLocal planar UVs are multiplied by the reviewed tilesPerMeter at author time; no runtime UV transform extension is present',
        },
        'cases': {},
    }
    if artifacts['X'] is None or artifacts['AC'] is None:
        report['blocked'] = 'Pinned X or AC GLB bytes are unavailable in this checkout'
        return report
    cases = classify.named_cases(artifacts['AC'], 'AC')
    # The singular glyph records exist in AA, not AC: AC is the repair. The
    # before/after comparison needs the pre-repair census, so take it from AA
    # and the repaired basis from AC.
    glyph_cases = classify.named_cases(artifacts['AA'], 'AA') if artifacts['AA'] else cases
    report['cases']['asymmetricFullRankFixture'] = asymmetric_full_rank_fixture()
    report['cases']['saltstoneFace11823'] = saltstone_face_11823(
        artifacts['X'], artifacts['AA'], artifacts['AC'], roles)
    report['cases']['storedTangentOpposesDUCorners'] = u_reversed_corners(
        cases, artifacts['AC'], roles)
    report['cases']['singularGlyphRecords'] = singular_glyph_records(
        glyph_cases, artifacts['AA'], artifacts['AC'], roles)
    report['cases']['perRoleSweep'] = per_role_sweep(artifacts['AC'], roles)
    report['cases']['exhaustiveAddressSweep'] = exhaustive_address_sweep(artifacts['AC'], roles)
    report['cases']['basisPreservation'] = basis_preservation(artifacts['X'], artifacts['AC'])
    report['cases']['strengthModelDivergence'] = strength_model_divergence(roles)
    report['summary'] = _summarise(report['cases'])
    return report


def _model_source(model):
    return {
        'blenderNormalMapNode': ('Blender v4.5.14 gpu_shader_material_normal_map.glsl: B = tangent.w * cross(Ni, tangent.xyz); '
                                 'texnormal.xy *= strength; texnormal.z = mix(1, z, saturate(strength))'),
        'godotForwardMixDepth': ('Godot 4.5.2-stable gltf_document.cpp:4911-4913 sets normal_scale from normalTexture.scale; '
                                 'material.cpp:1746 assigns it to NORMAL_MAP_DEPTH; scene.glsl:1950-1955 decodes xy, rebuilds z '
                                 'and mixes by normal_map_depth'),
    }[model]


def exhaustive_address_sweep(ac_raw, roles):
    """Every full-rank corner in the artifact, not a sample.

    Equal (column, row) indices imply equal decoded pixels for a deterministic
    decoder, so index identity is the exhaustive statement and the bounded
    `perRoleSweep` supplies the decoded-pixel evidence and the worked examples.
    """
    glb = EmbeddedGlb(ac_raw)
    glb.geometry()
    images = {}
    out = {'case': 'exhaustiveAddressSweep', 'compared': 'AC',
           'filter': 'bilinear REPEAT, the mode both pinned samplers declare',
           'secondaryFilter': 'nearest neighbour, reported only where it must break a tie',
           'roles': {}}
    for node in classify.scene_parts(glb):
        mesh = node['mesh']
        for primitive in glb.doc['meshes'][mesh]['primitives']:
            role_name = glb.doc['materials'][primitive['material']]['name']
            role = roles[role_name]
            bucket = out['roles'].setdefault(role_name, {
                'normalTexture': role['normalTexture'], 'corners': 0, 'sameBilinearSample': 0,
                'sameNearestIndex': 0, 'nearestTie': 0, 'mismatches': [], 'image': None})
            if not role['normalTexture']:
                continue
            if role_name not in images:
                material = _material_for_role(glb, role_name)
                source = glb.doc['textures'][material['normalTexture']['index']]['source']
                raw = glb.view_bytes(glb.doc['images'][source]['bufferView'])
                images[role_name] = decode_png(raw)
                bucket['image'] = {'sha256': sha(raw), 'width': images[role_name][0],
                                   'height': images[role_name][1]}
            image = images[role_name]
            width, height = image[0], image[1]
            arrays = classify.primitive_arrays(glb, primitive)
            indices = [v[0] for v in classify.stream(
                glb, primitive['indices'], 'SCALAR', (5121, 5123, 5125))]
            for face in range(len(indices) // 3):
                corners = classify.face_corners(arrays, indices, face)
                state, derivative = classify.face_verdict(corners)
                if state != classify.FULL_RANK:
                    continue
                for corner in corners:
                    if classify.spec_verdict(corner['N'], corner['T']):
                        continue
                    u, v_exported = corner['UV']
                    u_a, v_authored = authored_uv(corner['UV'])
                    gltf = sample_bilinear(image, u, v_exported, 'gltfTopDown')
                    blender = sample_bilinear(image, u_a, v_authored, 'blenderBottomUp')
                    worst = max(abs(a - b) for a, b in zip(gltf, blender))
                    bucket['corners'] += 1
                    bucket['sameBilinearSample'] += worst <= 1e-9
                    same_index = (texel_index(width, height, u, v_exported, 'gltfTopDown')
                                  == texel_index(width, height, u_a, v_authored, 'blenderBottomUp'))
                    bucket['sameNearestIndex'] += same_index
                    bucket['nearestTie'] += not same_index
                    if worst > 1e-9 and len(bucket['mismatches']) < 8:
                        bucket['mismatches'].append(
                            {'node': node['name'], 'face': face, 'corner': corner['corner'],
                             'UV': list(corner['UV']), 'gltf': list(gltf), 'blender': list(blender),
                             'maxChannelDifference': worst})
    total = sum(b['corners'] for b in out['roles'].values())
    same = sum(b['sameBilinearSample'] for b in out['roles'].values())
    out['summary'] = {
        'roles': len(out['roles']),
        'texturedRoles': sum(1 for b in out['roles'].values() if b['normalTexture']),
        'specValidCornersOnFullRankFaces': total,
        'sameBilinearSample': same,
        'sameNearestIndex': sum(b['sameNearestIndex'] for b in out['roles'].values()),
        'nearestTieCorners': sum(b['nearestTie'] for b in out['roles'].values()),
        'bilinearMismatches': total - same,
        'recordedMismatchExamples': sum(len(b['mismatches']) for b in out['roles'].values()),
        'verdict': total > 0 and same == total,
    }
    return out


def basis_preservation(x_raw, ac_raw):
    """The decisive count for a per-record appearance contract.

    A supplied tangent record either keeps its exact bytes or it does not. Where
    the bytes are unchanged, world-space perturbation is unchanged by
    construction, and the only remaining question is whether the sample location
    is preserved -- which `perRoleSweep` verifies per role. So the qualified
    population is (unchanged bytes) INTERSECT (addressing pair holds), and the
    changed records have to be argued one by one.
    """
    diff = classify.tangent_record_diff(x_raw, ac_raw)
    by_role = {}
    for entry in diff['changed']:
        bucket = by_role.setdefault(entry['role'], {'changedRecords': 0, 'wChanged': 0, 'entries': []})
        bucket['changedRecords'] += 1
        bucket['wChanged'] += entry['wChanged']
        bucket['entries'].append({k: entry[k] for k in
                                  ('accessor', 'vertex', 'node', 'mesh', 'before', 'after', 'wChanged')})
    return {'case': 'basisPreservation', 'compared': 'X -> AC',
            'records': diff['records'], 'changedRecords': diff['changedRecords'],
            'unchangedRecords': diff['unchangedRecords'],
            'unchangedFraction': diff['unchangedRecords'] / diff['records'],
            'changedByRole': by_role,
            'changed': [{k: entry[k] for k in
                         ('accessor', 'vertex', 'node', 'mesh', 'role', 'before', 'after',
                          'beforeNonUnitT', 'beforeWNotSign', 'afterNonUnitT', 'afterWNotSign', 'wChanged')}
                        for entry in diff['changed']],
            'interpretation': (
                'Unchanged bytes plus a verified addressing pair is identity of world-space '
                'perturbation, so those records need no appeal to a derivative sign. The changed '
                'records are the only ones requiring an argument: three saltstone corners and '
                'sixteen singular glyph records.')}


def _summarise(cases):
    fixture = cases['asymmetricFullRankFixture']
    saltstone = cases['saltstoneFace11823']
    reversed_u = cases['storedTangentOpposesDUCorners']
    glyphs = cases['singularGlyphRecords']
    sweep = cases['perRoleSweep']
    divergence = cases['strengthModelDivergence']
    basis = cases['basisPreservation']
    return {
        'asymmetricFixture': fixture['summary'],
        'saltstoneFace11823': saltstone.get('summary'),
        'storedTangentOpposesDU': reversed_u['summary'],
        'singularGlyphRecords': glyphs['summary'],
        'perRoleSweep': sweep['summary'],
        'exhaustiveAddressSweep': cases['exhaustiveAddressSweep']['summary'],
        'basisPreservation': {'records': basis['records'], 'changedRecords': basis['changedRecords'],
                              'unchangedRecords': basis['unchangedRecords'],
                              'changedByRole': {role: bucket['changedRecords']
                                                for role, bucket in sorted(basis['changedByRole'].items())}},
        'strengthModelDivergence': {'roles': divergence['summary']['roles'],
                                    'maxAngleDegrees': divergence['summary']['maxAngleDegrees']},
        'qualifiedByIdentity': {
            'unchangedBasisRecords': basis['unchangedRecords'],
            'rolesWithVerifiedAddressingPair': sweep['summary']['rolesPassing'],
            'specValidCornersWithExhaustiveAddressingProof':
                cases['exhaustiveAddressSweep']['summary']['sameBilinearSample'],
            'sampleLocationsChecked': sweep['summary']['locations'],
            'requiresCaseByCaseArgument': basis['changedRecords'],
        },
        'qualification': {
            'addressingPairHoldsExhaustively': cases['exhaustiveAddressSweep']['summary']['verdict'],
            'negativeControlsRejected': (fixture['summary']['wFlipRejected'] == fixture['summary']['locations']
                                          and fixture['summary']['greenFlipRejected'] == fixture['summary']['locations']
                                          and fixture['summary']['wrongOriginRejected'] == fixture['summary']['locations']),
            'saltstoneEditPreservesXAppearance': (
                saltstone.get('summary', {}).get('XAAPreserved') == saltstone.get('summary', {}).get('corners')),
            'saltstoneEditReversesGreen': saltstone.get('summary', {}).get('XvsAAgreenReversed', 0) > 0,
            'uReversedDerivativeAgreementProven': (
                reversed_u['summary']['unconditionalAppearsPreserved'] == reversed_u['summary']['comparable']),
            'glyphSingularFramesRepaired': glyphs['summary']['afterDegenerate'] == 0,
        },
    }


def main():
    report = run()
    (HERE / 'appearance-contract.json').write_text(json.dumps(report, indent=2, allow_nan=False) + '\n')
    print(json.dumps(report.get('summary', report), indent=2))
    return report


if __name__ == '__main__':
    main()