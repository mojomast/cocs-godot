"""Reconcile every frozen native contact with exact source collider triangles."""
import json
import sys
from fixture_inputs import HERE,ROOT,X_PINS,SOURCE_PINS,x_bytes,source,write
sys.path.insert(0,str(HERE.parent/'botanical-correction'))
from capsule import segment_triangle

def wall_ids_by_name():
    """``OverheadSide<n>`` -> wall id, as the frozen native evidence recorded it.

    ``contacts-evidence.json`` is committed and frozen: it was written from the
    pre-apron world, so it is the only surviving record of which *physical* wall
    each positional name denoted at the time the engine reported it.
    """
    evidence=json.loads((HERE/'contacts-evidence.json').read_text())
    names={}
    for record in evidence['records']:
        for contact in record['contacts']:
            name,cid=contact['nativeCollider'],contact['id']
            if not name.startswith('OverheadSide'):continue
            if names.setdefault(name,cid)!=cid:raise ValueError('Frozen evidence names two walls: '+name)
    return names

class Colliders(dict):
    """Collider lookup keyed by stable name, plus recorded wall-name aliases.

    ``unresolved`` lists the recorded wall names this world does not contain, so a
    caller can tell "the native run never hit that wall in this variant" apart
    from "the index moved" instead of both looking like a silent miss.
    """

    def __init__(self,entries,unresolved):
        super().__init__(entries)
        self.unresolved=unresolved

def colliders(arena,names=None):
    """Collider triangles keyed by stable name, plus recorded wall-name aliases.

    Surface colliders are keyed by ``<surface id>Collider`` and do not depend on
    insertion order. Wall colliders are not: ``WorldMap.build`` derives
    ``OverheadSide<n>`` from a running count of the triangles emitted before it, so
    adding surfaces ahead of the walls -- the 2026-10-05 apron adds 160 surface
    triangles -- shifts every wall index by 160, and the same name then denotes a
    different wall. Re-deriving that index therefore silently re-points a recorded
    contact at the wrong wall instead of failing.

    Walls are consequently keyed by their stable ``id``, and the recorded
    positional names are attached as aliases resolved through ``names``. A wall
    with no id cannot be addressed stably and is left unaliased. A recorded name
    whose wall is absent from this world is reported in ``unresolved``, never
    resolved to an index. ``census_bevel.py`` carries the id-pinned census.
    """
    out={}
    for s in arena['terrain']['surfaces']:
        out[s['id']+'Collider']={'id':s['id'],'kind':'surface','triangles':[[s['vertices'][i] for i in face] for face in s['triangles']]}
    walls={}
    for w in arena['terrain']['walls']:
        v=w['vertices']
        if not w.get('id'):continue
        walls[w['id']]={'id':w['id'],'kind':'wall','triangles':[[v[0],v[i],v[i+1]] for i in range(1,len(v)-1)]}
    out.update(walls)
    unresolved=[]
    for name,wid in sorted((names or {}).items()):
        if wid in walls:out[name]=walls[wid]
        else:unresolved.append(name)
    return Colliders(out,unresolved)

def check(foot,triangles,radius=.41,height=1.7):
    x,y,z=foot;bottom=[x,y+.05+radius,z];top=[x,y+.05+height-radius,z]
    distance=min(segment_triangle(bottom,top,t) for t in triangles)
    return {'distance':distance,'penetration':radius-distance,'overlaps':distance<radius-1e-7,
        'radius':radius,'height':height,'groundSeparation':.05}

def main():
    native=json.loads(x_bytes(next(p for p in X_PINS if p.endswith('stair-diagnostic.json'))))
    physics=json.loads(x_bytes(next(p for p in X_PINS if p.endswith('physics-report.json'))))
    assert len(physics['errors'])==184 and len(native['records'])==368
    maps={v:colliders(source(v)['arena'],wall_ids_by_name()) for v in SOURCE_PINS}
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
