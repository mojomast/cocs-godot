"""Future explicit-grant Blender build/reopen. Never imported by source tests."""
import json
import math
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from contract import HERE, ROOT, MASTER, MASTER_SHA, SOURCE_SHA, REVISION, pinned, repair, verify, sha
from editable import audit

OUTPUT = HERE / 'native/AA02'  # new attempt; AA01 traceback retained
RECIPE_KEY = 'PARALLAX_TANGENT_RECIPE.json'
COMPILER_KEY = 'PARALLAX_TANGENT_COMPILER.py'

def recipe():
    return {'visualRevision': REVISION, 'sourceGlbSha256': SOURCE_SHA, 'sourcePackedMasterSha256': MASTER_SHA,
        'geometryHash': '3a5800e89876ebcc741381802def24415d5050651c0d3b831ea8b9ec3b77b4f9',
        'compilerSha256': sha((HERE / 'contract.py').read_bytes()),
        'editableAuditSha256': sha((HERE / 'editable.py').read_bytes()),
        'uvBasisSha256': sha((ROOT / 'tools/godot-multiplayer/new-maps/botanical-post-x/uv_basis.py').read_bytes()),
        'materialGateSha256': sha((ROOT / 'tools/godot-multiplayer/new-maps/gravemill-foundry/revision7/material_contract.py').read_bytes()),
        'policy': 'Export all 39 editable X meshes; semantic audit, then deterministic three-corner compiler against exact X GLB. Plain Blender glTF is intermediate.'}

def main():
    if len(sys.argv) < 2 or '--authorized-parallax-tangent' not in sys.argv or '--grant-receipt' not in sys.argv:
        raise RuntimeError('An explicit new exclusive heavy grant and receipt are required')
    receipt = Path(sys.argv[sys.argv.index('--grant-receipt') + 1])
    grant = json.loads(receipt.read_text())
    if grant.get('exclusive') is not True or grant.get('map') != 'parallax-observatory' or grant.get('released') is not False:
        raise ValueError('Grant is missing, mismatched or released')
    import bpy
    if bpy.app.version[:3] != (4, 5, 14): raise RuntimeError('Pinned Blender 4.5.14 required')
    source = pinned()
    expected = recipe()
    encoded = json.dumps(expected, sort_keys=True)
    reopen = '--reopen' in sys.argv
    target = OUTPUT / 'parallax-observatory-tangent.blend'
    bpy.ops.wm.open_mainfile(filepath=str(target if reopen else MASTER))
    bpy.context.preferences.filepaths.save_version = 0
    if reopen:
        if (bpy.context.scene.get('parallax_tangent_recipe') != encoded or
            bpy.data.texts[RECIPE_KEY].as_string() != encoded or
            bpy.data.texts[COMPILER_KEY].as_string() != (HERE / 'contract.py').read_text()):
            raise ValueError('Reopened master recipe/compiler changed')
    else:
        bpy.context.scene['parallax_tangent_recipe'] = encoded
        bpy.context.scene['visualRevision'] = REVISION
        bpy.data.texts.new(RECIPE_KEY).write(encoded)
        bpy.data.texts.new(COMPILER_KEY).write((HERE / 'contract.py').read_text())
        if any(not image.packed_file for image in bpy.data.images if image.source == 'FILE'):
            raise ValueError('Source master has unpacked file textures')
        bpy.ops.file.pack_all()
        OUTPUT.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(target), compress=True)
    from contract import EmbeddedGlb
    original = EmbeddedGlb(source)
    names = {node['name'] for node in original.doc['nodes'] if 'mesh' in node}
    meshes = [obj for obj in bpy.data.objects if obj.type == 'MESH' and obj.name in names]
    if len(names) != 39 or len(meshes) != 39 or any(not math.isfinite(obj.matrix_world.determinant()) or obj.matrix_world.determinant() <= 0 for obj in meshes):
        raise ValueError('Packed editable mesh inventory or transform orientation changed')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes: obj.hide_set(False); obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    intermediate = OUTPUT / ('reopen-editable.glb' if reopen else 'build-editable.glb')
    bpy.ops.export_scene.gltf(filepath=str(intermediate), export_format='GLB', use_selection=True,
        export_yup=True, export_extras=True, export_tangents=True)
    editable = audit(intermediate.read_bytes(), source)
    candidate, _ = repair(source)
    proof = verify(source, candidate)
    artifact = OUTPUT / 'parallax-observatory-tangent.glb'
    if reopen:
        if artifact.read_bytes() != candidate: raise ValueError('Fresh process canonical reexport differs')
    else:
        artifact.write_bytes(candidate)
    report = {**proof, 'scope': 'future actual authorized production', 'artifactSha256': sha(candidate),
        'packedMasterSha256': sha(target.read_bytes()), 'editableReexport': editable, 'recipe': expected,
        'nativeAcceptance': 'pending'}
    (OUTPUT / ('reopen-report.json' if reopen else 'build-report.json')).write_text(json.dumps(report, indent=2) + '\n')
    pinned()  # ensure immutable X dependencies survived the build

if __name__ == '__main__': main()
