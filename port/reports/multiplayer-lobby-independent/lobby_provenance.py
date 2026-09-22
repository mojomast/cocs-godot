"""Snapshot hashes without altering runtime or historical attempt summaries."""
import hashlib, json, pathlib, subprocess
OUT = pathlib.Path(__file__).resolve().parent
ROOT = OUT.parents[2]
def git(*args): return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
runtime = [p for p in git('ls-files','godot','game','server','port/contracts','tools/godot-export').splitlines() if not p.startswith('godot/tests/protocol/lobby_independent_')]
binary = pathlib.Path('/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')
data = {'primaryBaseline':'df66fc6b6e66b429ae5673e9a1b323e1b95d068d','delivery':'3b9620639b2903bcccac953c123f9b9e0350b1a9','runtimeCherryPick':'2e93cfd5325a64b3f9a42ad5a58d8a6d47f2de51','captureHeads':['0c9207698b251efbb6db89a8836899ac3aad3920','37f0b9eee53d51511cfe9d8e904433aa6162e568'],'runtimeHashes':{p:digest(ROOT/p) for p in runtime},'generatedHashes':{str(p.relative_to(ROOT)):digest(p) for p in (ROOT/'godot/content/generated').rglob('*') if p.is_file()},'binary':{'path':str(binary),'sha256':digest(binary)},'inventory':{str(p.relative_to(ROOT)):digest(p) for p in OUT.rglob('*') if p.is_file() and p.name!='provenance.json' and '__pycache__' not in str(p)},'ownedObservers':{str(p.relative_to(ROOT)):digest(p) for p in (ROOT/'godot/tests/protocol').glob('lobby_independent_*')}}
assert not git('diff','2e93cfd','--',*runtime), 'Runtime drift'
(OUT/'provenance.json').write_text(json.dumps(data,indent=2)+'\n')
print(json.dumps({'runtimeFiles':len(runtime),'evidenceFiles':len(data['inventory']),'runtimeDrift':False}))
