"""Exact accepted-map colors and BRDF scalars for non-Moth glass/emissive art.

The map binding file is the authority. Moth resources have their own adapter;
these authored materials use scene-linear shader values from accepted sRGB
palette entries, never a guessed material name or a pack fallback.
"""
import math
import re


PRESERVED_NAMES = {
    'abyssal-pressureworks': frozenset(('observation-glass', 'equalizer-emissive', 'amber', 'cyan', 'glass')),
    'stormglass-causeway': frozenset(('harbour-glass', 'amber', 'glass', 'ocean')),
}
FIELDS = frozenset(('role', 'colorSrgb', 'alpha', 'roughness', 'metallic', 'emissionStrength', 'tilesPerMeter'))
HEX_COLOR = re.compile(r'^#[0-9a-f]{6}$')


def srgb_channels(value):
    if isinstance(value, str) and HEX_COLOR.fullmatch(value):
        return tuple(int(value[i:i+2], 16) / 255 for i in (1, 3, 5))
    if isinstance(value, list) and len(value) == 3 and all(type(c) in (int, float) and math.isfinite(c) and 0 <= c <= 1 for c in value):
        return tuple(value)
    raise ValueError('Preserved color must be an explicit sRGB hex triplet or three finite unit floats')


def linear_color(color):
    return tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in srgb_channels(color))


def split_bindings(bindings, map_id):
    if map_id not in PRESERVED_NAMES:
        raise ValueError('Unreviewed preserved palette for ' + map_id)
    pack, preserved = {}, {}
    for name, binding in bindings.items():
        role = binding.get('role')
        if role == 'preserve':
            if name not in PRESERVED_NAMES[map_id] or set(binding) != FIELDS:
                raise ValueError('Unknown or incomplete preserved material: ' + name)
            srgb_channels(binding['colorSrgb'])
            if any(type(binding[k]) not in (int, float) or not math.isfinite(binding[k]) or not 0 <= binding[k] <= 1
                   for k in ('alpha', 'roughness', 'metallic')):
                raise ValueError('Invalid preserved BRDF scalar: ' + name)
            strength, density = binding['emissionStrength'], binding['tilesPerMeter']
            if (type(strength) not in (int, float) or not math.isfinite(strength) or not 0 <= strength <= 4
                    or type(density) not in (int, float) or not math.isfinite(density) or not 0 < density <= 16):
                raise ValueError('Invalid preserved emission or UV density: ' + name)
            preserved[name] = binding
        elif role in ('surface', 'team'):
            if not isinstance(binding.get('normal'), bool) or not isinstance(binding.get('material'), str) or not binding['material']:
                raise ValueError('Incomplete Moth binding: ' + name)
            if role == 'team' and binding.get('teamColorSource') != 'COLOR_0':
                raise ValueError('Team binding lacks COLOR_0: ' + name)
            pack[name] = binding
        else:
            raise ValueError('Unknown material role for ' + name)
    if set(preserved) != PRESERVED_NAMES[map_id]:
        raise ValueError('Missing preserved materials: ' + ', '.join(sorted(PRESERVED_NAMES[map_id] - set(preserved))))
    return pack, preserved


def make_materials(bpy, bindings):
    materials, density = {}, {}
    for name, entry in bindings.items():
        rgb = linear_color(entry['colorSrgb'])
        alpha = entry['alpha']
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = (*rgb, alpha)
        shader.inputs['Alpha'].default_value = alpha
        shader.inputs['Roughness'].default_value = entry['roughness']
        shader.inputs['Metallic'].default_value = entry['metallic']
        mat.diffuse_color = (*rgb, alpha)
        mat.use_backface_culling = False
        if alpha < 1:
            mat.surface_render_method = 'DITHERED'
        if entry['emissionStrength']:
            shader.inputs['Emission Color'].default_value = (*rgb, 1)
            shader.inputs['Emission Strength'].default_value = entry['emissionStrength']
        materials[name] = mat
        density[name] = entry['tilesPerMeter']
    return materials, density
