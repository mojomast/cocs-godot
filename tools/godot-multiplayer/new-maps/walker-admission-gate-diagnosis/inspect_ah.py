"""Offline source-model inspection of immutable AH; never invokes native code.

Python replay and binary64/calendar calculations are labelled separately from
unobserved GDScript execution. No Godot evaluator is implemented here.
"""
import datetime,hashlib,json,math,re,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
AH=Path('/home/mojo/.tmp-on-disk/cocs-walker-parity-admission-ah')
STAGE=AH/'godot/tests/walker_parity_admission/parity-admission-ah-01'
sys.path.insert(0,str(HERE.parent/'walker-parity-admission'))
from prepare import load,dependencies
from policy import successful,validate,PHASE,MODE,GROUPS
from evidence import supervisor_ok,profile,canonical,spec_equal
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def utc_microseconds(text):
    """Exact reference for the CURRENT +00:00 six-digit emitter schema only.
    Integer microseconds avoid rounding in the reference; not a runtime patch.
    """
    if not isinstance(text,str) or not re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{6}\+00:00',text):raise ValueError('exact UTC emitter schema')
    dt=datetime.datetime.fromisoformat(text);epoch=datetime.datetime(1970,1,1,tzinfo=datetime.timezone.utc);delta=dt-epoch
    return (delta.days*86400+delta.seconds)*1000000+delta.microseconds
def frozen_check():
    manifest=AH/'tools/godot-multiplayer/new-maps/walker-parity-admission-ah/evidence/artifact-inventory.json';inventory=load(manifest)
    assert len(inventory['files'])==42
    for n,row in inventory['files'].items():
        p=AH/n;assert sha(p)==row['sha256'] and p.stat().st_size==row['bytes'],n
    return sha(manifest)
def inspect():
    manifest=frozen_check();source=load(STAGE/'source.json');grant=load(STAGE/'grant.json')
    neg=load(STAGE/'negative-controls-result.json');sup=load(STAGE/'negative-controls-supervisor.json');inc=load(STAGE/'inclined-landing-rejections-supervisor.json');dep=load(STAGE/'inclined-landing-rejections-dependencies.json')
    source_hash=sha(STAGE/'source.json');grant_hash=sha(STAGE/'grant.json');engine_hash=inc['engineSha256']
    checks=[]
    def row(gate,status,basis):checks.append({'gate':gate,'status':status,'basis':basis})
    args=inc['argv'][inc['argv'].index('--')+1:];argdict=dict(a.split('=',1) for a in args)
    assert len(args)==len(argdict)==5 and argdict['--group']==GROUPS[1] and argdict['--mode']==MODE
    row('_initialize args count/keys/group/mode','data_pass','Actual archived argv: five unique reviewed keys; inclined group; synthetic-controls. No native branch trace.')
    assert not (STAGE/'inclined-landing-rejections-result.json').exists()
    row('_initialize output does not exist','archive_absent','Inclined result absent in frozen AH. No manufactured native receipt.')
    assert grant_hash==argdict['--grant-sha256'] and source_hash==grant['sourceSha256'] and engine_hash==grant['engineSha256']
    assert sha(Path(inc['argv'][0]))==engine_hash
    for at in [inc['lockAcquiredUnix'],inc['lockReleasePendingUnix']]:
        validate(grant,group=GROUPS[1],mode=MODE,grant_id=argdict['--grant-id'],source_hash=source_hash,engine_hash=engine_hash,now=at)
    row('run grant hash/schema/phase/group/binary/expiry','host_pass','Both historical invocation endpoints precede expiry; exact CLI/file SHA binding. Grant is now released, not reusable.')
    assert source['phase']==PHASE and source['mode']==MODE and source['order']==GROUPS
    assert len(source['files'])==17
    for n,h in source['files'].items():assert n.startswith('res://') and '..' not in n and sha(STAGE/n[6:])==h,n
    row('run source schema/order and17 file hashes','bytes_pass','Actual16 scripts + project bytes match SHA values in frozen source.json; no dict reserialization hashing.')
    assert sha(STAGE/'inclined-landing-rejections-dependencies.json')==argdict['--dependencies-sha256']
    expected=dependencies(STAGE,GROUPS[1],source_hash,grant_hash,engine_hash)
    assert dep==expected
    row('predecessors dependency hash/bindings/count/member/native+supervisor hashes','host_pass','Actual dependency JSON equals strict reader reconstruction and contains exactly negative-controls.')
    assert successful(neg,GROUPS[0],source_hash,grant_hash,engine_hash)
    floating=json.loads((STAGE/'negative-controls-result.json').read_text(),parse_int=float)
    assert successful(floating,GROUPS[0],source_hash,grant_hash,engine_hash)
    row('Policy.successful top-level counters/roles/census','host_pass','Actual receipt and all-JSON-numbers-as-double Python model both pass. This is not Godot evaluation.')
    profiles=[]
    for case,spec in zip(neg['records'],canonical(GROUPS[0])):
        assert spec_equal(case['spec'],spec)
        for j,p in enumerate(case['profiles']):
            assert profile(p,spec,GROUPS[0],bool(j))
            profiles.append({'caseIndex':case['caseIndex'],'fixture':spec['id'],'radius':spec['radius'],'experimental':bool(j),'settles':len(p['settle']),'inputs':len(p['frames']),'terminalReason':p['frames'][-1]['proposal']['reason'],'pythonProfile':True})
    row('Evidence.campaign/profile all34x2; selected paired state agreement','host_pass','All68 profiles satisfy current Python parameter/clock/state/lifecycle/stage predicates; serialized-number model also passes. GD arithmetic/equality not executed.')
    assert supervisor_ok(sup,GROUPS[0],source_hash,grant_hash,engine_hash,sha(STAGE/'negative-controls-result.json'))
    row('Evidence.supervisor_ok bindings/flags/errors/return/owned/interval','host_pass','Actual negative supervisor passes strict host check; return0, failedfalse, releaseclean, positiveAdmissionfalse, no failure fields.')
    audits=[];previous=sup['lockAcquiredUnix'];last_us=None
    for a in sup['releaseAudits']:
        text=a['utc'];micros=utc_microseconds(text)
        whole=datetime.datetime.strptime(text[:19],'%Y-%m-%dT%H:%M:%S').replace(tzinfo=datetime.timezone.utc)
        seconds=int(whole.timestamp());instant=seconds+float('0.'+text[20:26])
        assert whole.strftime('%Y-%m-%dT%H:%M:%S')==text[:19]
        assert previous<instant<=sup['lockReleasePendingUnix'] and a['measured'] is True and a['members']==[]
        audits.append({'utc':text,'wholeEpochSeconds':seconds,'integerMicroseconds':micros,'binary64Reconstruction':instant,'gapMicroseconds':None if last_us is None else micros-last_us,'binary64UlpMicroseconds':math.ulp(instant)*1e6,'withinRecordedLockInterval':True})
        previous=instant;last_us=micros
    row('Evidence.supervisor_ok timestamp format/round-trip/fraction/order','source_model_pass','Staged GD explicitly adds parsed six-digit fraction. Valid UTC calendar source model yields distinct epochs, strict ordering and interval containment. Not a measured GD result.')
    row('actual native rejecting predicate','unobserved','Engine exit2; banner only; no native receipt/label. No unique branch or cause established by this offline inspection.')
    return {'status':'SOURCE ONLY; no native engine or GDScript execution','base':'5b01702e','AHManifestSha256':manifest,'AHInventoryVerified':42,'parentAHApproval':{'helpers':'58138256','analysis':'d1aa4b63','evidence':'dcda8780'},'bindings':{'sourceSha256':source_hash,'grantSha256':grant_hash,'engineSha256':engine_hash,'negativeNativeSha256':sha(STAGE/'negative-controls-result.json'),'negativeSupervisorSha256':sha(STAGE/'negative-controls-supervisor.json'),'inclinedDependenciesSha256':sha(STAGE/'inclined-landing-rejections-dependencies.json')},'gateTable':checks,'profileChecks':profiles,'auditSourceModel':audits,'expiryUnix':grant['expiresUnix'],'inclinedInvocationUnix':[inc['lockAcquiredUnix'],inc['lockReleasePendingUnix']],'conclusion':'No concrete cross-language rejection established. Fraction-truncation/collapse hypothesis unsupported by actual staged source and timestamps. Add diagnostic stderr at silent admission gates without changing predicates.','accounting':'AH inclined internal attempted/completed/failed/interrupted/call counts remain unknown; zero instrumented completion is not an internal zero count. Positive4/8 remains unrun.','newNativeGrant':None,'freshSourceRequiresFreshGrantAndNegativeRerun':True}
if __name__=='__main__':print(json.dumps(inspect(),indent=2))
