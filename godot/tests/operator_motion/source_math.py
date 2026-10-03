#!/usr/bin/env python3
"""Source-only gate. Executes the scalar production GDScript equations in Python.

This is NOT a Godot runtime/IK/render pass. The deliberately small translation
supports only the four scalar functions below, and fails on unsupported syntax.
The independent checks are dimensional/semigroup/contact invariants, not a second
copy of those equations. GLB measurements use actual authored node/accessor data.
"""
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Vec(tuple):
    def __new__(cls, *values):
        return tuple.__new__(cls, values)

    x = property(lambda self: self[0])
    y = property(lambda self: self[1])
    z = property(lambda self: self[2])


def production_math():
    text = (ROOT / 'source_operators/motion_math.gd').read_text()
    names = ['spring', 'smooth', 'stride_contact', 'gait']
    code = []
    active = False
    for line in text.splitlines():
        if line.startswith('static func '):
            name = line.split('(')[0].split()[-1]
            active = name in names
            if active:
                line = re.sub(r' -> [^:]+:', ':', line)
                line = re.sub(r': (float|Vector2|Vector3)', '', line)
                code.append(line.replace('static func ', 'def '))
            continue
        if not active or not line.strip() or line.lstrip().startswith('#'):
            continue
        line = re.sub(r'\bvar (\w+)\s*(?:: float)?\s*:?=', r'\1 =', line)
        code.append(line)
    env = dict(sin=math.sin, exp=math.exp, sqrt=math.sqrt, pow=pow,
               clampf=lambda x, lo, hi: max(lo, min(hi, x)),
               lerpf=lambda a, b, t: a + (b - a) * t,
               fposmod=lambda x, y: x % y, maxf=max, minf=min,
               Vector2=Vec, Vector3=Vec, PI=math.pi, TAU=math.tau)
    exec(compile('\n'.join(code), 'production-motion-math', 'exec'), env)
    return env


M = production_math()


class MotionMath(unittest.TestCase):
    def test_critical_spring_partition_invariance(self):
        for rate in [9, 12, 22, 24, 28]:
            exact = M['spring'](.13, -2.4, -.02, rate, .6)
            for hz in [30, 60, 144]:
                value, velocity = .13, -2.4
                dt = 1 / hz
                time = 0
                while time < .6 - 1e-12:
                    step = min(dt, .6 - time)
                    value, velocity = M['spring'](value, velocity, -.02, rate, step)
                    time += step
                self.assertAlmostEqual(value, exact.x, places=12)
                self.assertAlmostEqual(velocity, exact.y, places=12)
            first = M['spring'](.13, -2.4, -.02, rate, .1)
            hitched = M['spring'](*first, -.02, rate, .5)
            self.assertAlmostEqual(hitched.x, exact.x, places=12)

    def test_stance_world_velocity_cancels_travel(self):
        # Independent world-space invariant for forwards/backwards/diagonals.
        # Deliberately exercises speeds below maxSpeed, the original slip bug.
        for speed in [1, 2, 4, 8, 11]:
            for crouch in [0, .5, 1]:
                cycle, stance, lift = M['gait'](speed, crouch, .69)
                for hz in [30, 60, 144]:
                    for angle in [0, math.pi / 2, math.pi, -math.pi / 4]:
                        phase = stance * .15 * math.tau
                        dt = min(1 / hz, cycle * stance * .3 / speed)
                        a = M['stride_contact'](phase, cycle, lift, stance)
                        b = M['stride_contact'](phase + speed * dt * math.tau / cycle, cycle, lift, stance)
                        for component in [math.sin(angle), math.cos(angle)]:
                            drift = (speed * dt + b.x - a.x) * component
                            self.assertLess(abs(drift), 1e-12)
                        self.assertEqual(a.y, 0)
                        self.assertEqual(b.y, 0)

    def test_swing_clearance_reach_and_phase_wrap(self):
        for speed in [0, .1, 1, 2, 4, 8, 11]:
            for crouch in [0, 1]:
                cycle, stance, lift = M['gait'](speed, crouch, .69)
                self.assertLessEqual(cycle * stance / 2, .69 * .5 + 1e-12)
                mid = M['stride_contact']((stance + (1-stance)/2) * math.tau, cycle, lift, stance)
                self.assertAlmostEqual(mid.y, lift)
                self.assertAlmostEqual(mid.x, 0)
                for t in [.1, .3, .9]:
                    a = M['stride_contact'](t * math.tau, cycle, lift, stance)
                    b = M['stride_contact']((t + 4) * math.tau, cycle, lift, stance)
                    self.assertAlmostEqual(a.x, b.x)
                    self.assertAlmostEqual(a.y, b.y)

    def test_contact_velocity_continuity(self):
        for speed in [1, 2, 4, 8, 11]:
            cycle, stance, lift = M['gait'](speed, 0, .69)
            eps = 1e-6
            for boundary in [0, stance * math.tau]:
                a = M['stride_contact'](boundary-eps, cycle, lift, stance)
                b = M['stride_contact'](boundary, cycle, lift, stance)
                c = M['stride_contact'](boundary+eps, cycle, lift, stance)
                self.assertAlmostEqual((b.x-a.x)/eps, -cycle/math.tau, places=5)
                self.assertAlmostEqual((c.x-b.x)/eps, -cycle/math.tau, places=5)
                self.assertAlmostEqual((b.y-a.y)/eps, 0, places=5)
                self.assertAlmostEqual((c.y-b.y)/eps, 0, places=5)

    def test_nine_actual_rigs_contact_plane_and_asset_identity(self):
        catalog = json.loads((ROOT / 'source_operators/generated/catalog.gd').read_text().split('const OPERATORS = ', 1)[1])
        self.assertEqual(len(catalog), 9)
        for identity, record in catalog.items():
            data = (ROOT / f'source_operators/generated/{identity}.glb').read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), record['sha256'])
            gltf = json.loads(data[20:20 + struct.unpack_from('<I', data, 12)[0]])
            nodes = gltf['nodes']
            by_name = {n.get('name'): i for i, n in enumerate(nodes)}
            parents = {child: i for i, n in enumerate(nodes) for child in n.get('children', [])}

            def position(index):
                n = nodes[index]
                # Rigid source pivots are translation-only; refuse assumptions.
                matrix = n.get('matrix')
                if matrix:
                    self.assertEqual(matrix[:12], [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0])
                return matrix[12:15] if matrix else n.get('translation', [0, 0, 0])

            def world(index):
                value = position(index)
                if index in parents:
                    value = [a+b for a, b in zip(value, world(parents[index]))]
                return value

            for side in ['L', 'R']:
                hip, knee, foot = [by_name[key+side] for key in ['legUpper', 'legLower', 'foot']]
                a = math.dist(world(hip), world(knee))
                b = math.dist(world(knee), world(foot))
                self.assertAlmostEqual(a, .34)
                self.assertAlmostEqual(b, .35)
                # The intermediate pivot owns the thigh length; reading the
                # legLower translation alone would produce a zero-length thigh.
                self.assertEqual(position(knee), [0, 0, 0])
                minimum = min(gltf['accessors'][prim['attributes']['POSITION']]['min'][1]
                              for child in nodes[foot]['children']
                              for prim in gltf['meshes'][nodes[child]['mesh']]['primitives'])
                self.assertAlmostEqual(world(foot)[1] + minimum, 0, places=7)
            self.assertFalse(gltf.get('animations'), 'Baked motion now requires an ownership review')


if __name__ == '__main__':
    unittest.main(verbosity=2)
