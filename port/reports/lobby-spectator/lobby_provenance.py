"""Hash new artifacts and verify inherited runtime/generated/test inputs unchanged."""
import hashlib,json,pathlib,subprocess
OUT=pathlib.Path(__file__).resolve().parent
ROOT=OUT.parents[2]
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
previous=json.loads((ROOT/'port/reports/lobby-followup/provenance.json').read_text())
allowed={'godot/net/client.gd','godot/world/session.gd','godot/ui/lobby_menu.gd'}
verified={}
for key in ['runtimeHashes','generatedHashes','newTests']:
    for name,expected in previous[key].items():
        if name in allowed: continue
        actual=digest(ROOT/name)
        assert actual==expected,(name,'inherited input changed')
        verified[name]=actual
binary=pathlib.Path(previous['binary']['path'])
assert digest(binary)==previous['binary']['sha256']
commits=subprocess.check_output(['git','log','12e770d..HEAD','--format=%H %s'],cwd=ROOT,text=True).splitlines()
files=list(OUT.rglob('*'))+list((ROOT/'godot/tests/protocol').glob('lobby_spectator_*.gd'))
inventory={str(p.relative_to(ROOT)):digest(p) for p in sorted(files) if p.is_file() and p.name!='provenance.json'}
report={'base':'12e770ddbcc0befb74e95b7154cfc0ab55b6812b','commitsBeforeEvidence':commits,'source':'51289b79c627a26a381ba556b92bab71f93f3732','binary':previous['binary'],'dependencies':str((ROOT/'node_modules').resolve()),'runtimeHashes':{n:digest(ROOT/n) for n in sorted(allowed)},'inheritedInputsVerified':verified,'inventory':inventory}
(OUT/'provenance.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'inheritedInputsVerified':len(verified),'newArtifactsHashed':len(inventory),'runtimeHashes':report['runtimeHashes']},indent=2))
