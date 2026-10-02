"""Source-only queue contract tests; no bpy import, engine or master execution."""
import ast
import hashlib
import json
from pathlib import Path
import re
import tempfile
from types import SimpleNamespace as NS
import unittest

from moth_finish import family, FAMILIES, checked_source, derive_pixels, uv_project

ROOT = Path(__file__).resolve().parents[2]


class FinishTests(unittest.TestCase):
    def test_live_queue_palettes_are_reviewed(self):
        # Read actual builder/recipe palettes, rather than enumerating the role
        # table twice. Adding a new material must prompt a semantic decision.
        for unit, filename in (
            ('vesper-viaduct', 'author_blender.py'),
            ('stormglass-causeway', 'blender_export.py'),
        ):
            tree = ast.parse((ROOT/'tools/godot-multiplayer/new-maps'/unit/filename).read_text())
            palette = next(ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
                           and any(isinstance(t, ast.Name) and t.id == 'COLORS' for t in n.targets))
            for name in palette:
                self.assertIsInstance(family(name, unit), str)
        data = json.loads((ROOT/'tools/godot-biomes/expansion/meshes.json').read_text())
        for name in data['palette']:
            family('biome4_' + name, 'scenery')
        data = json.loads((ROOT/'port/native-multiplayer-worlds/worlds/abyssal-pressureworks.json').read_text())
        for name in data['art']['palette']:
            family(name, 'abyssal-pressureworks')
        source = (ROOT/'tools/godot-vehicle-assets/recipe.mjs').read_text().split('export const palette = {')[1].split('};')[0]
        for name in re.findall(r'(\w+)\s*:\s*\[', source):
            family(name, 'vehicles')
        source = (ROOT/'tools/godot-robots/build.py').read_text()
        for name in re.findall(r"materials.new\('([^']+)'\)", source):
            family(name, 'robots')

    def test_semantics_not_color_or_substring(self):
        self.assertEqual(family('navy', 'abyssal-pressureworks'), 'coating')
        self.assertEqual(family('biome4_moss.001', 'scenery'), 'foliage')
        self.assertEqual(family('rubber', 'vehicles'), 'rubber')
        self.assertEqual(family('seat', 'vehicles'), 'fabric')
        self.assertEqual(family('lamp', 'vehicles'), 'preserve')
        self.assertEqual(family('Switchyard_vertex_enamel', 'robots'), 'coating')
        for name, unit in [('mystery', 'vehicles'), ('steelish', 'stormglass-causeway'),
                           ('navy', 'vehicles'), ('glass', 'unknown')]:
            with self.assertRaisesRegex(ValueError, 'review required'):
                family(name, unit)
        for role in ('coating', 'rubber', 'fabric', 'foliage', 'coral'):
            self.assertEqual(FAMILIES[role][2], 0)

    def test_actual_moth_hashes_and_tamper_refusal(self):
        manifest = json.loads((ROOT/'godot/moth/generated/manifest.json').read_text())
        for key, *_ in FAMILIES.values():
            checked_source(ROOT, manifest['textures'][key])
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as folder:
            p = Path(folder)/'godot/test.png'
            p.parent.mkdir(); p.write_bytes(b'original source')
            record = {'path': 'res://test.png', 'png_sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
            checked_source(folder, record)
            p.write_bytes(b'modified source')
            with self.assertRaisesRegex(ValueError, 'hash mismatch'):
                checked_source(folder, record)

    def test_multiscale_pixels_neutral_bounded_source_dependent(self):
        source = [c for y in range(8) for x in range(8) for c in (x/8, y/8, (x+y)/16, 1)]
        for role in FAMILIES:
            colors, normals = derive_pixels(source, 8, 8, role)
            self.assertGreater(max(colors[::4])-min(colors[::4]), .001)
            for i in range(0, len(colors), 4):
                self.assertEqual(colors[i], colors[i+1]); self.assertEqual(colors[i], colors[i+2])
                self.assertTrue(.94 <= colors[i] <= 1.05)
                self.assertAlmostEqual(sum((c*2-1)**2 for c in normals[i:i+3]), 1)
            changed, _ = derive_pixels([.5]*(8*8*4), 8, 8, role)
            self.assertNotEqual(colors, changed)

    def test_uv_part_identity_pose_stability_and_join_preservation(self):
        class Layers(dict):
            def new(self, name):
                self[name] = NS(data=[NS(uv=None) for _ in range(3)])
                return self[name]
        class Object(dict):
            pass
        def part(name):
            obj = Object()
            obj.name = name; obj.parent_bone = 'wheel'; obj.scale = (1, 2, 3)
            obj.data = NS(users=1, uv_layers=Layers(),
                          vertices=[NS(index=i, co=p) for i, p in enumerate(((0, 0, 0), (1, 0, 0), (0, 1, 0)))],
                          edges=[NS(vertices=e) for e in ((0, 1), (1, 2), (2, 0))],
                          loops=[NS(vertex_index=i) for i in range(3)],
                          polygons=[NS(material_index=0, normal=(0, 0, 1), loop_indices=(0, 1, 2), loop_start=0)],
                          materials=[NS(name='rubber')])
            return obj
        def uvs(obj):
            uv_project(obj, (1, 1, 1), 'vehicles')
            return [v.uv for v in obj.data.uv_layers['MothLocal'].data]
        a = part('front-left'); first = uvs(a)
        self.assertEqual(first, uvs(part('front-left')))
        self.assertNotEqual(first, uvs(part('rear-left')))
        # Manufactured orientation/density stays fixed while phase differs.
        other = uvs(part('rear-left'))
        self.assertAlmostEqual(first[1][0]-first[0][0], other[1][0]-other[0][0])
        a.name = 'joined-batch'; a.location = (98, 34, -27); a.rotation_euler = (1, 2, 3)
        self.assertEqual(first, uvs(a))


if __name__ == '__main__':
    unittest.main()
