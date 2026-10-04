"""Future authorized Blender build/reopen only. No engine import at module load."""
import json
import math
import os
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from successor import *

def old_recipe():
    import importlib.util
    spec=importlib.util.spec_from_file_location('frozen_aa_production',AA_DIR/'production.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module.recipe()

def recipe():
    files={p.name:sha(p.read_bytes()) for p in HERE.glob('*.py')}
    return {'visualRevision':REVISION,'policy':POLICY,'sourceAAArtSha256':AA_SHA,'sourceAAMasterSha256':AA_MASTER_SHA,
        'geometryHash':aa.GEOMETRY,'originalAARecipe':old_recipe(),'sourceCompilerSha256':sha((HERE/'successor.py').read_bytes()),
        'newSourceFiles':files,'dependencyLockSha256':sha((HERE/'dependency-lock.json').read_bytes()),'dependencies':dependency_hashes(),'entrySet':sorted(approved_policy.EXPECTED),
        'policyMeaning':'Explicit all-incident geometric fallback for singular rank-one UVs, not a unique Mikk/dUV basis',
        'pipeline':'Audit actual editable export against AA, then deterministic AA+16; original X+3 remains unchanged provenance'}

def verify_old_recipe(scene,texts):
    encoded=json.dumps(old_recipe(),sort_keys=True)
    if scene.get('parallax_tangent_recipe')!=encoded or texts['PARALLAX_TANGENT_RECIPE.json'].as_string()!=encoded:
        raise ValueError('Original AA packed recipe changed')
    if texts['PARALLAX_TANGENT_COMPILER.py'].as_string()!=(AA_DIR/'contract.py').read_text():raise ValueError('Original AA packed compiler changed')

def main():
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--grant-receipt',required=True);parser.add_argument('--attempt',required=True);parser.add_argument('--reopen',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:])
    from stage import attempt_path,require_grant
    require_grant(Path(args.grant_receipt));out=attempt_path(args.attempt)
    raw=frozen();expected=recipe();encoded=json.dumps(expected,sort_keys=True)
    import bpy
    if bpy.app.version[:3]!=(4,5,14):raise ValueError('Pinned Blender 4.5.14 required')
    target=out/'parallax-glyph-tangents.blend';artifact=out/'parallax-glyph-tangents.glb'
    if not args.reopen:out.mkdir(parents=True,exist_ok=False)
    report_path=out/('reopen-report.json' if args.reopen else 'build-report.json')
    if report_path.exists():raise FileExistsError('Immutable production attempt/report already exists')
    bpy.ops.wm.open_mainfile(filepath=str(target if args.reopen else AA_MASTER))
    verify_old_recipe(bpy.context.scene,bpy.data.texts)
    keys={'PARALLAX_GLYPH_RECIPE.json':encoded,'PARALLAX_GLYPH_COMPILER.py':(HERE/'successor.py').read_text(),
        'PARALLAX_GLYPH_POLICY.py':(DIAG/'proposal.py').read_text()}
    if args.reopen:
        if bpy.context.scene.get('parallax_glyph_recipe')!=encoded:raise ValueError('New packed scene recipe changed')
        for key,text in keys.items():
            if bpy.data.texts[key].as_string()!=text:raise ValueError('New packed recipe/compiler changed')
    else:
        if any(k in bpy.data.texts for k in keys):raise ValueError('New text namespace already exists')
        bpy.context.scene['parallax_glyph_recipe']=encoded;bpy.context.scene['visualRevision']=REVISION
        for key,text in keys.items():bpy.data.texts.new(key).write(text)
        if any(not i.packed_file for i in bpy.data.images if i.source=='FILE'):raise ValueError('Unpacked AA source image')
        bpy.context.preferences.filepaths.save_version=0;bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(target),compress=True)
    names={n['name'] for n in aa.EmbeddedGlb(raw).doc['nodes']}
    meshes=[o for o in bpy.data.objects if o.type=='MESH' and o.name in names]
    if len(meshes)!=39 or any(o.parent or not math.isfinite(o.matrix_world.determinant()) or o.matrix_world.determinant()<=0 for o in meshes):raise ValueError('Expected 39 flat editable roots with proper transforms')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:obj.hide_set(False);obj.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    intermediate=out/('reopen-editable.glb' if args.reopen else 'build-editable.glb')
    if intermediate.exists():raise FileExistsError('Intermediate attempt already exists')
    bpy.ops.export_scene.gltf(filepath=str(intermediate),export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_tangents=True)
    audit=audit_editable(intermediate.read_bytes(),raw)
    result,_=compile_art(raw);proof=verify_art(raw,result)
    if args.reopen:
        previous=json.loads((out/'build-report.json').read_text())
        if previous['processId']==os.getpid():raise ValueError('Reopen requires a fresh Blender process')
        if artifact.read_bytes()!=result:raise ValueError('Fresh master canonical reexport differs')
    else:artifact.write_bytes(result)
    proof.update(actualArtHash=sha(result),actualMasterHash=sha(target.read_bytes()),processId=os.getpid(),scope='Actual authorized production; native/manual pending',editable=audit,recipe=expected)
    report_path.write_text(json.dumps(proof,indent=2)+'\n');frozen()

if __name__=='__main__':main()
