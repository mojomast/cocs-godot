"""Grant-only Blender finishing shared by the queued asset builders.

Bounded reuse of actual baked Moth data; object/attachment-local UVs are fixed
at authoring time, so moving rigid/skinned parts never swim through map textures.
No geometry edits, world-coordinate shader, global palette rewrite or bake job.
"""
import hashlib
import json
from pathlib import Path
import bpy

PRESERVE = {'glass', 'water', 'ocean', 'cyan', 'amber', 'letter'}
FAMILIES = {
    'alloy': ('brushed_metal', 'metal'),
    'ceramic': ('hex_paneling', 'hex_paneling'),
    'mineral': ('weathered_concrete', 'weathered_concrete'),
    'organic': ('rough_stucco', 'rough_stucco'),
}


def family(name):
    name = name.lower()
    if any(k in name for k in ('bark', 'moss', 'wood', 'coral')):
        return 'organic'
    if any(k in name for k in ('ceramic', 'ivory', 'enamel', 'shell')):
        return 'ceramic'
    if any(k in name for k in ('stone', 'brick', 'quay', 'cobble', 'asphalt', 'concrete', 'salt', 'basalt', 'slate', 'silt', 'plaster', 'navy')):
        return 'mineral'
    return 'alloy'


def uv_project(obj, coordinate_scale):
    mesh = obj.data
    uv = mesh.uv_layers.get('MothLocal') or mesh.uv_layers.new(name='MothLocal')
    mesh.uv_layers.active = uv
    uv.active_render = True
    for polygon in mesh.polygons:
        normal = polygon.normal
        axis = max(range(3), key=lambda i: abs(normal[i]))
        axes = ((1, 2), (0, 2), (0, 1))[axis]
        for loop in polygon.loop_indices:
            p = mesh.vertices[mesh.loops[loop].vertex_index].co
            uv.data[loop].uv = tuple(p[i] * obj.scale[i] * coordinate_scale[i] * .65 for i in axes)
    obj['moth_uv_space'] = 'attachment-local; authored UV; 0.65 tiles/metre'


def finish_scene(root, unit, coordinate_scale=(1, 1, 1)):
    root = Path(root)
    manifest = json.loads((root / 'godot/moth/generated/manifest.json').read_text())
    objects = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    used = {mat.name: mat for obj in objects for mat in obj.data.materials if mat}
    if len(used) > 64:
        raise ValueError('Bounded finish refuses more than 64 source materials')
    for obj in objects:
        uv_project(obj, coordinate_scale)
    for mat in used.values():
        if mat.get('moth_finish_version') == 1:
            continue
        name = mat.name.split('.')[0]
        if name in PRESERVE:
            mat['moth_preserved_reason'] = 'transparent/water/wayfinding/emissive response'
            continue
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get('Principled BSDF')
        if shader is None:
            raise ValueError('Unknown shader on ' + name)
        base, normal = FAMILIES[family(name)]
        paths = [root / 'godot' / manifest[bucket][key]['path'].removeprefix('res://')
                 for bucket, key in [('textures', base), ('normals', normal)]]
        for path in paths:
            if not path.is_file():
                raise FileNotFoundError(path)
        source = bpy.data.images.load(str(paths[0]), check_existing=True)
        # A small, explicit modulation preserves each owner's swatch. This is
        # derived from the real Moth image, not generated noise or a flat factor.
        tint = tuple(shader.inputs['Base Color'].default_value)
        prior = shader.inputs['Base Color'].links[0].from_socket if shader.inputs['Base Color'].is_linked else None
        if prior is not None:
            tint = (1, 1, 1, 1)  # Preserve robot COLOR_0 palette through multiply.
        pixels = list(source.pixels[:])
        for i in range(0, len(pixels), 4):
            luminance = sum(pixels[i:i+3]) / 3
            variation = .88 + .24 * luminance
            pixels[i:i+4] = [min(1, tint[k] * variation) for k in range(3)] + [1]
        image = bpy.data.images.new('MothLocal_' + mat.name, width=source.size[0], height=source.size[1])
        image.pixels.foreach_set(pixels)
        image.pack()
        texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
        texture.image = image
        texture.extension = 'REPEAT'
        texture.label = 'Moth baked ' + base + '; restrained swatch modulation'
        if prior is None:
            mat.node_tree.links.new(texture.outputs['Color'], shader.inputs['Base Color'])
        else:
            blend = mat.node_tree.nodes.new('ShaderNodeMixRGB')
            blend.blend_type = 'MULTIPLY'
            blend.inputs[0].default_value = 1
            mat.node_tree.links.new(prior, blend.inputs[1])
            mat.node_tree.links.new(texture.outputs['Color'], blend.inputs[2])
            mat.node_tree.links.new(blend.outputs[0], shader.inputs['Base Color'])
        normal_texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
        normal_texture.image = bpy.data.images.load(str(paths[1]), check_existing=True)
        normal_texture.image.colorspace_settings.name = 'Non-Color'
        normal_texture.image.pack()
        normal_map = mat.node_tree.nodes.new('ShaderNodeNormalMap')
        normal_map.inputs['Strength'].default_value = .18
        mat.node_tree.links.new(normal_texture.outputs['Color'], normal_map.inputs['Color'])
        mat.node_tree.links.new(normal_map.outputs['Normal'], shader.inputs['Normal'])
        mat['moth_finish_version'] = 1
        mat['moth_family'] = family(name)
        mat['moth_resource_sha256'] = json.dumps({str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}, sort_keys=True)
    bpy.context.scene['asset_production_unit'] = unit
    bpy.context.scene['moth_finish_version'] = 1
    bpy.context.scene['moth_finish_review'] = 'PENDING native texture/UV/material/readability acceptance'
