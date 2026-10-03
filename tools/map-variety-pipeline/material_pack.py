"""Reviewed map-variety Moth pack -> Blender PBR, without legacy registry aliases.

Call load_materials(root, bindings, output_dir) inside Blender. Each binding is
{resource, role, metallic}; role is surface/team/preserve. No fallback names.
Albedo source PNG is linear RGBA8 and MUST be sRGB encoded for glTF baseColor.
"""
import hashlib
import json
from pathlib import Path
import struct
import zlib


PACK = 'assets/moth/map-variety-20261003/candidate-v3/manifest.json'


def sha(data): return hashlib.sha256(data).hexdigest()


def _chunks(raw):
    if raw[:8] != b'\x89PNG\r\n\x1a\n': raise ValueError('Not PNG')
    at = 8
    while at < len(raw):
        size = struct.unpack_from('>I', raw, at)[0]
        name = raw[at+4:at+8]
        body = raw[at+8:at+8+size]
        if len(body) != size or struct.unpack_from('>I', raw, at+8+size)[0] != zlib.crc32(name+body):
            raise ValueError('Invalid PNG chunk')
        at += size+12
        yield name, body
        if name == b'IEND': break


def linear_rgba(linear):
    """Decode bounded RGBA8 PNG with all standard lossless PNG scanline filters."""
    chunks = list(_chunks(linear))
    width,height,depth,color,*_ = struct.unpack('>IIBBBBB', next(v for k,v in chunks if k==b'IHDR'))
    if depth != 8 or color not in (2,6) or width*height > 1024*1024:
        raise ValueError('Expected bounded RGB/RGBA8 linear PNG')
    packed = zlib.decompress(b''.join(v for k,v in chunks if k==b'IDAT'))
    bpp=4 if color==6 else 3
    stride = width*bpp
    raw = bytearray()
    previous = bytearray(stride)
    at = 0
    for _ in range(height):
        mode = packed[at]
        row = bytearray(packed[at+1:at+1+stride])
        if len(row) != stride: raise ValueError('Truncated PNG scanline')
        at += stride+1
        for i in range(stride):
            a = row[i-bpp] if i>=bpp else 0
            b = previous[i]
            c = previous[i-bpp] if i>=bpp else 0
            if mode == 1: delta = a
            elif mode == 2: delta = b
            elif mode == 3: delta = (a+b)//2
            elif mode == 4:
                p=a+b-c
                da,db,dc=abs(p-a),abs(p-b),abs(p-c)
                delta = a if da<=db and da<=dc else b if db<=dc else c
            elif mode == 0: delta = 0
            else: raise ValueError('Invalid PNG filter')
            row[i] = (row[i]+delta)&255
        previous = row[:]
        if bpp==4:raw.extend(row)
        else:
            for i in range(0,stride,3):raw.extend(row[i:i+3]+b'\xff')
    if at != len(packed): raise ValueError('Unexpected PNG payload')
    return width,height,raw


def srgb_png(linear):
    """RGBA8 linear PNG -> RGBA8 sRGB PNG; alpha unmodified, no PIL dependency."""
    width,height,pixels = linear_rgba(linear)
    raw = bytearray()
    stride=width*4
    for y in range(height):
        row=pixels[y*stride:(y+1)*stride]
        for i in range(0,stride,4):
            for channel in range(3):
                value = row[i+channel]/255
                transformed = 12.92*value if value<=.0031308 else 1.055*value**(1/2.4)-.055
                row[i+channel] = max(0,min(255,round(transformed*255)))
        raw.extend(b'\0'+row)
    def chunk(kind, body): return struct.pack('>I',len(body))+kind+body+struct.pack('>I',zlib.crc32(kind+body))
    header = struct.pack('>IIBBBBB',width,height,8,6,0,0,0)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',header)+chunk(b'IDAT',zlib.compress(bytes(raw),9))+chunk(b'IEND',b'')


def load_pack(root, manifest=PACK):
    root = Path(root).resolve()
    overlay_path = (root/manifest).resolve()
    if not overlay_path.is_relative_to(root): raise ValueError('Manifest outside root')
    overlay_bytes = overlay_path.read_bytes()
    overlay = json.loads(overlay_bytes)
    if overlay.get('schema') != 'moth-map-material-overlay/v1': raise ValueError('Wrong Moth overlay schema')
    base_path = (overlay_path.parent/overlay['basePack']['manifest']).resolve()
    if not base_path.is_relative_to(root): raise ValueError('Base manifest outside root')
    base_bytes = base_path.read_bytes()
    if sha(base_bytes) != overlay['basePack']['sha256']: raise ValueError('Moth base manifest hash mismatch')
    base = json.loads(base_bytes)
    if base.get('schema') != 'moth-map-material-pack/v1': raise ValueError('Wrong Moth base schema')
    materials = {}
    for doc,path in ((base,base_path),(overlay,overlay_path)):
        for item in doc['materials']:
            ident = item['id']
            if ident in materials: raise ValueError('Duplicate Moth ID: '+ident)
            channels = {}
            for role,key in item['channels'].items():
                meta = doc['textures'][key]
                source = (path.parent/meta['path']).resolve()
                if not source.is_relative_to(root): raise ValueError('Moth texture escapes root')
                data = source.read_bytes()
                semantic = 'coverage mask in RGB; use red channel for alpha clip' if role == 'alpha' else role
                if sha(data) != meta['sha256'] or len(data) != meta['bytes'] or meta['semantic'] != semantic or meta['colorSpace'] != 'linear':
                    raise ValueError('Moth texture identity/semantics mismatch: '+key)
                channels[role] = {'path': source, 'sha256': meta['sha256'], 'bytes': len(data)}
            if not all(k in channels for k in ('albedo','normal','roughness')):
                raise ValueError('Incomplete PBR Moth resource: '+ident)
            materials[ident] = {'channels': channels, 'tileMeters':item['tileMeters'],
                                'texelsPerMeter':item['texelsPerMeter'], 'manifestSha256':sha(path.read_bytes())}
    return materials, {'overlaySha256':sha(overlay_bytes),'baseSha256':sha(base_bytes)}


def load_materials(root, bindings, output_dir, *, manifest=PACK):
    import bpy
    resources, pack = load_pack(root, manifest)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    materials, densities, report = {}, {}, {}
    for name,binding in bindings.items():
        if binding['role'] == 'preserve':
            raise ValueError('Preserved glass/emissive materials must be explicitly authored outside pack: '+name)
        resource = resources[binding['resource']]
        if binding['role'] not in ('surface','team') or binding['role']=='team' and binding.get('teamColorSource')!='COLOR_0':
            raise ValueError('Unreviewed Moth role '+name)
        metallic = binding['metallic']
        if not isinstance(metallic,(int,float)) or isinstance(metallic,bool) or not 0<=metallic<=1:
            raise ValueError('Invalid metallic scalar '+name)
        converted = srgb_png(resource['channels']['albedo']['path'].read_bytes())
        color_path = output_dir/(binding['resource']+'-albedo-srgb.png')
        if color_path.exists() and color_path.read_bytes()!=converted:
            raise ValueError('Different converted albedo at '+str(color_path))
        color_path.write_bytes(converted)
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links
        bs = nodes.get('Principled BSDF')
        bs.inputs['Metallic'].default_value = metallic
        uv = nodes.new('ShaderNodeUVMap'); uv.uv_map = 'MothLocal'
        def image(path, space, label):
            node=nodes.new('ShaderNodeTexImage')
            node.image=bpy.data.images.load(str(path),check_existing=True)
            node.image.colorspace_settings.name=space
            node.extension='REPEAT'
            node.label=label
            links.new(uv.outputs['UV'],node.inputs['Vector'])
            return node
        albedo=image(color_path,'sRGB','Moth linear albedo -> sRGB encoded glTF bytes')
        links.new(albedo.outputs['Color'],bs.inputs['Base Color'])
        if binding.get('normal',True):
            normal=image(resource['channels']['normal']['path'],'Non-Color','Moth OpenGL +Y normal')
            normal_map=nodes.new('ShaderNodeNormalMap');normal_map.uv_map='MothLocal'
            links.new(normal.outputs['Color'],normal_map.inputs['Color'])
            links.new(normal_map.outputs['Normal'],bs.inputs['Normal'])
        rough=image(resource['channels']['roughness']['path'],'Non-Color','Moth scalar roughness')
        separate=nodes.new('ShaderNodeSeparateColor');links.new(rough.outputs['Color'],separate.inputs['Color'])
        links.new(separate.outputs['Red'],bs.inputs['Roughness'])
        materials[name]=mat
        densities[name]=1/resource['tileMeters']
        report[name]={'resource':binding['resource'],'role':binding['role'],'tileMeters':resource['tileMeters'],
                      'tilesPerMeter':densities[name],'texelsPerMeter':resource['texelsPerMeter'],
                      'sourceColorSha256':resource['channels']['albedo']['sha256'],
                      'sourceNormalSha256':resource['channels']['normal']['sha256'],
                      'normalAttached':bool(binding.get('normal',True)),
                      'sourceRoughnessSha256':resource['channels']['roughness']['sha256'],
                      'convertedAlbedoSha256':sha(converted),'metallic':metallic,
                      'teamColorSource':binding.get('teamColorSource'),
                      'manifestSha256':resource['manifestSha256']}
    return materials,densities,{'pack':pack,'materials':report}
