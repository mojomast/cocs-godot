"""Complete, deliberately synthetic operand fixtures; never native evidence."""
from copy import deepcopy as copy
from policy import *
SOURCE='a'*64;GRANT='b'*64;DEPS='c'*64
def pose(pos,b=IDENTITY):return {'origin':list(pos),'basis':copy(b)}
def params(s):
    return dict(radius=s['radius'],height=1.8,margin=.02,snap=.3,floorAngle=ANGLE,walk=6,sprint=10,gravity=20,jump=6.5,layer=1,mask=1,motionMode=0,maxSlides=6,wallMinSlideAngle=math.radians(15),platformFloorLayers=4294967295,platformWallLayers=0,platformOnLeave=0,floorStopOnSlope=True,floorConstantSpeed=False,floorBlockOnWall=True,slideOnCeiling=True,exceptions=[],up=[0,1,0],offset=pose([0,.9,0]),bodyRid=100,shapeRid=101)
def geo(s):
    f=faces(s);lo=[min(v[i] for v in f) for i in range(3)];hi=[max(v[i] for v in f) for i in range(3)]
    base=dict(rid=200,shapeRid=201,shape=0,path='/root/Base',type='BoxShape3D',transform=pose([0,0,0]),offset=pose([0,-.5,0]),layer=1,mask=1,velocity=[0,0,0],angularVelocity=[0,0,0],size=[20,1,20])
    target=dict(rid=300,shapeRid=301,shape=0,path='/root/Target',type='ConcavePolygonShape3D',transform=pose([0,0,0]),offset=pose([0,0,0]),layer=1,mask=1,velocity=[0,0,0],angularVelocity=[0,0,0],faces=f,backface=True,plane=s['rise'],aabb=dict(position=lo,size=sub(hi,lo)))
    return dict(base=base,target=target)
def st(pos,s,delta=None):
    delta=delta or [0,0,0]
    return dict(transform=pose(pos,basis(s)),velocity=[0,0,0],grounded=True,floorNormal=[0,1,0],onWall=False,onCeiling=False,platformVelocity=[0,0,0],platformAngularVelocity=[0,0,0],slideCount=0,lastMotion=delta,parentDelta=delta,realVelocity=[x*60 for x in delta],resetCount=1)
def ct(g,role,point,normal):return dict(rid=g[role]['rid'],path=g[role]['path'],shape=0,localShape=0,point=point,normal=normal,velocity=[0,0,0],depth=0)
def sample(s,p,g,before,along,y,frame,moving,witness=False,target=False):
    d=direction(s);pos=[along*d[0],y,along*d[2]];delta=sub(pos,before['transform']['origin']);a=st(pos,s,delta);slides=[]
    if witness:
        a['slideCount']=1;a['onWall']=True
        n=[-d[0]*math.sin(math.radians(51.306892)),math.cos(math.radians(51.306892)),-d[2]*math.sin(math.radians(51.306892))]
        c=ct(g,'target',[0,s['rise'],0],n);slides=[c|dict(slideIndex=0,contactIndex=0,travel=[0,0,0],remainder=[d[0]*.1,0,d[2]*.1])]
    contacts=[ct(g,'target' if target else 'base',[pos[0],s['rise'] if target else 0,pos[2]],[0,1,0])]
    if witness:contacts.append({k:v for k,v in slides[0].items() if k not in ['slideIndex','contactIndex','travel','remainder']})
    q=dict(before=copy(a),after=copy(a),bodyRid=p['bodyRid'],**{'from':copy(a['transform'])},motion=[0,-.0201,0],margin=.02,maxCollisions=32,recoveryAsCollision=True,collideSeparationRay=True,excludeBodies=[],excludeObjects=[],hit=True,safeFraction=0,unsafeFraction=0,travel=[0,0,0],remainder=[0,-.0201,0],count=len(contacts),contacts=contacts)
    return dict(frame=frame,usec=frame*16667,delta=1/60,physicsHz=60,timeScale=1,inPhysicsFrame=True,parameters=copy(p),before=copy(before),after=a,wholeDelta=delta,slides=slides,support=q,input=[0,-1] if moving else [0,0],requestedMotion=[x*.1 for x in d] if moving else [0,0,0],jump=False,sprint=False,returned=True,parentCalls=1)
def make_profile(index,outcome):
    s=copy(MATRIX[index]);p=params(s);g=geo(s);d=direction(s);before=st([-d[0],.05,-d[2]],s)
    rows=[];frame=1
    for _ in range(20):
        r=sample(s,p,g,before,-1,.0166667,frame,False);rows.append(r);before=r['after'];frame+=1
    inputs=[];landing=blocked=0
    # Moving approach then sustained evidence; never empty or summary-only fixtures.
    for i in range(240):
        if outcome=='arrived':along=min(-.9+i*.1,1.1);target=along>=.5;y=s['rise']+.016 if target else .0166667;w=False
        else:along=min(-.9+i*.1,-.3);target=False;y=.0166667;w=outcome=='blocked_with_target_witness' and i>=7
        r=sample(s,p,g,before,along,y,frame,True,w,target);inputs.append(r);before=r['after'];frame+=1
        l,b,along,_=row(r,p,g,s,True);landing=landing+1 if l else 0;blocked=blocked+1 if b else 0
        if (landing>=3 and along>=1) or blocked>=120:break
    return dict(caseIndex=index,spec=s,experimental=False,parameters=p,geometry=g,settle=rows,frames=inputs,status='completed',outcome=outcome,landingStreak=landing,blockedStreak=blocked)
def receipt(outcomes=None):
    outcomes=outcomes or ['blocked_with_target_witness']*2+['arrived','unresolved_at_cap']+['blocked_with_target_witness']*4
    profiles=[make_profile(i,o) for i,o in enumerate(outcomes)]
    return dict(phase=PHASE,mode=MODE,group=GROUP,sourceSha256=SOURCE,grantSha256=GRANT,engineSha256=ENGINE,dependenciesSha256=DEPS,startedUnix=100,finishedUnix=140,engine={'major':4,'minor':5,'patch':2},lineage={'AKManifestSha256':AK,'AKPositiveSha256':AK_RESULT,'role':'failed-positive-lineage-not-admission'},completedCharacterization=True,failed=False,outcome='collection_complete',candidateAdmission=False,nativeStepAdmission=False,productionPromotion=False,selectionQualified=False,backendImplementationVerified=False,parentInternalCallsTraced=False,selectedHeight=None,physicalCallCounts=None,candidateMapWalks=0,attemptedProfiles=8,completedProfiles=8,unrunProfiles=0,records=profiles,referenceAgreement=outcomes[:3]==['blocked_with_target_witness']*2+['arrived'],inputResponses=sum(len(p['frames']) for p in profiles),settleResponses=160)
