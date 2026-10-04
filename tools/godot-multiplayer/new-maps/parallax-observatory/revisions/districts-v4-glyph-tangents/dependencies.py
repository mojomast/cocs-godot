"""Explicit frozen source dependencies; imports launch no engine and write nothing."""
import sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
AA_DIR=HERE.parent/'districts-v4-tangent'
DIAG=ROOT/'tools/godot-multiplayer/new-maps/botanical-parallax-aa-diagnosis'
sys.path.insert(0,str(AA_DIR))
import contract as aa
import editable as aa_editable
sys.path.insert(0,str(DIAG))
import census
import proposal as approved_policy
AA_ART=ROOT/'godot/tests/new_maps/parallax_tangent/candidate.glb'
AA_MASTER=AA_DIR/'native/AA02/parallax-observatory-tangent.blend'
AA_SHA='95e9da98a45565ca2aae90858a9e5027d9123e4ffd1347da98d5de8573141cd5'
AA_MASTER_SHA='2e6617840ec57d08685dd78e64a29bbe7f55db2b1a26da40b6c6a46cd4c0373d'
X_STAGE=ROOT/'godot/tests/new_maps/botanical_correction/x-03/parallax-observatory'
REVISION='parallax-districts-v4-glyph-tangents-v1'
POLICY='rank-one-glyph-extrusion-preserve-w-align-positive-v-v1'
sha=aa.sha

def frozen():
    import json
    for path,digest in json.loads((HERE/'dependency-lock.json').read_text()).items():
        if sha((ROOT/path).read_bytes())!=digest:raise ValueError('Frozen helper/stage dependency changed: '+path)
    raw=AA_ART.read_bytes()
    if sha(raw)!=AA_SHA or sha(AA_MASTER.read_bytes())!=AA_MASTER_SHA:raise ValueError('Frozen AA GLB/master identity changed')
    aa.pinned()  # original X GLB/master dependencies remain explicit
    return raw

def dependency_hashes():
    paths=[AA_DIR/'contract.py',AA_DIR/'editable.py',AA_DIR/'production.py',DIAG/'census.py',DIAG/'proposal.py',
        ROOT/'tools/godot-multiplayer/new-maps/gravemill-foundry/revision7/material_contract.py',
        ROOT/'tools/godot-multiplayer/new-maps/map_variety/glb_geometry.py']
    return {str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in paths}
