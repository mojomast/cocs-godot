"""Serialized, synthetic test operands. Never a native receipt or admission claim."""
import copy,math,json
from pathlib import Path
from functools import lru_cache
from .evidence import canonical,IDS,REASONS
@lru_cache()
def ag_record():
    root=Path(__file__).resolve().parents[4]
    return json.loads((root/'godot/tests/walker_parity_response/parity-response-ag-01/response-result.json').read_text())
def support_fixture(after,name,rise=.15):
    # Actual AG request format/parameters, with explicitly synthetic flat-contact
    # result and transformed origin. This is never native full-admission evidence.
    q=copy.deepcopy(ag_record()['records'][-1]['parityProposal']['responseGuard']['support'])
    q.update(name=name,bodyRid=200,excludeBodies=[],excludeObjects=[],**{'from':copy.deepcopy(after['transform'])},travel=[0,0,0],remainder=q['motion'].copy(),safeFraction=0.,unsafeFraction=0.)
    pos=after['transform']['origin']
    q['contacts']=[{'colliderRid':100,'colliderId':101,'colliderShape':0,'localShape':0,'point':[pos[0],rise,pos[2]],'normal':[0,1,0],'velocity':[0,0,0],'depth':0.}]
    return q
def state(pos):return {'transform':{'origin':pos,'basis':[[1,0,0],[0,1,0],[0,0,1]]},'velocity':[0,0,0],'grounded':True,'resetCount':1,'floorNormal':[0,1,0],'slideCount':0,'platformVelocity':[0,0,0],'platformAngularVelocity':[0,0,0],'lastMotion':[0,0,0],'parentPositionDelta':[0,0,0],'parentRealVelocity':[0,0,0]}
def campaign_fixture(group,source='s',grant='g',engine='e'):
    negative=group=='negative-controls';inclined=group=='inclined-landing-rejections'
    specs=canonical(group);n=len(specs)
    r={'phase':'parity-admission-calibrated-v1','mode':'calibrated-controls','group':group,'scope':'calibrated-admission','sourceSha256':source,'grantSha256':grant,'engineSha256':engine,'failed':False,'passed':True,'nativeStepAdmission':False,'productionPromotion':False,'positiveAdmission':not negative and not inclined,'attemptedPairs':n,'completedPairs':n,'passedPairs':n,'failedPairs':0,'interruptedPairs':0,'unrunPairs':0,'attemptedProfiles':2*n,'completedProfiles':2*n,'failedProfiles':0,'interruptedProfiles':0,'unrunProfiles':0,'candidateMapWalks':0,'records':[]}
    r['outcome']='negative_control_group_pass' if negative else 'synthetic_group_pass'
    for index,spec in enumerate(specs):
        pair={'caseIndex':index,'spec':spec,'status':'passed','profiles':[]};r['records'].append(pair)
        for experimental in [False,True]:
            positive=not negative and not inclined and experimental
            outcome='expected_original_rejection_and_ordinary_response' if negative else 'expected_inclined_rejection_and_block' if inclined else 'full_tread_guarded_arrival' if experimental else 'expected_baseline_blocked'
            p={'status':'completed','experimental':experimental,'outcome':outcome,'appliedUpCount':int(positive),'verifiedLifts':int(positive),'reached':positive,'settle':[],'frames':[],'stallCount':0 if positive else 120,'ordinaryLandingStreak':3 if positive else 0,'inclinedWitnesses':120 if inclined else 0,'geometry':[{'name':'ControlTread','rid':100}],
                'parameters':{'bodyRid':200,'shape':{'radius':spec['radius'],'height':1.8},'offset':{'origin':[0,.9,0]},'margin':.02,'snap':.3,'floorAngle':math.radians(46),'walk':6,'sprint':10,'gravity':20,'jump':6.5}}
            pair['profiles'].append(p);rise=spec.get('rise',.15);yaw=spec.get('yaw',0);direction=[math.sin(yaw),0,math.cos(yaw)]
            if not negative:
                back=rise+3*math.tan(math.radians(spec['incline']));vertices=[[-2,rise,0],[-2,back,3],[2,back,3],[2,rise,0]]
                faces=[[math.cos(yaw)*x+math.sin(yaw)*z,y,-math.sin(yaw)*x+math.cos(yaw)*z] for x,y,z in [vertices[k] for k in [0,1,2,0,2,3]]]
                p.update(targetRid=100,targetShape=0,target={'rid':100,'shape':0,'path':'/root/Tread','direction':direction,'normal':[-math.sin(math.radians(spec['incline']))*direction[0],math.cos(math.radians(spec['incline'])),-math.sin(math.radians(spec['incline']))*direction[2]],'faces':faces})
                p['geometry']=[{'name':'InclinedLanding' if inclined else 'PositiveTread','rid':100,'bodyTransform':state([0,0,0])['transform'],'offset':state([0,0,0])['transform'],'linearVelocity':[0,0,0],'shapeData':{'backface_collision':True,'faces':copy.deepcopy(faces)}}]
            else:p['expectedReasons']=REASONS[IDS.index(spec['id'])]
            settles=1 if negative and spec['id']=='airborne' else 20
            inputs=(2 if spec['id']=='jumping' else 1) if negative else 11 if positive else 120
            applied=0;pos=[0,0,0]
            for i in range(settles+inputs):
                active=i>=settles;tick=i-settles;jump=negative and spec['id']=='jumping' and active and tick==0
                intent=[0,0] if not active or jump or negative and spec['id']=='no-input' else [2**-.5,-2**-.5] if negative and spec['id']=='lateral' else [0,-1]
                before=state(pos.copy());up=positive and active and tick==0
                if positive and active:pos=[direction[0]*(.1+.1*tick),rise,direction[2]*(.1+.1*tick)]
                after=state(pos.copy());reason=REASONS[IDS.index(spec['id'])][0] if negative and active and not jump else 'no_continuous_flat_landing' if inclined and active else 'no_bounded_riser' if active else 'no_input'
                for s in [before,after]:s['transform']['basis']=[[math.cos(yaw),0,-math.sin(yaw)],[0,1,0],[math.sin(yaw),0,math.cos(yaw)]]
                normal=[-direction[0]*math.sin(math.radians(47)),math.cos(math.radians(47)),-direction[2]*math.sin(math.radians(47))]
                contact={'collider':'/root/Tread','colliderShape':0,'point':[0,.1,0],'normal':normal}
                plan={'accepted':bool(up),'reason':reason,'stages':[{'name':'intent','hit':True,'validResult':True,'contacts':[contact]}] if active else []}
                if negative and active and IDS.index(spec['id'])<11:
                    names=['current-support','intent']+(['up'] if spec['id']=='ceiling-up' else ['up','forward'] if spec['id']=='overhang-forward' else [])
                    plan['stages']=[{'name':name,'hit':name!='up' or spec['id']=='ceiling-up','validResult':True,'maxCollisions':32,'margin':.02,'from':before['transform'],'motion':[0,0,.1],'travel':[0,0,0],'remainder':[0,0,.1],'safeFraction':0,'unsafeFraction':0,'contacts':[{'point':[0,0,0],'normal':[0,1,0]}] if name=='current-support' else [copy.deepcopy(contact)]} for name in names]
                row={'frame':100+i,'usec':1000000+i*16667,'actualDelta':1/60,'physicsHz':60,'timeScale':1,'input':intent,'jump':jump,'sprint':False,'returned':True,'candidateFault':'','before':before,'after':after,'wholeFrameDelta':[b-a for a,b in zip(before['transform']['origin'],pos)],'slides':[],'proposal':plan}
                row.update(bodyRid=200,floorConstantSpeed=False)
                if not negative and not inclined and not experimental and active:
                    row['slides']=[{'colliderRid':100,'colliderShapeIndex':0,'point':[0,rise,0],'normal':[-direction[0]*math.sqrt(.75),.5,-direction[2]*math.sqrt(.75)]}]
                if experimental:
                    applied+=int(up)
                    row.update(appliedUpCount=int(up),responseGuardPassed=bool(up),lifecycle={'frame':100+i,'returned':True,'originalProof':copy.deepcopy(plan),'ordinary':not up,'parentCalls':1,'totalAttempts':applied,'totalApplied':applied,'totalVerified':applied,'totalParentCalls':i+1})
                    if up:
                        plan.update(responseGuard={'passed':True},supportRid=100,supportShape=0,landingY=rise,expectedFinal=pos.copy())
                        row['telemetry']={'finalSupportQueryReached':True,'afterParent':after,'afterGuard':after,'upAfter':state([0,.2,0]),'actualUpTravel':[0,.2,0]}
                        q=support_fixture(after,'actual-final-support',rise)
                        plan['responseGuard'].update(reason='endpoint_and_pinned_clear_branch_and_live_support_agree',epsilon=1e-6,slideCount=0,observedSlides=[],actualFinal=pos.copy(),expectedFinal=pos.copy(),support=q)
                        t=row['telemetry'];t.update(beforePlanning=before,afterPlanning=before,beforeParent=t['upAfter'],upCollisionReturned=False,upContacts=[],upRequest={'before':before},finalSupportIdentities=[{'ridResolved':True,'colliderId':101,'colliderRid':100,'colliderShapeIndex':0,'localShapeIndex':0}])
                        horizontal=[direction[0]*.1,0,direction[2]*.1]
                        after.update(lastMotion=horizontal.copy(),parentPositionDelta=[horizontal[0],rise-.2,horizontal[2]],parentRealVelocity=[horizontal[0]*60,(rise-.2)*60,horizontal[2]*60])
                        plan.update(horizontalBudget=horizontal,raised=copy.deepcopy(t['upAfter']['transform']),upMotion=[0,.2,0],actualWholeFrameDelta=row['wholeFrameDelta'].copy(),parentPositionDelta=after['parentPositionDelta'].copy(),parentRealVelocity=after['parentRealVelocity'].copy(),actualVelocity=after['velocity'].copy(),actualGrounded=True,**{'from':copy.deepcopy(before['transform'])})
                        plan['raised']['basis']=copy.deepcopy(before['transform']['basis']);t['upAfter']['transform']['basis']=copy.deepcopy(before['transform']['basis'])
                        t['wholeFrameDelta']=row['wholeFrameDelta'].copy();plan['responseGuard']['lastMotion']=horizontal.copy()
                        t['upRequest'].update(bodyRid=200,motion=[0,.2,0],margin=.02,maxCollisions=32,testOnly=False,recoveryAsCollision=False,collideSeparationRay=False,epsilon=1e-6,modeledRaised=copy.deepcopy(plan['raised']),**{'from':copy.deepcopy(before['transform'])})
                else:row['afterQueries']=before
                p['frames' if active else 'settle'].append(row)
            if positive:
                from .evidence import footprint
                p['ordinaryLandingStreak']=sum(footprint(x['after'],spec) for x in p['frames'][1:])
                p['finalSupport']={'passed':True,'footprintInside':True,'reason':'full_footprint_and_fresh_target_support','bodyBefore':after,'bodyAfter':after,'epsilon':1e-6,'query':support_fixture(after,'fresh-full-tread-support',rise)}
    return r
def supervisor_fixture(group='negative-controls',source='s',grant='g',engine='e',native_hash='h'):
    return {'phase':'parity-admission-calibrated-v1','mode':'calibrated-controls','group':group,'scope':'calibrated-admission','sourceSha256':source,'grantSha256':grant,'engineSha256':engine,'nativeReceiptSha256':native_hash,'failed':False,'releasedCleanly':True,'returnCode':0,'nativeOutcome':'negative_control_group_pass' if group=='negative-controls' else 'synthetic_group_pass','partialCountersMayBeUnknown':False,'nativeStepAdmission':False,'productionPromotion':False,'positiveAdmission':group=='positive-step-admission','owned':{'pid':123,'pgid':123,'startTicks':456},'lockAcquiredUnix':1791072000.,'lockReleasePendingUnix':1791072004.,'releaseAudits':[{'utc':f'2026-10-04T00:00:0{i}.000000+00:00','measured':True,'members':[]} for i in [1,2,3]]}
