"""Fail-closed checks of serialized execution operands, not a physics oracle.

evidence.gd mirrors this contract for prelaunch predecessor checks. Numeric JSON
integers/floats are accepted; booleans never stand in for numbers.
"""
import math,re,datetime
IDS=['ceiling-up','overhang-forward','height-025','height-030','height-031','height-guard','narrow-width','narrow-depth','hole','pit','lateral','no-input','airborne','jumping','tilted-body','transformed-parent','moving-floor']
REASONS=[['up_blocked_or_lateral_recovery'],['raised_path_blocked']]+[['not_low_riser_band','strict_surface_rise_limit']]*4+[['unsupported_or_narrow_landing']]*2+[['no_continuous_flat_landing'],['no_bounded_riser','no_flat_static_base_support'],['lateral_wall_or_corner','multiple_obstacles'],['no_input'],['not_stationary_grounded_intent'],['not_stationary_grounded_intent'],['non_yaw_rotation'],['transformed_parent'],['moving_platform','no_flat_static_base_support']]
def num(x):return type(x) in (int,float) and math.isfinite(x)
def integer(x):return num(x) and x==int(x)
def near(x,y,e=1e-6):return num(x) and num(y) and abs(x-y)<=e
def vec(x,n=3):return isinstance(x,list) and len(x)==n and all(num(v) for v in x)
def distance(a,b):return math.sqrt(sum((x-y)**2 for x,y in zip(a,b))) if vec(a,len(b)) else math.inf
def origin(s):return s['transform']['origin']
def state(s):
    return isinstance(s,dict) and vec(origin(s)) and vec(s['velocity']) and type(s['grounded']) is bool and near(s['resetCount'],1,0)
def canonical(group):
    if group=='negative-controls':return [{'id':id,'radius':r} for id in IDS for r in [.35,.42]]
    return [{'id':str(r)+':'+str(deg),'radius':r,'yaw':math.radians(deg),'incline':47.0 if group=='inclined-landing-rejections' else 0.0,'start':-1.0,'goal':1.0,'maxResponses':240} for r in [.35,.42] for deg in [-45.0,45.0]]
def spec_equal(a,b):
    return isinstance(a,dict) and set(a)==set(b) and all(near(a[k],v,1e-12) if num(v) else a[k]==v for k,v in b.items())
def footprint(s,spec):
    if not state(s):return False
    x,y,z=origin(s);yaw=spec['yaw'];along=math.sin(yaw)*x+math.cos(yaw)*z
    return spec['radius']+.02<=along<=3-spec['radius']-.02 and abs(math.cos(yaw)*x-math.sin(yaw)*z)<=2-spec['radius']-.02 and s['grounded'] is True and abs(y-.15)<=.0201
def support(q,rid):
    return isinstance(q,dict) and q.get('hit') is True and q.get('validResult') is True and isinstance(q.get('contacts'),list) and 0<len(q['contacts'])<32 and all(near(c.get('colliderRid'),rid,0) and near(c.get('colliderShape'),0,0) and near(c.get('localShape'),0,0) and vec(c.get('point')) and abs(c['point'][1]-.15)<=1e-6 and vec(c.get('normal')) and c['normal'][1]>=math.cos(math.radians(46)) and distance(c.get('velocity'),[0,0,0])<=1e-6 for c in q['contacts'])
def witness(plan):
    return any(s.get('name')=='intent' and s.get('hit') is True and s.get('validResult') is True and isinstance(s.get('contacts'),list) and len(s['contacts'])>0 for s in plan['stages'])
def negative_stages(plan,id):
    reason=plan['reason'];required=['current-support','intent']
    if id=='ceiling-up':required+=['up']
    if id=='overhang-forward':required+=['up','forward']
    if id not in IDS[:11] and reason!='no_bounded_riser':return True
    if id=='pit' and reason=='no_flat_static_base_support':return plan['stages']==[]
    if [s.get('name') for s in plan['stages']]!=required:return False
    for s in plan['stages']:
        if s.get('validResult') is not True or type(s.get('hit')) is not bool or not near(s.get('maxCollisions'),32,0) or not near(s.get('margin'),.02) or not vec(s.get('motion')) or not vec(s.get('travel')) or not vec(s.get('remainder')) or not vec(s['from'].get('origin')):return False
        if not num(s.get('safeFraction')) or not num(s.get('unsafeFraction')) or not 0<=s['safeFraction']<=s['unsafeFraction']<=1 or not isinstance(s.get('contacts'),list):return False
    ground,intent=plan['stages'][:2]
    if ground['hit'] is not True or not any(vec(c.get('normal')) and c['normal'][1]>=math.cos(math.radians(46)) for c in ground['contacts']):return False
    if id in ['ceiling-up','overhang-forward','narrow-width','narrow-depth','hole']:
        if not any(vec(c.get('point')) and 0<c['point'][1]<.25 and vec(c.get('normal')) and c['normal'][2]<0 and math.hypot(c['normal'][0],c['normal'][2])>0 and -c['normal'][2]/math.hypot(c['normal'][0],c['normal'][2])>=.98 for c in intent['contacts']):return False
    return True
def target(p,spec):
    t=p['target'];direction=[math.sin(spec['yaw']),0,math.cos(spec['yaw'])]
    if not integer(p.get('targetRid')) or p['targetRid']<=0 or not near(p.get('targetShape'),0,0) or not near(t.get('rid'),p['targetRid'],0) or not near(t.get('shape'),0,0) or not isinstance(t.get('path'),str) or not t['path']:return False
    if distance(t.get('direction'),direction)>1e-6 or not vec(t.get('normal')) or not near(t['normal'][1],math.cos(math.radians(spec['incline']))):return False
    points=[[-2,.15,0],[-2,.15+3*math.tan(math.radians(spec['incline'])),3],[2,.15+3*math.tan(math.radians(spec['incline'])),3],[2,.15,0]]
    faces=[[math.cos(spec['yaw'])*x+math.sin(spec['yaw'])*z,y,-math.sin(spec['yaw'])*x+math.cos(spec['yaw'])*z] for x,y,z in [points[i] for i in [0,1,2,0,2,3]]]
    if not isinstance(t.get('faces'),list) or len(t['faces'])!=6 or any(distance(a,b)>1e-6 for a,b in zip(t['faces'],faces)):return False
    return any(near(g.get('rid'),p['targetRid'],0) and g.get('name')==('InclinedLanding' if spec['incline'] else 'PositiveTread') for g in p['geometry'])
def inclined_witness(plan,t):
    for s in plan['stages']:
        if s.get('name')!='intent' or s.get('hit') is not True or s.get('validResult') is not True:continue
        for c in s.get('contacts',[]):
            if c.get('collider')!=t['path'] or not near(c.get('colliderShape'),0,0) or not vec(c.get('point')) or not 0<c['point'][1]<.25 or not vec(c.get('normal')):continue
            n=c['normal'];length=math.hypot(n[0],n[2])
            if length>0 and -(n[0]*t['direction'][0]+n[2]*t['direction'][2])/length>=.98:return True
    return False
def guarded(row,p):
    plan=row['proposal'];g=plan['responseGuard'];t=row['telemetry']
    if g.get('reason')!='endpoint_and_pinned_clear_branch_and_live_support_agree' or not near(g.get('epsilon'),1e-6,0) or not near(g.get('slideCount'),0,0) or g.get('observedSlides')!=[]:return False
    if distance(g.get('actualFinal'),origin(row['after']))>1e-6 or distance(g.get('expectedFinal'),plan['expectedFinal'])>1e-6:return False
    if t.get('beforePlanning')!=row['before'] or t.get('afterPlanning')!=row['before'] or t.get('afterParent')!=row['after'] or t.get('beforeParent')!=t['upAfter']:return False
    if t.get('upCollisionReturned') is not False or t.get('upContacts')!=[] or t['upRequest'].get('before')!=row['before']:return False
    travel=[b-a for a,b in zip(origin(row['before']),origin(t['upAfter']))]
    if distance(t['actualUpTravel'],travel)>1e-6:return False
    q=g['support'];identities=t['finalSupportIdentities']
    if not isinstance(q.get('contacts'),list) or not isinstance(identities,list) or len(q['contacts'])!=len(identities):return False
    contacts=[]
    for c,identity in zip(q['contacts'],identities):
        if identity.get('ridResolved') is not True or not near(identity.get('colliderId'),c.get('colliderId'),0) or not near(identity.get('colliderShapeIndex'),c.get('colliderShape'),0) or not near(identity.get('localShapeIndex'),c.get('localShape'),0):return False
        contacts.append({**c,'colliderRid':identity.get('colliderRid')})
    return support({**q,'contacts':contacts},p['targetRid'])
def profile(p,spec,group,experimental):
    negative=group=='negative-controls';inclined=group=='inclined-landing-rejections'
    expected='expected_original_rejection_and_ordinary_response' if negative else 'expected_inclined_rejection_and_block' if inclined else 'full_tread_guarded_arrival' if experimental else 'expected_baseline_blocked'
    if p.get('outcome')!=expected or p.get('status')!='completed' or p.get('experimental') is not experimental:return False
    if p.get('reached') is not (not negative and not inclined and experimental):return False
    params=p['parameters']
    for key,value in [('margin',.02),('snap',.3),('floorAngle',math.radians(46)),('walk',6),('sprint',10),('gravity',20),('jump',6.5)]:
        if not near(params.get(key),value):return False
    if not near(params['shape'].get('radius'),spec['radius']) or not near(params['shape'].get('height'),1.8) or distance(params['offset']['origin'],[0,.9,0])>1e-6:return False
    if not isinstance(p.get('geometry'),list) or not p['geometry']:return False
    if not negative and not target(p,spec):return False
    settle=p['settle'];frames=p['frames'];settles=1 if negative and spec['id']=='airborne' else 20
    if not isinstance(settle,list) or len(settle)!=settles or not isinstance(frames,list):return False
    yaw=0 if negative else spec['yaw'];basis=[[math.cos(yaw),0,-math.sin(yaw)],[0,1,0],[math.sin(yaw),0,math.cos(yaw)]]
    actual_basis=settle[0]['before']['transform']['basis']
    if not isinstance(actual_basis,list) or len(actual_basis)!=3 or any(distance(a,b)>1e-6 for a,b in zip(actual_basis,basis)):return False
    if negative:
        if len(frames)!=(2 if spec['id']=='jumping' else 1):return False
    elif not 1<=len(frames)<=240:return False
    applied=verified=attempts=parents=0;stall=holds=inclined_hits=0;previous=None
    for i,row in enumerate(settle+frames):
        active=i>=settles;index=i-settles
        jump=negative and spec['id']=='jumping' and active and index==0
        input=[0,0] if not active or jump or negative and spec['id']=='no-input' else [2**-.5,-2**-.5] if negative and spec['id']=='lateral' else [0,-1]
        if row.get('returned') is not True or row.get('candidateFault')!='' or row.get('sprint') is not False or row.get('jump') is not jump or distance(row.get('input'),input)>1e-6:return False
        if not integer(row.get('frame')) or row['frame']<0 or previous is not None and row['frame']!=previous+1:return False
        previous=row['frame']
        if not near(row.get('actualDelta'),1/60,1e-8) or not near(row.get('physicsHz'),60,0) or not near(row.get('timeScale'),1,0) or not integer(row.get('usec')):return False
        if not state(row['before']) or not state(row['after']) or not vec(row.get('wholeFrameDelta')) or not isinstance(row.get('slides'),list):return False
        if distance(row['wholeFrameDelta'],[b-a for a,b in zip(origin(row['before']),origin(row['after']))])>1e-6:return False
        plan=row['proposal']
        if type(plan.get('accepted')) is not bool or not isinstance(plan.get('stages'),list):return False
        ordinary=True
        if experimental:
            life=row['lifecycle'];up=row['appliedUpCount'];parent=life['parentCalls'];accepted=life['originalProof']['accepted']
            if life.get('returned') is not True or not near(life.get('frame'),row['frame'],0) or not integer(up) or up not in (0,1) or not near(parent,1,0) or type(accepted) is not bool:return False
            ordinary=life.get('ordinary')
            if type(ordinary) is not bool or ordinary==accepted:return False
            if not accepted:
                if up!=0 or plan['accepted'] is not False or row.get('responseGuardPassed') is not False:return False
            else:
                if negative or inclined or up!=1 or plan['accepted'] is not True or row.get('responseGuardPassed') is not True or plan['responseGuard'].get('passed') is not True:return False
                t=row['telemetry']
                if t.get('finalSupportQueryReached') is not True or t['afterParent']!=t['afterGuard'] or not state(t['upAfter']) or not vec(t.get('actualUpTravel')) or t['actualUpTravel'][1]<=0:return False
                if not near(plan.get('supportRid'),p['targetRid'],0) or not near(plan.get('supportShape'),0,0) or not near(plan.get('landingY'),.15):return False
                if distance(plan.get('expectedFinal'),origin(row['after']))>1e-6:return False
                if not guarded(row,p):return False
                attempts+=1;verified+=1
            applied+=up;parents+=parent
            for key,value in [('totalAttempts',attempts),('totalApplied',applied),('totalVerified',verified),('totalParentCalls',parents)]:
                if not near(life.get(key),value,0):return False
        elif row.get('afterQueries')!=row['before']:return False
        if active:
            stall=stall+1 if distance(row['wholeFrameDelta'],[0,0,0])<.0001 else 0
            if inclined:
                if plan['accepted'] or plan.get('reason') not in ['no_bounded_riser','no_continuous_flat_landing']:return False
                if plan['reason']=='no_continuous_flat_landing':
                    if not inclined_witness(plan,p['target']):return False
                    inclined_hits+=1
            if not negative and not inclined:
                holds=holds+1 if ordinary and footprint(row['after'],spec) else 0
    if not near(p.get('appliedUpCount'),applied,0) or not near(p.get('verifiedLifts'),verified,0) or applied>math.ceil(2*spec['radius']/.1)+2:return False
    if negative:
        plan=frames[-1]['proposal'];reasons=REASONS[IDS.index(spec['id'])]
        if plan['accepted'] or plan.get('reason') not in reasons or p.get('expectedReasons')!=reasons or applied:return False
        if spec['id'] in IDS[:9] and not witness(plan):return False
        if not negative_stages(plan,spec['id']):return False
    elif inclined:
        if inclined_hits<1 or not near(p.get('inclinedWitnesses'),inclined_hits,0) or stall!=120 or applied:return False
    elif experimental:
        final=p['finalSupport'];last=frames[-1]['after'];pos=origin(last);along=math.sin(spec['yaw'])*pos[0]+math.cos(spec['yaw'])*pos[2]
        if verified<1 or verified!=applied or p.get('reached') is not True or holds<3 or along<spec['goal'] or not near(p.get('ordinaryLandingStreak'),holds,0):return False
        if not integer(p.get('targetRid')) or p['targetRid']<=0 or not near(p.get('targetShape'),0,0) or final.get('passed') is not True or final.get('footprintInside') is not True or final.get('reason')!='full_footprint_and_fresh_target_support':return False
        if final.get('bodyBefore')!=last or final.get('bodyAfter')!=last or not near(final.get('epsilon'),1e-6,0) or not support(final.get('query'),p['targetRid']):return False
    else:
        pos=origin(frames[-1]['after']);along=math.sin(spec['yaw'])*pos[0]+math.cos(spec['yaw'])*pos[2]
        if stall!=120 or p.get('reached') is not False or applied or along>=spec['goal']:return False
    if not negative and not near(p.get('stallCount'),stall,0):return False
    return True
def campaign(r,group):
    try:
        if r.get('outcome')!=('negative_control_group_pass' if group=='negative-controls' else 'synthetic_group_pass'):return False
        expected=canonical(group)
        if len(r['records'])!=len(expected):return False
        for row,spec in zip(r['records'],expected):
            if not spec_equal(row.get('spec'),spec):return False
            for j,p in enumerate(row['profiles']):
                if not profile(p,spec,group,bool(j)):return False
            if group!='positive-step-admission':
                a,b=row['profiles'];aa=a['settle']+a['frames'];bb=b['settle']+b['frames']
                if len(aa)!=len(bb):return False
                for x,y in zip(aa,bb):
                    if distance(origin(x['after']),origin(y['after']))>1e-6 or distance(x['after']['velocity'],y['after']['velocity'])>1e-6 or x['after']['grounded']!=y['after']['grounded']:return False
        return True
    except (KeyError,TypeError,ValueError,IndexError,AttributeError,OverflowError):return False
def supervisor_ok(s,group,source,grant,engine,native_hash):
    try:
        for k,v in [('phase','parity-admission-synthetic-v1'),('mode','synthetic-controls'),('group',group),('sourceSha256',source),('grantSha256',grant),('engineSha256',engine),('nativeReceiptSha256',native_hash)]:
            if s.get(k)!=v:return False
        for k,v in [('failed',False),('releasedCleanly',True),('partialCountersMayBeUnknown',False),('nativeStepAdmission',False),('productionPromotion',False),('positiveAdmission',group=='positive-step-admission')]:
            if s.get(k) is not v:return False
        if not near(s.get('returnCode'),0,0) or s.get('scope')!='synthetic-admission':return False
        if s.get('nativeOutcome')!=('negative_control_group_pass' if group=='negative-controls' else 'synthetic_group_pass'):return False
        for key in ['stopReason','supervisorError','invalidNativeReceipt']:
            if s.get(key) not in (None,'') or isinstance(s.get(key),bool):return False
        if s.get('cleanupErrors',[])!=[]:return False
        owned=s['owned']
        if any(not integer(owned.get(k)) or owned[k]<=0 for k in ['pid','pgid','startTicks']) or owned['pid']!=owned['pgid']:return False
        start=s['lockAcquiredUnix'];end=s['lockReleasePendingUnix']
        if not num(start) or not num(end) or start<=0 or end<=start:return False
        audits=s['releaseAudits']
        if not isinstance(audits,list) or len(audits)!=3:return False
        previous=start
        for a in audits:
            if a.get('measured') is not True or a.get('members')!=[] or a.get('error') not in (None,''):return False
            text=a['utc']
            if not isinstance(text,str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}\+00:00',text):return False
            instant=datetime.datetime.fromisoformat(text).timestamp()
            if not previous<instant<=end:return False
            previous=instant
        return True
    except (KeyError,TypeError,ValueError,AttributeError,OverflowError):return False
