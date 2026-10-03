"""Pin only newly generated R6 native sidecars. R5 sidecars remain immutable."""
from finish import ROOT,HERE,write,sha
path=ROOT/'godot/multiplayer_worlds/art/revisions/gravemill-foundry-r6.glb.import'
text=path.read_text();before=sha(path.read_bytes())
for key,old,new in [('meshes/force_disable_compression','false','true'),('meshes/generate_lods','true','false')]:
    assert key+'='+old in text or key+'='+new in text
    text=text.replace(key+'='+old,key+'='+new)
path.write_text(text)
write(HERE/'evidence/W/import-policy.json',{'beforeSha256':before,'afterSha256':sha(path.read_bytes()),
    'policy':'Same settings as shared botanical pin_import.py: retain generated native UID; disable mesh compression and generated LODs. R5 sidecars unchanged.'})
