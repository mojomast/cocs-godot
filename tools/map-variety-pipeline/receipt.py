"""Source-only admission of a proposed Moth/Blender map-art revision.

No Blender, Godot, package import, network access, or build is invoked. The
candidate JSON is deliberately separate from the frozen map/catalog and Moth
finish. See README.md for the handoff format. Exit nonzero on missing evidence.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct


ROOT = Path(__file__).resolve().parents[2]
SHA = re.compile(r"^[0-9a-f]{64}$")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def local(relative):
    if not isinstance(relative, str) or not relative or relative.startswith(('res://', '/')):
        raise ValueError('Expected a repository-relative path: ' + str(relative))
    path = (ROOT / relative).resolve()
    if not path.is_relative_to(ROOT) or not path.is_file():
        raise ValueError('Missing/out-of-tree source: ' + relative)
    return path


def checked(relative, expected):
    if not isinstance(expected, str) or not SHA.fullmatch(expected):
        raise ValueError('Missing SHA-256 for ' + relative)
    contents = local(relative).read_bytes()
    if digest(contents) != expected:
        raise ValueError('Hash mismatch: ' + relative)
    return contents


def glb_parts(raw):
    if len(raw) < 20 or raw[:4] != b'glTF' or struct.unpack_from('<II', raw, 4) != (2, len(raw)):
        raise ValueError('Invalid GLB header')
    at = 12
    chunks = []
    while at < len(raw):
        if at + 8 > len(raw):
            raise ValueError('Truncated GLB chunk')
        size, kind = struct.unpack_from('<I4s', raw, at)
        at += 8
        if at + size > len(raw):
            raise ValueError('Truncated GLB payload')
        chunks.append((kind, raw[at:at + size]))
        at += size
    if not chunks or chunks[0][0] != b'JSON':
        raise ValueError('Missing glTF JSON chunk')
    doc = json.loads(chunks[0][1])
    if any(c != b'BIN\x00' for c, _ in chunks[1:]) or len(chunks) > 2:
        raise ValueError('Unexpected GLB chunk structure')
    blob = chunks[1][1] if len(chunks) == 2 else b''
    return doc, blob


def inspect_art(raw, bindings, cap):
    doc, blob = glb_parts(raw)
    materials = doc.get('materials', [])
    primitives = [p for m in doc.get('meshes', []) for p in m.get('primitives', [])]
    if not primitives or len(primitives) > cap:
        raise ValueError('Missing art primitives or material-batch cap exceeded')
    names = [m.get('name') for m in materials]
    if len(names) != len(set(names)) or set(names) != set(bindings):
        raise ValueError('GLB material names differ from reviewed bindings')
    used = {p.get('material') for p in primitives}
    if used != set(range(len(materials))):
        raise ValueError('Unbound or unused material in GLB')
    accessors = doc.get('accessors', [])
    for p in primitives:
        attrs = p.get('attributes', {})
        if p.get('mode', 4) != 4 or not all(k in attrs for k in ('POSITION', 'NORMAL', 'TEXCOORD_0')):
            raise ValueError('Triangle, normal and repeat UV data required on every art primitive')
        if any(not isinstance(i, int) or i < 0 or i >= len(accessors) for i in attrs.values()):
            raise ValueError('Invalid GLB accessor')
        for kind, shape in (('POSITION', 'VEC3'), ('NORMAL', 'VEC3'), ('TEXCOORD_0', 'VEC2')):
            if accessors[attrs[kind]].get('type') != shape:
                raise ValueError('Incorrect ' + kind + ' accessor')
    for index, material in enumerate(materials):
        binding = bindings[material['name']]
        if binding['role'] == 'preserve':
            continue
        if not material.get('pbrMetallicRoughness', {}).get('baseColorTexture'):
            raise ValueError('Missing exported color texture: ' + material['name'])
        if binding['normal'] and 'normalTexture' not in material:
            raise ValueError('Missing exported normal texture: ' + material['name'])
        if binding['normal'] and any('TANGENT' not in p['attributes'] for p in primitives if p['material'] == index):
            raise ValueError('Normal mapped primitive lacks tangent: ' + material['name'])
    images = []
    for image in doc.get('images', []):
        if 'uri' in image:
            raise ValueError('External/data-URI texture: GLB must be self-contained')
        view = doc['bufferViews'][image['bufferView']]
        start = view.get('byteOffset', 0)
        end = start + view['byteLength']
        if end > len(blob) or not image.get('mimeType', '').startswith('image/'):
            raise ValueError('Invalid embedded texture buffer')
        images.append({'name': image.get('name', ''), 'sha256': digest(blob[start:end]), 'bytes': end-start})
    return {'primitives': len(primitives), 'materials': names, 'embeddedImages': images}


def verify(candidate, built=False):
    if candidate.get('schemaVersion') != 1 or not candidate.get('maps'):
        raise ValueError('Expected nonempty map-variety candidate v1')
    manifest_bytes = checked(candidate['moth']['manifest'], candidate['moth']['sha256'])
    manifest = json.loads(manifest_bytes)
    textures = manifest['textures']
    if not isinstance(textures, dict):
        raise ValueError('Moth texture registry missing')
    provenance = manifest['provenance']
    checked(provenance['source'], provenance['source_sha256'])
    reports = []
    seen = set()
    for m in candidate['maps']:
        ident = m['id']
        if not re.fullmatch(r'[a-z][a-z0-9-]*', ident) or ident in seen:
            raise ValueError('Invalid or duplicate map ID')
        seen.add(ident)
        authority = json.loads(checked(m['authority']['path'], m['authority']['sha256']))
        if authority['id'] != ident or authority['geometryHash'] != m['authority']['geometryHash']:
            raise ValueError('Map geometry identity mismatch: ' + ident)
        bindings = m['materials']
        if not bindings or len(bindings) > 64:
            raise ValueError('Missing or unbounded reviewed material registry: ' + ident)
        for name, binding in bindings.items():
            if not name or binding['role'] not in ('surface', 'team', 'preserve'):
                raise ValueError('Unreviewed material: ' + name)
            if binding['role'] == 'preserve':
                if binding.get('texture') or binding.get('normal'):
                    raise ValueError('Preserved material has a Moth texture: ' + name)
                continue
            entry = textures[binding['texture']]
            path = entry['path']
            if not path.startswith('res://moth/'):
                raise ValueError('Moth resource escapes approved namespace')
            checked('godot/' + path[6:], entry['png_sha256'])
            if binding['role'] == 'team' and not binding.get('teamColorSource'):
                raise ValueError('Team color preservation source missing: ' + name)
            if not isinstance(binding.get('tilesPerMeter'), (int, float)) or not 0 < binding['tilesPerMeter'] <= 16:
                raise ValueError('Invalid repeat UV density: ' + name)
        report = {'id': ident, 'geometryHash': authority['geometryHash'], 'registeredMaterials': len(bindings),
                  'mothManifestSha256': candidate['moth']['sha256'], 'built': False}
        if built:
            art = m['art']
            if art['maxPrimitives'] < 1 or art['maxPrimitives'] > 128:
                raise ValueError('Unbounded art primitive budget: ' + ident)
            blend = checked(art['blend'], art['blendSha256'])
            glb = checked(art['glb'], art['glbSha256'])
            report.update({'built': True, 'blendBytes': len(blend), 'glbBytes': len(glb),
                           'glb': inspect_art(glb, bindings, art['maxPrimitives'])})
        reports.append(report)
    return {'kind': 'source-only-map-variety-receipt', 'mothSource': candidate['moth']['manifest'],
            'maps': reports, 'nativeAcceptance': 'pending'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('candidate', help='Repository-relative candidate JSON')
    parser.add_argument('--built', action='store_true', help='Require hashed .blend/GLB and inspect embedded GLB material bytes')
    args = parser.parse_args()
    print(json.dumps(verify(json.loads(local(args.candidate).read_text()), args.built), indent=2))
