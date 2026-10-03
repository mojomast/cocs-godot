"""Small builder-facing material API for the reviewed v2 + additive v3 pack.

load_materials(root, bindings) -> (materials, tiles_per_metre)
Bindings map exact exported names to {material: pack ID, role: surface|team,
normal: bool, metallic: optional explicit 0..1}; team requires teamColorSource=COLOR_0.
Preserved glass/emissive is explicitly authored by each map builder instead.
The detailed proof report is available via load_materials(..., with_report=True).
"""
from pathlib import Path
from material_pack import load_materials as _load

# Reviewed semantic defaults apply only after a stable pack ID resolves. This
# is a scalar BRDF starting point, never a material/resource-name fallback.
METAL_RESOURCES=frozenset(('anodized-brush','copper-heat-oxide','copper-patina',
    'forge-steel','iron-grate','optical-mirror-opaque','oxidized-iron','ribbed-steel'))


def load_materials(root, bindings, *, output_dir=None, with_report=False):
    converted = {}
    for name, binding in bindings.items():
        if binding['role']=='preserve':
            raise ValueError('Author preserved glass/emissive explicitly outside Moth adapter: '+name)
        if not isinstance(binding.get('normal'),bool):
            raise ValueError('Normal attachment must be explicitly reviewed for '+name)
        converted[name]={'resource':binding['material'],'role':binding['role'],
                         'metallic':binding.get('metallic',.65 if binding['material'] in METAL_RESOURCES else 0),
                         'normal':binding['normal']}
        if binding['role']=='team':converted[name]['teamColorSource']=binding['teamColorSource']
    path=output_dir or Path(root)/'tools/map-variety-pipeline/converted'
    materials,densities,report=_load(root,converted,path)
    return (materials,densities,report) if with_report else (materials,densities)
