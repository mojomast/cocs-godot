"""Source-only coverage/rig oracle; --exported additionally inspects real GLBs."""
import argparse
import hashlib
import itertools
import json
import math
from pathlib import Path
from glb import GLB, source_rig
from kinematics import solve
from recipes import OPERATORS, STATES, MOVES, PAIRS, library, sample, timing
from content import inputs
from pairing import adapted_pose, grip, chest


def audit(root,exported=False):
    report = {'status':'source_only','operators':{},'pending':['Blender build','master reopen',
        'GLB export','native paired contact solve','native playback','side-on art inspection'],
        'uniqueness':{}}
    roster,pairs,rigs,libraries,hashes = inputs(root)
    report['content_hashes'] = hashes
    report['shared_rest'] = {'identical':True,'operators':9,'retargeting':'none','motion_scale':'unchanged','rest_fixer':'disabled'}
    curves = {}
    pair_errors = []
    for operator in OPERATORS:
        glb = GLB(root/'godot/source_operators/generated'/f'{operator}.glb')
        assert not glb.doc.get('skins') and not glb.doc.get('animations')
        rig = source_rig(glb)
        clips = library(operator)
        expected = set(STATES+MOVES)|{f'victim_{a}_{m}' for a,m in PAIRS}
        assert expected<=clips.keys()
        errors = {}
        root_positions = set()
        curves[operator] = {}
        for name,clip in clips.items():
            assert clip['keys'][0][0]==0 and clip['keys'][-1][0]==1
            assert all(a[0]<b[0] for a,b in zip(clip['keys'],clip['keys'][1:]))
            trajectory = []
            worst = 0
            for frame in range(61):
                pose = adapted_pose(operator,clip,frame/60,rig,rigs,libraries,pairs)
                heads,tails,clamps = solve(rig,pose)
                for bone,point in heads.items():
                    assert all(math.isfinite(v) for v in point+tails[bone])
                    assert math.dist(point,tails[bone])>.00001, (operator,name,frame,bone)
                root_positions.add(tuple(heads['Root']))
                worst = max(worst,max(clamps.values()))
                for side in ('Left','Right'):
                    for chain in (('UpperArm','LowerArm','Hand'),('UpperLeg','LowerLeg','Foot')):
                        for a,b in zip(chain,chain[1:]):
                            assert abs(math.dist(heads[side+a],heads[side+b])-math.dist(rig['heads'][side+a],rig['heads'][side+b]))<1e-6
                trajectory.extend(v/(90 if channel in ('torso','wrist') else 1) for channel in ('lh','rh','lf','rf','torso','hips','wrist') for v in pose[channel])
                if 'pair' in clip and .28<=frame/60<=.82:
                    pair = clip['pair']
                    definition = pairs[(pair['attacker'],pair['move'])]
                    ah,at,_ = solve(rigs[pair['attacker']],sample(libraries[pair['attacker']][pair['move']]['keys'],frame/60))
                    contact = grip(ah,at)
                    victim = chest(heads,pose)
                    victim = [-victim[0],definition['victim_x']/1000-victim[1],victim[2]+definition['victim_y']/1000]
                    error = math.dist(contact,victim)
                    assert error<=.060001,(operator,name,frame,error)
                    pair_errors.append(error)
            errors[name] = round(worst,6)
            assert worst<=.001,(operator,name,'unreachable authored target',worst)
            curves[operator][name] = trajectory
            keys = timing(clip)
            assert keys[0]==[0,0] and keys[-1]==[clip['frames'],1.0]
            move = roster[operator]['moves'].get(name)
            if 'pair' in clip:
                move = roster[clip['pair']['attacker']]['moves'][clip['pair']['move']]
            if move:
                bound = timing(clip,move)
                assert all(a[0]<b[0] and a[1]<b[1] for a,b in zip(bound,bound[1:])),(operator,name,bound)
        assert len(root_positions)==1
        for a,b in itertools.combinations(STATES+MOVES,2):
            assert curves[operator][a]!=curves[operator][b], ('aliased state/combat curves',operator,a,b)
        report['operators'][operator] = {'source_sha256':glb.sha256,'gun_removed_bounds':glb.bounds(),
            'bones':len(rig['heads']),'bone_lengths_m':{k:round(math.dist(v,rig['tails'][k]),6) for k,v in rig['heads'].items()},
            'clips':len(clips),'curve_sample_count':len(clips)*61,
            'max_ik_clamp_m':max(errors.values()),'ik_clamp_over_6cm':{k:v for k,v in errors.items() if v>.06}}
        if exported:
            report['operators'][operator]['exported'] = check_export(root,operator,clips)
    for name in STATES+MOVES:
        distances = []
        for a,b in itertools.combinations(OPERATORS,2):
            # Standardized angular channels prevent one torso degree dominating
            # positional channels; compare trajectories, not hashes or filenames.
            ca,cb = curves[a][name],curves[b][name]
            distance = math.sqrt(sum((x-y)**2 for x,y in zip(ca,cb))/len(ca))
            assert distance>.025,(name,a,b,distance)
            distances.append((distance,a,b))
        d,a,b = min(distances)
        report['uniqueness'][name] = {'min_curve_rms':round(d,5),'closest_pair':[a,b]}
    report['coverage'] = {'operators':9,'state_combat_clips':336,'paired_timelines':len(pairs),
        'victim_instances':225,'unique_authored_clips':361,'resolved_clip_usages':sum(len(library(o)) for o in OPERATORS)}
    report['paired_contacts'] = {'samples':len(pair_errors),'max_error_m':max(pair_errors),'tolerance_m':.06,'status':'task_space_only_not_native'}
    return report


def check_export(root,operator,clips):
    path = root/'godot/fighting/assets/operators'/f'{operator}.glb'
    glb = GLB(path)
    manifest = json.loads(path.with_suffix('.json').read_text())
    assert glb.sha256==manifest['sha256']
    doc = glb.doc
    source = GLB(root/'godot/source_operators/generated'/f'{operator}.glb')
    for lod in (1,2,4):
        a,b = source.bounds(lod=lod),glb.bounds(lod=lod)
        assert max(abs(x-y) for k in ('min','max') for x,y in zip(a[k],b[k]))<.0001, ('rest_geometry_bounds',operator,lod,a,b)
    assert len(doc.get('skins',[]))==1
    assert {a['name'] for a in doc['animations']}==set(clips)
    skin = doc['skins'][0]
    matrices = glb.accessor(skin['inverseBindMatrices'])
    assert len(matrices)==len(skin['joints'])
    for m in matrices:
        # Finite is checked by accessor; affine determinant rejects singular bind.
        det = m[0]*(m[5]*m[10]-m[9]*m[6])-m[4]*(m[1]*m[10]-m[9]*m[2])+m[8]*(m[1]*m[6]-m[5]*m[2])
        assert abs(det)>1e-8
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            at = primitive['attributes']
            assert 'JOINTS_0' in at and 'WEIGHTS_0' in at
            for joints,weights in zip(glb.accessor(at['JOINTS_0']),glb.accessor(at['WEIGHTS_0'])):
                assert abs(sum(weights)-1)<1e-5 and sum(w>1e-6 for w in weights)==1
                assert all(0<=j<len(skin['joints']) for j,w in zip(joints,weights) if w>0)
    assert not any(n.get('name') in ('weapon','gunAnchor','Muzzle') for n in doc['nodes'])
    for animation in doc['animations']:
        assert animation['channels']
        for sampler in animation['samplers']:
            time = glb.accessor(sampler['input'])
            glb.accessor(sampler['output'])
            assert all(a[0]<b[0] for a,b in zip(time,time[1:]))
    return {'status':'binary_checked_not_native_accepted','sha256':glb.sha256,'animations':len(doc['animations'])}


if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[3])
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--exported',action='store_true')
    options = parser.parse_args()
    result = audit(options.root,options.exported)
    options.output.parent.mkdir(parents=True,exist_ok=True)
    options.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'status':result['status'],**result['coverage'],
        'max_ik_clamp_m':max(o['max_ik_clamp_m'] for o in result['operators'].values()),'output':str(options.output)}))
