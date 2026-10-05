"""Closed Vesper JSON/art pairs for the post-X movement diagnostic."""
import json
import os
import sys
from pathlib import Path
from fixture_inputs import ROOT,HERE,SOURCE_PINS,sha
sys.path.insert(0,str(HERE.parent/'map_variety'))
from glb_geometry import EmbeddedGlb

ARTS={
 'accepted':{
  'path':'godot/multiplayer_worlds/art/worlds/vesper-viaduct.glb',
  'artSha256':'51a5b5768e5eb66bc0941652ea47436a5db4f75a282bd23e72bf007091b022d2',
  'geometryHash':'db20ce1fec59678ac3b7086be40b1dbac25fdaf9b576d284a1db448dcd9ebd22',
  'recipeHash':'6886cf86c360f24fdcd5e39762d7c978e89a1438b11e19a92b8de4ab563f3561'},
 'candidate':{
  'path':'tools/godot-multiplayer/new-maps/botanical-correction/runs/x-03/vesper-viaduct/vesper-viaduct.glb',
  'artSha256':'f859d49cc1b462b4a88e351d915518c49940ce24a7b8c2047c2d8f94f419e1db',
  'geometryHash':'fd8e7134c8933e908336d7b0409c66bdc90f4adc03fcfc6e596d5b4579f1c740',
  'recipeHash':'f22b863cab4caec974602b81548b11e7fd60e221d441e136c47c35df144220e2'},
}

def art_bytes(variant):
    if variant not in ARTS:raise ValueError('Unknown art variant')
    root=ROOT
    if variant=='candidate':
        configured=os.environ.get('COCS_BOTANICAL_X_FIXTURE_ROOT')
        if not configured:raise ValueError('Explicit COCS_BOTANICAL_X_FIXTURE_ROOT required for candidate art; no fallback')
        root=Path(configured).resolve(strict=True)
    path=(root/ARTS[variant]['path']).resolve(strict=True)
    if not path.is_relative_to(root):raise ValueError('Art escapes selected root')
    raw=path.read_bytes()
    if sha(raw)!=ARTS[variant]['artSha256']:raise ValueError('Exact '+variant+' art SHA256 mismatch')
    return raw

def inspect_pair(variant,authority_raw,art_raw):
    expected=ARTS[variant]
    if sha(authority_raw)!=SOURCE_PINS[variant][1]:raise ValueError('Authority bytes mismatch')
    data=json.loads(authority_raw)
    if data.get('id')!='vesper-viaduct' or data.get('geometryHash')!=expected['geometryHash'] or data.get('recipeHash')!=expected['recipeHash']:
        raise ValueError('Authority/recipe identity mismatch; static substitution forbidden')
    if sha(art_raw)!=expected['artSha256']:raise ValueError('Art SHA256 mismatch; accepted fallback forbidden')
    glb=EmbeddedGlb(art_raw);primitives,triangles,used=glb.geometry()
    extras=glb.doc['scenes'][glb.doc['scene']].get('extras',{})
    if variant=='candidate':
        if extras.get('geometry_hash')!=expected['geometryHash'] or extras.get('recipe_hash')!=expected['recipeHash']:raise ValueError('GLB embedded successor identity mismatch')
    elif extras.get('recipe_sha256')!=expected['recipeHash']:raise ValueError('Accepted GLB recipe identity mismatch')
    materials=sorted(glb.doc['materials'][i]['name'] for i in used)
    meshes=sum('mesh' in n for n in glb.doc['nodes'])
    if not triangles or not meshes or not materials:raise ValueError('Empty selected art')
    return {'map':'vesper-viaduct','authoritySha256':sha(authority_raw),'geometryHash':data['geometryHash'],
        'recipeHash':data['recipeHash'],'artSha256':sha(art_raw),'triangles':triangles,'meshInstances':meshes,
        'surfaces':len(primitives),'materials':materials,'nativeReady':False}

def preflight():
    # Both pairs must succeed before the destination directory or any file exists.
    result={}
    for variant,(path,_) in SOURCE_PINS.items():
        authority=(ROOT/path).read_bytes();art=art_bytes(variant)
        result[variant]=(authority,art,inspect_pair(variant,authority,art))
    return result
