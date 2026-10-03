"""Strict GLB/pixel acceptance, standard library only (also usable in Blender)."""
import hashlib
import json
import math
import struct
import zlib
from triangle_policy import triangle_advisory
from glb_geometry import EmbeddedGlb, finite_vector, integer


def png_pixels(raw):
    if raw[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('Expected lossless PNG')
    pos, compressed, header, ended = 8, bytearray(), None, False
    while pos < len(raw):
        if pos+12>len(raw):raise ValueError('Truncated PNG chunk')
        size = struct.unpack_from('>I', raw, pos)[0]
        if pos+size+12>len(raw):raise ValueError('PNG chunk exceeds image bytes')
        kind, data = raw[pos+4:pos+8], raw[pos+8:pos+8+size]
        if struct.unpack_from('>I',raw,pos+8+size)[0]!=zlib.crc32(kind+data):raise ValueError('PNG CRC mismatch')
        if kind == b'IHDR':
            if header is not None or pos!=8 or size!=13:raise ValueError('Invalid PNG header')
            header=struct.unpack('>IIBBBBB',data)
        if kind == b'IDAT':
            compressed.extend(data)
        pos += size+12
        if kind==b'IEND':
            if size or pos!=len(raw):raise ValueError('Invalid PNG end')
            ended=True;break
    if header is None or not ended:raise ValueError('Incomplete PNG')
    w,h,depth,color,compression,filter_method,interlace=header
    if depth != 8 or color not in (0, 2, 4, 6) or interlace or compression or filter_method:
        raise ValueError('Only noninterlaced 8-bit channel PNGs are accepted')
    if not w or not h or w*h>1024*1024:raise ValueError('PNG exceeds reviewed pack dimensions')
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[color]
    stride=w*channels;expected=(stride+1)*h
    decoder=zlib.decompressobj()
    try:data=decoder.decompress(compressed,expected+1)
    except zlib.error as error:raise ValueError('Invalid PNG compressed data') from error
    if len(data)!=expected or not decoder.eof or decoder.unused_data:raise ValueError('PNG decoded byte count mismatch')
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


def audit_glb(path, root, bindings, *, expected_materials=None, expected_triangles=None):
    validate_bindings(bindings)
    raw = path.read_bytes()
    container=EmbeddedGlb(raw)
    gltf=container.doc
    primitives,triangles,used_materials=container.geometry()
    advisory = triangle_advisory(triangles, 'exported-glb')
    if expected_triangles is not None:
        triangle_advisory(expected_triangles,'evaluated-scene')
        if triangles!=expected_triangles:raise ValueError('Export triangle count differs from evaluated build selection')
    used_names=[]
    for index in sorted(used_materials):
        name=gltf['materials'][index].get('name')
        if not isinstance(name,str) or name not in bindings['materials']:raise ValueError('Unbound used material: '+str(name))
        if name in used_names:raise ValueError('Ambiguous duplicate used material name: '+name)
        used_names.append(name)
    if expected_materials is not None and set(used_names)!=set(expected_materials):
        raise ValueError('Exported used materials differ from evaluated build selection')
    resources, textures = {}, {}
    for key in ('base','overlay'):
        manifest_path = root / bindings['pack'][key]
        manifest = json.loads(manifest_path.read_text())
        resources.update({m['id']:m for m in manifest['materials']})
        textures.update({k:(manifest_path.parent,v) for k,v in manifest['textures'].items()})
    evidence,material_evidence = {},{}
    def image_bytes(texture):
        if not isinstance(texture,dict):raise ValueError('Missing texture binding')
        uv='TEXCOORD_'+str(integer(texture.get('texCoord',0),'texture coordinate index'))
        if any(uv not in p['attributes'] for p in primitives if p['material']==material_index):
            raise ValueError('Textured primitive lost selected UV coordinates: '+name)
        return container.image_bytes(texture)
    for material_index in sorted(used_materials):
        material=gltf['materials'][material_index]
        name = material['name']
        binding = bindings['materials'][name]
        texture = material.get('pbrMetallicRoughness',{}).get('baseColorTexture')
        if binding['role'] == 'preserve':
            if texture or any(material.get(k) for k in ('normalTexture','emissiveTexture','occlusionTexture')) or material.get('pbrMetallicRoughness',{}).get('metallicRoughnessTexture'):
                raise ValueError('Preserved material acquired an unreviewed texture: '+name)
            material_evidence[name]={'role':'preserve','geometryReferenced':True}
            continue
        if not texture: raise ValueError('Surface missing base color texture: '+name)
        if any('TANGENT' not in p['attributes'] for p in primitives if p['material']==material_index):
            raise ValueError('Textured primitive lost tangents: '+name)
        factor = finite_vector(material.get('pbrMetallicRoughness',{}).get('baseColorFactor',[1,1,1,1]),4,'baseColorFactor')
        if any(abs(v-1)>1e-6 for v in factor[:3]):
            raise ValueError('Unreviewed albedo multiplier: '+name)
        resource = resources[binding['resource']]
        directory, entry = textures[resource['channels']['albedo']]
        source = (directory/entry['path']).read_bytes()
        if hashlib.sha256(source).hexdigest() != entry['sha256']:
            raise ValueError('Immutable source PNG hash mismatch')
        evidence[name] = verify_albedo(source,image_bytes(texture))
        normal = material.get('normalTexture')
        scale=normal.get('scale',1) if normal else None
        if type(scale) not in (int,float) or not math.isfinite(scale) or abs(scale-binding.get('normalStrength',1))>1e-6:
            raise ValueError('Missing/incorrect tangent normal binding: '+name)
        normal_dir, normal_entry = textures[resource['channels']['normal']]
        normal_source = (normal_dir/normal_entry['path']).read_bytes()
        normal_export = image_bytes(normal)
        if hashlib.sha256(normal_source).hexdigest()!=normal_entry['sha256'] or png_pixels(normal_source)!=png_pixels(normal_export):
            raise ValueError('OpenGL +Y normal pixels changed: '+name)
        evidence[name]['normalSourceSha256']=normal_entry['sha256']
        evidence[name]['normalExportSha256']=hashlib.sha256(normal_export).hexdigest()
        rough_texture=material.get('pbrMetallicRoughness',{}).get('metallicRoughnessTexture')
        rough_factor=material.get('pbrMetallicRoughness',{}).get('roughnessFactor',1)
        if not rough_texture or type(rough_factor) not in (int,float) or not math.isfinite(rough_factor) or abs(rough_factor-1)>1e-6:
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
        material_evidence[name]={'role':'surface','geometryReferenced':True,'pixelsVerified':True}
    return {'triangles':triangles,'triangleAdvisory':advisory,'primitives':len(primitives),
            'usedMaterials':sorted(used_names),'materialEvidence':material_evidence,'albedo':evidence,
            'evaluatedTriangleDelta':None if expected_triangles is None else triangles-expected_triangles,
            'geometryValidation':'scene-referenced embedded accessor bytes verified; non-instanced static export'}
