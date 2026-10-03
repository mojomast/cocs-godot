"""Adversarial structural/lineage checks; no Blender or engine needed."""
import importlib.util
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location('map_variety_receipt', Path(__file__).with_name('receipt.py'))
receipt = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(receipt)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def glb_doc(*, color=True, normal=True, invalid_index=False):
    payload = bytearray(256)
    payload.extend(b'color-embedded' + b'normal-embedded')
    doc = {'asset': {'version': '2.0'}, 'buffers': [{'byteLength': len(payload)}],
           'bufferViews': [{'buffer': 0, 'byteOffset': 0, 'byteLength': 48},
                           {'buffer': 0, 'byteOffset': 256, 'byteLength': 14},
                           {'buffer': 0, 'byteOffset': 270, 'byteLength': 15}],
           'accessors': [{'bufferView': 0, 'byteOffset': 0, 'componentType': 5126,
                          'count': 1, 'type': t} for t in ('VEC3', 'VEC3', 'VEC2', 'VEC4')],
           'meshes': [{'primitives': [{'material': 0, 'attributes': {'POSITION': 0, 'NORMAL': 1,
                       'TEXCOORD_0': 2, 'TANGENT': 3}}]}],
           'materials': [{'name': 'stone', 'pbrMetallicRoughness': {}}],
           'images': [{'bufferView': 1, 'mimeType': 'image/png'},
                      {'bufferView': 2, 'mimeType': 'image/png'}],
           'textures': [{'source': 0}, {'source': 1}]}
    if color:
        doc['materials'][0]['pbrMetallicRoughness']['baseColorTexture'] = {'index': 99 if invalid_index else 0}
    if normal:
        doc['materials'][0]['normalTexture'] = {'index': 1}
    text = json.dumps(doc).encode()
    text += b' ' * (-len(text) % 4)
    payload.extend(b'\0' * (-len(payload) % 4))
    return b'glTF' + struct.pack('<II', 2, 12+8+len(text)+8+len(payload)) + struct.pack('<I4s',len(text),b'JSON') + text + struct.pack('<I4s',len(payload),b'BIN\0') + payload


class ReceiptTests(unittest.TestCase):
    def test_texture_slots_resolve_to_real_embedded_bytes(self):
        binding = {'stone': {'role': 'surface', 'normal': 'rock'}}
        report = receipt.inspect_art(glb_doc(), binding, 4)
        self.assertEqual(report['materialImages']['stone']['color'], sha(b'color-embedded'))
        for changes in ({'color': False}, {'normal': False}, {'invalid_index': True}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                receipt.inspect_art(glb_doc(**changes), binding, 4)

    def test_built_requires_actual_normal_source_and_mapped_export(self):
        original = receipt.ROOT
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as temporary:
            receipt.ROOT = Path(temporary)
            try:
                def put(path, content):
                    dest = receipt.ROOT / path
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes(content)
                    return sha(content)
                source = put('game/source.mjs', b'actual source')
                color = put('godot/moth/generated/textures/stone.png', b'color-source')
                normal = put('godot/moth/generated/normals/stone.png', b'normal-source')
                manifest = {'provenance': {'source': 'game/source.mjs', 'source_sha256': source},
                            'textures': {'stone': {'path': 'res://moth/generated/textures/stone.png', 'png_sha256': color}},
                            'normals': {'stone': {'path': 'res://moth/generated/normals/stone.png', 'png_sha256': normal}}}
                mh = put('manifest.json', json.dumps(manifest).encode())
                authority = {'id': 'example', 'geometryHash': 'a'*64}
                ah = put('map.json', json.dumps(authority).encode())
                bh = put('example.blend', b'BLENDER-v450' + b'editable geometry')
                gh = put('example.glb', glb_doc())
                report = {'id': 'example', 'geometryHash': 'a'*64, 'mothManifestSha256': mh, 'glbSha256': gh,
                          'materials': {'stone': {'sourceColorSha256': color, 'sourceNormalSha256': normal,
                          'embeddedColorSha256': sha(b'color-embedded'), 'embeddedNormalSha256': sha(b'normal-embedded'),
                          'tilesPerMeter': 1.2, 'teamColorSource': None}}}
                rh = put('report.json', json.dumps(report).encode())
                candidate = {'schemaVersion': 1, 'moth': {'manifest': 'manifest.json', 'sha256': mh},
                             'maps': [{'id': 'example', 'authority': {'path': 'map.json', 'sha256': ah, 'geometryHash': 'a'*64},
                             'materials': {'stone': {'role': 'surface', 'texture': 'stone', 'normal': 'stone', 'tilesPerMeter': 1.2}},
                             'art': {'blend': 'example.blend', 'blendSha256': bh, 'glb': 'example.glb',
                                     'glbSha256': gh, 'report': 'report.json', 'reportSha256': rh, 'maxPrimitives': 4}}]}
                self.assertTrue(receipt.verify(candidate, True)['maps'][0]['built'])
                candidate['maps'][0]['materials']['stone']['normal'] = 'missing'
                with self.assertRaises(KeyError): receipt.verify(candidate, True)
                candidate['maps'][0]['materials']['stone']['normal'] = 'stone'
                report['materials']['stone']['embeddedNormalSha256'] = 'b'*64
                candidate['maps'][0]['art']['reportSha256'] = put('report.json', json.dumps(report).encode())
                with self.assertRaisesRegex(ValueError, 'mapping mismatch'): receipt.verify(candidate, True)
            finally:
                receipt.ROOT = original


if __name__ == '__main__':
    unittest.main()
