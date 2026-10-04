"""Independent arithmetic over AL raw terminal windows; no policy predicates or launch."""
import math
from audit_al import STAGE,OUT,GROUP,load,write,sha
def norm(v):return math.sqrt(sum(x*x for x in v))
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def degrees(n):return math.degrees(math.acos(max(-1,min(1,n[1]))))
def proofs():
    path=STAGE/(GROUP+'-result.json');native=load(path);out=[]
    for p in native['records']:
        s=p['spec'];theta=math.radians(s['yawDegrees']);direction=[math.sin(theta),0,math.cos(theta)];right=[direction[2],0,-direction[0]]
        base=p['geometry']['base']['rid'];target=p['geometry']['target']['rid'];fs=p['frames'];blocked=p['outcome']=='blocked_with_target_witness'
        window=fs[-120:] if blocked else fs[-3:]
        assert len(window)==(120 if blocked else 3)
        assert all(b['frame']==a['frame']+1 and b['usec']>a['usec'] for a,b in zip(window,window[1:]))
        assert all(r['input']==[0,-1] and abs(norm(r['requestedMotion'])-.1)<1e-6 and r['returned'] and r['parentCalls']==1 and r['after']['grounded'] for r in window)
        slide_angles=[];headons=[];point_heights=[];base_counts=[];support_angles=[];footprints=[];plane_errors=[];along=[]
        for r in window:
            q=r['support'];pos=r['after']['transform']['origin'];z=dot(pos,direction);along.append(z)
            assert q['before']==q['after']==r['after'] and q['from']==r['after']['transform'] and q['bodyRid']==p['parameters']['bodyRid']
            assert q['hit'] and 0<len(q['contacts'])<32 and q['count']==len(q['contacts'])
            assert abs(q['motion'][1]+p['parameters']['margin']+.0001)<1e-6 and q['motion'][0]==0 and q['motion'][2]==0
            assert q['recoveryAsCollision'] and q['collideSeparationRay'] and q['excludeBodies']==q['excludeObjects']==[]
            assert 0<=q['safeFraction']<=q['unsafeFraction']<=1
            assert all(c['shape']==c['localShape']==0 and norm(c['velocity'])<=1e-6 for c in q['contacts'])
            support_angles.extend(degrees(c['normal']) for c in q['contacts'])
            if blocked:
                assert norm(r['wholeDelta'])<.0001 and z<1
                floors=[c for c in q['contacts'] if c['normal'][1]>=math.cos(math.radians(46)+.01)]
                assert floors and all(c['rid']==base and abs(c['point'][1])<=1e-6 and norm([c['normal'][0],c['normal'][1]-1,c['normal'][2]])<=1e-6 for c in floors)
                assert all(c['rid']==base or (c['rid']==target and c['normal'][1]<math.cos(math.radians(46)+.01)) for c in q['contacts'])
                base_counts.append(len(floors));witness=[]
                for c in r['slides']:
                    if c['rid']!=target:continue
                    n=c['normal'];h=math.hypot(n[0],n[2]);headon=-(n[0]*direction[0]+n[2]*direction[2])/h if h else 0
                    if c['shape']==c['localShape']==0 and 0<c['point'][1]<.25 and n[1]<math.cos(math.radians(46)+.01) and headon>=.98:
                        witness.append(c);headons.append(headon);slide_angles.append(degrees(n));point_heights.append(c['point'][1])
                assert witness
            else:
                assert p['outcome']=='arrived';radius=p['parameters']['radius'];margin=p['parameters']['margin'];lateral=abs(dot(pos,right))
                assert radius+margin<=z<=3-radius-margin and lateral<=2-radius-margin and abs(pos[1]-s['rise'])<=margin+.0001
                footprints.append({'frame':r['frame'],'along':z,'lateral':lateral,'bodyY':pos[1],'radius':radius,'margin':margin})
                assert all(c['rid']==target and c['normal'][1]>=math.cos(math.radians(46)) and abs(c['point'][1]-s['rise'])<=1e-6 for c in q['contacts'])
                plane_errors.extend(abs(c['point'][1]-s['rise']) for c in q['contacts'])
        if not blocked:assert along[-1]>=1
        out.append({'caseIndex':p['caseIndex'],'spec':s,'recordedOutcome':p['outcome'],'independentTerminalProof':True,'windowResponses':len(window),'firstFrame':window[0]['frame'],'lastFrame':window[-1]['frame'],'maxWholeDisplacement':max(norm(r['wholeDelta']) for r in window),'alongMin':min(along),'alongMax':max(along),'baseRid':base,'targetRid':target,'baseWalkableContactsPerResponse':sorted(set(base_counts)),'supportAngleRange':[min(support_angles),max(support_angles)],'targetSlideAngleRange':[min(slide_angles),max(slide_angles)] if slide_angles else None,'targetHeadOnMinimum':min(headons) if headons else None,'targetPointYRange':[min(point_heights),max(point_heights)] if point_heights else None,'landingFootprints':footprints,'arrivalMaxPlaneError':max(plane_errors) if plane_errors else None,'bodyFinal':window[-1]['after']['transform'],'finalQuery':window[-1]['support']})
    return {'nativeSha256':sha(path),'qualification':'Independent arithmetic on terminal native operands; no unique backend or internal branch causal inference. No height selected.','selectedHeight':None,'profiles':out}
if __name__=='__main__':write(OUT/'independent-terminal-proofs.json',proofs())
