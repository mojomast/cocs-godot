"""World-space authored solid face winding against real exported GLB triangles.

Standalone post-build audit. Does not write or alter master, source, or GLB.
The material batch names cannot identify individual source parts; matching by
world-space ray contact and facing normal avoids that false shortcut.
"""
import argparse
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE), str(HERE.parents[4] / 'tools/map-variety-support')]
import layout
from service_cave_contacts import glb_triangles, segment_hits, triangles_from_specs


def normal(triangle):
    a, b, c = triangle
    u = [b[i] - a[i] for i in range(3)]
    v = [c[i] - a[i] for i in range(3)]
    cross = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
    length = math.sqrt(sum(x*x for x in cross))
    if length < 1e-10:
        raise ValueError('Collapsed visual/source face')
    return [x/length for x in cross]


def verify(glb):
    arena = json.loads((HERE / 'candidate.json').read_text())['arena']
    forms = [s for s in layout.parts(arena) if s['name'].startswith('service-cave.')]
    if len(forms) != 14:
        raise ValueError('Expected fourteen source cave solids')
    actual = list(glb_triangles(glb))
    rows = []
    for form in forms:
        bounds = [(min(v[axis] for v in form['vertices']), max(v[axis] for v in form['vertices']))
                  for axis in range(3)]
        axis = 1 if '.ledge' in form['name'] else (2 if '.0.' in form['name'] else 0)
        start = [(a+b)/2 for a,b in bounds]
        end = start.copy()
        start[axis],end[axis] = bounds[axis][0]-.25,bounds[axis][1]+.25
        source = list(triangles_from_specs([form]))
        source_hits = segment_hits(start, end, [(str(i), face) for i, (_, face) in enumerate(source)])
        actual_hits = segment_hits(start, end, [(str(i), face) for i, (_, face) in enumerate(actual)])
        tested = []
        for _, source_id, point in source_hits:
            candidates = [hit for hit in actual_hits if math.dist(point, hit[2]) < .09]
            if not candidates:
                raise ValueError('Missing exported face at source contact: ' + form['name'])
            match = min(candidates, key=lambda hit: math.dist(point, hit[2]))
            expected = normal(source[int(source_id)][1])
            exported = normal(actual[int(match[1])][1])
            dot = sum(a*b for a,b in zip(expected, exported))
            if dot < .85:
                raise ValueError('Reversed/misaligned exported winding for %s (dot %f)' % (form['name'], dot))
            tested.append(round(dot, 6))
        if not tested:
            raise ValueError('No contact face on ' + form['name'])
        rows.append({'name':form['name'], 'contactFaceNormals':tested})
    return {'status':'fourteen actual GLB forms face same direction as authored source',
            'glb':str(glb), 'forms':rows}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--glb', type=Path, required=True)
    print(json.dumps(verify(parser.parse_args().glb), indent=2))
