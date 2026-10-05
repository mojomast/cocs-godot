"""Proposed successor step: restore X's usable saltstone face-11823 basis.

UNAPPLIED. This module exists so the revert proposal in
`revert_proposal.py` is reviewable, testable source rather than a description.
It is byte arithmetic over the committed AC artifact and writes nothing: no
GLB, no master, no receipt, no sidecar, no capture. It is *not* wired into
`districts-v4-glyph-tangents/successor.py`; AC stays exactly as it is.

Why a successor step and not an edit to the AA compiler
-------------------------------------------------------
The three saltstone records were written by `districts-v4-tangent.contract.repair`
(X -> AA) and are inherited unchanged by `districts-v4-glyph-tangents.successor`
(AA -> AC). AC's three-corner edit is a reviewed, historically closed production
attempt, so a revert cannot be an edit to either compiler: it has to be a new
revision that consumes AC bytes and writes the basis back. That is what this
module is.

What "X's usable basis" means, exactly
--------------------------------------
X stores, on the three exclusive vertices of saltstone face 11823:

    corner 0 (vertex 24049): T = (0, 0, 0, +1)   <- NOT usable
    corner 1 (vertex 24050): T = (1, 0, 0, +1)   <- usable
    corner 2 (vertex 24051): T = (1, 0, 0, +1)   <- usable

Corner 0's X record is a zero tangent: `T.xyz` is the zero vector, so the
spec-prescribed bitangent `cross(N,T)*w` collapses to zero and the tangent space
the record is supposed to define does not exist. It is one of the 17
spec-invalid records that AC exists to close, and AC closes it. A byte-exact X
restore would put that spec-invalid record straight back, so it is rejected here
and the choice is made explicit rather than smuggled:

  * corners 1 and 2 are restored to X's stored bytes exactly; and
  * corner 0 keeps w = +1, which is the sign X stored, and takes the same usable
    unit `T.xyz = (1, 0, 0)` its two face-mates carry, so the whole triangle
    shares one handedness.

X supplies no appearance to restore at corner 0 -- its frame did not exist -- so
corner 0 is a declared choice, not a restoration. The measured consequence of
that choice is in `revert_proposal.json`.

Byte scope
----------
Three 16-byte `TANGENT` records in accessor 48, inside the 48 BIN positions the
AA compiler already declared for exactly these three vertices. Exactly three BIN
bytes change relative to AC: the final byte of each record's `w` float
(`0xbf` -> `0x3f`). Nothing else in the container, the scene, the geometry, the
materials or the embedded images moves, and both containment checks the AA
compiler already relies on are re-run here.

Re-verification a real revert would still need
----------------------------------------------
This module is source arithmetic. Producing an artifact from it would require,
at minimum, a new exclusive successor grant and revision string, a Blender
4.5.14 editable-master build and a separate fresh-process reopen, the native
mesh-local all-155,553-face proof with 19 repaired entries and 51 incident
occurrences re-mapped, the frozen R7 native material/image gate, matched
before/after captures, and manual material appearance acceptance. None of that
is claimed or run here.
"""
import copy
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/map_variety'))
sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/botanical-parallax-aa-diagnosis'))
from glb_geometry import EmbeddedGlb
import classify_records as cl
import contract as aa

REVERT = 'parallax-districts-v5-saltstone-green-revert-v1'
PREDECESSOR = 'parallax-districts-v4-glyph-tangents-v1'
ACCESSOR = 48
VERTICES = aa.VERTICES                       # (24049, 24050, 24051)
USABLE = (1., 0., 0., 1.)                    # X's stored basis where X had one
X_BASIS = ((0., 0., 0., 1.), USABLE, USABLE)  # X's stored bytes, corner 0 unusable
REVERT_BASIS = (USABLE, USABLE, USABLE)
EXPECTED_AC_SHA = cl.AC_SHA
PERMITTED_BYTES = 48
EXPECTED_CHANGED_BYTES = 3
ALPHA = 1e-12


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def encode(doc, blob):
    header = json.dumps(doc, separators=(',', ':'), allow_nan=False).encode()
    header += b' ' * (-len(header) % 4)
    return (struct.pack('<III', 0x46546c67, 2, 28 + len(header) + len(blob))
            + struct.pack('<I4s', len(header), b'JSON') + header
            + struct.pack('<I4s', len(blob), b'BIN\0') + bytes(blob))


def validate_rows(rows):
    """The record-level preconditions, independent of any container.

    Split out of `reviewed_state` so the guards can be driven from synthetic
    rows: a wrong AC record, a wrong X record, a vertex that picked up a second
    incident face, and a corner-0 record that is not the reviewed X zero tangent
    each have to be rejected, so a pass is not vacuous.
    """
    if [row['corner'] for row in rows] != list(range(len(VERTICES))) \
            or [row['vertex'] for row in rows] != list(VERTICES):
        raise ValueError('reviewed corner/vertex set changed')
    for row in rows:
        if row['incidentFaces'] != [11823]:
            raise ValueError('Reviewed vertex %d is no longer exclusive to face 11823'
                             % row['vertex'])
    if tuple(row['acTangent'] for row in rows) != (USABLE[:3] + (-1.,),) * 3:
        raise ValueError('AC no longer stores the reviewed uniform (+1,0,0,-1) on face 11823')
    # The proposal's whole shape rests on X having *no* usable basis at corner 0
    # and a usable one at corners 1-2, so that asymmetry is checked as a fact
    # about X rather than assumed from the byte comparison below.
    if not cl.spec_verdict(rows[0]['normal'], tuple(rows[0]['xTangent'])):
        raise ValueError('X corner 0 is expected to be the spec-invalid zero tangent, so the '
                         'revert has no usable X basis to restore there')
    for row in rows[1:]:
        if cl.spec_verdict(row['normal'], tuple(row['xTangent'])):
            raise ValueError('X corners 1-2 are expected to carry usable bases')
    if tuple(row['xTangent'] for row in rows) != X_BASIS:
        raise ValueError('X no longer stores the reviewed (0,0,0,+1)/(+1,0,0,+1) basis')
    return rows


def plan(ac_binary, x_binary, rows, doc, images):
    """Apply the revert to a BIN blob and run every containment guard.

    Container-independent on purpose: the guards are the interesting part, and
    they can be driven against synthetic blobs and a synthetic accessor table
    instead of only against the committed 19 MB artifact.
    """
    if not isinstance(ac_binary, (bytes, bytearray)):
        raise ValueError('AC BIN blob required')
    blob = bytearray(ac_binary)
    permitted = set()
    for row in rows:
        offset = row['binOffset']
        permitted |= set(range(offset, offset + 16))
        struct.pack_into('<4f', blob, offset, *REVERT_BASIS[row['corner']])
    if len(permitted) != PERMITTED_BYTES:
        raise ValueError('permitted storage window is not the reviewed 48 bytes')
    changed = {i for i, (before, after) in enumerate(zip(ac_binary, blob)) if before != after}
    if len(changed) != EXPECTED_CHANGED_BYTES or not changed <= permitted:
        raise ValueError('revert exceeds the reviewed three-byte delta inside the 48-byte window')
    for index, accessor in enumerate(doc['accessors']):
        if index == ACCESSOR:
            continue
        _, count, (start, stride, fmt) = _accessor_layout(doc, index, ac_binary)
        width = struct.calcsize(fmt)
        if any(0 <= offset - start and (offset - start) // stride < count
               and (offset - start) % stride < width for offset in changed):
            raise ValueError('revert aliases another accessor')
    for start, length in images:
        if any(start <= offset < start + length for offset in changed):
            raise ValueError('revert aliases an embedded image')
    return blob, changed, permitted


def _accessor_layout(doc, index, binary):
    """The AA compiler's own accessor probe, on a plain accessor table."""
    accessor = doc['accessors'][index]
    if 'sparse' in accessor or accessor.get('normalized', False):
        raise ValueError('unsupported accessor')
    shape = accessor['type']
    component = accessor['componentType']
    width, fmt = {5121: (1, 'B'), 5123: (2, 'H'), 5125: (4, 'I'), 5126: (4, 'f')}[component]
    dimensions = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[shape]
    view = doc['bufferViews'][accessor['bufferView']]
    base = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    stride = view.get('byteStride', width * dimensions)
    count = accessor['count']
    if offset_out_of_range(base, stride, dimensions * width, count, view, binary):
        raise ValueError('accessor exceeds its bufferView')
    del binary
    return accessor, count, (base, stride, '<' + fmt * dimensions)


def offset_out_of_range(base, stride, size, count, view, binary):
    return base + (count - 1) * stride + size > view.get('byteOffset', 0) + view['byteLength'] \
        or base + (count - 1) * stride + size > len(binary)


def reviewed_state(ac_raw, x_raw):
    """Fail closed unless AC and X still hold exactly the reviewed records."""
    if sha(ac_raw) != EXPECTED_AC_SHA:
        raise ValueError('Exact committed AC bytes required')
    if sha(x_raw) != aa.SOURCE_SHA:
        raise ValueError('Exact committed X bytes required')
    ac = EmbeddedGlb(ac_raw)
    ac.geometry()
    x = EmbeddedGlb(x_raw)
    x.geometry()
    _, _, ac_layout = ac.accessor(ACCESSOR, 'VEC4', (5126,), 'TANGENT')
    _, _, x_layout = x.accessor(ACCESSOR, 'VEC4', (5126,), 'TANGENT')
    if list(ac_layout) != list(x_layout):
        raise ValueError('TANGENT accessor layout drifted between AC and X')
    ac_positions, ac_normals, ac_uv, ac_tangents, ac_indices = aa.source_face(ac)
    x_positions, x_normals, x_uv, x_tangents, x_indices = aa.source_face(x)
    if ac_positions != x_positions or ac_normals != x_normals or ac_uv != x_uv \
            or ac_indices != x_indices:
        raise ValueError('Reviewed face geometry drifted between AC and X')
    rows = []
    for corner, vertex in enumerate(VERTICES):
        incidents = [i // 3 for i in range(0, len(ac_indices), 3)
                     if vertex in ac_indices[i:i + 3]]
        rows.append({
            'corner': corner, 'vertex': vertex,
            'acTangent': tuple(ac_tangents[vertex]),
            'xTangent': tuple(x_tangents[vertex]),
            'normal': tuple(ac_normals[vertex]),
            'incidentFaces': incidents,
            'binOffset': ac_layout[0] + vertex * ac_layout[1],
        })
    validate_rows(rows)
    return ac, ac_layout, rows


def revert(ac_raw, x_raw):
    """In-memory revert successor. Returns (bytes, proof). Writes nothing."""
    glb, layout, rows = reviewed_state(ac_raw, x_raw)
    if layout[1] != 16:
        raise ValueError('TANGENT accessor stride is not 16 bytes')
    images = []
    for image in glb.doc['images']:
        images.append(glb._view(glb.doc['bufferViews'][image['bufferView']]))
    blob, changed, permitted = plan(glb.binary, None, rows, glb.doc, images)
    doc = copy.deepcopy(glb.doc)
    doc['asset'].setdefault('extras', {}).update({
        'visualRevision': REVERT,
        'tangentPredecessorSha256': EXPECTED_AC_SHA,
        'tangentRevertsRevision': PREDECESSOR,
        'tangentPolicy': ('Restore X w=+1 on the three reviewed exclusive saltstone face 11823 '
                          'corners; corners 1-2 byte-identical to X, corner 0 declared usable '
                          'because X stored a zero tangent there')})
    for node in doc['nodes']:
        node.setdefault('extras', {})['visualRevision'] = REVERT
    result = encode(doc, blob)
    proof = {
        'visualRevision': REVERT,
        'predecessorRevision': PREDECESSOR,
        'predecessorSha256': EXPECTED_AC_SHA,
        'sourceXSha256': aa.SOURCE_SHA,
        'artifactSha256': None,
        'masterSha256': None,
        'face': 11823,
        'vertices': list(VERTICES),
        'accessor': ACCESSOR,
        'permittedBINBytes': len(permitted),
        'changedBINBytes': len(changed),
        'changedBINPositions': sorted(changed),
        'records': [
            {'corner': row['corner'], 'vertex': row['vertex'],
             'binOffset': row['binOffset'],
             'xTangent': list(row['xTangent']),
             'acTangent': list(row['acTangent']),
             'revertTangent': list(REVERT_BASIS[row['corner']]),
             'byteIdenticalToX': (row['xTangent'] == REVERT_BASIS[row['corner']]),
             # spec_verdict returns reasons, so truthy means the record is *invalid*.
             'xSpecVerdict': list(cl.spec_verdict(row['normal'], row['xTangent'])),
             'xUsableBasisExists': not cl.spec_verdict(row['normal'], row['xTangent'])}
            for row in rows],
        'allOtherBINBytesIdenticalToAC': True,
        'normalUVIndexMaterialJSONUnchanged': True,
        'artifactWritten': False,
        'nativeAcceptance': 'pending',
        'scope': ('Deterministic source/in-memory byte arithmetic over committed AC bytes. Not an '
                  'artifact, not a native proof, not a render, not appearance acceptance.'),
    }
    return result, proof


def verify(ac_raw, x_raw, output):
    """Post-condition a real build would have to satisfy. Not exercised here."""
    expected, proof = revert(ac_raw, x_raw)
    if output != expected:
        raise ValueError('Output differs from the canonical revert successor')
    actual = EmbeddedGlb(output)
    parts, triangles, _ = actual.geometry()
    if len(parts) != 39 or triangles != 155553:
        raise ValueError('Geometry inventory changed')
    checked = invalid = 0
    for mesh in actual.doc['meshes']:
        for primitive in mesh['primitives']:
            normals = cl.stream(actual, primitive['attributes']['NORMAL'], 'VEC3')
            for vertex, tangent in enumerate(cl.stream(actual,
                                                       primitive['attributes']['TANGENT'], 'VEC4')):
                if any(not math.isfinite(v) for v in tangent) \
                        or tangent[3] not in (-1., 1.) \
                        or abs(cl.norm(tangent[:3]) - 1) > cl.NONUNIT_TOL:
                    raise ValueError('undefined or invalid source tangent; no zero waiver')
                if cl.spec_verdict(normals[vertex], tangent):
                    invalid += 1
                checked += 1
    if invalid:
        raise ValueError('revert successor would carry %d spec-invalid tangent records' % invalid)
    return {**proof, 'artifactSha256': sha(output), 'finiteUnitTangentRecords': checked,
            'specInvalidRecords': invalid}


def restore_report():
    """Static description of the proposal, for the decision package."""
    return {
        'status': 'PROPOSAL ONLY, not applied',
        'revision': REVERT,
        'predecessorRevision': PREDECESSOR,
        'predecessorSha256': EXPECTED_AC_SHA,
        'basis': [list(t) for t in REVERT_BASIS],
        'xBasis': [list(t) for t in X_BASIS],
        'corner0Decision': ('X stored a zero tangent here, which is spec-invalid and defines no '
                            'tangent space. The revert refuses to restore it and instead keeps '
                            'X w=+1 with the usable unit T.xyz=(1,0,0) its face-mates carry, so '
                            'one triangle keeps one handedness.'),
        'byteScope': ('three 16-byte TANGENT records in accessor 48, inside the 48 BIN positions '
                      'the AA compiler already declared; exactly three BIN bytes change relative '
                      'to AC (each record w float 0xbf -> 0x3f)'),
        'artifactWritten': False,
        'patch': 'revert-11823-successor.patch (emitted, never applied)',
        'whatARealRevertStillNeeds': [
            'a new exclusive successor grant and revision string',
            'Blender 4.5.14 editable-master build and a separate fresh-process reopen',
            'fresh native mesh-local all-face proof: 155,553 strict equivalent faces, 19 repaired '
            'entries, 51 incident occurrences re-mapped, 0 parallel native corners',
            'the frozen R7 native material field (14 sets) and decoded image channel (39) gate',
            'matched before/after captures and manual material appearance acceptance',
        ],
    }
