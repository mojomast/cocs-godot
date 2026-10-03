"""Reconcile every frozen native contact with exact source collider triangles."""
import json
import sys
from fixture_inputs import HERE,ROOT,X_PINS,SOURCE_PINS,x_bytes,source,write
sys.path.insert(0,str(HERE.parent/'botanical-correction'))
from capsule import segment_triangle

def colliders(arena):
    # Names/count mirror WorldMap.build; triangles remain world-space authority.
    out={};count=12*len(arena['blocks'])
    for s in arena['terrain']['surfaces']:
        out[s['id']+'Collider']={'id':s['id'],'kind':'surface','triangles':[[s['vertices'][i] for i in face] for face in s['triangles']]}
        count+=len(s['triangles'])
    for w in arena['terrain']['walls']:
        v=w['vertices'];t=[[v[0],v[i],v[i+1]] for i in range(1,len(v)-1)]
        out['OverheadSide'+str(count)]={'id':w.get('id'),'kind':'wall','triangles':t};count+=len(t)
    return out

def check(foot,triangles,radius=.41,height=1.7):
    x,y,z=foot;bottom=[x,y+.05+radius,z];top=[x,y+.05+height-radius,z]
    distance=min(segment_triangle(bottom,top,t) for t in triangles)
    return {'distance':distance,'penetration':radius-distance,'overlaps':distance<radius-1e-7,
        'radius':radius,'height':height,'groundSeparation':.05}

def main():
    native=json.loads(x_bytes(next(p for p in X_PINS if p.endswith('stair-diagnostic.json'))))
    physics=json.loads(x_bytes(next(p for p in X_PINS if p.endswith('physics-report.json'))))
    assert len(physics['errors'])==184 and len(native['records'])==368
    maps={v:colliders(source(v)['arena']) for v in SOURCE_PINS}
    records=[]
    for record in native['records']:
        variant='candidate' if record['candidate'] else 'accepted';contacts=[]
        for name in record['contacts']:
            c=maps[variant][name]
            contacts.append({'nativeCollider':name,**c,'originalCapsule':check(record['foot'],c['triangles']),
                'gameEnvelopeCapsule':check(record['foot'],c['triangles'],.42,1.8)})
        records.append({**record,'variant':variant,'contacts':contacts})
    accepted={r['id']:r for r in records if r['variant']=='accepted'}
    candidate=[r for r in records if r['variant']=='candidate']
    added=[r['id'] for r in candidate if r['contacts'] and not accepted[r['id']]['contacts']]
    result={'scope':'source distance reconstruction of pinned X native contacts, not a new native run or waiver',
        'pins':X_PINS,'sourcePins':SOURCE_PINS,'records':records,'candidateOnlyContactPositions':added,
        'nativeAcceptedContactPositions':sum(bool(r['contacts']) for r in accepted.values()),
        'nativeCandidateContactPositions':sum(bool(r['contacts']) for r in candidate),
        'unreproducedContacts':[{'id':r['id'],'collider':c['nativeCollider']} for r in records for c in r['contacts'] if not c['originalCapsule']['overlaps']]}
    assert len(added)==13
    write(HERE/'contacts-evidence.json',result)
    print('Reconciled 184 candidate / 171 accepted positions; 13 candidate-only positions; source nonoverlaps:',len(result['unreproducedContacts']))
if __name__=='__main__':main()
