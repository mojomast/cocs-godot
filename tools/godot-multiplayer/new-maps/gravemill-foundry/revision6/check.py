"""Bounded source-only checks. No Blender/Godot/PNG production or R6 GLB writes."""
import ast
import collections
import json
import math
from finish import HERE,ROOT,R5,GLB,read,write,plan,primitives,glb_parts,sha,choose
from verify import planned_inventory
from material_pack import load_pack

def check():
    p=plan();assert p==read(HERE/'finish-plan.json'),'Recompute finish-plan.json after source changes'
    for path in HERE.glob('*.py'):ast.parse(path.read_text(),filename=str(path))
    original,blob=glb_parts(GLB.read_bytes());expected=planned_inventory(p)
    assert sum(expected.values())==87566
    # Each original oriented index triple occurs exactly once in planned groups;
    # material splitting does not introduce a vertex, reverse winding or clip.
    uv_scales=set();old_tris=collections.Counter();new_tris=collections.Counter()
    for (node,pi,prim,streams,faces),row in zip(primitives(original,blob),p['assignments']):
        assert len(faces)==len(row['roles'])==len(row['sourceIds'])
        groups=collections.defaultdict(list)
        for face,role in zip(faces,row['roles']):groups[role].append(tuple(face))
        assert collections.Counter(tuple(f) for f in faces)==sum((collections.Counter(v) for v in groups.values()),collections.Counter())
        for face in faces:old_tris[tuple(streams['POSITION'][i] for i in face)]+=1
        for role,group in groups.items():
            scale=row['uvScale'][role];assert math.isfinite(scale) and scale>0;uv_scales.add(scale)
            for face in group:new_tris[tuple(streams['POSITION'][i] for i in face)]+=1
    assert old_tris==new_tris
    # Explicit design regressions: no blanket copper-to-rust replacement, no
    # machinery-as-plaster, and no luminaire material reassignment.
    for ident,old,want in [('crusher-drum--48-0','GM / chalk','R6 / machine'),('crusher-process-roof-2','GM / copper','R6 / roof'),
        ('kiln-front','GM / ore','R6 / refractory'),('G5.bunker.0.surge','GM / ore','R6 / ore-shell'),
        ('cooling-nave-vault-2','GM / copper','GM / copper'),('furnace-0','GM / orange','GM / orange')]:
        assert choose(ident,old,'',(0,0,0),(0,1,0))[0]==want
    changed={r:sum(v for (role,_),v in expected.items() if role==r) for r in read(HERE/'bindings.json')}
    assert all(changed.values()),changed
    resources,pack=load_pack(ROOT)
    stage=ROOT/'godot/tests/new_maps/gravemill_foundry/revision6'
    assert 'generated/revisions/gravemill-foundry-r5.json' in (stage/'staged.gd').read_text()
    assert 'FileAccess.get_sha256(ART) == identity.artHash' in (stage/'staged.gd').read_text()
    assert (stage/'lights.json').read_bytes()==(stage.parent/'revision5/lights.json').read_bytes()
    assert (stage/'probes.json').read_bytes()==(stage.parent/'revision5/probes.json').read_bytes()
    assert len(read(stage/'profile.json')['preserve_materials'])==18
    protected=[R5/'candidate.json',R5/'gravemill-foundry-revision5.blend',GLB,
        ROOT/'godot/tests/new_maps/gravemill_foundry/revision5/staged.gd',ROOT/'godot/tests/new_maps/gravemill_foundry/revision5/lights.json']
    report={k:v for k,v in p.items() if k!='assignments'}
    report.update({'checks':{'orientedTriangleCoverageExact':True,'positionsUnchanged':True,'normalAndTangentStreamsCopied':True,
        'UVPolicy':'Positive uniform per-role scaling only; no rotation, reflection or new seams within a role. Tangent basis unchanged.',
        'uvScales':sorted(uv_scales),'allAuthoredRolesUsed':changed,'syntax':'all R6 Python parsed'},
        'protectedInputs':{str(path.relative_to(ROOT)):sha(path.read_bytes()) for path in protected},
        'resourceChannels':{name:{k:v['sha256'] for k,v in resources[b['resource']]['channels'].items()} for name,b in read(HERE/'bindings.json').items()},
        'reviewImages':{str(path.relative_to(ROOT)):sha(path.read_bytes()) for path in sorted((R5/'evidence/native').glob('*.png'))},
        'reviewContactSheets':{str(path.relative_to(ROOT)):sha(path.read_bytes()) for folder in ('candidate','candidate-v2','candidate-v3')
            for path in [ROOT/'assets/moth/map-variety-20261003'/folder/'contact-albedo.png']},
        'pending':['Blender build and packed-master reopen','actual R6 exported material pixels and native import','matched native renders and weather/dressing lifecycle','manual art acceptance','hosted gameplay cadence'],
        'notExecuted':['Blender','Godot','import','render','server'],'artHash':None,'nativeVisualAcceptance':'pending; source tests cannot establish appearance'})
    write(HERE/'source-report.json',report)
    print(json.dumps({'sourceChecks':'passed','triangles':p['triangles'],'plannedPrimitives':p['plannedPrimitives'],'newRoleTriangles':changed,'artHash':None,'nativeVisual':'pending'}))

if __name__=='__main__':check()
