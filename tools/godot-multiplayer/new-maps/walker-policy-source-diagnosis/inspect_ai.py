"""Read-only AI data and targeted pinned-C++ semantic model; no engine runner."""
import hashlib,json,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
AI=ROOT.parent/'cocs-walker-parity-admission-ai'
STAGE=AI/'godot/tests/walker_parity_admission/parity-admission-ai-01'
sys.path.insert(0,str(HERE.parent/'walker-parity-admission'))
from policy import successful
from evidence import profile,canonical
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def typed_numeric_member(value,choices):
    # Targeted model of Array.find -> StringLikeVariantComparator -> hash_compare.
    # Not a general Godot interpreter; only finite numeric inputs used here.
    return any(type(value) is type(x) and value==x for x in choices)
def inspect():
    manifest=AI/'tools/godot-multiplayer/new-maps/walker-parity-admission-ai/evidence/artifact-inventory.json'
    assert sha(manifest)=='e9f57119b10ac400430573e59253d78e714832743855094013ecba57797abd96'
    inventory=json.loads(manifest.read_text());assert len(inventory['files'])==40
    for name,row in inventory['files'].items():
        p=AI/name;assert sha(p)==row['sha256'] and p.stat().st_size==row['bytes'],name
    for name in ['policy.gd','evidence.gd','driver.gd']:
        assert (ROOT/'godot/tests/walker_parity_admission'/name).read_bytes()==(STAGE/'tests/walker_parity_admission'/name).read_bytes()
    raw=(STAGE/'negative-controls-result.json').read_text()
    r=json.loads(raw);parsed=json.loads(raw,parse_int=float)
    bindings=[r[k] for k in ['sourceSha256','grantSha256','engineSha256']]
    assert successful(r,'negative-controls',*bindings) and successful(parsed,'negative-controls',*bindings)
    witnesses=[];profile_count=0;max_integer=0
    def integers(v):
        nonlocal max_integer
        if type(v) is int:max_integer=max(max_integer,abs(v))
        elif isinstance(v,dict):
            for x in v.values():integers(x)
        elif isinstance(v,list):
            for x in v:integers(x)
    integers(r)
    for i,(case,spec) in enumerate(zip(parsed['records'],canonical('negative-controls'))):
        for j,p in enumerate(case['profiles']):
            assert profile(p,spec,'negative-controls',bool(j));profile_count+=1
            if not j:continue
            for section in ['settle','frames']:
                for k,row in enumerate(p[section]):
                    up=row['appliedUpCount'];assert up==0.0
                    assert up in [0,1] and not typed_numeric_member(up,[0,1])
                    witnesses.append({'pointer':f'/records/{i}/profiles/{j}/{section}/{k}/appliedUpCount','jsonValue':up,'modeledParsedType':'FLOAT','literalElementTypes':['INT','INT'],'pythonMembership':True,'pinnedCppMembershipModel':False})
    return {'qualification':'SOURCE MODEL ONLY; native internal branch untraced','AIInventoryVerified':40,'AIManifestSha256':sha(manifest),'nativeReceiptSha256':sha(STAGE/'negative-controls-result.json'),'hostReplay':True,'hostAllNumbersDoubleReplay':True,'profilesHostPassed':profile_count,'modeledMembershipFailures':len(witnesses),'firstWitness':witnesses[0],'largestJSONIntegerMagnitude':max_integer,'allJSONIntegersBelow2pow53':max_integer<2**53,'sourceHashes':{n:sha(STAGE/'tests/walker_parity_admission'/n) for n in ['policy.gd','evidence.gd','driver.gd']},'finding':'Concrete source-level INT/FLOAT membership mismatch at evidence.gd:139. Predicts rejection after JSON parsing; does not measure the first executed native internal branch. No acceptance changes applied.'}
if __name__=='__main__':print(json.dumps(inspect(),indent=2))
