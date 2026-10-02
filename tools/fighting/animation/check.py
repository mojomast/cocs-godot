"""Source-only coverage/rig oracle; --exported additionally inspects real GLBs."""
import argparse
import hashlib
import itertools
import json
import math
from pathlib import Path
from glb import GLB, source_rig
from kinematics import solve
from recipes import OPERATORS, STATES, MOVES, THROWS, library, sample, timing


def audit(root,exported=False):
    report = {'status':'source_only','operators':{},'pending':['Blender build','master reopen',
        'GLB export','content frame binding','paired contact solve','native playback','side-on art inspection'],
        'uniqueness':{}}
    curves = {}
    for operator in OPERATORS:
        glb = GLB(root/'godot/source_operators/generated'/f'{operator}.glb')
        assert not glb.doc.get('skins') and not glb.doc.get('animations')
        rig = source_rig(glb)
        clips = library(operator)
        expected = set(STATES+MOVES)|{f'victim_{a}_{m}' for a in OPERATORS for m in THROWS}
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
                pose = sample(clip['keys'],frame/60)
                heads,tails,clamps = solve(rig,pose)
                for bone,point in heads.items():
                    assert all(math.isfinite(v) for v in point+tails[bone])
                    assert math.dist(point,tails[bone])>.00001, (operator,name,frame,bone)
                root_positions.add(tuple(heads['Root']))
                worst = max(worst,max(clamps.values()))
                trajectory.extend(v for channel in ('lh','rh','lf','rf','torso','hips','wrist') for v in pose[channel])
            errors[name] = round(worst,6)
            curves[operator][name] = trajectory
            keys = timing(clip)
            assert keys[0]==[0,0] and keys[-1]==[60,1.0]
        assert len(root_positions)==1
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
            assert distance>.10,(name,a,b,distance)
            distances.append((distance,a,b))
        d,a,b = min(distances)
        report['uniqueness'][name] = {'min_curve_rms':round(d,5),'closest_pair':[a,b]}
    report['coverage'] = {'operators':9,'required_per_operator':64,'total_authored_clips':sum(len(library(o)) for o in OPERATORS)}
    return report


def check_export(root,operator,clips):
    path = root/'godot/fighting/assets/operators'/f'{operator}.glb'
    glb = GLB(path)
    manifest = json.loads(path.with_suffix('.json').read_text())
    assert glb.sha256==manifest['sha256']
    doc = glb.doc
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
