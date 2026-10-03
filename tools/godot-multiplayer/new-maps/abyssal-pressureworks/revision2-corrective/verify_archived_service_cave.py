"""Explicit read-only T GLB failure reproduction; never native acceptance.

python3 verify_archived_service_cave.py --fixture-root <path-to-native-T-20261003/abyssal-pressureworks>
Or set COCS_ABYSSAL_T_FIXTURE_ROOT. Missing/wrong archive is a hard error,
never a silent skip and never searched or fetched from another checkout.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path

from service_cave_contacts import glb_triangles, segment_hits

HERE = Path(__file__).resolve().parent
GLB_SHA256 = '925883eff465b7d470a36e215107420228ca8f537a08f2e3a7a879231668bfe7'
REPORT_SHA256 = '293a4d6b9561ef29d23274e02430d234bc6f13c686361e6ee82e2c67503e0066'
FROZEN_GEOMETRY = '5fea4aada721903cea26897fb6a17befaf146c576c095dc712feebef626adfa2'


def _verified_bytes(path, digest):
    if not path.is_file():
        raise FileNotFoundError('Explicit historical T fixture missing: ' + str(path))
    raw = path.read_bytes()
    actual = hashlib.sha256(raw).hexdigest()
    if actual != digest:
        raise ValueError('Wrong historical T fixture SHA-256 at %s: %s != %s' % (path, actual, digest))
    return raw


def verify(fixture_root):
    root = Path(fixture_root).expanduser().resolve()
    glb = root / 'abyssal-pressureworks-revision2.glb'
    report_file = root / 'material-report.json'
    # Hash both *before* any large GLB parse. An old candidate's coincidental
    # name or nearby generated JSON is never accepted as this specific fixture.
    _verified_bytes(glb, GLB_SHA256)
    report = json.loads(_verified_bytes(report_file, REPORT_SHA256))
    frozen = json.loads((HERE.parent / 'revision2/candidate.json').read_text())
    current = json.loads((HERE / 'candidate.json').read_text())
    if report['glbSha256'] != GLB_SHA256 or report['geometryHash'] != FROZEN_GEOMETRY or frozen['geometryHash'] != FROZEN_GEOMETRY:
        raise ValueError('Historical report/source geometry identity mismatch')
    if current['geometryHash'] == FROZEN_GEOMETRY:
        raise ValueError('Corrective candidate incorrectly reuses rejected geometry identity')
    triangles = list(glb_triangles(glb))
    if len(triangles) != report['glbTriangles']:
        raise ValueError('Historical primitive triangle inventory changed')
    cases = [((-106, 7.2, -97), (-106, 7.2, -100), 'deep-silt', 2, (-98.35, -98.65)),
             ((-94, 10, -98.5), (-94, 5, -98.5), 'salt-limestone', 1, (8.6, 8.2)),
             ((91, 4, -92.5), (91, -1, -92.5), 'salt-limestone', 1, (2.6, 2.2))]
    results = []
    for start, end, material, axis, coordinates in cases:
        hits = segment_hits(start, end, triangles)
        for coordinate in coordinates:
            if not any(material in name and abs(point[axis] - coordinate) < .002 for _, name, point in hits):
                raise ValueError('Missing reviewed P1 contact at %s: %r' % (coordinate, hits[:8]))
        results.append({'start': start, 'end': end, 'reviewedContactCoordinates': coordinates})
    return {'status': 'reproduced historical rejected T geometry; corrective native build pending',
            'fixtureRoot': str(root), 'glbSha256': GLB_SHA256, 'reportSha256': REPORT_SHA256,
            'historicalGeometryHash': FROZEN_GEOMETRY,
            'correctiveSourceGeometryHash': current['geometryHash'],
            'historicalTriangles': len(triangles), 'rays': results}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-root', default=os.environ.get('COCS_ABYSSAL_T_FIXTURE_ROOT'),
                        help='Explicit readonly directory containing the frozen T GLB and material-report.json')
    args = parser.parse_args(argv)
    if not args.fixture_root:
        parser.error('provide --fixture-root or COCS_ABYSSAL_T_FIXTURE_ROOT; no fixture search or skip')
    print(json.dumps(verify(args.fixture_root), indent=2))


if __name__ == '__main__':
    main()
