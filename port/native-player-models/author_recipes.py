"""Deterministic, original authored operator recipes; no network or external assets."""
import json
import math
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]

def variant(kind):
    parts = []
    def p(name, pos, size, material='dark', lower=.85, upper=.85, bevel=.12):
        parts.append(dict(name=name, op='prism', position=pos, size=size,
                          material=material, lower=lower, upper=upper, bevel=bevel, yaw=0.0))
    for side, label in [(-1, 'L'), (1, 'R')]:
        p('Boot'+label,[side*.145,-.805,-.055],[.205,.19,.35], 'dark',1,.78)
        p('Toe'+label,[side*.145,-.805,-.205],[.18,.12,.075],'trim')
        p('Shin'+label,[side*.145,-.615,.005],[.15,.21,.19],'dark')
        p('ShinPlate'+label,[side*.145,-.585,-.10],[.135,.20,.05],'armor',.65,1)
        p('Knee'+label,[side*.145,-.445,-.03],[.165,.12,.22],'trim')
        p('Thigh'+label,[side*.135,-.30,.015],[.19,.21,.235],'dark',.76,1)
        p('ThighPlate'+label,[side*.135,-.295,-.105],[.15,.19,.05],'armor',.72,1)
        shoulder_w = .16 if kind=='meta' else (.11 if kind=='grok' and side<0 else .145)
        p('Shoulder'+label,[side*(.35-shoulder_w/2),.305,0],[shoulder_w,.205,.29],'armor',.78,1)
        p('UpperArm'+label,[side*.28,.13,-.025],[.125,.23,.16],'dark',.82,1)
        p('Elbow'+label,[side*.265,.015,-.06],[.12,.105,.15],'trim')
        # Elbow-to-palm continuous support chain; left palm meets fore-end.
        ex, ez = side*.265, -.06
        hx, hz = (.18, -.43) if side < 0 else (.23, -.255)
        yaw = math.atan2(-(hx-ex), -(hz-ez))
        p('Forearm'+label,[(ex+hx)/2,.015,(ez+hz)/2],[.105,.105,math.hypot(hx-ex,hz-ez)],'dark')
        parts[-1]['yaw'] = yaw
        p('Gauntlet'+label,[(ex+hx)/2,.06,(ez+hz)/2],[.115,.045,.16],'armor')
        parts[-1]['yaw'] = yaw
        p('Hand'+label,[hx,.015,hz],[.105,.105,.105],'trim')
    p('Hip',[0,-.15,.005],[.38,.16,.27],'dark',.78,1)
    width = .46 if kind=='meta' else (.36 if kind=='grok' else .42)
    p('Torso',[0,.125,.01],[width,.40,.29],'armor',.67,1)
    p('ChestInset',[0,.19,-.14],[width*.73,.23,.055],'dark',.68,1)
    p('ChestPlateL',[-.095,.225,-.177],[.16,.21 if kind!='grok' else .13,.065],'armor',.52,1)
    p('ChestPlateR',[.095,.225,-.177],[.16,.21,.065],'armor',.52,1)
    p('CharacterBadge',[0,.23,-.215],[.032,.14,.018],'identity')
    p('BackpackL',[-.09,.18,.185],[.17,.31 if kind=='meta' else .25,.16],'dark')
    p('BackpackR',[.09,.18,.185],[.17,.31 if kind=='meta' else .25,.16],'dark')
    p('BackBadge',[0,.23,.277],[.16,.045,.018],'identity')
    p('Neck',[0,.43,.01],[.14,.20,.15],'trim')
    hw = .34 if kind=='meta' else (.27 if kind=='grok' else .31)
    p('Helmet',[0,.665,.005],[hw,.35,.30],'dark',.65,.87)
    p('Crown',[0,.845,.005],[hw+.02,.11,.29],'armor',1,.68 if kind=='grok' else .88)
    p('Visor',[0,.71,-.151],[hw*.85,.08,.044],'identity',.85,1)
    p('Jaw',[0,.565,-.10],[hw*.72,.10,.12],'trim',.65,1)
    # Existing generic compatibility carbine, not reserved weapon art.
    p('WeaponGrip',[.23,-.035,-.24],[.095,.18,.11],'dark',1,1)
    p('Weapon',[.23,.095,-.3],[.15,.15,.43],'dark',1,1)
    p('Muzzle',[.23,.1,-.555],[.09,.09,.12],'trim',1,1)
    p('WeaponSight',[.23,.195,-.31],[.05,.05,.09],'identity',1,1)
    for i in range(2):
        p('TeamStripe%d'%i,[-.07+i*.14,.15,-.223],[.065,.085,.025],'trim',1,1)
    return parts

if __name__ == '__main__':
    data = dict(version=1,generator='faceted-operator-1',seed=0,
                variants={k:variant(k) for k in ['claude','grok','meta']})
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT/'godot/player_models/recipes.json')
    dest = parser.parse_args().output
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(data,sort_keys=True,indent=2)+'\n')
    print(dest)
