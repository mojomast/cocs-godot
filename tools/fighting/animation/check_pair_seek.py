"""Source numeric oracle for the snapshot-only paired seek contract.

This exercises actual content catch ranges and core 6be3b1ce's published knot
construction, not the Godot runtime. Native assertions are prepared separately.
"""
import argparse
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path


def seconds(fighter, fixed):
    """Independent piecewise-linear reference for native expected values."""
    phase = fighter.get('pair_phase') or fighter.get('animation_pair_phase', {})
    clip, state = fighter['animation'], fighter.get('state','')
    move = phase.get('move_id','')
    matched = (fighter['id']==phase.get('actor') and clip==move) or (
        fighter['id']==phase.get('target') and clip.startswith('victim_') and clip.endswith('_'+move))
    if state in ('throw_tech','win','lose','knockdown','wakeup') or not move or not matched:
        keys = fixed
    else:
        fields = ('caught_move_frame','damage_frame','release_frame','end_frame','frame')
        values = [phase.get(k) for k in fields]
        if any(type(v) not in (int,float) or not math.isfinite(v) or v<0 or int(v)!=v for v in values):
            raise ValueError('nonintegral/nonfinite phase')
        caught,damage,release,end,frame = values
        if not caught<damage<release<end or frame!=fighter['animation_frame']:
            raise ValueError('degenerate or inconsistent phase')
        keys = [(caught,.28),(damage,.68),(release,.82),(end,1)]
        if caught>0: keys.insert(0,(0,0))
    frame = max(keys[0][0],min(keys[-1][0],fighter['animation_frame']))
    for (a,x),(b,y) in zip(keys,keys[1:]):
        if frame<=b: return x+(y-x)*(frame-a)/(b-a)
    return keys[-1][1]


def audit(root):
    raw = (root/'godot/fighting/data/roster.json').read_bytes()
    operators = json.loads(raw)['operators']
    cases, samples, interruptions, invalid = 0,0,0,0
    for operator in operators:
        for move_id,move in operator['moves'].items():
            meta = move.get('throw',move.get('counter',{}))
            if not meta: continue
            earliest = meta.get('from',move['startup'])
            latest = meta.get('to',move['startup']+move['active']-1)
            total = sum(move[k] for k in ('startup','active','recovery'))
            fixed = [(0,0),(earliest,.28),(meta['damage_frame'],.68),(meta['release_frame'],.82),(total,1)]
            for caught in range(earliest,latest+1):
                techable = move_id in ('throw_f','throw_b')
                damage = max(caught+(10 if techable else 1),meta['damage_frame'])
                release = max(16,meta['release_frame'],damage+1)
                end = max(total,release+1)
                phase = dict(actor=0,target=1,move_id=move_id,caught_move_frame=caught,
                    damage_frame=damage,release_frame=release,end_frame=end,elapsed=0,frame=caught)
                a = dict(id=0,animation=move_id,state='throw',animation_frame=caught,pair_phase=phase,x=1200,y=0,facing=1)
                b = dict(id=1,animation=f"victim_{operator['id']}_{move_id}",state='thrown',animation_frame=caught,pair_phase=phase,x=1800,y=0,facing=-1)
                previous = .28
                # Both actors use identical authoritative times throughout hold;
                # attacker recovery uses a persisted projection after release.
                for frame in range(caught,end+1):
                    phase['frame'],phase['elapsed'] = frame,frame-caught
                    a['animation_frame']=b['animation_frame']=frame
                    before = deepcopy((a,b))
                    x,y = seconds(a,fixed),seconds(b,fixed)
                    assert x==y and x>=previous and 0<=x<=1
                    assert seconds(deepcopy(a),fixed)==x  # repeated hitstop snapshot
                    mirrored=deepcopy(a)
                    mirrored.update(id=1,x=-1200,facing=-1)
                    mirrored['pair_phase'].update(actor=1,target=0)
                    assert seconds(mirrored,fixed)==x
                    assert before==(a,b), 'presentation mutated snapshot'
                    if frame in (caught,damage,release,end):
                        assert abs(x-{caught:.28,damage:.68,release:.82,end:1}[frame])<1e-12
                    if frame>=release:
                        recovery = dict(a,pair_phase={},animation_pair_phase=deepcopy(phase),state='attack')
                        assert seconds(recovery,fixed)==x
                        # Fresh adapter, repeated hitstop snapshot and rewind do
                        # not require previous observations or an elapsed timer.
                        assert seconds(deepcopy(recovery),fixed)==x
                    previous=x
                    samples+=1
                for state,clip in (('throw_tech','throw_tech'),('lose','lose'),('win','win'),('knockdown','knockdown'),('hitstun','hit_hi'),('attack','stand_l')):
                    interrupted = dict(a,state=state,animation=clip,animation_frame=3)
                    assert seconds(interrupted,[(0,0),(60,1)])==.05
                    interruptions+=1
                for field,value in (('damage_frame',caught),('release_frame',damage),('end_frame',release),
                    ('caught_move_frame',-1),('frame',end-1),('damage_frame',math.nan),('damage_frame',2.5)):
                    bad=deepcopy(a)
                    bad['pair_phase'][field]=value
                    try: seconds(bad,fixed)
                    except ValueError: invalid+=1
                    else: raise AssertionError((field,value))
                cases+=1
    # A synthetic extended-active catch exercises core's max(catch+10, damage)
    # and subsequent release/end extension. Static fallback jumps to the end.
    shifted = dict(actor=0,target=1,move_id='throw_f',caught_move_frame=30,
        damage_frame=40,release_frame=41,end_frame=42,frame=41)
    a = dict(id=0,animation='throw_f',state='attack',animation_frame=41,pair_phase=shifted)
    fixed = [(0,0),(6,.28),(18,.68),(29,.82),(38,1)]
    assert seconds(a,fixed)==.82
    fallback = seconds(dict(a,pair_phase={}),fixed)
    assert fallback==1.0
    zero=deepcopy(a)
    zero['animation_frame']=0
    zero['pair_phase'].update(caught_move_frame=0,damage_frame=1,release_frame=2,end_frame=3,frame=0)
    assert seconds(zero,fixed)==.28
    return {'status':'source_numeric_passed_native_unrun','core_reference':'6be3b1ce',
        'roster_sha256':hashlib.sha256(raw).hexdigest(),'catch_scenarios':cases,'shared_frame_samples':samples,
        'interruption_checks':interruptions,'invalid_phase_rejections':invalid,
        'release_metadata_drop_regression':{'dynamic':.82,'fixed_fallback':fallback},
        'required_core_followup':'Persist attacker animation_pair_phase through recovery, serialized with move lifecycle.'}


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[3])
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    result=audit(args.root)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
