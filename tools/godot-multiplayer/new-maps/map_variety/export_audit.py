"""Strict GLB/pixel acceptance, standard library only (also usable in Blender)."""
import hashlib
import json
import math
import struct
import zlib


def png_pixels(raw):
    if raw[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('Expected lossless PNG')
    pos, compressed = 8, bytearray()
    while pos < len(raw):
        size = struct.unpack_from('>I', raw, pos)[0]
        kind, data = raw[pos+4:pos+8], raw[pos+8:pos+8+size]
        if kind == b'IHDR':
            w, h, depth, color, _, _, interlace = struct.unpack('>IIBBBBB', data)
        if kind == b'IDAT':
            compressed.extend(data)
        pos += size+12
    if depth != 8 or color not in (0, 2, 4, 6) or interlace:
        raise ValueError('Only noninterlaced 8-bit channel PNGs are accepted')
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[color]
    data, stride = zlib.decompress(compressed), w*channels
    previous, pixels, pos = bytearray(stride), [], 0
    for _ in range(h):
        filter_type, row = data[pos], bytearray(data[pos+1:pos+1+stride])
        pos += stride+1
        for i in range(stride):
            a, b, c = (row[i-channels] if i >= channels else 0), previous[i], (previous[i-channels] if i >= channels else 0)
            if filter_type == 0: predictor = 0
            elif filter_type == 1: predictor = a
            elif filter_type == 2: predictor = b
            elif filter_type == 3: predictor = (a+b)//2
            elif filter_type == 4:
                p = a+b-c
                predictor = min((a,b,c), key=lambda v: abs(p-v))
            else: raise ValueError('Unknown PNG filter')
            row[i] = (row[i]+predictor) & 255
        for i in range(0,stride,channels):
            v = row[i:i+channels]
            rgb = tuple(v[:3]) if color in (2,6) else (v[0],)*3
            pixels.append((*rgb,v[-1] if color in (4,6) else 255))
        previous = row
    return (w,h), pixels


def srgb_byte(value):
    linear = value/255
    return round(255*(12.92*linear if linear <= .0031308 else 1.055*linear**(1/2.4)-.055))


def verify_albedo(source, exported):
    dimensions, linear = png_pixels(source)
    out_dimensions, encoded = png_pixels(exported)
    if dimensions != out_dimensions:
        raise ValueError('Albedo dimensions changed')
    if any(p[3]!=q[3] for p,q in zip(linear,encoded)):
        raise ValueError('Albedo alpha changed')
    error = max(abs(srgb_byte(a)-b) for p,q in zip(linear,encoded) for a,b in zip(p[:3],q[:3]))
    if error > 1:
        raise ValueError(f'Export albedo is not derived sRGB (maximum byte error {error})')
    return {'sourceLinearSha256': hashlib.sha256(source).hexdigest(),
            'exportSrgbSha256': hashlib.sha256(exported).hexdigest(), 'maxByteError': error}


def validate_bindings(bindings):
    if bindings.get('schema') != 'map-variety-bindings/v1':
        raise ValueError('Unknown binding schema')
    for name, binding in bindings['materials'].items():
        role = binding.get('role')
        if role == 'preserve':
            if binding.get('resource'):
                raise ValueError('Preserved material cannot bind a Moth resource: '+name)
        elif role == 'surface':
            density = binding.get('tilesPerMeter', 0)
            if not binding.get('resource') or not math.isfinite(density) or not 0 < density <= 16:
                raise ValueError('Incomplete surface binding: '+name)
        else:
            raise ValueError('Unknown binding role: '+str(role))


def audit_glb(path, root, bindings):
    validate_bindings(bindings)
    raw = path.read_bytes()
    magic, version, size = struct.unpack_from('<III',raw)
    if magic != 0x46546c67 or version != 2 or size != len(raw):
        raise ValueError('Malformed GLB')
    pos, binary, gltf = 12, None, None
    while pos < len(raw):
        n, kind = struct.unpack_from('<II',raw,pos)
        data = raw[pos+8:pos+8+n]
        if kind == 0x4e4f534a: gltf = json.loads(data)
        elif kind == 0x004e4942: binary = data
        pos += n+8
    primitives = [p for mesh in gltf['meshes'] for p in mesh['primitives']]
    if len(primitives) > 64:
        raise ValueError(f'GLB exceeds 64 primitives: {len(primitives)}')
    triangles = 0
    for p in primitives:
        if p.get('mode',4) != 4: raise ValueError('Nontriangle export primitive')
        count = gltf['accessors'][p['indices']]['count'] if 'indices' in p else gltf['accessors'][p['attributes']['POSITION']]['count']
        if count % 3:
            raise ValueError('Incomplete triangle primitive')
        triangles += count//3
    if triangles > 160000: raise ValueError(f'GLB exceeds 160000 triangles: {triangles}')
    resources, textures = {}, {}
    for key in ('base','overlay'):
        manifest_path = root / bindings['pack'][key]
        manifest = json.loads(manifest_path.read_text())
        resources.update({m['id']:m for m in manifest['materials']})
        textures.update({k:(manifest_path.parent,v) for k,v in manifest['textures'].items()})
    evidence = {}
    def image_bytes(texture):
        image = gltf['images'][gltf['textures'][texture['index']]['source']]
        view = gltf['bufferViews'][image['bufferView']]
        start = view.get('byteOffset',0)
        return binary[start:start+view['byteLength']]
    for material in gltf.get('materials',[]):
        name = material['name']
        binding = bindings['materials'][name]
        texture = material.get('pbrMetallicRoughness',{}).get('baseColorTexture')
        if binding['role'] == 'preserve':
            if texture: raise ValueError('Preserved material acquired albedo texture: '+name)
            continue
        if not texture: raise ValueError('Surface missing base color texture: '+name)
        factor = material.get('pbrMetallicRoughness',{}).get('baseColorFactor',[1,1,1,1])
        if any(abs(v-1)>1e-6 for v in factor[:3]):
            raise ValueError('Unreviewed albedo multiplier: '+name)
        resource = resources[binding['resource']]
        directory, entry = textures[resource['channels']['albedo']]
        source = (directory/entry['path']).read_bytes()
        if hashlib.sha256(source).hexdigest() != entry['sha256']:
            raise ValueError('Immutable source PNG hash mismatch')
        evidence[name] = verify_albedo(source,image_bytes(texture))
        normal = material.get('normalTexture')
        if not normal or abs(normal.get('scale',1)-binding.get('normalStrength',1))>1e-6:
            raise ValueError('Missing/incorrect tangent normal binding: '+name)
        normal_dir, normal_entry = textures[resource['channels']['normal']]
        normal_source = (normal_dir/normal_entry['path']).read_bytes()
        normal_export = image_bytes(normal)
        if hashlib.sha256(normal_source).hexdigest()!=normal_entry['sha256'] or png_pixels(normal_source)!=png_pixels(normal_export):
            raise ValueError('OpenGL +Y normal pixels changed: '+name)
        evidence[name]['normalSourceSha256']=normal_entry['sha256']
        evidence[name]['normalExportSha256']=hashlib.sha256(normal_export).hexdigest()
        rough_texture=material.get('pbrMetallicRoughness',{}).get('metallicRoughnessTexture')
        if not rough_texture or abs(material.get('pbrMetallicRoughness',{}).get('roughnessFactor',1)-1)>1e-6:
            raise ValueError('Missing/modified roughness texture: '+name)
        rough_dir,rough_entry=textures[resource['channels']['roughness']]
        rough_source=(rough_dir/rough_entry['path']).read_bytes()
        rough_export=image_bytes(rough_texture)
        source_size,source_pixels=png_pixels(rough_source)
        export_size,export_pixels=png_pixels(rough_export)
        if hashlib.sha256(rough_source).hexdigest()!=rough_entry['sha256'] or source_size!=export_size or any(abs(a[0]-b[1])>1 for a,b in zip(source_pixels,export_pixels)):
            raise ValueError('glTF roughness G does not match immutable roughness R: '+name)
        evidence[name]['roughnessSourceSha256']=rough_entry['sha256']
        evidence[name]['metallicRoughnessExportSha256']=hashlib.sha256(rough_export).hexdigest()
        material_index=gltf['materials'].index(material)
        if any('TANGENT' not in p['attributes'] for p in primitives if p.get('material')==material_index):
            raise ValueError('Normal-mapped primitive lost tangents: '+name)
    return {'triangles':triangles,'primitives':len(primitives),'albedo':evidence}
