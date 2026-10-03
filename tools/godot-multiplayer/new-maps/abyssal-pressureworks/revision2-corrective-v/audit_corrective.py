"""Compare entire fresh GLB to the fresh reopened-master GLB, and source ray contacts."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parents[4] / 'tools/map-variety-support'))
sys.path.insert(0, str(HERE.parents[4] / 'tools/map-variety-pipeline'))
from build_entry import _glb_material_images
from service_cave_contacts import glb_triangles, segment_hits, triangles_from_authority, triangles_from_specs
import layout
from native_harness import IDENTITY, validate_export, sha, atomic_json


def canonical_triangles(path):
    # Winding is retained (allow cyclic permutations); material batching/node
    # ordering may differ between two genuine exports of the same saved mesh.
    triangles = Counter()
    for name, triangle in glb_triangles(path):
        vertices = tuple(tuple(round(float(v), 4) for v in point) for point in triangle)
        triangles[name, min(vertices, vertices[1:] + vertices[:1], vertices[2:] + vertices[:2])] += 1
    return triangles


def audit(output):
    report = json.loads((output / 'material-report.json').read_text())
    candidate = json.loads((HERE / 'candidate.json').read_text())
    if report['geometryHash'] != candidate['geometryHash'] or candidate['geometryHash'] != IDENTITY:
        raise ValueError('Fresh report does not describe corrected source')
    primary = output / 'corrective.glb'
    reopened = output / 'reexport.glb'
    validated = validate_export(primary, report)
    # This export currently reproduces byte-for-byte. Keep an exact comparison
    # as the strongest possible normals/tangents/transforms and PBR proof; a
    # future exporter changing serialization must earn a new audited comparator.
    if sha(primary) != sha(reopened):
        raise ValueError('Reopened master reexport differs at GLB byte level (including normals/tangents/transforms)')
    # Reexport has independent bytes, but must have the same whole-scene mesh
    # topology, world coordinates, material bindings, and embedded PBR pixels.
    from glb_geometry import EmbeddedGlb
    other = EmbeddedGlb(reopened.read_bytes())
    primitives, triangles, used = other.geometry()
    if len(primitives) != validated['primitives'] or triangles != validated['triangles'] or not used:
        raise ValueError('Reopened master export lost primitives or triangles')
    if canonical_triangles(primary) != canonical_triangles(reopened):
        raise ValueError('Reopened master-to-GLB world geometry differs')
    images1, images2 = _glb_material_images(primary), _glb_material_images(reopened)
    if images1.keys() != images2.keys():
        raise ValueError('Reopened master material registry differs')
    # Compare decoded PNG pixel content, not PNG container compression.
    from material_pack import linear_rgba
    for material in images1:
        for channel in ('color', 'normal', 'roughness'):
            a, b = images1[material][channel], images2[material][channel]
            if (a is None) != (b is None) or (a is not None and linear_rgba(a) != linear_rgba(b)):
                raise ValueError('Reexport material pixel mismatch: %s/%s' % (material, channel))
    authority = list(triangles_from_authority(candidate['arena']))
    visual = list(glb_triangles(primary))
    # These old rays identified T art with no collision. New geometry must not
    # introduce a visually contactable service-cave ledge within their span.
    cases = [((-106, 7.2, -97), (-106, 7.2, -100)),
             ((-94, 10, -98.5), (-94, 5, -98.5)),
             ((91, 4, -92.5), (91, -1, -92.5))]
    rays = []
    for index, (start, end) in enumerate(cases):
        art_hits = segment_hits(start, end, visual)
        auth_hits = segment_hits(start, end, authority)
        rays.append({'start': start, 'end': end, 'art': art_hits[:8], 'authority': auth_hits[:8]})
        # Export batches are named for materials, not individual cave specs.
        # Compare every actual world-space GLB contact on these exact spans.
        if len(art_hits) != len(auth_hits) or any(
                sum((a[2][k] - b[2][k]) ** 2 for k in range(3)) ** .5 > .08
                for a, b in zip(art_hits, auth_hits)):
            raise ValueError('New GLB/authority mismatch at rejected P1 ray %d: %r vs %r' % (index, art_hits, auth_hits))
    # Explicitly find *all fourteen* decorative solid forms in the actual GLB.
    # Their material-batched node names cannot serve as object identifiers;
    # instead ray-probe each source form's exposed middle face and compare
    # actual GLB world contacts to the original, unbevelled authored mesh.
    forms = [part for part in layout.parts(candidate['arena']) if part['name'].startswith('service-cave.')]
    if len(forms) != 14:
        raise ValueError('Corrective source lost one of fourteen cave solids')
    form_rows = []
    for form in forms:
        bounds = [(min(v[axis] for v in form['vertices']), max(v[axis] for v in form['vertices']))
                  for axis in range(3)]
        axis = 1 if '.ledge' in form['name'] else (2 if '.0.' in form['name'] else 0)
        center = [(a + b) / 2 for a, b in bounds]
        start, end = center.copy(), center.copy()
        start[axis], end[axis] = bounds[axis][0] - .25, bounds[axis][1] + .25
        expected = segment_hits(start, end, list(triangles_from_specs([form])))
        actual = segment_hits(start, end, visual)
        matched = [point for _, _, point in expected if any(
            sum((point[i] - hit[2][i]) ** 2 for i in range(3)) ** .5 < .09 for hit in actual)]
        if not expected or not matched:
            raise ValueError('No actual GLB face near authored cave solid: ' + form['name'])
        form_rows.append({'name': form['name'], 'bounds': bounds, 'rayAxis': axis,
                          'expectedContacts': len(expected), 'matchedContacts': len(matched)})
    result = {'status': 'master reexport geometry and pixels match; in-engine collision pending',
              'geometryHash': IDENTITY, 'originalGlbSha256': sha(primary),
              'reexportGlbSha256': sha(reopened), 'primitives': len(primitives),
              'triangles': triangles, 'materials': len(images1), 'historicalRays': rays,
              'sourceSolidWorldContactChecks': form_rows}
    atomic_json(output / 'geometry-audit.json', result)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-root', required=True, type=Path)
    print(json.dumps(audit(parser.parse_args().output_root)))
