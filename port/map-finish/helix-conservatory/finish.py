#!/usr/bin/env python3
"""Source-only deterministic authoring and fail-closed spatial/resource audit.

No engine, imports, original asset writes, or third-party dependencies.
Run from any directory; --write regenerates this lane's profile/proof/cameras.
"""
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import sys

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
PROFILE = ROOT / 'godot/multiplayer_worlds/dressing/profiles/helix-conservatory.json'
HASH = 'f068d1abe262907659f1f02205e2bf56b7c5dbe298191f66d008b420965fa9b2'
GLB_HASH = '0c462ffa475f02aa388101c38339d6d81eb3df9549a7d664ca65ec390c802d88'
SEED = 610022
def load(path):
    return json.loads(path.read_text())
def sub(a,b): return [x-y for x,y in zip(a,b)]
def add(a,b): return [x+y for x,y in zip(a,b)]
def mul(a,s): return [x*s for x in a]
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def cross(a,b): return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def unit(a): return mul(a,1/math.sqrt(dot(a,a)))
def rounded(a): return [round(x,6) for x in a]
def require(condition, message):
    if not condition: raise ValueError(message)

def glb():
    raw=(ROOT/'godot/multiplayer_worlds/art/helix-conservatory/helix-conservatory.glb').read_bytes()
    require(hashlib.sha256(raw).hexdigest()==GLB_HASH,'accepted GLB identity changed')
    magic,version,length=struct.unpack_from('<III',raw)
    require(magic==0x46546c67 and version==2 and length==len(raw),'invalid GLB')
    size,kind=struct.unpack_from('<II',raw,12)
    doc=json.loads(raw[20:20+size]); start=20+size
    bsize,bkind=struct.unpack_from('<II',raw,start)
    binary=raw[start+8:start+8+bsize]
    def accessor(index):
        a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
        code,scalar={5126:('f',4),5125:('I',4),5123:('H',2),5121:('B',1)}[a['componentType']]
        width={'VEC3':3,'SCALAR':1}[a['type']];stride=v.get('byteStride',scalar*width)
        offset=v.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from('<'+code*width,binary,offset+i*stride) for i in range(a['count'])]
    # Source batches have identity transforms; converted text labels are excluded.
    triangles={}
    for node in doc['nodes']:
        if node.get('name','').startswith('wayfinding-'): continue
        require(not any(k in node for k in ['matrix','translation','rotation','scale']),'unexpected batch transform')
        for p in doc['meshes'][node['mesh']]['primitives']:
            name=doc['materials'][p['material']]['name'];pos=accessor(p['attributes']['POSITION'])
            idx=[i[0] for i in accessor(p['indices'])]
            for i in range(0,len(idx),3):
                tri=[pos[j] for j in idx[i:i+3]]
                key=tuple(sorted(tuple(round(x,3) for x in q) for q in tri))
                triangles.setdefault(name,set()).add(key)
    return doc,triangles

def family_catalog():
    # Extract only the data-table family blocks; resolve literal keys exactly as
    # library._shape does (variant inherits default normal/mask when omitted).
    import re
    text=(ROOT/'godot/material_language/families.gd').read_text()
    starts=list(re.finditer(r'^\t"([\w-]+)": \{',text,re.M));result={}
    for i,m in enumerate(starts):
        block=text[m.end():starts[i+1].start() if i+1<len(starts) else len(text)]
        base=re.search(r'"default": \{([^\n]+)',block).group(1)
        def fields(s): return dict(re.findall(r'"(base|normal|normal_source|mask)": "([\w-]+)"',s))
        variants={'default':fields(base)}
        vb=block.split('"variants": {',1)[1].split('\n\t\t},',1)[0]
        for v,body in re.findall(r'"([\w-]+)": \{([^\n]+)',vb): variants[v]={**fields(base),**fields(body)}
        lut=re.search(r'"lut": "([\w-]+)"',block).group(1)
        result[m.group(1)]={'variants':variants,'lut':lut}
    return result

def build():
    recipe=load(ROOT/'port/new-maps/helix-conservatory/revision-2/recipe.json')
    meshes={m['id']:m for m in recipe['art']['meshes']}
    rng=random.Random(SEED)
    p={'version':1,'map_id':'helix-conservatory','geometry_hash':HASH,'materials':[],
       'panels':[],'signs':[],'pockets':[],'preserve_materials':['glass'],
       'budgets':{'material_variants':12,'panels':64,'signs':20,'motes':72}}
    treatments=[
      ('verdigris','oxidised-copper','default','5b8f79',.65,.64),
      ('soil','regolith','default','817153',1.4,.94),
      ('stone','regolith','mossy','899681',.85,.82),
      ('ceramic','pearl-ceramic','polished','c8d0bb',.6,.30),
      ('brick','pearl-ceramic','worn','ad8b68',.65,.79),
      ('gold','brushed-alloy','default','b4ab83',1.1,.46),
      ('solar','brushed-alloy','circuit','324b61',.7,.35),
      ('leaflight','regolith','verdant','99b95d',.9,.86),
      ('botanical','regolith','verdant','50713e',.9,.92)]
    for source,family,variant,tint,density,roughness in treatments:
        p['materials'].append({'source':source,'family':family,'options':{
          'variant':variant,'tint':tint,'tiles_per_metre':density,'roughness':roughness,
          'lut_gain':0.035 if source=='verdigris' else 0.0,'pulse_speed':0.0,'pulse_depth':0.0,
          'normal_strength':.18 if source in ['leaflight','botanical'] else .30}})
    proof=[]
    def mount(id,mesh_id,face,width,height,lift,texture=None,text=None,side=1,**finish_fields):
        m=meshes[mesh_id];v=[m['vertices'][i] for i in face]
        tangent=unit(sub(v[1],v[0]));require(abs(tangent[1])<.3,'nonvertical supporting edge')
        # Vertical sector/box face. +Z front deliberately points into its aisle.
        n=mul(unit(cross(sub(v[1],v[0]),sub(v[2],v[0]))),side)
        require(abs(n[1])<1e-7,'mount requires vertical support')
        xaxis=[n[2],0,-n[0]]
        center=mul(add(v[0],v[1]),.5);center[1]+=lift
        position=add(center,mul(n,.018))
        row={'id':id,'position':rounded(position),'rotation_degrees':[0,round(math.degrees(math.atan2(n[0],n[2])),6),0],
             'size':[round(width,6),round(height,6)],'essential':bool(text)}
        if text: row.update(text=text,foreground='e4ebd8',background='233e35');p['signs'].append(row)
        else:
            row.update(texture=texture,tint='7c8e6a' if 'root' in id or 'damp' in id else '81968b',**finish_fields)
            p['panels'].append(row)
        proof.append({'id':id,'mesh':mesh_id,'material':m['material'],'face':face,'normal':rounded(n),
                      'clearance_metres':.018,'role':'wayfinding' if text else 'bounded-weather/service-inset',
                      'support_center':rounded(center),'axes':{'x':rounded(xaxis),'y':[0,1,0]},'size':row['size']})
    # Retaining faces already interrupted at route gaps. Never use clerestory glass.
    groups=[('archive','archive-inner-retaining-','weathered_concrete-damp',.22),
            ('irrigation','irrigation-inner-wall-','metal-oxide',.18),
            ('pavilion','pavilion-inner-plinth-','weathered_concrete-worn',.22)]
    sign_texts={'archive':['01 / SEED ARCHIVE','RESEARCH AISLE','SERVICE AISLE'],
                'irrigation':['02 / FILTRATION','MAINTENANCE LOOP','ARCHIVE RING'],
                'pavilion':['03 / GERMINATION','CANOPY RING','INNER CHAMBER']}
    for district,prefix,texture,opacity in groups:
        candidates=[m for m in meshes.values() if m['id'].startswith(prefix) and m['collision']=='wall']
        candidates.sort(key=lambda m:m['id'])
        for i,m in enumerate(candidates[::max(1,len(candidates)//6)][:6]):
            length=math.dist(m['vertices'][0],m['vertices'][1]);w=min(length*.70,1.8)
            mount(f'{district}-damp-foot-{i}',m['id'],[0,1,5,4],w,.24,.27,texture,side=-1,
                  wear_mask='dust-field',opacity=opacity,feather=.15,seed=SEED+len(p['panels']))
            if i<3:
                # Two lines fit narrow arc facets at human-readable letter height.
                words=sign_texts[district][i];split=words.rfind(' ')
                words=words[:split]+'\n'+words[split+1:]
                mount(f'{district}-route-{i}',m['id'],[0,1,5,4],w,.66,1.65,text=words,side=-1)
    for i in range(3):
        mesh=f'pump-bank-{i}'
        mount(f'pump-access-{i}',mesh,[0,1,5,4],1.40,.75,1.8,'brushed_metal',normal='baked:metal')
        mount(f'pump-record-{i}',mesh,[0,1,5,4],1.40,.48,3.1,text=f'PUMP 0{i+1}\nISOLATION')
    # Local mineral waterlines at vessel bases, each constrained to one actual
    # faceted shell. Inward-facing sides are visible from maintenance routes.
    for vessel,lift in [('settling-vault',3.0),('filter-vault',2.5),('water-pressure-tower',2.0)]:
        for shell in [7,8,9]:
            mesh=f'{vessel}-shell-{shell}';m=meshes[mesh]
            width=math.dist(m['vertices'][0],m['vertices'][1])*.80
            mount(f'{vessel}-waterline-{shell}',mesh,[0,1,2,3],width,.18,lift,'metal-oxide',
                  wear_mask='dust-field',opacity=.18,feather=.15,seed=SEED+len(p['panels']))
    beds=[m for m in meshes.values() if m['id'].startswith('botanical-bed-') and m['collision']=='wall']
    # Seeded selection spread across all four plant districts and all three bands.
    selected=[]
    for district in ['fern','orchid','cycad','reed']:
        group=[m for m in beds if f'bed-{district}-' in m['id']];rng.shuffle(group);selected+=group[:4]
    for i,m in enumerate(selected):
        length=math.dist(m['vertices'][0],m['vertices'][1])
        mount(f'root-stain-{i}',m['id'],[0,1,5,4],min(length*.58,.85),.23,.24,'rock-moss',side=-1,
              wear_mask='dust-field',opacity=.30,feather=.15,seed=SEED+len(p['panels']))
        if i%4==0:
            center=mul(add(m['vertices'][4],m['vertices'][6]),.5)
            # Bed-grown fern fronds are .9m above support, up to ~2.4m tall.
            center[1]+=.9
            p['pockets'].append({'id':f'plant-pollen-{i//4}','kind':'pollen','position':rounded(center),
                                 'size':[1.4,1.6,1.4],'color':'c6c68a','count':12})
            proof.append({'id':f'plant-pollen-{i//4}','mesh':m['id'],'role':'pollen-inside-existing-fern-crown',
                          'bed_top':rounded(mul(add(m['vertices'][4],m['vertices'][6]),.5))})
    # Articulated root piers: calm maintenance label, no objective icon.
    mount('lightwell-specimen-record','specimen-root-37.5',[0,1,5,4],.48,.75,1.8,text='04\nCORE',side=-1)
    return p,proof,recipe

def audit(p,proof,recipe):
    doc,triangles=glb();names=[m['name'] for m in doc['materials']]
    authority=load(ROOT/'godot/multiplayer_worlds/generated/helix-conservatory.json')
    require(authority['geometryHash']==HASH,'runtime geometry identity changed')
    assigned=[r['source'] for r in p['materials']];preserved=p['preserve_materials']
    require(len(assigned)==len(set(assigned)),'duplicate exact selectors')
    require(set(assigned).isdisjoint(preserved),'assigned preserved surface')
    require(set(names)==set(assigned+preserved),'unmatched/invented material')
    require(p['geometry_hash']==HASH,'geometry hash mismatch')
    catalog=family_catalog();manifest=load(ROOT/'godot/moth/generated/manifest.json');derived=load(ROOT/'godot/moth/derived/manifest.json')['derived']
    resources={}
    def resolve(bucket,key):
        require(key in bucket,'missing Moth key '+key)
        record=bucket[key];path=ROOT/'godot'/record['path'].removeprefix('res://')
        require(path.is_file(),'missing Moth image '+str(path))
        raw=path.read_bytes();require(raw[:8]==b'\x89PNG\r\n\x1a\n','invalid PNG')
        require(list(struct.unpack_from('>II',raw,16))==[record['width'],record['height']],'image size mismatch')
        resources[record['path']]=hashlib.sha256(raw).hexdigest()
    import re
    lib=(ROOT/'godot/material_language/library.gd').read_text()
    bounds={k:(float(lo),float(hi)) for k,lo,hi in re.findall(r'"([\w_]+)": \[([\d.-]+), ([\d.-]+),',lib)}
    for row in p['materials']:
        require(row['family'] in catalog,'missing family');f=catalog[row['family']]
        require(row['options']['variant'] in f['variants'],'missing variant');v=f['variants'][row['options']['variant']]
        for k,val in row['options'].items():
            if k in ['tint','variant']: continue
            require(k in bounds and bounds[k][0]<=val<=bounds[k][1],'unsupported/out of range option '+k)
        resolve(manifest['textures'],v['base']);resolve(derived,'data--'+v['base'])
        resolve(derived,'normal--'+v['normal']) if v['normal_source']=='derived' else resolve(manifest['normals'],v['normal'])
        if v.get('mask'): resolve(derived,v['mask'])
        for channel in ['r','t']: resolve({channel:manifest['materials'][f['lut']][channel]},channel)
    for row in p['panels']:
        resolve(manifest['textures'],row['texture'])
        normal=row.get('normal',row['texture'])
        if normal.startswith('baked:'): resolve(manifest['normals'],normal.removeprefix('baked:'))
        elif normal in manifest['normals']: resolve(manifest['normals'],normal)
        else: resolve(derived,'normal--'+normal)
        if 'wear_mask' in row:
            resolve(manifest['textures'],row['wear_mask'])
            require(0<=row['opacity']<=1 and 0<=row['feather']<=.5 and isinstance(row['seed'],int) and 0<=row['seed']<=2147483647,'invalid wear controls')
    meshes={m['id']:m for m in recipe['art']['meshes']};entries={r['id']:r for r in p['panels']+p['signs']+p['pockets']}
    require(len(entries)==len(proof),'duplicate IDs or missing placement proof')
    def inside(point,a,b,c):
        u=sub(b,a);v=sub(c,a);q=sub(point,a);n=unit(cross(u,v))
        if abs(dot(q,n))>.00001:return False
        uu=dot(u,u);vv=dot(v,v);uv=dot(u,v);qu=dot(q,u);qv=dot(q,v);d=uu*vv-uv*uv
        s=(qu*vv-qv*uv)/d;t=(qv*uu-qu*uv)/d
        return s>=-1e-7 and t>=-1e-7 and s+t<=1+1e-7
    for item in proof:
        m=meshes[item['mesh']];row=entries[item['id']]
        require(m['material']!='glass','paint over glazing')
        # Every support triangle must exist in the accepted binary, not merely
        # in a prospective recipe. Quantization envelope is under .1mm.
        for t in m['triangles']:
            key=tuple(sorted(tuple(round(x,3) for x in m['vertices'][i]) for i in t))
            require(key in triangles[m['material']],'support triangle absent in GLB '+m['id'])
        if 'face' in item:
            v=[m['vertices'][i] for i in item['face']]
            yaw=math.radians(row['rotation_degrees'][1]);n=[math.sin(yaw),0,math.cos(yaw)];xaxis=[n[2],0,-n[0]]
            center=sub(row['position'],mul(n,.018))
            require(math.dist(center,item['support_center'])<.000002,'mount moved off support')
            require(dot(n,item['normal'])>.999999,'+Z orientation changed')
            for sx in [-1,1]:
                for sy in [-1,1]:
                    q=add(add(center,mul(xaxis,row['size'][0]*sx/2)),[0,row['size'][1]*sy/2,0])
                    require(inside(q,*v[:3]) or inside(q,v[0],v[2],v[3]),'quad corner outside supporting face '+row['id'])
            if 'text' in row:
                require(max(map(len,row['text'].splitlines())) <= row['size'][0]/.065+1,'sign text too wide '+row['id'])
                require(len(row['text'].splitlines())*.20<=row['size'][1],'sign text too tall')
        else:
            require(row['kind']=='pollen' and row['count']<=12,'unbounded/unsupported pocket')
            require(math.dist(row['position'],add(item['bed_top'],[0,.9,0]))<.000002,'pollen disconnected from bed')
        require(all(math.isfinite(x) for x in row['position']+row['size']),'nonfinite input')
        require(abs(row['position'][0])<=121 and abs(row['position'][2])<=121 and 0<=row['position'][1]<=50,'placement beyond arena')
    counts={'material_variants':len(p['materials']),'panels':len(p['panels']),'signs':len(p['signs']),'motes':sum(r['count'] for r in p['pockets'])}
    for k,n in counts.items():require(n<=p['budgets'][k],'budget exceeded '+k)
    return {'status':'source-ready-native-review-pending','geometry_hash':HASH,'glb_sha256':GLB_HASH,'seed':SEED,
            'counts':counts,'matched_materials':assigned,'preserved_materials':preserved,'unmatched_materials':[],
            'resources':resources,'placements':proof,'proof_scope':'All quad corners contained by recipe support faces; every support triangle decoded from accepted GLB. No rendered appearance claim.'}

def cameras(recipe):
    # Eyes sit on actual walkable floor triangles, not guessed elevations.
    def floor(x,z):
        for m in recipe['art']['meshes']:
            if not m.get('walkable'): continue
            for t in m['triangles']:
                a,b,c=[m['vertices'][i] for i in t];v0=[b[0]-a[0],b[2]-a[2]];v1=[c[0]-a[0],c[2]-a[2]];q=[x-a[0],z-a[2]]
                d=v0[0]*v1[1]-v0[1]*v1[0]
                if abs(d)<1e-10: continue
                u=(q[0]*v1[1]-q[1]*v1[0])/d;v=(v0[0]*q[1]-v0[1]*q[0])/d
                if u>=-1e-8 and v>=-1e-8 and u+v<=1+1e-8:return a[1]+u*(b[1]-a[1])+v*(c[1]-a[1]),m['id']
        raise ValueError('camera off actual floor')
    output=[]
    for district,r,a,target in [('archive',46.7,178,[-50,11,-8]),('irrigation',57, -15,[64,13,-17]),
                                ('pavilion',83,82,[15,18,86]),('lightwell',12,37.5,[0,13,0]),
                                ('botanical',26,38,[28,5,22])]:
        x=r*math.cos(math.radians(a));z=r*math.sin(math.radians(a));y,support=floor(x,z)
        output.append({'district':district,'closeup':{'position':rounded([x,y+1.65,z]),'look_at':target,'floor_mesh':support,'eye_height':1.65},
                       'overview':{'position':rounded([x*.78,y+22,z*.78]),'look_at':target},
                       'review':['same-camera before/after','full/low/off','normal gameplay and compact HUD','reload/teardown counts']})
    return {'status':'planned-not-rendered','renderer':'record actual native renderer and cadence','districts':output}

if __name__=='__main__':
    p,proof,recipe=build();report=audit(p,proof,recipe);cams=cameras(recipe)
    if '--self-test' in sys.argv:
        import copy
        cases=[]
        bad=copy.deepcopy(p);bad['panels'][0]['texture']='not-a-real-Moth-resource';cases.append(('missing resource',bad))
        bad=copy.deepcopy(p);bad['materials'][0]['options']['variant']='fictional';cases.append(('invented variant',bad))
        bad=copy.deepcopy(p);bad['panels'][0]['position'][2]+=1;cases.append(('floating placement',bad))
        bad=copy.deepcopy(p);bad['panels'][0]['size'][0]=20;cases.append(('overhanging face',bad))
        bad=copy.deepcopy(p);bad['budgets']['motes']=47;cases.append(('mote ceiling',bad))
        bad=copy.deepcopy(p);bad['materials'].pop();cases.append(('unmatched material',bad))
        for name,bad in cases:
            try: audit(bad,proof,recipe)
            except ValueError: pass
            else: raise ValueError('negative probe did not fail: '+name)
        print(json.dumps({'negative_probes_passed':[name for name,_ in cases]}))
    if '--write' in sys.argv:
        PROFILE.parent.mkdir(parents=True,exist_ok=True)
        for path,data in [(PROFILE,p),(HERE/'source-proof.json',report),(HERE/'native-jobs.json',cams)]:
            path.write_text(json.dumps(data,indent=2)+'\n')
    else:
        require(load(PROFILE)==p,'profile differs from seeded authoring output')
        require(load(HERE/'source-proof.json')==report,'source proof stale')
        require(load(HERE/'native-jobs.json')==cams,'planned cameras stale')
    print(json.dumps({'status':report['status'],'counts':report['counts'],'resolved_resources':len(report['resources']),'unmatched_materials':report['unmatched_materials']}))
