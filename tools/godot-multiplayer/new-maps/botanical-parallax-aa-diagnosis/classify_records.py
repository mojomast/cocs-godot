"""Deterministic Parallax tangent-record classifier: spec-invalid vs
spec-valid-but-derivative-disagreeing vs unaffected. Source/math only.

This does not replace the census, it *reads* it. Every threshold below is
census.py's own literal and `reconcile_with_census` re-derives the committed
inventory through `census.source_faces` so the two cannot drift apart. The
near-global raw UV-derivative disagreement stays a category, not a verdict:
glTF 2.0 §3.7.2.1 requires T.xyz normalized and T.w a handedness sign; it does
not require dot(N,T)=0 per record. MikkTSpace is the recommendation for
*generated* tangents, not a validity test for supplied ones.

No engine, no import, no render, no artifact, master, receipt, registry or
promotion state is touched. Output is a diagnostic JSON next to the census.
"""
import collections as C
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import census
from census import (EmbeddedGlb, stream, derivative, dot, cross, norm, sha,
                    SOURCE, SOURCE_SHA, ROOT)

# census.py literals, restated once. `reconcile_with_census` re-derives the
# committed census counts with census.py itself, so a drift here fails loudly
# instead of silently reclassifying records.
NONUNIT_TOL = .001
PARALLEL_NT_TOL = 1e-12
# `census.derivative` owns the actual det/area comparison; this restates the
# literal it uses so the emitted thresholds block is auditable.
UV_DET_TOL = 1e-15
AREA_TOL = 1e-12

SPEC_INVALID = 'specInvalid'
SPEC_VALID_DISAGREEING = 'specValidDerivativeDisagreeing'
UNAFFECTED = 'unaffectedOther'
CATEGORIES = (SPEC_INVALID, SPEC_VALID_DISAGREEING, UNAFFECTED)

# Per-corner raw-derivative disagreement kinds, as a bitmask so a record can
# carry the union of every incident face's disagreement without storing faces.
CORNER_FLAGS = (('wSignDisagrees', 1), ('storedTangentOpposesDU', 2),
                ('storedBinormalOpposesDV', 4))
ZERO_AREA = 'zeroAreaFace'
UV_RANK_FAILURE = 'uvRankFailure'
FULL_RANK = 'fullRank'
FACE_STATES = (FULL_RANK, UV_RANK_FAILURE, ZERO_AREA)
SAMPLE_LIMIT = 3
FACE_SAMPLE_LIMIT = 2
FLAGGED_CORNER_LIMIT = 64

AC_GLB = ROOT / ('tools/godot-multiplayer/new-maps/parallax-observatory/revisions/'
                 'districts-v4-glyph-tangents/native/AC01/parallax-glyph-tangents.glb')
AC_SHA = '0903dc4f8487ff9011204a63421a398b3f647bd8b5baca4d1552aa67d00a660b'
SINGULAR_GLYPH_RECORDS = tuple((accessor, vertex)
                               for accessor in (165, 170)
                               for vertex in (1026, 1027, 1038, 1039, 1050, 1051, 1062, 1063))
REVIEWED_FACE = {'role': 'saltstone', 'mesh': 9, 'face': 11823, 'vertices': (24049, 24050, 24051)}


def flag_names(mask):
    return tuple(name for name, bit in CORNER_FLAGS if mask & bit)


def spec_verdict(N, T):
    """glTF 2.0 §3.7.2.1 record validity, decided without any UV derivative.

    `degenerateFrame` is the spec's own prescribed bitangent, `cross(N,T)*w`,
    collapsing to the zero vector: the tangent space the record is supposed to
    define does not exist. That is a frame-validity failure, distinct from the
    `nonorthogonalNT` advisory that the blocked program counted as a gate.
    """
    if any(not math.isfinite(x) for x in tuple(N) + tuple(T)):
        return ('nonFiniteRecord',)
    reasons = []
    if norm(T[:3]) == 0:
        reasons.append('zeroTangent')
    if abs(norm(T[:3]) - 1) > NONUNIT_TOL:
        reasons.append('nonUnitTangent')
    if T[3] not in (-1., 1.):
        reasons.append('wNotSign')
    if abs(norm(N) - 1) > NONUNIT_TOL:
        reasons.append('nonUnitNormal')
    if norm(cross(N, T[:3])) < PARALLEL_NT_TOL:
        reasons.append('degenerateFrame')
    return tuple(reasons)


def record_advisories(N, T, normal_texture):
    """Non-verdict observations. `nonorthogonalNT` is the 4,729/4,745 figure."""
    out = []
    if abs(dot(N, T[:3])) > NONUNIT_TOL:
        out.append('nonorthogonalNT')
    if not normal_texture:
        out.append('roleWithoutNormalTexture')
    return tuple(out)


def face_verdict(corners):
    """`census.derivative` plus the rank reason its single bool cannot express."""
    d = derivative(corners)
    if d['defined']:
        return FULL_RANK, d
    return (ZERO_AREA if d['area'] <= AREA_TOL else UV_RANK_FAILURE), d


def corner_disagreements(corner, d, derived_sign):
    """Raw exported-V derivative comparison. Not an appearance or spec verdict."""
    N, T = corner['N'], corner['T']
    mask = 0
    if T[3] != derived_sign:
        mask |= 1
    if dot(T[:3], d['du']) < 0:
        mask |= 2
    if dot(cross(N, T[:3]), d['dv']) * T[3] < 0:
        mask |= 4
    return mask


def record_category(spec, disagree, rank_failure, zero_area, agreeing):
    """Composite record category. Category (a) dominates (b) dominates (c)."""
    if spec:
        return SPEC_INVALID, 'spec:' + '+'.join(spec)
    if disagree:
        return SPEC_VALID_DISAGREEING, 'derivative:' + '+'.join(flag_names(disagree))
    if rank_failure:
        return UNAFFECTED, UV_RANK_FAILURE + 'Only'
    if zero_area:
        return UNAFFECTED, ZERO_AREA + 'Only'
    if agreeing:
        return UNAFFECTED, 'derivativeAgreeing'
    return UNAFFECTED, 'noIncidentFace'


def scene_parts(g):
    nodes = [n for n in g.doc['nodes'] if 'mesh' in n]
    names = [n['name'].replace('.', '_') for n in nodes]
    if len(names) != len(set(names)):
        raise ValueError('Node-name sanitization collision')
    return nodes


def primitive_arrays(g, primitive):
    fields = (('N', 'NORMAL', 'VEC3'), ('T', 'TANGENT', 'VEC4'),
              ('P', 'POSITION', 'VEC3'), ('UV', 'TEXCOORD_0', 'VEC2'))
    return {k: stream(g, primitive['attributes'][a], shape)
            for k, a, shape in fields}


def face_corners(arrays, indices, face):
    return [{'N': arrays['N'][v], 'T': arrays['T'][v], 'P': arrays['P'][v],
             'UV': arrays['UV'][v], 'vertex': v, 'corner': ci}
            for ci, v in enumerate(indices[face * 3:face * 3 + 3])]


def classify(raw, label, include_records=False):
    """Two-axis classification of every supplied TANGENT record and face.

    Axis 1 `specStatus` is normative (glTF 2.0 §3.7.2.1) plus frame
    degeneracy. Axis 2 `derivativeStatus` is the raw exported-UV derivative
    metric the census already measures. The composite record category is
    (a) spec-invalid, (b) spec-valid but derivative-disagreeing, (c) the rest.
    """
    g = EmbeddedGlb(raw)
    _, triangles, _ = g.geometry()
    rows = []
    # Four parallel tallies, one slot per supplied TANGENT record in enumeration
    # order. Flat lists rather than per-record dicts keep the 319k-record census
    # cheap to hold and to replay.
    masks = []
    agreeing = []
    rank_failure = []
    zero_area = []
    face_counts = C.Counter()
    corner_counts = C.Counter()
    corner_totals = C.Counter()
    face_samples = C.defaultdict(list)
    flagged = []
    flagged_truncated = 0
    for node_index, node in enumerate(scene_parts(g)):
        mesh = node['mesh']
        for primitive_index, primitive in enumerate(g.doc['meshes'][mesh]['primitives']):
            arrays = primitive_arrays(g, primitive)
            indices = [v[0] for v in stream(g, primitive['indices'], 'SCALAR', (5121, 5123, 5125))]
            material = g.doc['materials'][primitive['material']]
            role = material['name']
            slot = material.get('normalTexture')
            normal_texture = isinstance(slot, dict)
            normal_scale = None if not normal_texture else slot.get('scale', 1.0)
            base = len(rows)
            count = len(arrays['T'])
            local_masks = [0] * count
            local_agreeing = [0] * count
            local_rank_failure = [0] * count
            local_zero_area = [0] * count
            for vertex, (N, T) in enumerate(zip(arrays['N'], arrays['T'])):
                rows.append({'node': node['name'], 'nodeIndex': node_index, 'mesh': mesh,
                             'primitive': primitive_index, 'accessor': primitive['attributes']['TANGENT'],
                             'vertex': vertex, 'N': N, 'T': T, 'role': role,
                             'normalTexture': normal_texture, 'normalScale': normal_scale,
                             'spec': spec_verdict(N, T),
                             'advisories': record_advisories(N, T, normal_texture)})
            for face in range(len(indices) // 3):
                corners = face_corners(arrays, indices, face)
                state, d = face_verdict(corners)
                face_counts[state] += 1
                corner_totals[state] += len(corners)
                if state != FULL_RANK:
                    counter = local_zero_area if state == ZERO_AREA else local_rank_failure
                    for c in corners:
                        counter[c['vertex']] += 1
                else:
                    for corner_index, c in enumerate(corners):
                        mask = corner_disagreements(c, d, d['wFromUV'][corner_index])
                        corner_counts.update(flag_names(mask))
                        if mask:
                            local_masks[c['vertex']] |= mask
                        else:
                            local_agreeing[c['vertex']] += 1
                        if mask & 2:
                            if len(flagged) < FLAGGED_CORNER_LIMIT:
                                flagged.append({'node': node['name'], 'nodeIndex': node_index,
                                                'mesh': mesh, 'primitive': primitive_index,
                                                'face': face, 'corner': c['corner'],
                                                'vertex': c['vertex'], 'role': role,
                                                'flags': flag_names(mask), 'N': c['N'], 'T': c['T'],
                                                'UV': c['UV'], 'dPdu': d['du'],
                                                'dotTangentDudu': dot(c['T'][:3], d['du']),
                                                'uvJacobian': d['uvJacobian'], 'area': d['area']})
                            else:
                                flagged_truncated += 1
                key = (role, 'disagreeing' if state == FULL_RANK and any(local_masks[c['vertex']] for c in corners)
                       else 'agreeing' if state == FULL_RANK else state)
                bucket = face_samples[key]
                if len(bucket) < FACE_SAMPLE_LIMIT:
                    bucket.append({'node': node['name'], 'nodeIndex': node_index, 'mesh': mesh,
                                   'primitive': primitive_index, 'face': face, 'role': role,
                                   'faceState': state, 'uvJacobian': d['uvJacobian'],
                                   'area': d['area'], 'cornerFlags': [flag_names(local_masks[c['vertex']]) for c in corners]})
            masks[base:base + count] = local_masks
            agreeing[base:base + count] = local_agreeing
            rank_failure[base:base + count] = local_rank_failure
            zero_area[base:base + count] = local_zero_area
    records = C.Counter()
    reasons = C.Counter()
    advisories = C.Counter()
    roles = {}
    stricter_spec_invalid = 0
    for offset, row in enumerate(rows):
        category, reason = record_category(row['spec'], masks[offset], rank_failure[offset],
                                          zero_area[offset], agreeing[offset])
        row['category'] = category
        row['reason'] = reason
        records[category] += 1
        reasons[(category, reason)] += 1
        for name in row['advisories']:
            advisories[(category, name)] += 1
        if category == SPEC_INVALID or (category == UNAFFECTED and reason == UV_RANK_FAILURE + 'Only'):
            stricter_spec_invalid += 1
        role = roles.setdefault(row['role'], {
            'normalTexture': row['normalTexture'], 'normalScale': row['normalScale'],
            'records': 0, 'categories': C.Counter(), 'advisories': C.Counter(), 'samples': {}})
        role['records'] += 1
        role['categories'][category] += 1
        for name in row['advisories']:
            role['advisories'][name] += 1
        bucket = role['samples'].setdefault(category, [])
        if len(bucket) < SAMPLE_LIMIT:
            bucket.append({k: row[k] for k in ('node', 'mesh', 'primitive', 'vertex', 'N', 'T',
                                             'spec', 'advisories', 'reason', 'role')})
    for role in roles.values():
        role['categories'] = dict(role['categories'])
        role['advisories'] = dict(role['advisories'])
    return {
        'label': label,
        'triangles': triangles,
        'records': len(rows),
        'faces': sum(face_counts.values()),
        'faceStates': {state: face_counts[state] for state in FACE_STATES},
        'cornerStates': {state: corner_totals[state] for state in FACE_STATES},
        'cornerDisagreements': {name: corner_counts[name] for name, _ in CORNER_FLAGS},
        'categories': {category: records[category] for category in CATEGORIES},
        'categoryReasons': {'%s|%s' % key: n for key, n in sorted(reasons.items())},
        'advisories': {'%s|%s' % key: n for key, n in sorted(advisories.items())},
        'stricterReadingIncludingUVRank': {
            'definition': 'category (a) plus category (c) records whose only full-rank-equivalent path is a UV-rank failure',
            'records': stricter_spec_invalid},
        'roles': roles,
        'faceSamples': {'%s|%s' % key: value for key, value in sorted(face_samples.items())},
        'storedTangentOpposesDUCorners': flagged,
        'storedTangentOpposesDUCornersTruncated': flagged_truncated,
        'corpora': {},
        'recordDetails': (rows if include_records else None),
    }


def census_inventory(raw):
    """Re-derive census.py's own inventory through census.py itself."""
    _, inventory, _ = census.source_faces(EmbeddedGlb(raw))
    return inventory['uniqueVertexRecords']


def reconcile_with_census(raw, committed_inventory, label):
    """Assert this module's thresholds still reproduce the committed census."""
    derived = census_inventory(raw)
    expected = {k: v for k, v in committed_inventory.items() if isinstance(v, int)}
    mismatched = {k: (derived.get(k), expected.get(k))
                  for k in sorted(set(derived) | set(expected)) if derived.get(k) != expected.get(k)}
    if mismatched:
        raise ValueError('census drift for %s: %r' % (label, mismatched))
    return {'label': label, 'reproducedCensusInventory': True, 'comparedKeys': sorted(expected)}


def named_cases(raw, label):
    """The three bounded cases the appearance contract must cover."""
    g = EmbeddedGlb(raw)
    g.geometry()
    want = REVIEWED_FACE
    out = {'label': label, 'saltstoneFace11823': None,
           'storedTangentOpposesDU': [], 'singularGlyphRecords': []}
    for node_index, node in enumerate(scene_parts(g)):
        mesh = node['mesh']
        for primitive_index, primitive in enumerate(g.doc['meshes'][mesh]['primitives']):
            role = g.doc['materials'][primitive['material']]['name']
            arrays = primitive_arrays(g, primitive)
            indices = [v[0] for v in stream(g, primitive['indices'], 'SCALAR', (5121, 5123, 5125))]
            faces = len(indices) // 3
            if (mesh, role) == (want['mesh'], want['role']):
                corners = face_corners(arrays, indices, want['face'])
                if tuple(c['vertex'] for c in corners) != want['vertices']:
                    raise ValueError('reviewed face 11823 vertices changed')
                state, d = face_verdict(corners)
                out['saltstoneFace11823'] = {
                    'node': node['name'], 'mesh': mesh, 'face': want['face'], 'role': role,
                    'faceState': state, 'uvJacobian': d['uvJacobian'], 'area': d['area'],
                    'dPdu': d.get('du'), 'dPdv': d.get('dv'),
                    'corners': [{'corner': c['corner'], 'vertex': c['vertex'], 'P': c['P'],
                                 'N': c['N'], 'UV': c['UV'], 'T': c['T'],
                                 'derivedSign': (d['wFromUV'][c['corner']] if d['defined'] else None),
                                 'flags': flag_names(corner_disagreements(c, d, d['wFromUV'][c['corner']]))
                                 if d['defined'] else []} for c in corners]}
            for face in range(faces):
                corners = face_corners(arrays, indices, face)
                state, d = face_verdict(corners)
                singular = [c for c in corners if 'degenerateFrame' in spec_verdict(c['N'], c['T'])]
                if singular and len(out['singularGlyphRecords']) < FLAGGED_CORNER_LIMIT * 2:
                    for c in singular:
                        out['singularGlyphRecords'].append({
                            'node': node['name'], 'mesh': mesh, 'face': face, 'role': role,
                            'corner': c['corner'], 'vertex': c['vertex'], 'N': c['N'], 'T': c['T'],
                            'UV': c['UV'], 'accessor': primitive['attributes']['TANGENT'],
                            'faceState': state, 'area': d['area'], 'uvJacobian': d['uvJacobian']})
                if not d['defined']:
                    continue
                for corner_index, c in enumerate(corners):
                    if dot(c['T'][:3], d['du']) >= 0:
                        continue
                    if len(out['storedTangentOpposesDU']) < FLAGGED_CORNER_LIMIT:
                        out['storedTangentOpposesDU'].append({
                            'node': node['name'], 'nodeIndex': node_index, 'mesh': mesh,
                            'primitive': primitive_index, 'face': face, 'role': role,
                            'corner': c['corner'], 'vertex': c['vertex'], 'N': c['N'], 'T': c['T'],
                            'UV': c['UV'], 'dPdu': d['du'], 'dPdv': d['dv'],
                            'dotTangentDudu': dot(c['T'][:3], d['du']),
                            'dotBinormalDvdv': dot(cross(c['N'], c['T'][:3]), d['dv']),
                            'uvJacobian': d['uvJacobian'], 'area': d['area'],
                            'faceUV': [c2['UV'] for c2 in corners],
                            'faceP': [c2['P'] for c2 in corners]})
    for key in ('saltstoneFace11823',):
        if out[key] is None:
            raise ValueError('reviewed %s not found in %s' % (key, label))
    singular = {(r['accessor'], r['vertex']) for r in out['singularGlyphRecords']}
    expected = set(SINGULAR_GLYPH_RECORDS)
    present = singular & expected
    if present and present != expected:
        # A partially present reviewed set is incoherent and must not be reported
        # as the sixteen. AC legitimately has none of them.
        raise ValueError('reviewed glyph singular records are only partially present: %r'
                         % sorted(expected - present))
    out['singularGlyphRecordSet'] = {
        'degenerateFrameRecords': len(singular),
        'reviewedGlyphRecordsPresent': len(present),
        'accessors': sorted({a for a, _ in singular}),
        'vertices': sorted({v for _, v in singular}),
        'otherDegenerateFrameRecords': sorted('%d:%d' % pair for pair in singular - expected),
    }
    return out


def derive_aa_from_x(raw):
    """Reproduce the reviewed three-corner successor from committed X bytes.

    `districts-v4-tangent.contract.repair` is pure source/byte arithmetic and is
    already covered by the frozen successor tests. Deriving AA this way keeps the
    classification reproducible from committed evidence instead of from an
    uncommitted external worktree.
    """
    sys.path.insert(0, str(HERE.parent / 'parallax-observatory/revisions/districts-v4-tangent'))
    import contract
    out, proof = contract.repair(raw)
    if sha(out) != census.ART_SHA:
        raise ValueError('derived AA bytes do not match the pinned failed AA artifact')
    return out, proof


def tangent_record_diff(before_raw, after_raw):
    """Exactly which supplied TANGENT records differ between two artifacts."""
    a, b = EmbeddedGlb(before_raw), EmbeddedGlb(after_raw)
    a.geometry(); b.geometry()
    before, after = {}, {}
    where = {}
    for g, into in ((a, before), (b, after)):
        for node in scene_parts(g):
            for primitive in g.doc['meshes'][node['mesh']]['primitives']:
                accessor = primitive['attributes']['TANGENT']
                where.setdefault(accessor, {'node': node['name'], 'mesh': node['mesh'],
                                            'role': g.doc['materials'][primitive['material']]['name'],
                                            'normalTexture': 'normalTexture' in g.doc['materials'][primitive['material']]})
                for vertex, T in enumerate(stream(g, accessor, 'VEC4')):
                    into[(accessor, vertex)] = T
    if set(before) != set(after):
        raise ValueError('tangent record inventory changed between artifacts')
    changed = []
    for k in sorted(before):
        if before[k] == after[k]:
            continue
        changed.append({'accessor': k[0], 'vertex': k[1], 'before': before[k], 'after': after[k],
                        'beforeNonUnitT': abs(norm(before[k][:3]) - 1) > NONUNIT_TOL,
                        'beforeWNotSign': before[k][3] not in (-1., 1.),
                        'afterNonUnitT': abs(norm(after[k][:3]) - 1) > NONUNIT_TOL,
                        'afterWNotSign': after[k][3] not in (-1., 1.),
                        'wChanged': before[k][3] != after[k][3],
                        **where[k[0]]})
    return {'records': len(before), 'changedRecords': len(changed),
            'unchangedRecords': len(before) - len(changed), 'changed': changed}


def compact(label, result):
    advisories = C.Counter()
    for key, count in result['advisories'].items():
        advisories[key.split('|', 1)[1]] += count
    rows = ['parallax tangent record classification -- %s' % label,
            '  records %d  faces %d  triangles %d' % (result['records'], result['faces'], result['triangles']),
            '  faces ' + '  '.join('%s=%d' % (k, v) for k, v in result['faceStates'].items()),
            '  (a) spec-invalid                    %d' % result['categories'][SPEC_INVALID],
            '  (b) spec-valid, derivative-disagree %d' % result['categories'][SPEC_VALID_DISAGREEING],
            '  (c) unaffected / other               %d' % result['categories'][UNAFFECTED],
            '  stricter reading incl. UV-rank       %d' % result['stricterReadingIncludingUVRank']['records'],
            '  corner disagreements ' + '  '.join('%s=%d' % (k, v) for k, v in result['cornerDisagreements'].items()),
            '  advisories ' + '  '.join('%s=%d' % (k, v) for k, v in sorted(advisories.items())),
            '  storedTangentOpposesDU corners      %d%s' % (len(result['storedTangentOpposesDUCorners']),
                                                           ' (truncated %d)' % result['storedTangentOpposesDUCornersTruncated']
                                                           if result['storedTangentOpposesDUCornersTruncated'] else '')]
    return '\n'.join(rows)


def main():
    committed = json.loads((HERE / 'source-census.json').read_text())
    inputs = []
    x_raw = SOURCE.read_bytes()
    if sha(x_raw) != SOURCE_SHA:
        raise ValueError('committed X GLB identity changed')
    inputs.append({'label': 'X', 'path': str(SOURCE.relative_to(ROOT)), 'sha256': SOURCE_SHA,
                   'available': True, 'derivation': 'committed X source GLB', 'raw': x_raw})
    aa_raw, proof = derive_aa_from_x(x_raw)
    inputs.append({'label': 'AA', 'path': str(census.NATIVE / 'candidate.glb'), 'sha256': census.ART_SHA,
                   'available': True, 'derivation': 'districts-v4-tangent.contract.repair(committed X)',
                   'derivedChangedBINBytes': proof['changedBytes'], 'raw': aa_raw})
    external = census.NATIVE / 'candidate.glb'
    inputs[-1]['externalCopyPresent'] = external.is_file()
    inputs[-1]['externalCopyMatchesDerivation'] = (
        external.read_bytes() == aa_raw if external.is_file() else None)
    if AC_GLB.is_file():
        ac_raw = AC_GLB.read_bytes()
        inputs.append({'label': 'AC', 'path': str(AC_GLB.relative_to(ROOT)), 'sha256': sha(ac_raw),
                       'expectedSha256': AC_SHA, 'available': True,
                       'derivation': 'committed AC artifact', 'raw': ac_raw})
    else:
        inputs.append({'label': 'AC', 'path': str(AC_GLB.relative_to(ROOT)), 'sha256': None,
                       'expectedSha256': AC_SHA, 'available': False,
                       'derivation': 'committed AC artifact MISSING from this checkout'})
    report = {'schema': 'parallax-tangent-record-classification/v1',
              'scope': ('Static source/math classification of supplied TANGENT records and faces. '
                        'Axis 1 is glTF 2.0 §3.7.2.1 record validity plus frame degeneracy; axis 2 is '
                        'the raw exported-UV derivative metric. No engine, no artifact change, no '
                        'promotion, no acceptance.'),
              'thresholds': {'nonunitTol': NONUNIT_TOL, 'parallelNTTol': PARALLEL_NT_TOL,
                             'uvJacobianTol': UV_DET_TOL, 'areaTol': AREA_TOL,
                             'source': 'botanical-parallax-aa-diagnosis/census.py literals'},
              'categoryDefinitions': {
                  SPEC_INVALID: 'nonfinite, zero/non-unit T, w not in {-1,+1}, non-unit N, or cross(N,T)*w degenerate',
                  SPEC_VALID_DISAGREEING: 'spec-valid and used by a full-rank face whose stored w/dP-du/dP-dv comparison disagrees',
                  UNAFFECTED: 'spec-valid with no raw derivative disagreement; UV-rank/zero-area/no-incident-face records are sub-reasons, not verdicts'},
              'inputs': [], 'reconciliation': [], 'recordDiffs': [], 'namedCases': {}}
    by_label = {}
    for entry in inputs:
        record = {k: v for k, v in entry.items() if k != 'raw'}
        if entry['available']:
            if entry.get('expectedSha256') and entry['sha256'] != entry['expectedSha256']:
                raise ValueError('%s identity changed' % entry['label'])
            result = classify(entry['raw'], entry['label'])
            result['corpora'] = named_cases(entry['raw'], entry['label'])
            by_label[entry['label']] = (result, entry['raw'])
            record['classification'] = result
            print(compact(entry['label'], result))
        else:
            record['classification'] = None
            print('%s unavailable: %s' % (entry['label'], entry['derivation']))
        report['inputs'].append(record)
        report['namedCases'][entry['label']] = (record.get('classification') or {}).get('corpora')
    for label, committed_label in (('X', 'X'), ('AA', 'AA')):
        if label in by_label:
            report['reconciliation'].append(
                reconcile_with_census(by_label[label][1], committed[committed_label]['uniqueVertexRecords'], label))
    for before, after in (('X', 'AA'), ('AA', 'AC'), ('X', 'AC')):
        if before in by_label and after in by_label:
            diff = tangent_record_diff(by_label[before][1], by_label[after][1])
            diff['from'], diff['to'] = before, after
            report['recordDiffs'].append(diff)
    (HERE / 'classification.json').write_text(json.dumps(report, indent=2, allow_nan=False) + '\n')
    return report


if __name__ == '__main__':
    main()