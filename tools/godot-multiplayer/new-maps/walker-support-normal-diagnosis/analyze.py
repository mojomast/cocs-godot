"""Offline AM operands only. Never stages, imports GDScript or launches processes."""
import csv,hashlib,json,math
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
AM=ROOT.parent/'cocs-walker-calibrated-admission-am'
STAGE=AM/'godot/tests/walker_calibrated_admission/calibrated-admission-am-01'
MANIFEST='tools/godot-multiplayer/new-maps/walker-calibrated-admission-am/evidence/artifact-inventory.json'
MANIFEST_HASH='f86b2f6eff59b70fed653a80ca01ce2d590ee07214247317e8c1a89d0419a026'
NATIVE_HASH='779b00c88f53d6b4fcb9b171844769ffc2133e2d11c0bf3300419861b3a81a57'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):return json.loads(p.read_text())
def verify():
    p=AM/MANIFEST;assert sha(p)==MANIFEST_HASH and p.stat().st_size==13282
    rows=load(p)['files'];assert len(rows)==60
    for name,r in rows.items():
        f=AM/name;assert sha(f)==r['sha256'] and f.stat().st_size==r['bytes'],name
    assert sum(r['bytes'] for r in rows.values())==49983925
    assert sha(STAGE/'positive-step-admission-result.json')==NATIVE_HASH
    pins=load(ROOT/'tools/godot-multiplayer/new-maps/walker-calibrated-admission/review-pins.json')
    for group in ['stageInputs','hostInputs','productionDependencies','preservedInputs']:
        for n,h in pins[group].items():assert sha(ROOT/n)==h,n
    return {'AMEntries':60,'AMBytes':49983925,'manifestBytes':13282,'manifestSha256':MANIFEST_HASH,'currentControlledPinsUnchanged':True}
def angles(n):
    length=math.sqrt(sum(x*x for x in n));assert length>0 and all(math.isfinite(x) for x in n)
    return {'rawNormal':n,'length':length,'unitLengthError':abs(length-1),'rawUpDot':n[1],
        'rawDotAngleDegrees':math.degrees(math.acos(max(-1,min(1,n[1])))),
        'normalizedAngleDegrees':math.degrees(math.acos(max(-1,min(1,n[1]/length))))}
def query(label,q,profile,plan,identities=None):
    contacts=[]
    for i,c in enumerate(q['contacts']):
        rawrid=c.get('colliderRid');identity=identities[i] if identities else None
        contacts.append({'raw':c,'normalAnalysis':angles(c['normal']),
            'ridDirectlyRecorded':rawrid,'resolvedIdentityTelemetry':identity,
            'targetRid':profile['targetRid'],'targetShape':profile['targetShape'],
            'ridQualification':'direct query field' if rawrid is not None else 'separate post-query identity telemetry' if identity else 'not in legacy query serialization; same colliderId as bound parity contact, not an invented RID',
            'pointPlaneErrorCanonical':abs(c['point'][1]-profile['_rise']),
            'pointPlaneErrorPlan':abs(c['point'][1]-plan['landingY']),
            'staticVelocityExactlyZero':c['velocity']==[0,0,0]})
    # Conditional reconstruction from GodotPhysics source formula, not engine trace.
    residual=[q['travel'][i]-q['safeFraction']*q['motion'][i] for i in range(3)]
    sample=[q['from']['origin'][i]+residual[i]+q['unsafeFraction']*q['motion'][i] for i in range(3)]
    return {'label':label,'rawRequestResponse':q,'bodyContext':profile['parameters'],
        'contactAnalysis':contacts,'conditionalGodotPhysicsRecoveryResidual':residual,
        'conditionalGodotPhysicsRestSampleOrigin':sample,
        'conditionalOnly':'Assumes pinned GodotPhysics test_body_motion formula; active backend/internal calls untraced. Not an applied pose.'}
def analyze(native):
    result=[]
    for case in native['records']:
        p=case['profiles'][1];p={**p,'_rise':case['spec']['rise']}
        for x in p['frames']:
            if not x['appliedUpCount']:continue
            plan=x['proposal'];g=plan['responseGuard'];qp=plan['queryParity']
            qs=[query('original-down32',next(v for v in plan['stages'] if v['name']=='down'),p,plan),
                query('parity-short32',qp['short32'],p,plan),query('parity-full4',qp['parentSnap4'],p,plan),
                query('fresh-guard-down32',g['support'],p,plan,x['telemetry']['finalSupportIdentities'])]
            result.append({'caseIndex':case['caseIndex'],'spec':case['spec'],'frame':x['frame'],
                'parameters':p['parameters'],'target':p['target'],'planFrom':plan['from'],'raised':plan['raised'],
                'horizontalBudget':plan['horizontalBudget'],'originalExpectedFinal':plan['originalExpectedFinal'],
                'expectedFinal':plan['expectedFinal'],'actualFinal':g['actualFinal'],
                'endpointError':math.dist(g['actualFinal'],g['expectedFinal']),'epsilon':g['epsilon'],
                'guardPassed':g['passed'],'guardReason':g['reason'],'guardFromMatchesActual':g['support']['from']==x['after']['transform'],
                'actualParent':{'after':x['telemetry']['afterParent'],'floorNormalAnalysis':angles(x['after']['floorNormal']),
                    'beforeParent':x['telemetry']['beforeParent'],'wholeFrameDelta':x['wholeFrameDelta'],
                    'parentPositionDelta':x['after']['parentPositionDelta'],'parentRealVelocity':x['after']['parentRealVelocity'],
                    'internalSnapRequest':None,'qualification':'Returned API state only; full4 above is modeled read-only request, not a trace of internal snap'},
                'queries':qs,'preflightAtPredictedEndpointRecorded':False,
                'planeGuardReached':g['passed'],'planeErrorIsOfflineArithmetic':True,
                'reached':p['reached'],'appliedLifts':p['appliedUpCount'],'verifiedLifts':p['verifiedLifts']})
    return {'nativeSha256':NATIVE_HASH,'phase':native['phase'],'outcome':native['outcome'],
        'groupsQualification':'Negative and inclined passed; whole positive failed; last +45 pair unrun',
        'applications':result,'backendImplementationVerified':False,'physicalCallCounts':None}
def write_outputs():
    preservation=verify();r=analyze(load(STAGE/'positive-step-admission-result.json'))
    (HERE/'comparison.json').write_text(json.dumps(r,indent=2)+'\n')
    (HERE/'preservation.json').write_text(json.dumps(preservation,indent=2)+'\n')
    with (HERE/'operands.csv').open('w',newline='') as f:
        w=csv.writer(f,lineterminator='\n');w.writerow(['case','frame','query','origin','basis','motion','margin','recovery','rays','maxContacts','safe','unsafe','travel','remainder','rawContacts','normalAnalysis','identityQualification'])
        for a in r['applications']:
            for q in a['queries']:
                v=q['rawRequestResponse'];w.writerow([a['caseIndex'],a['frame'],q['label'],json.dumps(v['from']['origin']),json.dumps(v['from']['basis']),json.dumps(v['motion']),v['margin'],v['recoveryAsCollision'],v['collideSeparationRay'],v['maxCollisions'],v['safeFraction'],v['unsafeFraction'],json.dumps(v['travel']),json.dumps(v['remainder']),json.dumps(v['contacts']),json.dumps([c['normalAnalysis'] for c in q['contactAnalysis']]),json.dumps([c['ridQualification'] for c in q['contactAnalysis']])])
if __name__=='__main__':write_outputs()
