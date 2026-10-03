"""Archive the released Z attempt; clean only proven Z-created sidecars by hash."""
import hashlib
import json
import re
import subprocess
from pathlib import Path
from grant_z import HERE,ROOT,now,write

def sha(raw):return hashlib.sha256(raw).hexdigest()
def main():
    evidence=HERE/'evidence';attempt=ROOT/'godot/tests/new_maps/botanical_post_x/vesper-Z-01'
    assert json.loads((evidence/'lock-available.json').read_text())['released']
    destination=evidence/'vesper-Z-01/imported';destination.mkdir()
    copied={}
    for sidecar in sorted(attempt.glob('*.import')):
        for resource in re.findall(r'"(res://\.godot/imported/[^"\n]+)"',sidecar.read_text()):
            source=ROOT/'godot'/resource[6:]
            assert source.is_file(),resource
            for p in [source,source.with_suffix('.md5')]:
                if not p.exists():continue
                target=destination/p.name
                if target.exists():assert target.read_bytes()==p.read_bytes()
                else:target.write_bytes(p.read_bytes())
                copied[str(p.relative_to(ROOT))]={'archive':str(target.relative_to(ROOT)),'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size}
    (evidence/'vesper-Z-01/project.godot').write_bytes((ROOT/'godot/project.godot').read_bytes())
    write(evidence/'vesper-Z-01/cache-archive.json',{'time':now(),'files':copied})
    before=json.loads((evidence/'attempts/sidecars-before.json').read_text())
    after=json.loads((evidence/'attempts/sidecars-after.json').read_text())
    tracked=set(subprocess.check_output(['git','ls-files'],cwd=ROOT,text=True).splitlines())
    removed={};retained={}
    for path,digest in after.items():
        p=ROOT/path
        if path in before:
            assert before[path]==digest==sha(p.read_bytes()),'Preexisting sidecar changed: '+path
            continue
        assert path not in tracked,'Tracked artifact cannot be removed'
        assert sha(p.read_bytes())==digest,'New owned sidecar changed since release audit'
        if p.is_relative_to(attempt):retained[path]=digest;continue
        assert p.suffix in ['.import','.uid']
        p.unlink();removed[path]=digest
    write(evidence/'owned-sidecar-cleanup.json',{'time':now(),'method':'Absent before Z, present in release inventory, untracked, exact release hash matched; no general untracked cleanup',
        'removedCount':len(removed),'removed':removed,'retainedAttemptSidecars':retained,'preexistingSidecarsUnchanged':len(before)})
    print('Archived',len(copied),'imported cache files; removed',len(removed),'provably Z-created unrelated sidecars; retained',len(retained),'attempt sidecars')
if __name__=='__main__':main()
