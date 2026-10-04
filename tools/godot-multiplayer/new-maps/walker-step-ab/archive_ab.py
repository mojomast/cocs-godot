"""Hash-constrained AB evidence archive/cleanup after explicit release; no engines."""
import hashlib,json,re,sys,subprocess,tarfile
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3];E=HERE/'evidence'
sys.path.insert(0,str(HERE.parent/'walker-step-up'))
from prepare_v2 import write,digest
def main():
    assert json.loads((E/'AB-release.json').read_text())['status']=='RELEASED'
    baseline=json.loads((E/'baseline.json').read_text())
    assert '?? godot/' not in baseline['trackedStatus']
    for name,r in baseline['sidecars'].items():assert digest(ROOT/name)==r['sha256'],name
    attempt=ROOT/'godot/tests/walker_step_up/walker-step-AB-01'
    cache={}
    for sidecar in attempt.glob('*.import'):
        for name in re.findall(r'res://(\.godot/imported/[^"\s]+)',sidecar.read_text()):
            path=ROOT/'godot'/name
            if path.is_file():cache[path]=True
            md5=path.with_suffix('.md5')
            if md5.is_file():cache[md5]=True
    inventory={str(p.relative_to(ROOT)):{'sha256':digest(p),'bytes':p.stat().st_size} for p in sorted(cache)}
    with tarfile.open(E/'attempt-import-cache.tar.gz','x:gz') as tar:
        for p in sorted(cache):tar.add(p,arcname=str(p.relative_to(ROOT)),recursive=False)
    write(E/'attempt-import-cache.json',{'files':inventory,'count':len(inventory)})
    untracked=subprocess.check_output(['git','ls-files','--others','--exclude-standard','-z'],cwd=ROOT).decode().split('\0')
    cleanup={}
    for name in untracked:
        p=ROOT/name
        if not name.startswith('godot/') or p.suffix not in ['.import','.uid'] or p.is_relative_to(attempt):continue
        if p.is_relative_to(ROOT/'godot/tests/walker_step_up'):continue
        assert name not in baseline['sidecars'] and p.is_file() and not p.is_symlink()
        cleanup[name]={'sha256':digest(p),'bytes':p.stat().st_size}
    write(E/'owned-unrelated-sidecars.json',{'ownership':'fresh isolated worktree, no baseline untracked godot paths, only four AB jobs before release','files':cleanup})
    with tarfile.open(E/'owned-unrelated-sidecars.tar.gz','x:gz') as tar:
        for name in cleanup:tar.add(ROOT/name,arcname=name,recursive=False)
    for name,r in cleanup.items():
        p=ROOT/name;assert digest(p)==r['sha256'] and p.stat().st_size==r['bytes'];p.unlink()
    for name,r in baseline['sidecars'].items():assert digest(ROOT/name)==r['sha256'],name
    write(E/'cleanup.json',{'removedOwnedHashMatchingSidecars':len(cleanup),'archivedBeforeRemoval':True,'preexistingSidecarsPreserved':len(baseline['sidecars']),'importCacheFilesArchived':len(inventory),'wildcardDeletion':False})
    print('Archived',len(inventory),'cache files; hash-checked',len(cleanup),'owned removals;',len(baseline['sidecars']),'preexisting sidecars preserved')
if __name__=='__main__':main()
