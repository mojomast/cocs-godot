"""Write-once source acceptance specification. Does not stage/import/run an engine."""
import hashlib
import json
from pathlib import Path
import subprocess
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    original=json.loads(subprocess.check_output(['node',str(HERE.parent/'botanical-post-x/native_cases.mjs')],cwd=ROOT))
    groups=[]
    baseline=original['groups']['accepted-civic-r035']
    groups.append({'id':'reference-accepted-civic-r035','profile':'unchanged-production-Walker','timeoutSeconds':180,
        'referenceOnly':True,'expectedHistoricalOutcome':{'passedDownhill':5,'failedUphill':5},**baseline})
    for key,group in original['groups'].items():
        groups.append({**group,'id':'step-v1-'+key,'profile':'unpromoted-test-subclass','controller':'res://tests/walker_step_up/candidate_walker.gd',
            'timeoutSeconds':180,'internalTimeoutSeconds':170,'referenceOnly':False,'requiredPassed':10,
            'radiusScope':'actual exploration size' if group['radius']==.35 else 'test-only .42 envelope; no production resize'})
    dependencies=['godot/exploration/walker.gd','godot/multiplayer_worlds/map.gd','godot/multiplayer_worlds/dressing/binder.gd',
        'game/core.mjs','game/data.mjs','godot/project.godot',
        'godot/tests/graphics_batch/walker.gd','godot/tests/aurora_basin/validate.gd','godot/tests/cinder_array/verify.gd']
    report={'status':'SOURCE PROPOSAL ONLY; no GDScript parse, import, physics or controller success claimed',
        'version':'walker-step-up-experiment-v1','base':'d8822447','engine':'Godot 4.5.2 official 6ce3de25a',
        'productionPromotion':False,'nativeGrant':None,'fixedPhysicsHz':60,'timeScale':1,'walkOnly':True,
        'groups':groups,'totalWalkTrials':sum(len(g['trials']) for g in groups),
        'sequence':'Native counterexamples first; reference group retains failed=true; parent must explicitly authorize proceeding from the known failed reference to the experimental profile. Require step-v1-accepted-civic-r035 10/10 before the other five candidate groups. No autonomous loop.',
        'binding':'Both exact Vesper authority/GLB pairs and actual UID-retaining compression-off/LOD-off import/readback as approved 525b9fbe; preserve Z paths and pins, use fresh walker_step_up attempt namespace.',
        'perFrameRequired':['physicsFrame','actualDelta','bodyBefore','bodyAfter','actualShapeData','ordinaryVelocity','ordinaryRealVelocity','wholeFrameDelta',
            'groundedBefore','groundedAfter','resetCount','input','profile','allSweepParametersAndResults','supportFaceCertificate','acceptedLiftCount','candidateFault'],
        'nativeCounterexamples':[
            {'id':'low-ceiling-up','foot':[32,12.0166673660278,24.7000026702881],'tread':[30,34,25,25.5,12.15],'ceiling':[30,34,24,24.9,13.9],'required':'no lift; up volume blocked'},
            {'id':'low-overhang-forward','foot':[32,12.0166673660278,24.7000026702881],'tread':[30,34,25,25.5,12.15],'ceiling':[30,34,25.12,26,13.78],'required':'no lift; up clear but raised-forward volume blocked'},
            {'id':'strict-rise-boundaries','rises':[.15,.249,.24995,.25,.25001,.3,.31],'required':'only .15 and .249 may plan a step; .24995 rejected conservatively by 0.1mm guard, all boundary/greater heights rejected'},
            {'id':'steep-contact','anglesDegrees':[46,46.01,47,51.3],'required':'down support >46 rejected; no native floor threshold broadening'},
            {'id':'narrow-and-hole','required':'width less than capsule diameter plus two margins OR depth less than radius plus two margins rejected; two overlapping triangles with a shared outside edge rejected'},
            {'id':'pit','required':'no down hit within bounded drop => no lift'},
            {'id':'lateral-corner','approachCosines':[1,.98,.97,.70710678,0],'required':'below .98 rejected; no diagonal wall climb'},
            {'id':'no-intent-airborne-jump','required':'zero input, airborne, ascending or descending jump, jump press => unchanged original path'},
            {'id':'platform-and-transform','required':'moving/rotating platforms, non-static floor, non-yaw rotation, scaling, transformed parent, extra/disabled shapes => no assist'},
            {'id':'edge-ladder','rises':[.15,.30,.45,.60],'shelfDepth':.08,'required':'no assist on any shelf; no accumulating partial lifts up a wall'},
            {'id':'one-frame-budget','required':'one proposal maximum; no query consumes horizontal budget; exactly one original step; no second forward movement or frame warp'},
            {'id':'ordinary-controls','required':'flat walk/sprint and diagonal speed, ramps both ways, jump arc/landing, focus/pointer release, reset remain baseline-equivalent; unsupported capsule-height changes bypass assist'}],
        'promotionImpactMatrix':[
            {'consumer':'godot/aurora_basin/demo.gd','acceptance':'existing tests/aurora_basin/validate.gd route loop, native heights/slopes; separately instantiate candidate without changing originals'},
            {'consumer':'godot/cinder_array/demo.gd','acceptance':'existing tests/cinder_array/verify.gd transfer deck, walk/sprint route, inclines and bridge connections; separately instantiate candidate'},
            {'consumer':'godot/tests/graphics_batch/walker.gd','acceptance':'ground, wall, jump, fall reset, focus, pointer and clamped spawn tests for both profiles'},
            {'consumer':'standing capsule and crouch-like inputs','acceptance':'Walker has no crouch implementation; confirm Control/input does not resize it, altered heights reject assist; add no crouch behavior'},
            {'consumer':'get_real_velocity/get_position_delta consumers','acceptance':'pre-lift is outside parent move_and_slide accounting; whole-frame telemetry mandatory and production-promotion blocker until downstream semantics reviewed'}],
        'excludedSystems':['authoritative JS movement','Fighting movement','network session movement','Parallax production','global movement epochs'],
        'dependencies':{p:sha(ROOT/p) for p in dependencies}}
    with (HERE/'acceptance-plan.json').open('x') as f:json.dump(report,f,indent=2);f.write('\n')
    print('Prepared',len(groups),'future walk groups /',report['totalWalkTrials'],'trials; nothing staged or executed')
if __name__=='__main__':main()
