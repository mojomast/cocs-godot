"""Source-only contract from the actual builders and refined helper; no bpy."""
import ast
import json
from pathlib import Path
import subprocess
from moth_finish import family, FAMILIES, checked_source

ROOT = Path(__file__).resolve().parents[2]


def literal(path, name):
    tree = ast.parse((ROOT/path).read_text())
    return next(ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
                and any(isinstance(t, ast.Name) and t.id == name for t in n.targets))


def contract():
    names = {
        'robots': ['Switchyard_vertex_enamel'],
        'vehicles': json.loads(subprocess.check_output(['node', '--input-type=module', '-e',
            "import {palette} from './tools/godot-vehicle-assets/recipe.mjs'; console.log(JSON.stringify(Object.keys(palette)))"], cwd=ROOT, text=True, timeout=10)),
        'scenery': ['biome4_'+n for n in json.loads((ROOT/'tools/godot-biomes/expansion/meshes.json').read_text())['palette']],
        'vesper-viaduct': list(literal('tools/godot-multiplayer/new-maps/vesper-viaduct/author_blender.py', 'COLORS')),
        'abyssal-pressureworks': list(json.loads((ROOT/'godot/multiplayer_worlds/generated/abyssal-pressureworks.json').read_text())['arena']['art']['palette']),
        'stormglass-causeway': list(literal('tools/godot-multiplayer/new-maps/stormglass-causeway/blender_export.py', 'COLORS')),
    }
    # Catch renamed robot authoring material instead of trusting a second palette.
    tree = ast.parse((ROOT/'tools/godot-robots/build.py').read_text())
    actual = [n.args[0].value for n in ast.walk(tree) if isinstance(n, ast.Call)
              and ast.unparse(n.func) == 'bpy.data.materials.new' and isinstance(n.args[0], ast.Constant)]
    assert actual == names['robots'], actual
    manifest = json.loads((ROOT/'godot/moth/generated/manifest.json').read_text())
    import hashlib
    master = ROOT/manifest['provenance']['source']
    assert hashlib.sha256(master.read_bytes()).hexdigest() == manifest['provenance']['source_sha256']
    resources = {}
    units = {}
    for unit, palette in names.items():
        units[unit] = {}
        for name in palette:
            role = family(name, unit)
            normal = role != 'preserve' and FAMILIES[role][2] > 0
            units[unit][name.lower()] = {'role': role, 'normalRequired': normal, 'colorRequired': unit == 'robots'}
            if role != 'preserve':
                path, digest = checked_source(ROOT, manifest['textures'][FAMILIES[role][0]])
                resources[str(path.relative_to(ROOT))] = digest
                units[unit][name.lower()]['sourceHashes'] = {str(path.relative_to(ROOT)): digest}
                units[unit][name.lower()]['normalStrength'] = FAMILIES[role][2]
    return {'units': units, 'resources': resources, 'master': {str(master.relative_to(ROOT)): manifest['provenance']['source_sha256']}}


if __name__ == '__main__':
    print(json.dumps(contract(), sort_keys=True))
