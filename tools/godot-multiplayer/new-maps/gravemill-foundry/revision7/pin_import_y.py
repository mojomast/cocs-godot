"""Only the new R7 sidecar: retain real native UID, full precision, no LODs."""
from tangents import *
path=ROOT/'godot/multiplayer_worlds/art/revisions/gravemill-foundry-r7.glb.import'
text=path.read_text();before=sha(path.read_bytes())
for key,old,new in [('meshes/force_disable_compression','false','true'),('meshes/generate_lods','true','false')]:
    assert key+'='+old in text or key+'='+new in text
    text=text.replace(key+'='+old,key+'='+new)
path.write_text(text)
(HERE/'evidence/Y/import-policy.json').write_text(json.dumps({'beforeSha256':before,'afterSha256':sha(path.read_bytes()),
    'policy':'R7 native generated UID retained; full precision positions and no generated LODs'},indent=2)+'\n')
