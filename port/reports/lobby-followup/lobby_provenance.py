"""Record follow-up identity/hashes while preserving previous evidence files."""
import hashlib,json,pathlib,subprocess
OUT=pathlib.Path(__file__).resolve().parent
ROOT=OUT.parents[2]
def git(*args): return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
runtime=[p for p in git('ls-files','godot','game','server','port/contracts','tools/godot-export').splitlines() if not p.startswith(('godot/tests/protocol/lobby_independent_','godot/tests/protocol/lobby_followup_'))]
assert not git('diff','f7626397a142e44409e5d2466eb506bb8ae419ac','--',*runtime),'Runtime drift from tested UI fix'
binary=pathlib.Path('/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')
data={'followupBase':'0cc3b8e30095afe98816ea3a8143b84261ee7fce','runtimeFix':'f7626397a142e44409e5d2466eb506bb8ae419ac','captureHead':'c8c1513059972adf31b2e453903f16401fac2a1a','binary':{'path':str(binary),'sha256':sha(binary)},'dependencies':str((ROOT/'node_modules').resolve()),'runtimeHashes':{p:sha(ROOT/p) for p in runtime},'generatedHashes':{str(p.relative_to(ROOT)):sha(p) for p in (ROOT/'godot/content/generated').rglob('*') if p.is_file()},'newTests':{str(p.relative_to(ROOT)):sha(p) for p in (ROOT/'godot/tests/protocol').glob('lobby_followup_*')},'inventory':{str(p.relative_to(ROOT)):sha(p) for p in OUT.rglob('*') if p.is_file() and p.name!='provenance.json' and '__pycache__' not in str(p)}}
(OUT/'provenance.json').write_text(json.dumps(data,indent=2)+'\n')
print(json.dumps({'runtimeFiles':len(runtime),'newTests':len(data['newTests']),'evidenceFiles':len(data['inventory']),'runtimeDrift':False}))
