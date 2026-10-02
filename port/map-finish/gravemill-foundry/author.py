#!/usr/bin/env python3
"""Deterministic source-only foundry finish. No engine, import, or geometry writes."""
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
PROFILE = ROOT / 'godot/multiplayer_worlds/dressing/profiles/gravemill-foundry.json'
HASH = '8ebb148f209aca14c54246517f7332a18e5fbb5c68f7b607d980f5664fcde25f'
RECIPE = 'tools/godot-multiplayer/new-maps/gravemill-foundry/revision3/recipe.mjs'
arena = json.loads(subprocess.check_output(['node', '--input-type=module', '-e',
    f"import {{recipe}} from './{RECIPE}'; console.log(JSON.stringify(recipe()));"], cwd=ROOT))
profile = dict(version=1, map_id='gravemill-foundry', geometry_hash=HASH,
               materials=[], panels=[], signs=[], pockets=[], preserve_materials=[],
               budgets=dict(material_variants=8, panels=64, signs=20, motes=64))
# Explicit resolved triples are checked against the actual family table below.
specs = [
    # One soot batch covers walls, floors, pillars AND machine housings. Fine
    # matte coating is compatible with all of them; diamond plate is not.
    ('soot','pearl-ceramic','cast','weathered_concrete','weathered_concrete','baked','777872',1.35,.79,1.25),
    ('mineral','pearl-ceramic','worn','weathered_concrete-worn','weathered_concrete-worn','derived','b5ab97',1.15,.91,1.35),
    ('copper','oxidised-copper','default','metal-oxide','metal-oxide','derived','8b9682',1.2,.67,1.35),
    ('brass','brushed-alloy','default','brushed_metal','metal','baked','a78a58',1.4,.55,1.3),
    # Ore also owns kiln masonry, arches and stratified foundations, not armor.
    ('ore','pearl-ceramic','worn','weathered_concrete-worn','weathered_concrete-worn','derived','a7856c',1.25,.89,1.35),
    ('orange','pearl-ceramic','cast','weathered_concrete','weathered_concrete','baked','c69243',1.5,.69,1.15),
    ('chalk','pearl-ceramic','cast','weathered_concrete','weathered_concrete','baked','c4bcaa',1.4,.82,1.2),
    ('cooling-floor','pearl-ceramic','cast','weathered_concrete','weathered_concrete','baked','93948b',1.2,.78,1.3),
]
for index,(source,family,variant,base,normal,normal_source,tint,density,roughness,gain) in enumerate(specs):
    strength={'soot':.24,'mineral':.35,'copper':.22,'brass':.18,'ore':.32,'orange':.14,'chalk':.22,'cooling-floor':.30}[source]
    profile['materials'].append(dict(source='GM / '+source, family=family, options=dict(
        variant=variant,tint=tint,tiles_per_metre=density,roughness=roughness,
        albedo_gain=gain,texture_strength=strength,texture_saturation=.08 if source=='copper' else 0,
        normal_strength=.06 if source in ['brass','orange'] else .10,
        metallic=.38 if source=='copper' else (.46 if source=='brass' else .02),
        specular_strength=.22,detail_strength=.08,ao_strength=.16,
        roughness_variation=.10,glow=False,lut_gain=0,pulse_speed=0,pulse_depth=0,
        variation_mode='manufactured' if source=='brass' else 'organic',
        variation_strength=.12 if source=='brass' else .30,
        variation_scale=.07,variation_seed=610240+index)))

mounts = []
angle = -math.degrees(math.atan(.14))
def mount(bucket, ident, x, q, y, size, support, side=1, axis='q', **fields):
    # +Z is the visible front. q walls run along (1,0,.14), x walls along Z.
    slope=.14 if axis=='q' else .14+11/53
    normal = [-slope/math.sqrt(1+slope*slope),0,1/math.sqrt(1+slope*slope)] if axis!='x' else [1,0,0]
    normal = [v*side for v in normal]
    face = [x,y,q+.14*x]
    offset = .065 if bucket=='signs' else .045
    pos = [round(a+offset*b,6) for a,b in zip(face,normal)]
    rotation = [0,-math.degrees(math.atan(slope))+(180 if side<0 else 0),0] if axis!='x' else [0,90*side,0]
    record = dict(id=ident,position=pos,rotation_degrees=rotation,size=size,**fields)
    profile[bucket].append(record)
    mounts.append(dict(id=ident,support=support,face=face,normal=normal,offset=offset,
                       axis=axis,side=side,size=size))
def panel(ident,x,q,y,size,support,texture,tint,side=1,axis='q',**finish_fields):
    mount('panels',ident,x,q,y,size,support,side,axis,texture=texture,tint=tint,essential=False,**finish_fields)
def wear(opacity):
    # Explicitly requested at each authored deposit, never inferred at runtime.
    # Actual dust-field pixels have hard rectangular lobes. A continuous concrete
    # mask and wide alpha feather retain a deposit rather than a muddy plaque.
    return dict(wear_mask='weathered_concrete',opacity=round(opacity*.55,3),feather=.4,seed=610024+len(profile['panels']))
def sign(ident,text,x,q,y,size,support,side=1,axis='q',bg='253239'):
    mount('signs',ident,x,q,y,size,support,side,axis,text=text,
          foreground='e8e3cf',background=bg,essential=True)

# Crusher: bolted wear/access plates at the two real bed bases, not in aisles.
for x,q in [(-72,-7),(-48,0)]:
    base=(q-8+25)*12/50
    for dx in [-5,0,5]:
        panel(f'crusher-{x}-abrasion-{dx}',x+dx,q-8,base+2,[3.5,2.6],
              f'crusher-bed-{x}-side-3','metal','9b9588',-1)
    panel(f'crusher-{x}-grease',x,q+8,base+1.2,[8,.8],f'crusher-bed-{x}-side-1',
          'weathered_concrete-worn','686158',**wear(.28))
    sign(f'crusher-{x}-isolate','ISOLATE / PINCH',x,q-8,base+4,[6,.9],
         f'crusher-bed-{x}-side-3',-1,bg='554532')
    panel(f'crusher-{x}-hazard',x,q-8,base+3,[7,.45],f'crusher-bed-{x}-side-3',
          'hazard_stripes','c6ae72',-1)
sign('crusher-sector','CRUSHER / C1',-94,-52,7,[9,1.3],'crusher-house-front',-1)
for x in [-94,-81,-61,-44]:
    panel(f'crusher-back-soot-{x}',x,23,3,[5,4],'crusher-house-back',
          'weathered_concrete-worn','8b8173',-1,**wear(.24))

# Cooling: damp/chalk bands on CLOSED recess bank faces, under window openings.
for x in [-84,-48]:
    for side in [-1,1]:
        q=36+side*5.5+side*1.1
        support='cooling-recess-bank'
        panel(f'cooling-{x}-{side}-waterline',x,q,12.8,[5.2,1.2],support,
              'weathered_concrete-worn','aba798',side,**wear(.22))
        panel(f'cooling-{x}-{side}-vent-grate',x,q,14.6,[3,1.3],support,
              'metal_grating','9b9c95',side)
        sign(f'cooling-{x}-{side}-circuit','C2 / RETURN',x,q,15.65,[4.8,.5],support,side)
sign('cooling-sector','COOLING / C2',-73,26,18.4,[5,1.0],'cooling-enclosure',-1)
# Internal assay lintels have full-height backing above empty inspection windows.
for i,(a,b) in enumerate([(42,55),(59,75),(79,90)]):
    x=(a+b)/2
    for q,side in [(32,1),(40,-1)]:
        panel(f'assay-{i}-{q}-enamel',x,q,19,[b-a-1,2],
              'assay-inspection-lintel','weathered_concrete','c5bdab',side)
        sign(f'assay-{i}-{q}-station',f'A3 / SAMPLE 0{i+1}',x,q,19,[7.5,.85],
             'assay-inspection-lintel',side,bg='365358')
sign('assay-sector','ASSAY / A3',73,26,18.5,[5,1.0],'assay-outer-wall',-1)
# Furnace: heat-distressed stock at actual buttresses and the rear service wall.
for x in [44,80,104]:
    panel(f'kiln-{x}-heat',x,-21.5,6,[2.5,9],'kiln-buttress',
          'weathered_concrete-worn','998473',-1,**wear(.26))
    panel(f'kiln-{x}-hazard',x,-21.5,1.5,[2.5,.65],'kiln-buttress',
          'hazard_stripes','d4b578',-1)
for x in [52,72,94]:
    panel(f'kiln-rear-{x}-soot',x,22,4,[9,6],'kiln-service-back',
          'weathered_concrete-worn','8b8277',-1,**wear(.24))
sign('kiln-sector','FURNACE / F4',74,22,11,[10,1.3],'kiln-service-back',-1)
sign('kiln-danger','HOT STOCK / KEEP CLEAR',56,22,6.9,[11,1.0],'kiln-service-back',-1,bg='554532')
sign('transfer-sector','TRANSFER / T0',0,-83+25*11/53,6,[12,1.0],
     'transfer-south-cut',-1,axis='transfer')
# Service-loop guidance on existing hopper bodies, safely outside the road.
for x in [-132,134]:
    sign(f'service-{x}','SERVICE / LOOP',x,-98,2,[7.5,.8],f'ore-hopper-{x}-side-3',-1)

# Small bounded pockets ABOVE machinery tops, outside eye-height projectile lines.
profile['pockets'] = [
    dict(id='crusher-ore-dust',kind='dust',position=[-72,25.3,-17.08],size=[3,1,2],color='b1a58e',count=12),
    dict(id='kiln-hot-ash',kind='ash',position=[64,33,.96],size=[4,2,4],color='bdb1a2',count=12),
    dict(id='cooling-return-vent',kind='vent',position=[-84,18,18.74],size=[3,2,2],color='bdcfcb',count=8),
]

def sub(a,b): return [x-y for x,y in zip(a,b)]
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def inside(p,t):
    a,b,c=t; u=sub(b,a); v=sub(c,a); w=sub(p,a)
    uu,vv,uv,wu,wv=dot(u,u),dot(v,v),dot(u,v),dot(w,u),dot(w,v)
    d=uu*vv-uv*uv
    if d<1e-12:return False
    s=(wu*vv-wv*uv)/d; r=(wv*uu-wu*uv)/d
    projected=[a[i]+s*u[i]+r*v[i] for i in range(3)]
    return s>=-1e-5 and r>=-1e-5 and s+r<=1.00001 and math.dist(p,projected)<1e-4

def validate():
    raw=(ROOT/'godot/multiplayer_worlds/art/worlds/gravemill-foundry.glb').read_bytes()
    n=struct.unpack_from('<I',raw,12)[0]; glb=json.loads(raw[20:20+n])
    assert len(glb['materials'])==8 and not glb.get('textures')
    assert hashlib.sha256(raw).hexdigest()=='46bf1648b32d23e337cd11b2c639a47f17d36c41361aab9434e1e621361e5935'
    assert {m['name'] for m in glb['materials']}=={m['source'] for m in profile['materials']}
    assert json.loads((ROOT/'godot/multiplayer_worlds/art/gravemill-foundry/gravemill-foundry-art-report.json').read_text())['geometryHash']==HASH
    baked=json.loads((ROOT/'godot/moth/generated/manifest.json').read_text())
    derived=json.loads((ROOT/'godot/moth/derived/manifest.json').read_text())
    resources={}
    def resource(bucket,key):
        record=bucket[key]; path=ROOT/'godot'/record['path'].removeprefix('res://')
        assert path.is_file(),path
        resources[record['path']]=hashlib.sha256(path.read_bytes()).hexdigest()
        if 'png_sha256' in record:assert resources[record['path']]==record['png_sha256'],path
    family_text=(ROOT/'godot/material_language/families.gd').read_text()
    derived_bucket=derived['derived']
    for _,family,variant,base,normal,ns,*_ in specs:
        start=family_text.index(f'"{family}": {{')
        next_family=family_text.find('\n\t"',start+1)
        block=family_text[start:next_family if next_family!=-1 else len(family_text)]
        assert f'"base": "{base}", "normal": "{normal}"' in block
        if variant!='default': assert f'"{variant}": {{"base": "{base}"' in block
        resource(baked['textures'],base)
        resource(derived_bucket,'data--'+base)
        resource(derived_bucket if ns=='derived' else baked['normals'],('normal--' if ns=='derived' else '')+normal)
        lut=re.search(r'"lut": "([^"]+)"',block)[1]
        for plane in ['r','t']:resource({plane:baked['materials'][lut][plane]},plane)
        if family=='hazard-industrial':resource(derived_bucket,'mask--hazard_stripes')
    for panel in profile['panels']:
        resource(baked['textures'],panel['texture'])
        normal=panel.get('normal',panel['texture'])
        if normal.startswith('baked:'):resource(baked['normals'],normal.removeprefix('baked:'))
        elif normal in baked['normals']:resource(baked['normals'],normal)
        else:resource(derived_bucket,'normal--'+normal)
        if 'wear_mask' in panel:
            resource(baked['textures'],panel['wear_mask'])
            assert 0<=panel['opacity']<=1 and 0<=panel['feather']<=.5 and isinstance(panel['seed'],int) and 0<=panel['seed']<=2147483647
    bounds=(ROOT/'godot/material_language/library.gd').read_text()
    shader=(ROOT/'godot/material_language/family.gdshader').read_text()
    assert 'derived_roughness = data.g' in shader
    assert 'texture(data_map, ux)' in shader and 'texture(data_map, uz)' in shader
    assert 'normal_map' in shader and 'weights' in shader
    for m in profile['materials']:
        for key,value in m['options'].items():
            if key in ['variant','tint','glow']:continue
            # Private dressing contract from surface-refinement/BRIEF.md, not
            # common material-language options. Shared integration checked below.
            if key=='variation_mode':
                assert value in ['none','organic','manufactured'];continue
            if key in ['variation_strength','variation_scale','variation_seed']:
                lo,hi={'variation_strength':(0,1),'variation_scale':(.01,1),'variation_seed':(0,2147483647)}[key]
                assert math.isfinite(value) and lo<=value<=hi
                if key=='variation_seed':assert type(value) is int
                continue
            match=re.search(r'"'+key+r'": \[([\d.-]+), ([\d.-]+),',bounds)
            assert match and float(match[1])<=value<=float(match[2]),key
    walls=arena['terrain']['walls']
    binary_start=20+n+8
    def accessor(index):
        a=glb['accessors'][index];view=glb['bufferViews'][a['bufferView']]
        fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
        width={'SCALAR':1,'VEC3':3}[a['type']]
        size=struct.calcsize('<'+fmt*width)
        offset=binary_start+view.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from('<'+fmt*width,raw,offset+i*view.get('byteStride',size)) for i in range(a['count'])]
    actual=[]
    for mesh in glb['meshes']:
        for primitive in mesh['primitives']:
            points=accessor(primitive['attributes']['POSITION'])
            indices=[i[0] for i in accessor(primitive['indices'])]
            actual.extend([[points[indices[i+j]] for j in range(3)] for i in range(0,len(indices),3)])
    for m in mounts:
        triangles=[w['vertices'] for w in walls if w['id']==m['support']]
        assert triangles,m
        slope=.14 if m['axis']=='q' else .14+11/53
        tangent=[1/math.sqrt(1+slope*slope),0,slope/math.sqrt(1+slope*slope)] if m['axis']!='x' else [0,0,1]
        # GLB meshes are already in Godot coordinates; verify actual exported backing.
        actual_near=[tri for tri in actual if all(min(p[i] for p in tri)-.001<=m['face'][i]<=max(p[i] for p in tri)+.001 for i in range(3))]
        assert any(inside(m['face'],tri) for tri in actual_near),(m['id'],'GLB backing')
        # Check a 5x5 footprint grid against the UNION of actual source triangles.
        for s in [-.5,-.25,0,.25,.5]:
            for t in [-.5,-.25,0,.25,.5]:
                p=[m['face'][i]+s*m['size'][0]*tangent[i]+(t*m['size'][1] if i==1 else 0) for i in range(3)]
                assert any(inside(p,tri) for tri in triangles),(m['id'],p)
    # Signs use a conservative 0.55 em character width and 0.7m cap height.
    for sign in profile['signs']:
        assert sign['size'][0]/len(sign['text'])>=.3,sign['id']
    assert len(profile['panels'])<=profile['budgets']['panels']
    assert len(profile['signs'])<=profile['budgets']['signs']
    assert sum(p['count'] for p in profile['pockets'])<=profile['budgets']['motes']
    for pocket in profile['pockets']:
        assert pocket['kind'] in ['dust','pollen','ash','mist','vent']
        assert all(0<s<=5 for s in pocket['size'])
        assert -192<pocket['position'][0]<192 and -144<pocket['position'][2]<144
    originals={}
    for path in [RECIPE,'tools/godot-multiplayer/new-maps/gravemill-foundry/gravemill-foundry.blend',
                 'port/native-multiplayer-worlds/worlds/gravemill-foundry.json',
                 'godot/material_language/families.gd','godot/material_language/library.gd',
                 'godot/material_language/family.gdshader']:
        originals[path]=hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
    return dict(geometry_hash=HASH,glb_sha256=hashlib.sha256(raw).hexdigest(),
        profile_sha256=hashlib.sha256((json.dumps(profile,indent=2)+'\n').encode()).hexdigest(),
        variation_contract='BRIEF.md; local bounds checked; shared validator must pass after rendering-owner integration',
        material_coverage='8/8',embedded_source_textures=0,panels=len(profile['panels']),
        signs=len(profile['signs']),motes=sum(p['count'] for p in profile['pockets']),
        face_samples=len(mounts)*25,resources=resources,mounts=mounts,source_provenance=originals,
        native_render_validation='pending integration grant; source checks only')

if __name__=='__main__':
    report=validate()
    PROFILE.parent.mkdir(parents=True,exist_ok=True)
    PROFILE.write_text(json.dumps(profile,indent=2)+'\n')
    (HERE/'source-validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ['resources','mounts']},indent=2))
