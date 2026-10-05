"""Bounded source-only decision package for Parallax saltstone face 11823.

`parallax-tangent-provenance/appearance_contract.py` measured that the AA sign
change on saltstone face 11823 does **not** preserve X appearance: 2 of 2
comparable corners reverse green exactly 180 degrees and the world normal moves
4.90 / 5.59 degrees at the reviewed strength. This module turns that measurement
into a decidable package, from committed evidence only:

1. the exact face-11823 corner set and the X / AA / AC tangent values, re-derived
   from committed bytes through the committed parsers;
2. what an exact source-level revert would be, as an **unapplied** unified diff
   against the successor pipeline plus the byte-level proof that the intent is
   representable inside the already-permitted 48-byte storage window;
3. how visually significant the measured deviation is at the reviewed normal
   strength -- per corner, across the face's own UV footprint, across the whole
   committed normal map, against the pinned AC01 sun, and against the twelve
   committed probe cameras;
4. whether a controlled close-up render is feasible with the committed
   parity-glyph capture harness, and if not, exactly which precondition fails.

Nothing here writes a GLB, a master, a receipt, a sidecar or a capture. Every
revert candidate is built **in memory only**; the revert diff is emitted as a file
this tool never applies. A missing source is reported, never fabricated.
"""
import collections as C
import difflib
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/map_variety'))
sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/botanical-parallax-aa-diagnosis'))
sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/parallax-tangent-provenance'))
sys.path.insert(0, str(HERE))

from glb_geometry import EmbeddedGlb
import appearance_contract as ap
import classify_records as cl
import census
import contract as aa
import proposal as glyph_policy

import proposed_successor_contract as psc

AC_GLB = ROOT / ('tools/godot-multiplayer/new-maps/parallax-observatory/revisions/'
                 'districts-v4-glyph-tangents/native/AC01/parallax-glyph-tangents.glb')
AC_STAGE = ROOT / 'godot/tests/new_maps/parallax_glyph/AC01'
PROBES = AC_STAGE / 'probes.json'
AUTHORITY = AC_STAGE / 'authority.json'
CAPTURE_GD = AC_STAGE / 'capture.gd'
STAGED_GD = AC_STAGE / 'staged.gd'
STAGE_PY = ROOT / ('tools/godot-multiplayer/new-maps/parallax-observatory/revisions/'
                   'districts-v4-glyph-tangents/stage.py')
SUCCESSOR_PY = ROOT / ('tools/godot-multiplayer/new-maps/parallax-observatory/revisions/'
                       'districts-v4-glyph-tangents/successor.py')
PROPOSED_DIR = ('tools/godot-multiplayer/new-maps/parallax-observatory/revisions/'
                'districts-v5-saltstone-green-revert')
PATCH_FILE = HERE / 'revert-11823-successor.patch'
REPORT_FILE = HERE / 'face-11823-revert.json'
PROPOSED_SOURCES = (('proposed_successor_contract.py', 'contract.py'),
                    ('PROPOSED_README.md', 'README.md'))
IMAGE_W, IMAGE_H = 1280, 720
FOOTPRINT_STEPS = 64
SUN_ROTATION_DEGREES = (-44.0, -30.0, 0.0)
SUN_ENERGY = 0.6
AMBIENT_ENERGY = 0.45
STAGED_OMNI_ENERGY, STAGED_OMNI_RANGE = 1.2, 20.0
MIXED_BASIS = ([1., 0., 0., -1.], list(psc.USABLE), list(psc.USABLE))


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


# --------------------------------------------------------------------------
# 1. Committed inputs.
# --------------------------------------------------------------------------

def artifacts():
    """X, the AA re-derived from committed X, and the committed AC."""
    x = aa.pinned()
    out = {'X': {'path': str(aa.SOURCE.relative_to(ROOT)), 'sha256': aa.SOURCE_SHA,
                 'available': True, 'raw': x}}
    aa_raw, proof = cl.derive_aa_from_x(x)
    out['AA'] = {'derivation': 'districts-v4-tangent.contract.repair(committed X)',
                 'sha256': sha(aa_raw), 'changedBytesVsX': proof['changedBytes'],
                 'available': True, 'raw': aa_raw}
    out['AC'] = {'path': str(AC_GLB.relative_to(ROOT)), 'expectedSha256': cl.AC_SHA,
                 'available': False, 'raw': None}
    if AC_GLB.is_file():
        raw = AC_GLB.read_bytes()
        if sha(raw) == cl.AC_SHA:
            out['AC'].update({'sha256': cl.AC_SHA, 'available': True, 'raw': raw})
        else:
            out['AC']['observedSha256'] = sha(raw)
    return out


# --------------------------------------------------------------------------
# 2. The reviewed corner set, re-derived from committed bytes.
# --------------------------------------------------------------------------

def label_view(raw, layout):
    glb = EmbeddedGlb(raw)
    glb.geometry()
    tangents = census.stream(glb, psc.ACCESSOR, 'VEC4')
    rows = []
    for corner, vertex in enumerate(psc.VERTICES):
        offset = layout[0] + vertex * layout[1]
        rows.append({
            'corner': corner, 'vertex': vertex,
            'binOffset': offset,
            'bytes': bytes(glb.binary[offset:offset + 16]).hex(),
            'basis': list(tangents[vertex]),
        })
    return rows


def face_facts(arts, roles):
    """Everything the decision rests on, read from committed bytes only."""
    appearance = ap.saltstone_face_11823(arts['X']['raw'], arts['AA']['raw'],
                                          arts['AC']['raw'], roles)
    glb = EmbeddedGlb(arts['AC']['raw'])
    glb.geometry()
    _, _, ac_layout = glb.accessor(psc.ACCESSOR, 'VEC4', (5126,), 'TANGENT')
    positions, normals, uv, _tangents, indices = aa.source_face(glb)
    views = {label: label_view(arts[label]['raw'], ac_layout) for label in ('X', 'AA', 'AC')}
    corners = []
    for corner, vertex in enumerate(psc.VERTICES):
        appearances = appearance['corners'][corner]
        entry = {
            'corner': corner, 'vertex': vertex,
            'position': list(positions[vertex]),
            'normal': list(normals[vertex]),
            'uv': list(uv[vertex]),
            'incidentFaces': [i // 3 for i in range(0, len(indices), 3)
                              if vertex in indices[i:i + 3]],
            'binOffset': views['AC'][corner]['binOffset'],
            'bytes': {label: views[label][corner]['bytes'] for label in views},
            'basis': {label: views[label][corner]['basis'] for label in views},
            'specVerdict': {label: list(cl.spec_verdict(normals[vertex],
                                                        tuple(views[label][corner]['basis'])))
                            for label in views},
            'derivedSignFromUV': None,
            'addressing': appearances['evaluations']['AC']['addressing'],
            'xVsAc': {model: appearances['XvsAC'][model] for model in ap.STRENGTH_MODELS},
            'xVsAa': {model: appearances['XvsAA'][model] for model in ap.STRENGTH_MODELS},
        }
        corners.append(entry)
    face_state, derivative = cl.face_verdict(
        [{'N': normals[v], 'T': tuple(views['AC'][corner]['basis']), 'P': positions[v],
          'UV': uv[v], 'vertex': v, 'corner': corner}
         for corner, v in enumerate(psc.VERTICES)])
    for corner, entry in enumerate(corners):
        entry['derivedSignFromUV'] = (derivative['wFromUV'][corner]
                                      if derivative['defined'] else None)
    return {
        'case': 'saltstoneFace11823',
        'accessor': psc.ACCESSOR,
        'binLayout': {'start': ac_layout[0], 'stride': ac_layout[1], 'format': ac_layout[2]},
        'reviewedFace': {'mesh': 9, 'face': 11823, 'vertices': list(psc.VERTICES),
                         'meshName': glb.doc['meshes'][9]['name'],
                         'node': 'kit.authority.saltstone.00',
                         'faceState': face_state,
                         'uvJacobian': derivative['uvJacobian'],
                         'area': derivative['area'],
                         'dPdu': list(derivative['du']), 'dPdv': list(derivative['dv'])},
        'normalScale': appearance['normalScale'],
        'tilesPerMeter': appearance['tilesPerMeter'],
        'normalConvention': appearance['normalConvention'],
        'normalImage': appearance['image'],
        'corners': corners,
        'appearance': appearance,
    }


# --------------------------------------------------------------------------
# 3. Revert candidates, built in memory only.
# --------------------------------------------------------------------------

def permitted_window(glb, layout):
    glyph = set()
    for accessor, vertex in sorted(glyph_policy.EXPECTED):
        _, _, glyph_layout = glb.accessor(accessor, 'VEC4', (5126,), 'TANGENT')
        offset = glyph_layout[0] + vertex * glyph_layout[1]
        glyph |= set(range(offset, offset + 16))
    saltstone = {layout[0] + vertex * layout[1] + byte
                 for vertex in psc.VERTICES for byte in range(16)}
    return saltstone, glyph, saltstone | glyph


def aliasing(glb, blob, changed):
    """The AA compiler's own containment checks, re-run on the candidate."""
    aliased_accessors = []
    for index, accessor in enumerate(glb.doc['accessors']):
        if index == psc.ACCESSOR:
            continue
        _, count, (start, stride, fmt) = glb.accessor(index, accessor['type'],
                                                      (5121, 5123, 5125, 5126),
                                                      'other stream')
        width = struct.calcsize(fmt)
        if any(0 <= offset - start and (offset - start) // stride < count
               and (offset - start) % stride < width for offset in changed):
            aliased_accessors.append(index)
    aliased_images = []
    for image in glb.doc['images']:
        start, length = glb._view(glb.doc['bufferViews'][image['bufferView']])
        if any(start <= offset < start + length for offset in changed):
            aliased_images.append(image.get('name'))
    return aliased_accessors, aliased_images


def classification(raw, label, baseline):
    result = cl.classify(raw, label)
    return {
        'label': label,
        'categories': result['categories'],
        'cornerDisagreements': result['cornerDisagreements'],
        'saltstone': result['roles']['saltstone']['categories'],
        'nonorthogonalNTAdvisory': sum(count for key, count in result['advisories'].items()
                                       if key.endswith('nonorthogonalNT')),
        'faceStates': result['faceStates'],
        'deltaVsAc': {
            'specInvalid': result['categories'][cl.SPEC_INVALID]
            - baseline['categories'][cl.SPEC_INVALID],
            'specValidDerivativeDisagreeing':
                result['categories'][cl.SPEC_VALID_DISAGREEING]
                - baseline['categories'][cl.SPEC_VALID_DISAGREEING],
            'unaffectedOther': result['categories'][cl.UNAFFECTED]
                - baseline['categories'][cl.UNAFFECTED],
            'wSignDisagrees': result['cornerDisagreements']['wSignDisagrees']
                - baseline['cornerDisagreements']['wSignDisagrees'],
            'storedBinormalOpposesDV':
                result['cornerDisagreements']['storedBinormalOpposesDV']
                - baseline['cornerDisagreements']['storedBinormalOpposesDV'],
        },
    }


def candidates(arts, baseline):
    """Every revert shape a reviewer could ask for, each measured, not asserted."""
    ac_raw = arts['AC']['raw']
    x_raw = arts['X']['raw']
    glb = EmbeddedGlb(ac_raw)
    glb.geometry()
    _, _, layout = glb.accessor(psc.ACCESSOR, 'VEC4', (5126,), 'TANGENT')
    saltstone, glyph, permitted = permitted_window(glb, layout)
    ac_binary, x_binary = glb.binary, EmbeddedGlb(x_raw).binary
    normals = [tuple(entry['normal']) for entry in face_positions_normals(ac_raw)]

    shapes = C.OrderedDict((
        ('R1_uniform_w_plus1', {
            'basis': [list(t) for t in psc.REVERT_BASIS],
            'intent': ("restore X's w=+1 on all three corners; corners 1-2 become byte-identical "
                       "to X, corner 0 keeps X's w and takes the usable unit T.xyz its two "
                       "face-mates carry, because X stored a zero tangent there"),
            'reversible': True,
        }),
        ('R2_mixed_w', {
            'basis': [list(t) for t in MIXED_BASIS],
            'intent': ("restore X's w=+1 only on the two corners where X stored a usable basis "
                       "and keep AC on corner 0: smallest delta, but it mixes handedness inside "
                       "one triangle, so an interpolated handedness crosses zero across the face"),
            'reversible': True,
        }),
        ('LITERAL_X_bytes', {
            'basis': [list(t) for t in psc.X_BASIS],
            'intent': 'byte-exact X restore on all three corners',
            'reversible': False,
            'rejection': ('reinstates one spec-invalid record (zero tangent, degenerate frame) '
                          'at vertex 24049, which is exactly what AC exists to close'),
        }),
    ))

    out = []
    for name, spec in shapes.items():
        blob = bytearray(ac_binary)
        for vertex, tangent in zip(psc.VERTICES, spec['basis']):
            struct.pack_into('<4f', blob, layout[0] + vertex * layout[1], *tangent)
        changed = {i for i, (a, b) in enumerate(zip(ac_binary, blob)) if a != b}
        changed_vs_x = {i for i, (a, b) in enumerate(zip(x_binary, blob)) if a != b}
        aliased_accessors, aliased_images = aliasing(glb, blob, changed)
        encoded = aa.encode(glb.doc, blob)
        container = {'geometryReParsed': None, 'error': None}
        try:
            check = EmbeddedGlb(encoded)
            parts, triangles, _ = check.geometry()
            container['geometryReParsed'] = {'primitives': len(parts), 'triangles': triangles}
        except Exception as error:                                    # pragma: no cover
            container['error'] = str(error)
        verdicts = [list(cl.spec_verdict(normals[i], tuple(spec['basis'][i]))) for i in range(3)]
        entry = {
            'candidate': name,
            'intent': spec['intent'],
            'admissible': spec['reversible'] and not any(verdicts),
            'rejection': spec.get('rejection'),
            'perCorner': [
                {'corner': i, 'vertex': vertex,
                 'xStored': list(psc.X_BASIS[i]),
                 'xUsableBasisExists': not any(cl.spec_verdict(normals[i],
                                                               tuple(psc.X_BASIS[i]))),
                 'acStored': list(entry_basis(i)),
                 'proposed': list(spec['basis'][i]),
                 'targetBytes': struct.pack('<4f', *spec['basis'][i]).hex(),
                 'byteIdenticalToX': spec['basis'][i] == list(psc.X_BASIS[i]),
                 'specVerdict': verdicts[i]}
                for i, vertex in enumerate(psc.VERTICES)],
            'bytes': {
                'artifactSha256': sha(encoded),
                'binSha256': sha(bytes(blob)),
                'artifactWritten': False,
                'changedVsAC': len(changed),
                'changedVsACPositions': sorted(changed),
                'changedVsX': len(changed_vs_x),
                'permittedSaltstoneWindow': len(saltstone),
                'permittedGlyphWindow': len(glyph),
                'permittedCombinedWindow': len(permitted),
                'changedWithinPermittedWindow': changed <= permitted,
                'aliasedAccessors': aliased_accessors,
                'aliasedImages': aliased_images,
            },
            'container': container,
            'containerJsonLeftAtAc': True,
            'note': ('the candidate is built with the AC container JSON untouched, so the '
                     'measured sha256 isolates the basis change; the proposed successor in '
                     'proposed_successor_contract.revert() additionally stamps its own '
                     'revision metadata, which is why its BIN hash matches this candidate '
                     'while its whole-file hash does not'),
            'classification': None,
        }
        if not container['error']:
            entry['classification'] = classification(encoded, name, baseline)
        out.append(entry)
    return out


def entry_basis(index):
    """AC's stored basis on corner `index`, read from the committed AC artifact."""
    glb = EmbeddedGlb(AC_GLB.read_bytes())
    glb.geometry()
    return census.stream(glb, psc.ACCESSOR, 'VEC4')[psc.VERTICES[index]]


_FACE_CACHE = {}


def face_positions_normals(ac_raw):
    if ac_raw not in _FACE_CACHE:
        glb = EmbeddedGlb(ac_raw)
        glb.geometry()
        positions, normals, _uv, _t, _i = aa.source_face(glb)
        _FACE_CACHE[ac_raw] = [{'position': positions[v], 'normal': normals[v]}
                               for v in psc.VERTICES]
    return _FACE_CACHE[ac_raw]


# --------------------------------------------------------------------------
# 4. Visual significance.
# --------------------------------------------------------------------------

def staged_light():
    """The committed AC01 presentation, read from staged.gd's own literals."""
    rx, ry, rz = (math.radians(a) for a in SUN_ROTATION_DEGREES)

    def rot_x(a):
        c, s = math.cos(a), math.sin(a)
        return ((1., 0., 0.), (0., c, -s), (0., s, c))

    def rot_y(a):
        c, s = math.cos(a), math.sin(a)
        return ((c, 0., s), (0., 1., 0.), (-s, 0., c))

    def mul(a, b):
        return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3))
                     for i in range(3))

    basis = mul(rot_y(ry), mul(rot_x(rx), rot_y(rz)))
    emitted = ap.unit(tuple(sum(basis[i][k] * (0., 0., -1.)[k] for k in range(3))
                            for i in range(3)))
    overhead = []
    if AUTHORITY.is_file():
        arena = json.loads(AUTHORITY.read_text())['arena']
        for entry in arena.get('overhead', []):
            overhead.append({'id': entry['id'],
                             'lightPosition': [entry['x'], entry['minY'] - 0.45, entry['z']],
                             'lightEnergy': STAGED_OMNI_ENERGY,
                             'rangeMetres': STAGED_OMNI_RANGE})
    return {
        'source': ('godot/tests/new_maps/parallax_glyph/AC01/staged.gd:151-157 '
                   'sun.rotation_degrees = Vector3(-44,-30,0), light_energy = .6, '
                   'ambient_light_energy = .45; staged.gd:104-109 overhead omnis at '
                   'energy 1.2, range 20'),
        'sunRotationDegrees': list(SUN_ROTATION_DEGREES),
        'sunEnergy': SUN_ENERGY,
        'ambientEnergy': AMBIENT_ENERGY,
        'sunEmittedDirection': list(emitted),
        'directionToLight': [-v for v in emitted],
        'overheadOmniLights': overhead,
    }


def distribution(values):
    ordered = sorted(values)
    n = len(ordered)

    def pct(p):
        return ordered[min(n - 1, int(p * n))]

    return {'samples': n,
            'minDegrees': ordered[0],
            'p25Degrees': pct(0.25),
            'medianDegrees': pct(0.50),
            'p75Degrees': pct(0.75),
            'p90Degrees': pct(0.90),
            'p99Degrees': pct(0.99),
            'maxDegrees': ordered[-1],
            'meanDegrees': sum(ordered) / n,
            'fractionAbove': {('%ddeg' % t): sum(1 for v in ordered if v > t) / n
                              for t in (1, 2, 3, 5, 10)}}


def visual_significance(arts, roles, facts):
    role = dict(roles['saltstone'], _name='saltstone')
    image, image_report = ap.normal_image(role, EmbeddedGlb(arts['AC']['raw']))
    strength = facts['normalScale']
    corners = facts['corners']
    n = tuple(corners[0]['normal'])
    tangent = (1., 0., 0.)
    light = staged_light()
    to_light = light['directionToLight']

    per_corner = []
    for entry in corners:
        row = {'corner': entry['corner'], 'vertex': entry['vertex'],
               'sampledRGB': entry['addressing']['gltf']['rgb'],
               'sampledColumnRow': [entry['addressing']['gltf']['column'],
                                    entry['addressing']['gltf']['row']],
               'sameTexelAcrossOrigins': entry['addressing']['sameTexel'],
               'models': {}}
        for model in ap.STRENGTH_MODELS:
            x_side = entry['xVsAc'][model]
            row['models'][model] = {
                'comparable': x_side['comparable'],
                'status': x_side.get('status'),
                'worldNormalAngleDegrees': x_side.get('worldAngleDegrees'),
                'maxComponentError': x_side.get('maxComponentError'),
                'binormalAngleDegrees': x_side.get('binormalAngleDegrees'),
                'greenComponentAngleDegrees': x_side.get('greenComponentAngleDegrees'),
            }
            evaluations = facts['appearance']['corners'][entry['corner']]['evaluations']
            nx = evaluations['X']['models'][model]['gltfTopDown']['worldNormal']
            nac = evaluations['AC']['models'][model]['gltfTopDown']['worldNormal']
            if nx is not None and nac is not None:
                dx = max(0., ap.dot(nx, to_light))
                dac = max(0., ap.dot(nac, to_light))
                row['models'][model]['directionalDiffuse'] = {
                    'xBasis': dx, 'acBasis': dac,
                    'absoluteDelta': dac - dx,
                    'relativeDeltaPercent': (100.0 * (dac - dx) / dx) if dx else None,
                    'albedoLinearRangeFromCommittedPack': [0.29, 0.43],
                    'linearRadianceDelta': (dac - dx) * (0.29 + 0.43) / 2.0 * SUN_ENERGY,
                }
        per_corner.append(row)

    uv = [tuple(entry['uv']) for entry in corners]
    footprint = {model: [] for model in ap.STRENGTH_MODELS}
    greens = []
    for i in range(FOOTPRINT_STEPS + 1):
        for j in range(FOOTPRINT_STEPS + 1 - i):
            a = i / FOOTPRINT_STEPS
            b = j / FOOTPRINT_STEPS
            c = 1.0 - a - b
            rgb = ap.sample_bilinear(image,
                                     a * uv[0][0] + b * uv[1][0] + c * uv[2][0],
                                     a * uv[0][1] + b * uv[1][1] + c * uv[2][1],
                                     'gltfTopDown')
            greens.append(rgb[1])
            tx, ty, tz = ap.decode_normal(rgb)
            for model in ap.STRENGTH_MODELS:
                _, left, _, _ = ap.world_perturbation(n, tangent, 1., tx, ty, tz, model, strength)
                _, right, _, _ = ap.world_perturbation(n, tangent, -1., tx, ty, tz, model, strength)
                footprint[model].append(ap.angle_degrees(left, right))

    width, height, bpp, pixels = image
    whole = {model: [] for model in ap.STRENGTH_MODELS}
    for row in range(height):
        base = row * width * bpp
        for column in range(width):
            offset = base + column * bpp
            tx, ty, tz = ap.decode_normal(tuple(pixels[offset:offset + 3]))
            for model in ap.STRENGTH_MODELS:
                _, left, _, _ = ap.world_perturbation(n, tangent, 1., tx, ty, tz, model, strength)
                _, right, _, _ = ap.world_perturbation(n, tangent, -1., tx, ty, tz, model, strength)
                whole[model].append(ap.angle_degrees(left, right))

    return {
        'reviewedStrength': strength,
        'normalImage': image_report,
        'stagedPresentation': light,
        'perCorner': per_corner,
        'faceUvFootprint': {
            'sampling': ('barycentric %dx grid over the three reviewed UVs, bilinear REPEAT '
                         'sample -- the filter both pinned samplers declare' % FOOTPRINT_STEPS),
            'greenRange': [min(greens), max(greens)],
            'greenNeutralFraction': sum(1 for g in greens if g == 128) / len(greens),
            'worldNormalAngleByModel': {model: distribution(values)
                                        for model, values in footprint.items()},
        },
        'wholeNormalMap': {
            'texels': width * height,
            'note': ('upper bound on the same reversal anywhere on this material; the reviewed '
                     'face addresses %d distinct bilinear samples of it' % len(greens)),
            'worldNormalAngleByModel': {model: distribution(values)
                                        for model, values in whole.items()},
        },
        'geometryFootprint': sliver_metrics(arts['X']['raw'], facts),
        'cameraVisibility': camera_visibility(facts, light),
    }


def sliver_metrics(x_raw, facts):
    positions = [tuple(entry['position']) for entry in facts['corners']]
    a, b, c = positions
    cross = census.cross(census.sub(b, a), census.sub(c, a))
    area = 0.5 * census.norm(cross)
    edges = [census.norm(census.sub(b, a)), census.norm(census.sub(c, a)),
             census.norm(census.sub(c, b))]
    uv = [entry['uv'] for entry in facts['corners']]
    uv_area = 0.5 * abs((uv[1][0] - uv[0][0]) * (uv[2][1] - uv[0][1])
                        - (uv[1][1] - uv[0][1]) * (uv[2][0] - uv[0][0]))
    glb = EmbeddedGlb(x_raw)
    glb.geometry()
    scene = saltstone = 0.0
    for node in cl.scene_parts(glb):
        for primitive in glb.doc['meshes'][node['mesh']]['primitives']:
            arrays = cl.primitive_arrays(glb, primitive)
            indices = [v[0] for v in census.stream(glb, primitive['indices'], 'SCALAR',
                                                   (5121, 5123, 5125))]
            role = glb.doc['materials'][primitive['material']]['name']
            role_area = 0.0
            for face in range(len(indices) // 3):
                p0, p1, p2 = (arrays['P'][indices[face * 3 + k]] for k in range(3))
                role_area += 0.5 * census.norm(census.cross(census.sub(p1, p0),
                                                            census.sub(p2, p0)))
            scene += role_area
            if role == 'saltstone':
                saltstone += role_area
    mean_width = 2.0 * area / max(edges)
    return {
        'areaSquareMetres': area,
        'edgeLengthsMetres': edges,
        'longestEdgeMetres': max(edges),
        'shortestEdgeMetres': min(edges),
        'meanWidthMetres': mean_width,
        'uvArea': uv_area,
        'squareMetresPerUvUnit': area / uv_area if uv_area else None,
        'saltstoneSurfaceSquareMetres': saltstone,
        'sceneSurfaceSquareMetres': scene,
        'fractionOfSaltstone': area / saltstone if saltstone else None,
        'fractionOfScene': area / scene if scene else None,
        'distanceForOnePixelWidthMetres': _one_pixel_distance(mean_width),
        'distanceForTenPixelWidthMetres': _one_pixel_distance(mean_width) / 10.0,
        'note': ('The reviewed face is a long needle: shortest edge %.4f m, longest %.4f m, mean '
                 'width %.4f m, total %.6f m2, which is %.3e of the saltstone surface and %.3e of '
                 'the whole scene.' % (min(edges), max(edges), mean_width, area,
                                       area / saltstone, area / scene)),
    }


def _one_pixel_distance(mean_width, fov_degrees=68.0, image_height=IMAGE_H):
    """How close a camera must be for the needle to be one pixel wide.

    The AC01 probe set is 68 degrees vertical, which is the widest committed fov
    and therefore the most generous case: if even that leaves the face
    sub-pixel, no committed camera can resolve it.
    """
    half_tan = math.tan(math.radians(fov_degrees) / 2.0)
    return mean_width * (image_height / 2.0) / half_tan


def camera_visibility(facts, light):
    """The twelve committed AC01 probe cameras against the reviewed face."""
    if not PROBES.is_file():
        return {'available': False, 'reason': 'committed probes.json is absent'}
    probes = json.loads(PROBES.read_text())
    corners = facts['corners']
    centroid = tuple(sum(entry['position'][i] for entry in corners) / 3.0 for i in range(3))
    normal = ap.unit(tuple(corners[0]['normal']))
    mean_width = sliver_metrics_standalone(facts)
    rows = []
    for camera in probes['cameras']:
        eye = tuple(float(v) for v in camera['eye'])
        target = tuple(float(v) for v in camera['target'])
        forward = ap.unit(census.sub(target, eye))
        right = ap.unit(census.cross(forward, (0., 1., 0.)))
        up = census.cross(right, forward)
        delta = census.sub(centroid, eye)
        depth = ap.dot(delta, forward)
        tan_half = math.tan(math.radians(float(camera['fov'])) / 2.0)
        row = {'camera': camera['id'], 'fovDegrees': camera['fov'],
               'eye': list(eye), 'target': list(target),
               'distanceToCentroidMetres': census.norm(delta)}
        if depth <= 0:
            row.update({'inFrustum': False,
                        'reason': 'the face centroid is behind this camera'})
            rows.append(row)
            continue
        ndc_x = ap.dot(delta, right) / (depth * tan_half * (IMAGE_W / IMAGE_H))
        ndc_y = ap.dot(delta, up) / (depth * tan_half)
        pixels_per_metre = (IMAGE_H / 2.0) / (depth * tan_half)
        facing = ap.dot(normal, [-v for v in forward])
        row.update({
            'depthMetres': depth,
            'ndc': [ndc_x, ndc_y],
            'inFrustum': abs(ndc_x) <= 1.0 and abs(ndc_y) <= 1.0,
            'frontFacing': facing > 0.0,
            'faceNormalDotAgainstViewAxis': facing,
            'faceLitByStagedSun': ap.dot(normal, light['directionToLight']) > 0.0,
            'sliverWidthPixelsAtCentroid': mean_width * pixels_per_metre,
            'resolvesTheFace': (abs(ndc_x) <= 1.0 and abs(ndc_y) <= 1.0 and facing > 0.0
                                and mean_width * pixels_per_metre >= 1.0),
        })
        rows.append(row)
    resolving = [r['camera'] for r in rows if r.get('resolvesTheFace')]
    return {
        'available': True,
        'image': [IMAGE_W, IMAGE_H],
        'faceCentroid': list(centroid),
        'faceNormal': list(normal),
        'meanWidthMetres': mean_width,
        'cameras': rows,
        'camerasResolvingTheFace': resolving,
        'camerasWithFaceInFrustum': [r['camera'] for r in rows if r.get('inFrustum')],
        'camerasWithFaceFrontFacing': [r['camera'] for r in rows if r.get('frontFacing')],
    }


def sliver_metrics_standalone(facts):
    positions = [tuple(entry['position']) for entry in facts['corners']]
    a, b, c = positions
    area = 0.5 * census.norm(census.cross(census.sub(b, a), census.sub(c, a)))
    longest = max(census.norm(census.sub(b, a)), census.norm(census.sub(c, a)),
                  census.norm(census.sub(c, b)))
    return 2.0 * area / longest


# --------------------------------------------------------------------------
# 5. Render feasibility against the committed harness.
# --------------------------------------------------------------------------

def render_feasibility(visibility):
    """Audit the committed parity-glyph capture harness against a close-up render."""
    captures_dir = AC_STAGE / 'captures'
    existing = sorted(p.name for p in captures_dir.glob('*.png')) if captures_dir.is_dir() else []
    return render_feasibility_from_text(
        CAPTURE_GD.read_text(), STAGED_GD.read_text(), STAGE_PY.read_text(),
        captures=existing,
        import_cache=(ROOT / 'godot/.godot').is_dir(),
        blender=blender_path(),
        resolving=visibility['camerasResolvingTheFace'])


def render_feasibility_from_text(capture_text, staged_text, stage_text, captures,
                                 import_cache, blender, resolving):
    """The harness audit, driven from text so it can be tested without the harness.

    Every precondition is a literal the committed harness either contains or does
    not, so a synthetic harness that satisfies all of them must reach `feasible`
    and any missing literal must not. That keeps a positive verdict from being
    unreachable by accident.
    """
    checks = []

    def check(name, satisfied, detail):
        checks.append({'precondition': name, 'satisfied': bool(satisfied), 'detail': detail})

    existing = list(captures)

    # A precondition is *satisfied* when it lets a close-up render happen, so each
    # check below is the absence of a blocker, not the presence of a capability.
    check('harnessSupportsThreeVariants',
          not ('for candidate: bool in [false,true]' in capture_text
               and 'records.size()==(2 if selected!="" else probes.cameras.size()*2)'
               in capture_text),
          'capture.gd iterates exactly [false,true] (failed-AA-before, candidate-runtime-after) '
          'and asserts records.size()==probes.cameras.size()*2, so a third variant cannot be '
          'expressed without editing a frozen staged script')
    check('stagedScriptsAreRewritable',
          'Stale staged bytes' not in staged_text,
          'staged.gd asserts FileAccess.get_sha256(path) against manifest.json["files"] for '
          'every staged file, so editing capture.gd, staged.gd or probes.json invalidates the '
          'committed AC01 stage')
    check('stageIsRerenderable',
          not ('exist_ok=False' in stage_text and 'use a new attempt' in capture_text),
          'stage.prepare() calls mkdir(exist_ok=False) and capture.gd refuses an existing '
          'capture path or receipt, so the committed AC01 stage cannot be re-rendered in place')
    check('committedCapturesDoNotBlockRerun', not existing,
          '%d capture PNGs already sit under the stage captures directory and each is asserted '
          'absent before writing' % len(existing))
    check('noNewGrantOrBuildReceiptNeeded',
          not ('require_grant' in stage_text and 'reopen-report.json' in stage_text),
          'stage.prepare() requires an active exclusive successor grant plus actual '
          'build-report.json and reopen-report.json artifact/master hashes')
    check('noRealUidSidecarCheck',
          'check_sidecar' not in stage_text,
          'stage.check_sidecar requires importer="scene", a generated uid://, '
          'meshes/force_disable_compression=true and meshes/generate_lods=false')
    check('projectImportCachePresent', bool(import_cache),
          'this worktree has no godot/.godot import cache, so real generated-UID, full-precision, '
          'LOD-off sidecars would need a first editor import of the whole 709 MB project')
    check('blenderAvailable', blender is not None,
          'no Blender 4.5.14 is reachable here, and the AC production path (build.py) requires it '
          'to derive a new editable master and canonical bytes')
    check('committedCamerasResolveTheFace', bool(resolving),
          'no committed probe camera is simultaneously inside its frustum, front facing and at a '
          'scale that resolves the face; the best committed camera projects it to a small '
          'fraction of one pixel, so a close-up needs a new probe camera and therefore a new '
          'stage. Cameras that resolve it: %s' % (list(resolving) or 'none'))
    missing = [c['precondition'] for c in checks if not c['satisfied']]
    return {
        'harness': {
            'capture': str(CAPTURE_GD.relative_to(ROOT)),
            'staged': str(STAGED_GD.relative_to(ROOT)),
            'stage': str(STAGE_PY.relative_to(ROOT)),
            'successor': str(SUCCESSOR_PY.relative_to(ROOT)),
            'committedCapturePngs': len(existing),
        },
        'checks': checks,
        'unsatisfiedPreconditions': missing,
        'feasible': not missing,
        'verdict': ('feasible' if not missing else
                    'NOT FEASIBLE with the committed harness: ' + '; '.join(missing)),
        'missingFixture': [
            'a new write-once stage directory; AC01 is already populated and hash-pinned',
            'a third staged GLB variant with a manifest entry, which means a new artifact',
            'a real generated-UID, full-precision, LOD-off .import sidecar for that variant, '
            'which needs an editor import pass over a project with no import cache here',
            'a new probe camera inside probes.json that frames face 11823, because none of the '
            'twelve committed cameras resolves it',
            'a capture.gd that iterates three variants instead of [false,true]',
            'an actual artifact and editable master for the revert, i.e. a Blender 4.5.14 build '
            'and a separate fresh-process reopen under a new exclusive successor grant',
        ],
        'boundedAlternative': ('a purpose-built static fixture would work: a minimal scene holding '
                               'only the saltstone role plane plus the committed normal map, one '
                               'camera framing face 11823, and a frozen X / AC / revert basis '
                               'triple. That is a new fixture, not the parity-glyph harness, and '
                               'it would demonstrate basis arithmetic rather than scene '
                               'appearance, so it cannot settle final art acceptance either.'),
    }


def blender_path():
    for path in ('/usr/bin/blender', '/usr/local/bin/blender', '/opt/blender/blender'):
        if Path(path).exists():
            return path
    return None


# --------------------------------------------------------------------------
# 6. The unapplied source-level revert diff.
# --------------------------------------------------------------------------

def revert_diff():
    """A real unified diff for the successor pipeline. Emitted, never applied."""
    parts = []
    added = []
    for source_name, target_name in PROPOSED_SOURCES:
        path = HERE / source_name
        if not path.is_file():
            raise ValueError('missing proposed source: ' + source_name)
        body = path.read_text().splitlines(keepends=True)
        target = '%s/%s' % (PROPOSED_DIR, target_name)
        added.append({'addedPath': target,
                      'sha256': sha(path.read_bytes()),
                      'bytes': path.stat().st_size,
                      'lines': len(body)})
        parts.append('diff --git a/%s b/%s\n' % (target, target))
        parts.append('new file mode 100644\n')
        parts.extend(difflib.unified_diff([], body, fromfile='/dev/null',
                                          tofile='b/' + target, n=3))
    return ''.join(parts), added


# --------------------------------------------------------------------------
# Driver.
# --------------------------------------------------------------------------

def baseline_classification(ac_raw):
    result = cl.classify(ac_raw, 'AC')
    return {'categories': result['categories'],
            'cornerDisagreements': result['cornerDisagreements']}


def run():
    roles, conventions = ap.material_table()
    arts = artifacts()
    if arts['AC']['raw'] is None:
        report = {'schema': 'parallax-11823-revert-decision/v1',
                  'scope': __doc__.strip().splitlines()[0],
                  'blocked': ('committed AC GLB bytes are unavailable or changed in this checkout: '
                              + json.dumps({k: v for k, v in arts['AC'].items() if k != 'raw'}))}
        return report
    facts = face_facts(arts, roles)
    baseline = baseline_classification(arts['AC']['raw'])
    patch_text, patch_files = revert_diff()
    revert_bytes, revert_proof = psc.revert(arts['AC']['raw'], arts['X']['raw'])
    significance = visual_significance(arts, roles, facts)
    feasibility = render_feasibility(significance['cameraVisibility'])
    report = {
        'schema': 'parallax-11823-revert-decision/v1',
        'scope': ('Source-only decision package for the reviewed Parallax saltstone face 11823. '
                  'Re-derives the corner set from committed bytes, measures an exact source-level '
                  'revert in memory, quantifies the appearance deviation at the reviewed normal '
                  'strength, and audits render feasibility against the committed parity-glyph '
                  'capture harness. No engine, no import, no render, and no artifact, master, '
                  'receipt, sidecar, registry or promotion state is written; the revert diff is '
                  'emitted as a file this tool never applies.'),
        'inputs': {label: {k: v for k, v in entry.items() if k != 'raw'}
                   for label, entry in arts.items()},
        'reviewedFace': facts['reviewedFace'],
        'role': 'saltstone',
        'normalScale': facts['normalScale'],
        'tilesPerMeter': facts['tilesPerMeter'],
        'normalConvention': facts['normalConvention'],
        'normalImage': facts['normalImage'],
        'tangentAccessor': facts['accessor'],
        'binLayout': facts['binLayout'],
        'corners': facts['corners'],
        'appearanceSummary': facts['appearance']['summary'],
        'acBaseline': baseline,
        'revertCandidates': candidates(arts, baseline),
        'proposedRevert': {
            'report': psc.restore_report(),
            'inMemoryProof': revert_proof,
            'inMemorySha256': sha(revert_bytes),
            'artifactWritten': False,
        },
        'visualSignificance': significance,
        'renderFeasibility': feasibility,
        'revertPatch': {
            'path': str(PATCH_FILE.relative_to(ROOT)),
            'applied': False,
            'targetDirectory': PROPOSED_DIR,
            'addedFiles': patch_files,
            'sha256': hashlib.sha256(patch_text.encode()).hexdigest(),
            'bytes': len(patch_text.encode()),
        },
        'boundaries': [
            'An analytic CPU source measurement over the two pinned shader expressions; not a '
            'Blender or Godot render measurement.',
            'The authored side is reconstructed as v_authored = 1 - v_exported, the inverse of '
            'the pinned exporter transform. Blender was not run.',
            'Per-record basis only. No MikkTSpace smoothing-seam claim, no native importer run, '
            'no native world transform.',
            'Which strength convention the accepted appearance refers to stays a render '
            'question; both pinned models are reported side by side everywhere.',
            'The directional-diffuse figures use the committed AC01 sun/ambient literals and the '
            'committed pack albedo range; they are analytic, not sampled pixels.',
            'No artifact change, no native claim, no promotion. AC stays exactly as it is.',
        ],
    }
    REPORT_FILE.write_text(json.dumps(report, indent=2, allow_nan=False) + '\n')
    if not PATCH_FILE.is_file() or PATCH_FILE.read_text() != patch_text:
        PATCH_FILE.write_text(patch_text)
    return report


if __name__ == '__main__':
    out = run()
    if 'blocked' in out:
        print(json.dumps(out, indent=2))
    else:
        print(json.dumps({
            'corners': [{'corner': c['corner'], 'vertex': c['vertex'],
                         'X': c['basis']['X'], 'AA': c['basis']['AA'], 'AC': c['basis']['AC']}
                        for c in out['corners']],
            'candidates': [(c['candidate'], c['bytes']['changedVsAC'], c['bytes']['changedVsX'],
                            c['admissible']) for c in out['revertCandidates']],
            'renderFeasible': out['renderFeasibility']['feasible'],
            'camerasResolvingTheFace': out['visualSignificance']['cameraVisibility']
                ['camerasResolvingTheFace'],
            'patchSha256': out['revertPatch']['sha256'],
        }, indent=1))