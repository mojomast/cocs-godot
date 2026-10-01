#!/usr/bin/env python3
"""Conservative v1 story-operator visibility audit for selective gesture recapture.

Matches the v1 camera paths and terrain interpolation. Tests a 1.5m actor sphere,
ignores occlusion (so false positives cause recapture, never false approval).
"""
import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def vec(p):
    return [p['x'], p['y'], p['z']]


def add(a, b):
    return [x+y for x, y in zip(a, b)]


def sub(a, b):
    return [x-y for x, y in zip(a, b)]


def dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def unit(a):
    n = math.sqrt(dot(a, a))
    return [x/n for x in a]


def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]


def camera(h, r, recipe, heights):
    shot, focus = h['shot'], vec(h['focus'])
    t = r['frame'] / (shot['seconds']*24-1)
    if shot.get('camera') == 'fp':
        a = r['state']['actors'][0]
        eye = [a['x'], a['y']+a.get('eyeHeight', 1.45), a['z']]
        forward = [-math.sin(a['yaw'])*math.cos(a['pitch']), math.sin(a['pitch']), -math.cos(a['yaw'])*math.cos(a['pitch'])]
        return eye, forward
    if shot['kind'] == 'terrain':
        overview = recipe['cameras'][0]
        target = overview['target']
        scale = .9 if shot.get('height', 15) >= 30 else .68
        eye = add(add(target, [v*scale for v in sub(overview['at'], target)]), [-10+20*t, 0, -5+10*t])
        return eye, unit(sub(add(target, [-4+8*t, 0, 0]), eye))
    distance, height = {'npc':(3.3, 1.5), 'pet':(3.4, 1.4), 'artillery':(14, 9)}.get(shot['kind'], (8, 2.8))
    angle = -.45+.8*t
    if shot['kind'] in ('npc', 'pet'):
        angle += math.pi
    if shot['kind'] in ('combat', 'warden') and 'vantage' in h:
        angle = math.atan2(h['vantage']['x']-focus[0], h['vantage']['z']-focus[2])-.12+.24*t
        distance, height = (10 if shot['kind'] == 'combat' else 5.5), 2.3
    eye = add(focus, [math.sin(angle)*distance, height, math.cos(angle)*distance])
    bounds = recipe['arena']['bounds']
    x, z = eye[0], eye[2]
    if bounds['minX'] <= x <= bounds['maxX'] and bounds['minZ'] <= z <= bounds['maxZ']:
        ix = min(math.floor((x-bounds['minX'])/4)*4+bounds['minX'], bounds['maxX']-4)
        iz = min(math.floor((z-bounds['minZ'])/4)*4+bounds['minZ'], bounds['maxZ']-4)
        u, v = (x-ix)/4, (z-iz)/4
        a, b, c, d = [heights[p] for p in [(ix,iz), (ix,iz+4), (ix+4,iz+4), (ix+4,iz)]]
        ground = a+(c-b)*u+(b-a)*v if v >= u else a+(d-a)*u+(c-d)*v
        eye[1] = max(eye[1], ground+1.2)
    target = add(focus, [0, .5 if shot['kind'] == 'pet' else 1.3 if shot['kind'] == 'warden' else .8, 0])
    return eye, unit(sub(target, eye))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--evidence', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    manifest = json.loads((ROOT/'tools/godot-campaign/trailer.json').read_text())
    report = []
    for shot in manifest['shots']:
        recipe = json.loads((ROOT/f'godot/campaign/generated/{shot["map"]}.json').read_text())
        heights = {(v[0],v[2]):v[1] for s in recipe['arena']['terrain']['surfaces'] for v in s['vertices']}
        seen = {}
        with (args.evidence/shot['id']/'replay.jsonl').open() as f:
            header = json.loads(next(f))
            for line in f:
                r = json.loads(line)
                eye, forward = camera(header, r, recipe, heights)
                right = unit(cross(forward, [0, 1, 0]))
                up = cross(right, forward)
                for e in r['state']['campaign']['story']['entities']:
                    if e['kind'] != 'operator' or not e['active']:
                        continue
                    delta = sub(add(vec(e), [0, .9, 0]), eye)
                    depth = dot(delta, forward)
                    if math.sqrt(dot(delta,delta)) > 90.1 or depth < -1.5:
                        continue
                    half = max(0,depth)*math.tan(math.radians(65)/2)
                    if abs(dot(delta,right)) <= half*16/9+1.5 and abs(dot(delta,up)) <= half+1.5:
                        seen.setdefault(e['id'], []).append(r['frame'])
        report.append({'shot':shot['id'], 'recapture':bool(seen), 'potentiallyVisibleOperators':
                       {k:{'first':min(v),'last':max(v),'frames':len(v)} for k,v in seen.items()}})
    args.output.write_text(json.dumps({'method':'v1 paths; 1.5m sphere; occlusion ignored', 'shots':report}, indent=2))
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
