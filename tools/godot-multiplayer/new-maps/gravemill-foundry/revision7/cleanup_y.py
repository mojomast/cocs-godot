"""Remove only newly generated, unrelated Y native sidecars after recording hashes."""
import subprocess
from tangents import *
before=json.loads((HERE/'evidence/Y/attempts/sidecars-before.json').read_text());removed={}
untracked=subprocess.check_output(['git','ls-files','--others','--exclude-standard','-z'],cwd=ROOT).decode().split('\0')
for name in untracked:
    if not name.startswith('godot/') or Path(name).suffix not in ('.uid','.import'):continue
    if name.startswith('godot/tests/new_maps/gravemill_foundry/revision7/') or name.startswith('godot/multiplayer_worlds/art/revisions/gravemill-foundry-r7'):continue
    assert name not in before
    p=ROOT/name;removed[name]=sha(p.read_bytes());p.unlink()
(HERE/'evidence/Y/attempts/unrelated-sidecars-removed.json').write_text(json.dumps(removed,indent=2)+'\n')
print('Removed only Y-generated unrelated sidecars:',len(removed))
