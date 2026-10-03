#!/usr/bin/env python3
"""Execute the shared scalar kick sequence/pose source without launching Godot.

Limited syntax adapter, not a native event-routing/transform/audio test. Native
coverage lives in melee_contracts.gd and remains pending an engine grant.
"""
import math
from pathlib import Path
import re
import unittest

GODOT = Path(__file__).resolve().parents[2]


class Vector(tuple):
    def __new__(cls, *values):
        return tuple.__new__(cls, values)

    def __mul__(self, value):
        return Vector(*(component * value for component in self))


def sequence():
    source = (GODOT / 'first_person/kick_motion.gd').read_text()
    members = re.findall(r'^var (\w+)', source, re.M)
    code = []
    for line in source.splitlines():
        if not line.strip() or line.lstrip().startswith('#') or line.startswith('extends '):
            continue
        if line.startswith(('func ', 'static func ')):
            line = re.sub(r' -> [^:]+:', ':', line)
            line = re.sub(r': (Dictionary|float|bool|int)', '', line)
            line = re.sub(r'\btrue\b', 'True', line)
            line = re.sub(r'\bfalse\b', 'False', line)
            code.append(line.replace('static func ', 'def ').replace('func ', 'def '))
            code.append('\tglobal ' + ','.join(members))
            continue
        line = re.sub(r'\b(var|const) (\w+)\s*(?:: (?:Variant|float))?\s*:?=', r'\2 =', line)
        line = re.sub(r'for (\w+): int in ', r'for \1 in ', line)
        line = re.sub(r'(\w+) is (int|float)', r'type(\1) == \2', line)
        line = re.sub(r'(\w+)\.size\(\)', r'len(\1)', line)
        line = re.sub(r'\btrue\b', 'True', line)
        line = re.sub(r'\bfalse\b', 'False', line)
        code.append(line)

    def smoothstep(a, b, value):
        t = max(0, min(1, (value-a)/(b-a)))
        return t*t*(3-2*t)

    env = dict(INF=math.inf, is_finite=math.isfinite, floor=math.floor,
               minf=min, clampf=lambda v, a, b: max(a, min(b, v)),
               clampi=lambda v, a, b: max(a, min(b, v)), Vector3=Vector,
               smoothstep=smoothstep, lerpf=lambda a, b, t: a+(b-a)*t)
    exec(compile('\n'.join(code), 'production-kick-motion', 'exec'), env)
    return env


def event(index, time, hit=3, **extra):
    return dict(id=index, time=time, type='melee', actor=2, hit=hit, **extra)


def rotate_xyz(vector, angles):
    # Independent matrix composition for the imported anatomical axes: Z,Y,X.
    x, y, z = vector
    a, b, c = angles
    x, y = math.cos(c)*x-math.sin(c)*y, math.sin(c)*x+math.cos(c)*y
    x, z = math.cos(b)*x+math.sin(b)*z, -math.sin(b)*x+math.cos(b)*z
    y, z = math.cos(a)*y-math.sin(a)*z, math.sin(a)*y+math.cos(a)*z
    return x, y, z


class WorldMeleeSource(unittest.TestCase):
    def test_accepted_chain_and_duplicates(self):
        state = sequence()
        for index in range(1, 5):
            accepted = event(index, index*.32)
            self.assertTrue(state['accept'](accepted))
            self.assertEqual(state['step'], (index-1) % 3)
            self.assertFalse(state['accept'](accepted))
            self.assertEqual(state['accepted'], index)

    def test_miss_block_protection_and_interrupt(self):
        for denied in [dict(hit=None), dict(hit=3, blocked=True), dict(hit=3, protected=True)]:
            state = sequence()
            self.assertTrue(state['accept'](event(1, 1)))
            self.assertTrue(state['accept'](event(2, 1.32, **denied)))
            self.assertEqual(state['step'], 1)
            self.assertFalse(state['continuing'])
            self.assertTrue(state['accept'](event(3, 1.64)))
            self.assertEqual(state['step'], 0)
            state['interrupt']()
            self.assertFalse(state['accept'](event(3, 1.64)))
            self.assertFalse(state['sample']()['visible'])

    def test_invalid_clock_ids_and_exact_completion(self):
        state = sequence()
        for bad in [event(-1, 1), event(1.5, 1), event(1, math.nan), event(1, -1), event(True, 1)]:
            self.assertFalse(state['accept'](bad))
        for hz in [30, 60, 144]:
            state = sequence()
            state['accept'](event(1, 1))
            for _ in range(math.ceil(.29*hz)):
                state['advance'](1/hz)
            self.assertFalse(state['sample']()['visible'])
            self.assertEqual(state['age'], state['DURATION'])

    def test_world_anatomical_contact_without_camera_root(self):
        state = sequence()
        for strike in range(3):
            pose = state['pose'](strike, state['CONTACT'])
            thigh = rotate_xyz((0, -.34, 0), pose['hip'])
            shin = rotate_xyz(rotate_xyz((0, -.35, 0), pose['knee']), pose['hip'])
            ankle = tuple(a+b for a, b in zip(thigh, shin))
            self.assertLess(ankle[2], -.45, 'accepted contact must extend forward in -Z')
            self.assertLess(abs(ankle[0]), .45, 'world leg must remain a bounded lateral strike')
            self.assertGreater(.7835+ankle[1], .3, 'contact must lift the authored ankle')
            self.assertAlmostEqual(math.dist((0, 0, 0), thigh), .34)
            self.assertAlmostEqual(math.dist((0, 0, 0), shin), .35)
            self.assertGreater(pose['hip'][0], 1)
            self.assertLess(pose['knee'][0], 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
