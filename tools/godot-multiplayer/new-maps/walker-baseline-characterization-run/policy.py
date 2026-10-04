"""Strict offline replay of the baseline-only v1 receipt. No execution authority."""
import math,re
PHASE='baseline-characterization-v1';MODE='baseline-only';GROUP='radius-rise'
ENGINE='5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae'
AK='827dd68b00c400b7ec17f9ab0e5a2067929277c3bb22e1681d38a1d5143a5ee1'
AK_RESULT='76130effe1da05bfc800fa8e14bea5b0382b87b130899a3cc1b52e2dab9bb6d7'
MATRIX=[{'radius':r,'rise':h,'yawDegrees':y} for r,h in [(.35,.15),(.42,.15),(.42,.18),(.42,.20)] for y in [-45,45]]
KEYS={'phase','mode','allowedGroups','grantId','authorized','expiresUnix','sourceSha256','engineSha256'}
EPS=1e-6;ANGLE=math.radians(46);ENGINE_ANGLE=ANGLE+.01
OUTCOMES=('arrived','blocked_with_target_witness','unresolved_at_cap')
FAULTS=('clock','parameters','state','query_mutation','not_settled','internal_timeout','receipt_validation','geometry')
def number(x):return type(x) in (int,float) and math.isfinite(x)
def integer(x):return number(x) and x==int(x)
def count(x,n):return integer(x) and x==n
def hash_valid(x):return isinstance(x,str) and re.fullmatch('[a-f0-9]{64}',x) is not None
def need(x,why):
    if not x:raise ValueError(why)
def close(a,b,e=EPS):return number(a) and number(b) and abs(a-b)<=e
def vec(v):return isinstance(v,list) and len(v)==3 and all(number(x) for x in v)
def near(a,b,e=EPS):return vec(a) and vec(b) and all(close(x,y,e) for x,y in zip(a,b))
def length(a):return math.sqrt(sum(x*x for x in a))
def sub(a,b):return [x-y for x,y in zip(a,b)]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def direction(s):return [math.sin(math.radians(s['yawDegrees'])),0,math.cos(math.radians(s['yawDegrees']))]
def basis(s):
    t=math.radians(s['yawDegrees']);return [[math.cos(t),0,-math.sin(t)],[0,1,0],[math.sin(t),0,math.cos(t)]]
IDENTITY=[[1,0,0],[0,1,0],[0,0,1]]
def transform(t,b=None):
    need(isinstance(t,dict) and set(t)=={'origin','basis'} and vec(t['origin']) and len(t['basis'])==3 and all(vec(v) for v in t['basis']),'transform')
    if b is not None:need(all(near(a,c) for a,c in zip(t['basis'],b)),'basis')
def validate(g,*,group,mode,grant_id,source_hash,engine_hash,now):
    need(isinstance(g,dict) and set(g)==KEYS,'grant schema')
    need(g['phase']==PHASE and g['mode']==mode==MODE and group==GROUP and g['allowedGroups']==[GROUP],'grant scope')
    need(g['authorized'] is True and isinstance(grant_id,str) and 0<len(grant_id)<=128 and g['grantId']==grant_id,'grant identity')
    need(number(now) and number(g['expiresUnix']) and g['expiresUnix']>now,'grant expiry')
    need(hash_valid(source_hash) and g['sourceSha256']==source_hash and engine_hash==ENGINE and g['engineSha256']==engine_hash,'grant binding')
def parameters(p,s):
    expected={'radius':s['radius'],'height':1.8,'margin':.02,'snap':.3,'floorAngle':ANGLE,'walk':6,'sprint':10,'gravity':20,'jump':6.5,'layer':1,'mask':1,'motionMode':0,'maxSlides':6,'wallMinSlideAngle':math.radians(15),'platformFloorLayers':4294967295,'platformWallLayers':0,'platformOnLeave':0}
    need(all(close(p.get(k),v) for k,v in expected.items()),'parameters')
    need(all(count(p.get(k),expected[k]) for k in ['layer','mask','motionMode','maxSlides','platformFloorLayers','platformWallLayers','platformOnLeave']),'integer parameters')
    need(p.get('floorStopOnSlope') is True and p.get('floorConstantSpeed') is False and p.get('floorBlockOnWall') is True and p.get('slideOnCeiling') is True and p.get('exceptions')==[],'flags')
    need(near(p.get('up'),[0,1,0]),'up');transform(p['offset'],IDENTITY);need(near(p['offset']['origin'],[0,.9,0]),'offset')
    for k in ['bodyRid','shapeRid']:need(integer(p[k]) and p[k]>0,'RID')
def faces(s):
    d=direction(s);right=[d[2],0,-d[0]]
    def v(x,z):return [right[0]*x+d[0]*z,s['rise'],right[2]*x+d[2]*z]
    a,b,c,dv=v(-2,0),v(-2,3),v(2,3),v(2,0)
    return [a,b,c,a,c,dv]
def geometry(g,s):
    need(isinstance(g,dict) and set(g)=={'base','target'},'geometry')
    for role in ['base','target']:
        o=g[role];need(integer(o['rid']) and o['rid']>0 and integer(o['shapeRid']) and o['shapeRid']>0,'geometry RID')
        need(count(o['shape'],0) and count(o['layer'],1) and count(o['mask'],1) and isinstance(o['path'],str) and o['path'],'geometry identity')
        transform(o['transform'],IDENTITY);need(near(o['transform']['origin'],[0,0,0]),'world transform')
        need(near(o['velocity'],[0,0,0]) and near(o['angularVelocity'],[0,0,0]),'static')
        transform(o['offset'],IDENTITY)
    need(g['base']['rid']!=g['target']['rid'] and g['base']['shapeRid']!=g['target']['shapeRid'],'distinct geometry')
    b=g['base'];need(b['type']=='BoxShape3D' and near(b['size'],[20,1,20]) and near(b['offset']['origin'],[0,-.5,0]),'base geometry')
    t=g['target'];need(t['type']=='ConcavePolygonShape3D' and t['backface'] is True and near(t['offset']['origin'],[0,0,0]),'target geometry')
    f=faces(s);need(len(t['faces'])==6 and all(near(a,b) for a,b in zip(t['faces'],f)),'rise-derived vertices')
    lo=[min(v[i] for v in f) for i in range(3)];hi=[max(v[i] for v in f) for i in range(3)]
    need(near(t['aabb']['position'],lo) and near(t['aabb']['size'],sub(hi,lo)) and close(t['plane'],s['rise']),'rise-derived certificate')
def state(a,s):
    transform(a['transform'],basis(s));need(all(abs(x)<8 for x in a['transform']['origin']),'coordinate domain')
    for k in ['velocity','floorNormal','platformVelocity','platformAngularVelocity','lastMotion','parentDelta','realVelocity']:need(vec(a[k]),'state vector')
    need(near(a['platformVelocity'],[0,0,0]) and near(a['platformAngularVelocity'],[0,0,0]),'platform')
    for k in ['grounded','onWall','onCeiling']:need(type(a[k]) is bool,'state bool')
    need(count(a['resetCount'],1) and integer(a['slideCount']) and 0<=a['slideCount']<=6,'state counters')
    need(abs(dot(a['transform']['origin'],[direction(s)[2],0,-direction(s)[0]]))<=.0001,'centerline')
def contact(c,g):
    need(vec(c['point']) and vec(c['normal']) and close(length(c['normal']),1,1e-4) and vec(c['velocity']) and near(c['velocity'],[0,0,0]),'contact vectors')
    need(number(c['depth']) and c['depth']>=0 and count(c['localShape'],0) and count(c['shape'],0) and integer(c['rid']),'contact shape/depth')
    role=next((k for k in ['base','target'] if c['rid']==g[k]['rid']),None)
    need(role is not None and c['path']==g[role]['path'],'contact identity')
    if role=='target':
        f=g['target']['faces'];edge=sub(c['point'],f[0]);forward=[x/3 for x in sub(f[1],f[0])];right=[x/4 for x in sub(f[5],f[0])]
        need(abs(c['point'][1]-g['target']['plane'])<=EPS and -EPS<=dot(edge,forward)<=3+EPS and -EPS<=dot(edge,right)<=4+EPS,'target contact certificate')
    else:need(abs(c['point'][0])<=10+EPS and abs(c['point'][2])<=10+EPS and -1-EPS<=c['point'][1]<=EPS,'base contact certificate')
    return role
def support(q,a,p,g,s):
    need(q['before']==a==q['after'],'query mutation')
    need(q['bodyRid']==p['bodyRid'] and q['from']==a['transform'],'query actual transform')
    need(near(q['motion'],[0,-(p['margin']+.0001),0]) and close(q['margin'],p['margin']) and count(q['maxCollisions'],32),'query dimensions')
    need(q['recoveryAsCollision'] is True and q['collideSeparationRay'] is True and q['excludeBodies']==[] and q['excludeObjects']==[],'query flags')
    need(type(q['hit']) is bool and vec(q['travel']) and vec(q['remainder']) and number(q['safeFraction']) and number(q['unsafeFraction']) and 0<=q['safeFraction']<=q['unsafeFraction']<=1,'query result')
    cs=q['contacts'];need(isinstance(cs,list) and len(cs)<=32 and count(q['count'],len(cs)),'query contacts')
    roles=[contact(c,g) for c in cs]
    usable=q['hit'] and 0<len(cs)<32
    target=usable and all(k=='target' and c['normal'][1]>=math.cos(ANGLE) and abs(c['point'][1]-s['rise'])<=EPS for k,c in zip(roles,cs))
    # All contacts remain in evidence: steep target contacts do not constitute base support.
    walkable=[(k,c) for k,c in zip(roles,cs) if c['normal'][1]>=math.cos(ENGINE_ANGLE)]
    base=usable and bool(walkable) and all(k=='base' and near(c['normal'],[0,1,0]) and abs(c['point'][1])<=EPS for k,c in walkable)
    base=base and all(k=='base' or (k=='target' and c['normal'][1]<math.cos(ENGINE_ANGLE)) for k,c in zip(roles,cs))
    return bool(base),bool(target)
def row(r,p,g,s,moving):
    need(r['returned'] is True and count(r['parentCalls'],1) and r['input']==([0,-1] if moving else [0,0]) and all(number(x) for x in r['input']) and r['jump'] is False and r['sprint'] is False,'ordinary input')
    need(integer(r['frame']) and r['frame']>=0 and integer(r['usec']) and r['usec']>=0 and count(r['physicsHz'],60) and count(r['timeScale'],1) and close(r['delta'],1/60,1e-8) and r['inPhysicsFrame'] is True,'clock')
    need(near(r['requestedMotion'],[x*.1 for x in direction(s)] if moving else [0,0,0]),'requested ordinary intent')
    parameters(r['parameters'],s);need(r['parameters']==p,'parameter drift')
    state(r['before'],s);state(r['after'],s);a=r['after'];delta=sub(a['transform']['origin'],r['before']['transform']['origin'])
    need(near(r['wholeDelta'],delta) and near(a['parentDelta'],delta) and near(a['realVelocity'],[x/r['delta'] for x in delta],1e-5),'ordinary motion accounting')
    need(isinstance(r['slides'],list) and len(r['slides'])<=192,'slides cap')
    witness=False;d=direction(s);indices={}
    for c in r['slides']:
        role=contact(c,g);need(integer(c['slideIndex']) and 0<=c['slideIndex']<a['slideCount'] and integer(c['contactIndex']) and 0<=c['contactIndex']<32,'slide indices')
        need(vec(c['travel']) and vec(c['remainder']),'slide travel')
        indices.setdefault(c['slideIndex'],[]).append(c['contactIndex'])
        n=c['normal'];horizontal=math.hypot(n[0],n[2])
        if role=='target' and 0<c['point'][1]<.25 and n[1]<math.cos(ENGINE_ANGLE) and horizontal>0 and -(n[0]*d[0]+n[2]*d[2])/horizontal>=.98:witness=True
    need(sorted(indices)==list(range(int(a['slideCount']))) and all(v==list(range(len(v))) for v in indices.values()),'complete ordered slide census')
    base,target=support(r['support'],a,p,g,s)
    pos=a['transform']['origin'];along=dot(pos,d);lateral=abs(dot(pos,[d[2],0,-d[0]]));radius=p['radius'];margin=p['margin']
    footprint=radius+margin<=along<=3-radius-margin and lateral<=2-radius-margin
    landing=moving and a['grounded'] and footprint and abs(pos[1]-s['rise'])<=margin+.0001 and target
    blocked=moving and a['grounded'] and along<1 and length(delta)<.0001 and base and witness
    return bool(landing),bool(blocked),along,bool(base)
def profile(p,index):
    need(count(p['caseIndex'],index) and p['spec']==MATRIX[index] and all(number(x) for x in p['spec'].values()) and p['experimental'] is False,'canonical case')
    s=p['spec'];parameters(p['parameters'],s);geometry(p['geometry'],s)
    need(all(p['parameters']['bodyRid']!=p['geometry'][k]['rid'] and p['parameters']['shapeRid']!=p['geometry'][k]['shapeRid'] for k in ['base','target']),'distinct body')
    need(len(p['settle'])==20 and 1<=len(p['frames'])<=240,'response census')
    prev=None;landing=blocked=0;outcome=None
    for i,r in enumerate(p['settle']+p['frames']):
        l,b,along,base=row(r,p['parameters'],p['geometry'],s,i>=20)
        if prev is not None:need(r['frame']==prev['frame']+1 and r['usec']>prev['usec'] and r['before']==prev['after'],'consecutive state/clock')
        else:need(near(r['before']['transform']['origin'],[x*(-1) if j!=1 else .05 for j,x in enumerate(direction(s))]) and near(r['before']['velocity'],[0,0,0]),'spawn')
        if i==19:need(r['after']['grounded'] and base,'settled base')
        if i>=20:
            need(outcome is None,'continued after terminal classification')
            landing=landing+1 if l else 0;blocked=blocked+1 if b else 0
            if landing>=3 and along>=1:outcome='arrived'
            elif blocked>=120:outcome='blocked_with_target_witness'
        prev=r
    if outcome is None:need(len(p['frames'])==240,'premature unresolved');outcome='unresolved_at_cap'
    need(p['outcome']==outcome and p['status']=='completed' and count(p['landingStreak'],landing) and count(p['blockedStreak'],blocked),'profile classification')
    return outcome
def replay(r,source_hash,grant_hash,engine_hash):
    need(r['phase']==PHASE and r['mode']==MODE and r['group']==GROUP and r['sourceSha256']==source_hash and r['grantSha256']==grant_hash and r['engineSha256']==engine_hash==ENGINE,'receipt binding')
    need(all(hash_valid(h) for h in [source_hash,grant_hash,r['dependenciesSha256']]),'hash')
    need(number(r['startedUnix']) and number(r['finishedUnix']) and 0<r['startedUnix']<r['finishedUnix'],'receipt timestamps')
    need(all(count(r['engine'][k],n) for k,n in [('major',4),('minor',5),('patch',2)]),'engine version')
    need(r['lineage']=={'AKManifestSha256':AK,'AKPositiveSha256':AK_RESULT,'role':'failed-positive-lineage-not-admission'},'lineage')
    need(r['completedCharacterization'] is True and r['failed'] is False and r['outcome']=='collection_complete' and 'faultCode' not in r,'collection')
    for k in ['candidateAdmission','nativeStepAdmission','productionPromotion','selectionQualified','backendImplementationVerified','parentInternalCallsTraced']:need(r[k] is False,'non-admission')
    need(r['selectedHeight'] is None and r['physicalCallCounts'] is None and count(r['candidateMapWalks'],0),'no inferred calls/selection')
    need(count(r['attemptedProfiles'],8) and count(r['completedProfiles'],8) and count(r['unrunProfiles'],0) and len(r['records'])==8,'census')
    outcomes=[profile(p,i) for i,p in enumerate(r['records'])]
    need(type(r['referenceAgreement']) is bool and r['referenceAgreement']==(outcomes[:3]==['blocked_with_target_witness','blocked_with_target_witness','arrived']),'reference facts')
    need(count(r['inputResponses'],sum(len(p['frames']) for p in r['records'])) and count(r['settleResponses'],160),'total census')
    return outcomes
def successful(r,source_hash,grant_hash,engine_hash):
    try:replay(r,source_hash,grant_hash,engine_hash);return True
    except (KeyError,TypeError,ValueError,IndexError,OverflowError,AttributeError):return False
