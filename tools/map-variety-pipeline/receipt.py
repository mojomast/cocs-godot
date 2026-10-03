"""Source-only admission of a proposed Moth/Blender map-art revision.

No Blender, Godot, package import, network access, or build is invoked. The
candidate JSON is deliberately separate from the frozen map/catalog and Moth
finish. See README.md for the handoff format. Exit nonzero on missing evidence.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import sys


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


def blend_header(raw):
    """Recognize Blender plain or Blender-Zstd saved masters (reopen proves full data)."""
    offset=0 if raw.startswith(b'BLENDER') else raw[:32].find(b'BLENDER') if raw[:4]==b'\x28\xb5\x2f\xfd' else -1
    return offset>=0 and len(raw)>64 and raw[offset+9:offset+12].isdigit()


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
    views = doc.get('bufferViews', [])
    buffers = doc.get('buffers', [])
    if len(buffers) != 1 or buffers[0].get('uri') or not isinstance(buffers[0].get('byteLength'), int) or buffers[0]['byteLength'] > len(blob):
        raise ValueError('GLB must contain one bounded embedded buffer')
    def integer(value):
        return type(value) is int and value >= 0

    def view_at(index):
        if not integer(index) or index >= len(views):
            raise ValueError('Invalid buffer view index')
        view = views[index]
        start, size = view.get('byteOffset', 0), view.get('byteLength')
        if view.get('buffer') != 0 or not integer(start) or not integer(size) or start + size > buffers[0]['byteLength']:
            raise ValueError('Out-of-range buffer view')
        return view, start, size

    def accessor(index, kind):
        if not integer(index) or index >= len(accessors):
            raise ValueError('Invalid accessor index')
        a = accessors[index]
        shapes = {'POSITION': 'VEC3', 'NORMAL': 'VEC3', 'TEXCOORD_0': 'VEC2',
                  'TANGENT': 'VEC4', 'COLOR_0': ('VEC3', 'VEC4')}
        components = {'POSITION': (5126,), 'NORMAL': (5126,), 'TEXCOORD_0': (5126,),
                      'TANGENT': (5126,), 'COLOR_0': (5121, 5123, 5126)}
        shape, component = a.get('type'), a.get('componentType')
        allowed = shapes[kind]
        if shape not in (allowed if isinstance(allowed, tuple) else (allowed,)) or component not in components[kind]:
            raise ValueError('Incorrect ' + kind + ' accessor format')
        count, offset = a.get('count'), a.get('byteOffset', 0)
        if not integer(count) or count == 0 or not integer(offset) or a.get('sparse'):
            raise ValueError('Missing or unsupported accessor data')
        view, _, size = view_at(a.get('bufferView'))
        width = {'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[shape] * {5121: 1, 5123: 2, 5126: 4}[component]
        stride = view.get('byteStride', width)
        if not integer(stride) or stride < width or offset + (count - 1) * stride + width > size:
            raise ValueError('Out-of-range ' + kind + ' accessor bytes')
        return count

    for view_index in range(len(views)):
        view_at(view_index)
    for p in primitives:
        attrs = p.get('attributes', {})
        if p.get('mode', 4) != 4 or not all(k in attrs for k in ('POSITION', 'NORMAL', 'TEXCOORD_0')):
            raise ValueError('Triangle, normal and repeat UV data required on every art primitive')
        count = accessor(attrs['POSITION'], 'POSITION')
        for kind in ('NORMAL', 'TEXCOORD_0', 'TANGENT', 'COLOR_0'):
            if kind in attrs and accessor(attrs[kind], kind) != count:
                raise ValueError('Mismatched ' + kind + ' vertex count')
        if any(kind.startswith('_') for kind in attrs):
            raise ValueError('Unreviewed private vertex attribute')
    images = []
    for image in doc.get('images', []):
        if 'uri' in image:
            raise ValueError('External/data-URI texture: GLB must be self-contained')
        _, start, size = view_at(image.get('bufferView'))
        if size == 0 or image.get('mimeType') not in ('image/png', 'image/jpeg', 'image/webp'):
            raise ValueError('Invalid embedded texture buffer')
        images.append({'name': image.get('name', ''), 'sha256': digest(blob[start:start+size]), 'bytes': size})
    def image_for(slot):
        if not isinstance(slot, dict) or slot.get('texCoord', 0) != 0:
            raise ValueError('Invalid or non-UV0 material texture slot')
        index = slot.get('index')
        textures = doc.get('textures', [])
        if not integer(index) or index >= len(textures):
            raise ValueError('Invalid material texture index')
        source = textures[index].get('source')
        if not integer(source) or source >= len(images):
            raise ValueError('Invalid material image index')
        sampler = textures[index].get('sampler')
        if sampler is not None:
            samplers = doc.get('samplers', [])
            if not integer(sampler) or sampler >= len(samplers):
                raise ValueError('Invalid material sampler')
            if samplers[sampler].get('wrapS', 10497) != 10497 or samplers[sampler].get('wrapT', 10497) != 10497:
                raise ValueError('Moth UVs require repeat wrap')
        return images[source]['sha256']
    resolved = {}
    for index, material in enumerate(materials):
        binding = bindings[material['name']]
        base_slot = material.get('pbrMetallicRoughness', {}).get('baseColorTexture')
        normal_slot = material.get('normalTexture')
        if binding['role'] == 'preserve':
            if base_slot is not None:
                image_for(base_slot)
            if normal_slot is not None:
                image_for(normal_slot)
            continue
        color = image_for(base_slot)
        if not binding['normal'] and normal_slot is not None:
            raise ValueError('Unexpected unreviewed normal slot: ' + material['name'])
        normal = image_for(normal_slot) if binding['normal'] else None
        if binding['normal'] and any('TANGENT' not in p['attributes'] for p in primitives if p['material'] == index):
            raise ValueError('Normal mapped primitive lacks tangent: ' + material['name'])
        if binding['role'] == 'team' and any('COLOR_0' not in p['attributes'] for p in primitives if p['material'] == index):
            raise ValueError('Team material primitive lacks COLOR_0: ' + material['name'])
        resolved[material['name']] = {'color': color, 'normal': normal}
    return {'primitives': len(primitives), 'materials': names, 'embeddedImages': images, 'materialImages': resolved}


def verify(candidate, built=False):
    if candidate.get('schemaVersion') == 2:
        return verify_pack(candidate, built)
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
            normal_key = binding.get('normal')
            if normal_key is not False and (not isinstance(normal_key, str) or not normal_key):
                raise ValueError('Normal requires a reviewed Moth normal key or false: ' + name)
            if normal_key:
                normal_entry = manifest['normals'][normal_key]
                if not normal_entry['path'].startswith('res://moth/'):
                    raise ValueError('Normal resource escapes approved namespace')
                checked('godot/' + normal_entry['path'][6:], normal_entry['png_sha256'])
            if binding['role'] == 'team' and binding.get('teamColorSource') != 'COLOR_0':
                raise ValueError('Team color preservation must use exported COLOR_0: ' + name)
            if not isinstance(binding.get('tilesPerMeter'), (int, float)) or isinstance(binding['tilesPerMeter'], bool) or not math.isfinite(binding['tilesPerMeter']) or not 0 < binding['tilesPerMeter'] <= 16:
                raise ValueError('Invalid repeat UV density: ' + name)
        report = {'id': ident, 'geometryHash': authority['geometryHash'], 'registeredMaterials': len(bindings),
                  'mothManifestSha256': candidate['moth']['sha256'], 'built': False}
        if built:
            art = m['art']
            if art['maxPrimitives'] < 1 or art['maxPrimitives'] > 128:
                raise ValueError('Unbounded art primitive budget: ' + ident)
            blend = checked(art['blend'], art['blendSha256'])
            if not blend_header(blend):
                raise ValueError('Not a Blender master file: ' + art['blend'])
            glb = checked(art['glb'], art['glbSha256'])
            inspection = inspect_art(glb, bindings, art['maxPrimitives'])
            build_report = json.loads(checked(art['report'], art['reportSha256']))
            if build_report.get('id') != ident or build_report.get('geometryHash') != authority['geometryHash'] or build_report.get('mothManifestSha256') != candidate['moth']['sha256'] or build_report.get('glbSha256') != art['glbSha256'] or set(build_report.get('materials', {})) != set(bindings):
                raise ValueError('Blender build report identity/bindings mismatch: ' + ident)
            for name, binding in bindings.items():
                evidence = build_report['materials'][name]
                if binding['role'] == 'preserve':
                    continue
                expected = textures[binding['texture']]['png_sha256']
                normal_expected = manifest['normals'][binding['normal']]['png_sha256'] if binding['normal'] else None
                exported = inspection['materialImages'][name]
                if (evidence.get('sourceColorSha256') != expected or evidence.get('sourceNormalSha256') != normal_expected
                    or evidence.get('embeddedColorSha256') != exported['color'] or evidence.get('embeddedNormalSha256') != exported['normal']
                    or evidence.get('tilesPerMeter') != binding['tilesPerMeter'] or evidence.get('teamColorSource') != binding.get('teamColorSource')):
                    raise ValueError('Moth source/export mapping mismatch: ' + name)
            report.update({'built': True, 'blendBytes': len(blend), 'glbBytes': len(glb),
                           'glb': inspection, 'buildReportSha256': art['reportSha256'],
                           'inspectionScope': 'structural bytes plus builder-reported lineage; native pixels/UV density unproven'})
        reports.append(report)
    return {'kind': 'source-only-map-variety-receipt', 'mothSource': candidate['moth']['manifest'],
            'maps': reports, 'nativeAcceptance': 'pending'}


def verify_pack(candidate, built=False):
    """Actual v2 linear material pack plus additive v3 overlay, never legacy aliases."""
    sys.path.insert(0,str(Path(__file__).parent))
    from material_pack import load_pack,linear_rgba,srgb_png
    overlay = candidate['moth']['manifest']
    checked(overlay,candidate['moth']['sha256'])
    registry,pack_hashes=load_pack(ROOT,overlay)
    if pack_hashes['overlaySha256']!=candidate['moth']['sha256']:
        raise ValueError('Overlay manifest identity mismatch')
    if not candidate.get('maps'):raise ValueError('No maps in actual pack candidate')
    reports=[]
    for map_data in candidate['maps']:
        authority=map_data['authority']
        data=json.loads(checked(authority['path'],authority['sha256']))
        if data['id']!=map_data['id'] or data['geometryHash']!=authority['geometryHash']:
            raise ValueError('Revised authority mismatch')
        bindings=map_data['materials']
        if not bindings or len(bindings)>64:raise ValueError('Unbounded reviewed material registry')
        for name,binding in bindings.items():
            if binding['role']=='preserve':
                if binding.get('resource') or binding.get('normal'):
                    raise ValueError('Preserved material includes Moth input: '+name)
                continue
            if binding['role'] not in ('surface','team') or not isinstance(binding.get('normal'),bool):
                raise ValueError('Unreviewed Moth binding '+name)
            if binding['role']=='team' and binding.get('teamColorSource')!='COLOR_0':
                raise ValueError('Team binding needs COLOR_0')
            resource=registry[binding['resource']]
            if binding.get('tileMeters')!=resource['tileMeters']:
                raise ValueError('Moth density mismatch: '+name)
        entry={'id':map_data['id'],'geometryHash':data['geometryHash'],
               'mothOverlaySha256':pack_hashes['overlaySha256'],
               'reviewedMaterials':len(bindings),'built':False}
        if built:
            art=map_data['art']
            master=checked(art['blend'],art['blendSha256'])
            glb=checked(art['glb'],art['glbSha256'])
            if not blend_header(master):
                raise ValueError('Missing actual Blender master')
            if art['maxPrimitives']<1 or art['maxPrimitives']>128:
                raise ValueError('Invalid primitive cap')
            inspection=inspect_art(glb,{name:{'role':b['role'],'normal':b.get('normal',False)}
                                        for name,b in bindings.items()},art['maxPrimitives'])
            doc,blob=glb_parts(glb)
            lineage=json.loads(checked(art['lineage'],art['lineageSha256']))
            if lineage.get('glbSha256')!=art['glbSha256'] or lineage.get('geometryHash')!=data['geometryHash'] or lineage.get('pack')!=pack_hashes:
                raise ValueError('Source/packed lineage identity mismatch')
            if set(lineage['materialLineage'])!={name for name,b in bindings.items() if b['role']!='preserve'}:
                raise ValueError('Source/packed lineage coverage mismatch')
            def image_bytes(slot):
                textures=doc['textures']
                if not isinstance(slot,dict) or type(slot.get('index')) is not int or not 0<=slot['index']<len(textures):
                    raise ValueError('Invalid PBR texture index')
                index=textures[slot['index']]['source']
                view=doc['bufferViews'][doc['images'][index]['bufferView']]
                at=view.get('byteOffset',0)
                return blob[at:at+view['byteLength']]
            for mat in doc['materials']:
                name=mat['name']
                binding=bindings[name]
                if binding['role']=='preserve':continue
                resource=registry[binding['resource']]['channels']
                color=image_bytes(mat['pbrMetallicRoughness']['baseColorTexture'])
                expected=srgb_png(resource['albedo']['path'].read_bytes())
                normal=image_bytes(mat['normalTexture']) if binding['normal'] else None
                if color!=expected or binding['normal'] and digest(normal)!=resource['normal']['sha256']:
                    raise ValueError('Actual Moth color/normal GLB bytes mismatch: '+name)
                packed=image_bytes(mat['pbrMetallicRoughness']['metallicRoughnessTexture'])
                w,h,source=linear_rgba(resource['roughness']['path'].read_bytes())
                ew,eh,output=linear_rgba(packed)
                if (w,h)!=(ew,eh) or any(abs(source[i]-output[i+1])>1 for i in range(0,len(source),4)):
                    raise ValueError('Moth packed roughness differs: '+name)
                evidence=lineage['materialLineage'][name]
                if (evidence['sourceAlbedoSha256']!=resource['albedo']['sha256'] or
                    evidence['embeddedSrgbAlbedoSha256']!=digest(color) or
                    evidence['normalSourceAndEmbeddedSha256']!=(digest(normal) if binding['normal'] else None) or
                    evidence['sourceRoughnessSha256']!=resource['roughness']['sha256'] or
                    evidence['embeddedPackedRoughnessSha256']!=digest(packed)):
                    raise ValueError('Builder report differs from independently resolved GLB bytes: '+name)
            entry.update({'built':True,'blendBytes':len(master),'glbBytes':len(glb),
                          'primitives':inspection['primitives'],'lineageSha256':art['lineageSha256'],
                          'inspectionScope':'actual decoded source-to-GLB channels; native gameplay review separate'})
        reports.append(entry)
    return {'kind':'actual-Moth-pack-source-and-export-receipt','pack':pack_hashes,'maps':reports,
            'nativeAcceptance':'pending hosted journeys and visual signoff'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('candidate', help='Repository-relative candidate JSON')
    parser.add_argument('--built', action='store_true', help='Require hashed .blend/GLB and inspect embedded GLB material bytes')
    args = parser.parse_args()
    print(json.dumps(verify(json.loads(local(args.candidate).read_text()), args.built), indent=2))
