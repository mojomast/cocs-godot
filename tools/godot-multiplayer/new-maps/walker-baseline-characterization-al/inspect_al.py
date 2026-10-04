"""Offline AL native operand reconstruction. Never launches or selects a height."""
import csv,io,json,math,sys
from audit_al import OUT,STAGE,load,write,sha,GROUP
from policy import row,profile,direction,dot,length,ENGINE_ANGLE
def angle(n):return math.degrees(math.acos(max(-1,min(1,n[1]))))
def inspect():
    path=STAGE/(GROUP+'-result.json');rows=[];profiles=[]
    if not path.exists():
        return {'nativeReceiptPresent':False,'physicalCallCounts':None,'qualification':'No native result: no per-case completion or zero-work inference.','selectedHeight':None,'profiles':[]},rows
    native=load(path)
    for p in native['records']:
        s=p['spec'];items=[]
        for settling,array in [(True,p.get('settle',[])),(False,p.get('frames',[]))]:
            for i,r in enumerate(array):
                if not r.get('returned'):continue
                post=r['after'];pos=post['transform']['origin'];d=direction(s)
                target=[c for c in r['slides'] if c['rid']==p['geometry']['target']['rid']]
                query=r['support'];contacts=query['contacts'];walkable=[c for c in contacts if c['normal'][1]>=math.cos(ENGINE_ANGLE)]
                entry={'caseIndex':p['caseIndex'],'radius':s['radius'],'rise':s['rise'],'yawDegrees':s['yawDegrees'],'settling':settling,'responseIndex':i,'frame':r['frame'],'usec':r['usec'],'delta':r['delta'],'position':pos,'along':dot(pos,d),'wholeDelta':r['wholeDelta'],'wholeDistance':length(r['wholeDelta']),'parentDelta':post['parentDelta'],'realVelocity':post['realVelocity'],'lastMotion':post['lastMotion'],'grounded':post['grounded'],'onWall':post['onWall'],'targetSlideAngles':list(map(lambda c:angle(c['normal']),target)),'targetSlidePoints':[c['point'] for c in target],'supportContactCount':len(contacts),'supportHit':query['hit'],'supportAngles':[angle(c['normal']) for c in contacts],'supportIdentities':[{'rid':c['rid'],'shape':c['shape'],'localShape':c['localShape'],'point':c['point']} for c in contacts],'walkableSupportRids':[c['rid'] for c in walkable],'queryStateUnchanged':query['before']==query['after']}
                try:
                    landing,blocked,along,base=row(r,p['parameters'],p['geometry'],s,not settling)
                    entry.update(operandReplayValid=True,landingQualified=landing,blockedResponseQualified=blocked,baseSupportQualified=base)
                except (KeyError,TypeError,ValueError,IndexError,AttributeError) as error:entry.update(operandReplayValid=False,operandError=str(error))
                items.append(entry);rows.append(entry)
        moving=[r for r in items if not r['settling']];slides=[x for r in moving for x in r['targetSlideAngles']]
        summary={'caseIndex':p['caseIndex'],'spec':s,'status':p['status'],'outcome':p['outcome'],'settleRecords':len(p.get('settle',[])),'inputRecords':len(p.get('frames',[])),'inflight':p.get('inflight'),'allReturnedOperandReplayValid':all(r['operandReplayValid'] for r in items),'firstTargetSlide':next((r for r in moving if r['targetSlideAngles']),None),'targetAngleMin':min(slides) if slides else None,'targetAngleMax':max(slides) if slides else None,'lastResponse':moving[-1] if moving else None,'last120BlockedWitnesses':sum(r.get('blockedResponseQualified',False) for r in moving[-120:]),'lastThreeLandingQualified':sum(r.get('landingQualified',False) for r in moving[-3:])}
        if p['status']=='completed':
            try:summary['profileReplay']=profile(p,p['caseIndex'])
            except (KeyError,TypeError,ValueError,IndexError,AttributeError) as error:summary['profileReplayError']=str(error)
        profiles.append(summary)
    return {'nativeReceiptPresent':True,'nativeSha256':sha(path),'qualification':'Offline reconstruction of recorded operands only; aggregate floor state does not identify internal contact branch or unique backend cause.','selectedHeight':None,'candidateAdmission':False,'physicalCallCounts':None,'profiles':profiles},rows
if __name__=='__main__':
    report,rows=inspect();write(OUT/'native-detail.json',report)
    if rows:
        fields=list(dict.fromkeys(k for r in rows for k in r));stream=io.StringIO();writer=csv.DictWriter(stream,fieldnames=fields,lineterminator='\n');writer.writeheader()
        for r in rows:writer.writerow({k:json.dumps(v,separators=(',',':')) if isinstance(v,(list,dict)) else v for k,v in r.items()})
        with (OUT/'response-chart.csv').open('x') as f:f.write(stream.getvalue())
    print(json.dumps({'nativeReceiptPresent':report['nativeReceiptPresent'],'profiles':len(report['profiles']),'chartedReturnedResponses':len(rows)}))
