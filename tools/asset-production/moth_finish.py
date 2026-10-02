"""Grant-only Blender finishing shared by the queued asset builders.

Bounded reuse of actual baked Moth data; object/attachment-local UVs are fixed
at authoring time, so moving rigid/skinned parts never swim through map textures.
No geometry edits, world-coordinate shader, global palette rewrite or bake job.
"""
import hashlib
import json
import math
import re
from pathlib import Path

PRESERVE = {'glass', 'water', 'ocean', 'cyan', 'amber', 'letter'}
# Explicit source palette semantics. No substring guesses or unknown-metal fallback.
# (baked grain, contrast, normal strength, tiles/metre). Coatings/plants/soft goods
# retain their authored BRDF and geometry normals, rather than universal relief.
FAMILIES = {
    'alloy': ('brushed_metal', .08, .08, 2.4),
    'coating': ('sand', .035, 0, 2.4),
    'mineral': ('weathered_concrete', .10, .10, .65),
    'bark': ('macro-organic', .10, .06, 1.2),
    'foliage': ('grass', .08, 0, 1.2),
    'coral': ('sand', .07, 0, 1.2),
    'rubber': ('sand', .025, 0, 2.4),
    'fabric': ('sand', .045, 0, 2.4),
}
MATERIAL_ROLES = {
    'robots': {'switchyard_vertex_enamel': 'coating'},
    'vehicles': {'armor': 'coating', 'edge': 'alloy', 'rubber': 'rubber',
                 'recess': 'coating', 'seat': 'fabric', 'team_accent': 'coating',
                 'lamp': 'preserve', 'red': 'coating'},
    'scenery': {'biome4_bark': 'bark', 'biome4_moss': 'foliage',
                'biome4_sandstone': 'mineral', 'biome4_silt': 'mineral',
                'biome4_basalt': 'mineral', 'biome4_copper': 'alloy',
                'biome4_ceramic': 'coating', 'biome4_iron': 'alloy'},
    'vesper-viaduct': {**dict.fromkeys(('brick', 'plaster', 'slate', 'quay',
                                     'cobbles', 'asphalt', 'sandstone'), 'mineral'),
                       'iron': 'alloy'},
    'abyssal-pressureworks': {'navy': 'coating', 'ivory': 'coating',
                              'coral': 'coral', 'copper': 'alloy'},
    'stormglass-causeway': {**dict.fromkeys(('asphalt', 'concrete', 'salt', 'brick'), 'mineral'),
                            'teal': 'coating', 'steel': 'alloy'},
}


def family(name, unit):
    name = re.sub(r'\.\d{3,}$', '', name).lower()
    if unit not in MATERIAL_ROLES:
        raise ValueError('Material review required for unit ' + unit)
    if name in PRESERVE:
        return 'preserve'
    try:
        return MATERIAL_ROLES[unit][name]
    except KeyError:
        raise ValueError('Material review required: ' + unit + '/' + name) from None


def stable_offset(identity):
    digest = hashlib.sha256(identity.encode()).digest()
    return tuple(int.from_bytes(digest[i:i+4], 'big') / 2**32 for i in (0, 4))


def checked_source(root, record):
    path = Path(root) / 'godot' / record['path'].removeprefix('res://')
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != record['png_sha256']:
        raise ValueError('Moth source hash mismatch: ' + str(path))
    return path, digest


def derive_pixels(pixels, width, height, role):
    """Two aligned scales of actual baked pixels; no hue/noise/rotated tile mix.

    Blender supplies scene-linear samples. A neutral, near-unity modulation keeps
    authored warm/cool swatches and COLOR_0 intact. No global grime multiplier.
    Normals derive from this exact mixed height, never unrelated raw normal UVs.
    """
    contrast = FAMILIES[role][1]
    lum = [sum(pixels[i:i+3])/3 for i in range(0, len(pixels), 4)]
    mean = sum(lum)/len(lum)
    # Normalize the baked sample's contrast before applying the physical bound.
    # Otherwise a dark sRGB grain can quantize to a completely flat packed PNG.
    span = max(max(lum)-min(lum), 1e-8)
    grain = []
    for y in range(height):
        for x in range(width):
            broad = (lum[y*width+x] - mean)/span
            fine = (lum[((y*3+height//3) % height)*width+(x*3+width//5) % width] - mean)/span
            grain.append(max(-.5, min(.5, broad*.75 + fine*.25)))
    colors, normals = [], []
    for y in range(height):
        for x in range(width):
            g = grain[y*width+x]
            v = .995 + contrast*g
            colors.extend((v, v, v, 1))
            dx = (grain[y*width+(x+1) % width] - grain[y*width+(x-1) % width])*.5
            dy = (grain[((y+1) % height)*width+x] - grain[((y-1) % height)*width+x])*.5
            length = math.sqrt(dx*dx + dy*dy + 1)
            normals.extend((.5-dx/length*.5, .5-dy/length*.5, .5+.5/length, 1))
    return colors, normals


def uv_project(obj, coordinate_scale, unit):
    mesh = obj.data
    # Joined copies already carry the original part-local coordinates. Reprojecting
    # here would stamp them all from the batch origin (Vesper calls twice).
    if mesh.uv_layers.get('MothLocal'):
        return
    if mesh.users > 1:
        mesh = obj.data = mesh.copy()
    uv = mesh.uv_layers.get('MothLocal') or mesh.uv_layers.new(name='MothLocal')
    mesh.uv_layers.active = uv
    uv.active_render = True
    # Connected components identify real parts even inside a rigid attachment or
    # a material batch. Sorted local coordinates make seeds independent of vertex
    # numbering, face traversal and Python hash randomization. No pose/world input.
    parents = list(range(len(mesh.vertices)))
    def find(i):
        while parents[i] != i:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i
    for edge in mesh.edges:
        a, b = map(find, edge.vertices)
        parents[b] = a
    components = {}
    for vertex in mesh.vertices:
        components.setdefault(find(vertex.index), []).append(tuple(round(c, 6) for c in vertex.co))
    identity = unit + '/' + obj.name + '/' + obj.parent_bone
    offsets = {key: stable_offset(identity + json.dumps(sorted(points))) for key, points in components.items()}
    for polygon in mesh.polygons:
        mat = mesh.materials[polygon.material_index]
        role = family(mat.name, unit) if mat else 'preserve'
        density = FAMILIES[role][3] if role != 'preserve' else .65
        offset = offsets[find(mesh.loops[polygon.loop_start].vertex_index)]
        normal = polygon.normal
        axis = max(range(3), key=lambda i: abs(normal[i]))
        axes = ((1, 2), (0, 2), (0, 1))[axis]
        for loop in polygon.loop_indices:
            p = mesh.vertices[mesh.loops[loop].vertex_index].co
            uv.data[loop].uv = tuple(p[i] * obj.scale[i] * coordinate_scale[i] * density + offset[j] for j, i in enumerate(axes))
    obj['moth_uv_space'] = 'attachment-local; stable component phase; material density; no rotations'


def finish_scene(root, unit, coordinate_scale=(1, 1, 1)):
    import bpy
    root = Path(root)
    plan = json.loads((root / 'port/finish/ASSET_PRODUCTION.json').read_text())
    record = next(entry for entry in plan['units'] if entry['id'] == unit)
    source_hashes = {path: hashlib.sha256((root/path).read_bytes()).hexdigest()
                     for path in record['recipePaths'] + [plan['common']['finishScript']]}
    fingerprint = hashlib.sha256(json.dumps(source_hashes, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    manifest = json.loads((root / 'godot/moth/generated/manifest.json').read_text())
    master = root / manifest['provenance']['source']
    master_hash = hashlib.sha256(master.read_bytes()).hexdigest()
    if master_hash != manifest['provenance']['source_sha256']:
        raise ValueError('Moth baked master hash mismatch')
    objects = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    used = {mat.name: mat for obj in objects for mat in obj.data.materials if mat}
    if len(used) > 64:
        raise ValueError('Bounded finish refuses more than 64 source materials')
    roles = {name: family(name, unit) for name in used}  # review before any mutation
    for obj in objects:
        uv_project(obj, coordinate_scale, unit)
        obj['asset_source_fingerprint'] = fingerprint
    for mat in used.values():
        if mat.get('moth_finish_revision') == 2:
            continue
        if mat.get('moth_finish_version'):
            raise ValueError('Rebuild from source; refusing to layer finish on ' + mat.name)
        name = mat.name.split('.')[0]
        role = roles[mat.name]
        if role == 'preserve':
            mat['moth_preserved_reason'] = 'transparent/water/wayfinding/emissive response'
            continue
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get('Principled BSDF')
        if shader is None:
            raise ValueError('Unknown shader on ' + name)
        base, _, normal_strength, _ = FAMILIES[role]
        path, source_hash = checked_source(root, manifest['textures'][base])
        source = bpy.data.images.load(str(path), check_existing=True)
        source.colorspace_settings.name = 'Non-Color' if manifest['textures'][base]['color_space'] == 'linear' else 'sRGB'
        # A small, explicit modulation preserves each owner's swatch. This is
        # derived from the real Moth image, not generated noise or a flat factor.
        tint = tuple(shader.inputs['Base Color'].default_value)
        prior = shader.inputs['Base Color'].links[0].from_socket if shader.inputs['Base Color'].is_linked else None
        if prior is not None:
            tint = (1, 1, 1, 1)  # Preserve robot COLOR_0 palette through multiply.
        pixels, normals = derive_pixels(list(source.pixels[:]), *source.size, role)
        for i in range(0, len(pixels), 4):
            variation = pixels[i]
            pixels[i:i+4] = [min(1, tint[k] * variation) for k in range(3)] + [1]
        image = bpy.data.images.new('MothLocal_' + mat.name, width=source.size[0], height=source.size[1])
        image.pixels.foreach_set(pixels)
        image.pack()
        texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
        texture.image = image
        texture.extension = 'REPEAT'
        texture.label = 'Moth baked ' + base + '; restrained swatch modulation'
        uv_node = mat.node_tree.nodes.new('ShaderNodeUVMap')
        uv_node.uv_map = 'MothLocal'
        mat.node_tree.links.new(uv_node.outputs['UV'], texture.inputs['Vector'])
        if prior is None:
            mat.node_tree.links.new(texture.outputs['Color'], shader.inputs['Base Color'])
        else:
            blend = mat.node_tree.nodes.new('ShaderNodeMixRGB')
            blend.blend_type = 'MULTIPLY'
            blend.inputs[0].default_value = 1
            mat.node_tree.links.new(prior, blend.inputs[1])
            mat.node_tree.links.new(texture.outputs['Color'], blend.inputs[2])
            mat.node_tree.links.new(blend.outputs[0], shader.inputs['Base Color'])
        if normal_strength and not shader.inputs['Normal'].is_linked:
            normal_texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
            normal_image = bpy.data.images.new('MothLocalNormal_' + mat.name, width=source.size[0], height=source.size[1])
            normal_image.colorspace_settings.name = 'Non-Color'
            normal_image.pixels.foreach_set(normals)
            normal_image.pack()
            normal_texture.image = normal_image
            mat.node_tree.links.new(uv_node.outputs['UV'], normal_texture.inputs['Vector'])
            normal_map = mat.node_tree.nodes.new('ShaderNodeNormalMap')
            normal_map.uv_map = 'MothLocal'
            normal_map.inputs['Strength'].default_value = normal_strength
            mat.node_tree.links.new(normal_texture.outputs['Color'], normal_map.inputs['Color'])
            mat.node_tree.links.new(normal_map.outputs['Normal'], shader.inputs['Normal'])
        mat['moth_finish_version'] = 1
        mat['moth_finish_revision'] = 2
        mat['moth_family'] = role
        mat['moth_resource_sha256'] = json.dumps({str(path.relative_to(root)): source_hash}, sort_keys=True)
        mat['moth_baked_master_sha256'] = master_hash
    bpy.context.scene['asset_production_unit'] = unit
    bpy.context.scene['moth_finish_version'] = 1
    bpy.context.scene['asset_source_fingerprint'] = fingerprint
    bpy.context.scene['moth_finish_review'] = 'PENDING native texture/UV/material/readability acceptance'
