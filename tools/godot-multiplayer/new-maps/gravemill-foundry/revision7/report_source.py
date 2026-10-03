"""Reproduce source-only evidence; compose GLB bytes in memory, never write art."""
import datetime
import subprocess
from tangents import *

def main():
    manifest=R6/'evidence/W/final-manifest.json'
    entries=json.loads(manifest.read_text())['files']
    for path,entry in entries.items():
        raw=(ROOT/path).read_bytes()
        if sha(raw)!=entry['sha256'] or len(raw)!=entry['bytes']:
            raise ValueError('Frozen W file changed: '+path)
    if subprocess.check_output(['git','diff','9c5eca6d','--name-only','--','.',
            ':!tools/godot-multiplayer/new-maps/gravemill-foundry/revision7'],cwd=ROOT).strip():
        raise ValueError('Tracked baseline files changed')
    raw=SOURCE.read_bytes();result,_=repair(raw);report=verify(raw,result)
    command=[sys.executable,'-m','unittest','discover','-s',str(HERE),'-p','test_tangents.py','-v']
    completed=subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
    evidence={'time':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'scope':'Python source-only; no native engine or production artifact',
        'command':command,'exitCode':completed.returncode,'stdout':completed.stdout,'stderr':completed.stderr,
        'frozenWManifestSha256':sha(manifest.read_bytes()),'frozenWFilesVerified':len(entries),
        'trackedDiffOutsideR7Empty':True,'sourceHashes':{p.name:sha(p.read_bytes()) for p in sorted(HERE.glob('*.py'))}}
    (HERE/'source-tests.json').write_text(json.dumps(evidence,indent=2)+'\n')
    if completed.returncode:raise RuntimeError(completed.stderr)
    report.update({'sourceArtHash':sha(raw),'actualArtifactProduced':False,'nativeAcceptance':'pending',
        'productionRecipeExecuted':False,'frozenWFilesVerified':len(entries)})
    (HERE/'source-report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(completed.stderr)
    print('Verified frozen W files:',len(entries))

if __name__=='__main__':main()
