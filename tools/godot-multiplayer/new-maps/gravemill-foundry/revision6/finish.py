"""Source-only finish planning on immutable R5 triangles; no engine imports."""
import collections
import itertools
import json
import math
from pathlib import Path
import struct
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
R5 = HERE.parent / 'revision5'
GLB = ROOT / 'godot/multiplayer_worlds/art/revisions/gravemill-foundry-r5.glb'
sys.path.insert(0, str(ROOT / 'tools/map-variety-pipeline'))
from material_pack import load_pack, sha
from glb_contract import parts as glb_parts, from_parts, values

def read(p): return json.loads(p.read_text())
def write(p, value):
    p.write_text(json.dumps(value, separators=(',',':'))+'\n' if p.name=='finish-plan.json' else json.dumps(value, indent=2)+'\n')
def key(points): return tuple(sorted(tuple(round(x, 4) for x in p) for p in points))
def sub(a, b): return tuple(x-y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def length(a): return math.sqrt(sum(x*x for x in a))

def access(doc, blob, index):
    return values(from_parts(doc,blob),index)

def primitives(doc, blob):
    glb=from_parts(doc,blob)
    for index in glb.foundry_node_order:
        node=doc['nodes'][index]
        if 'mesh' not in node: continue
        assert not any(k in node for k in ('translation','rotation','scale','matrix'))
        for pi,p in enumerate(doc['meshes'][node['mesh']]['primitives']):
            assert p.get('mode',4)==4
            streams={k:values(glb,v) for k,v in p['attributes'].items()}
            assert all(k in streams for k in ('POSITION','NORMAL','TANGENT','TEXCOORD_0'))
            ids=[v[0] for v in values(glb,p['indices'])]
            yield node,pi,p,streams,[ids[i:i+3] for i in range(0,len(ids),3)]

def provenance():
    result=collections.defaultdict(set)
    terrain=read(R5/'candidate.json')['arena']['terrain']
    for s in terrain['surfaces']+terrain['walls']:
        if s['id'].startswith('R5'): continue
        vertices=s['vertices']
        # Source polygon triangulation can choose either diagonal. Match vertex
        # membership, never a nearest-centroid guess across adjacent buildings.
        faces=s.get('triangles') or list(itertools.combinations(range(len(vertices)),3))
        for face in faces: result[key([vertices[i] for i in face])].add(s['id'])
    for ident,triangles in read(R5/'component-triangles.json').items():
        for tri in triangles: result[key(tri)]={ident}
    return result

def choose(ident, old, node, center, normal):
    """Whole architectural parts first; original-role fallback is conservative."""
    if old=='GM / orange': return old,'preserved luminaire'
    if ident.startswith(('crusher-drum','crusher-cap')): return 'R6 / machine','crusher rotating steel shell'
    if ident.startswith('crusher-bed'): return 'R6 / plinth','crusher cast foundation'
    if ident.startswith('crusher-process-roof'): return 'R6 / roof','crusher folded ribbed steel roof'
    if ident.startswith('crusher-house'):
        if any(s in ident for s in ('end-','lintel')): return 'R6 / plinth','crusher cast end frame'
        return 'R6 / wall','crusher mineral infill'
    if ident.startswith(('kiln-','furnace-hall')): return 'R6 / refractory','kiln warm refractory masonry'
    if ident.startswith('G5.'):
        if any(s in ident for s in ('surge','body','hopper')): return 'R6 / ore-shell','ore-bin oxidized iron shell'
        if any(s in ident for s in ('live-bottom','discharge')): return 'R6 / machine','ore-bin dark discharge machinery'
        if any(s in ident for s in ('foot','base')): return 'R6 / plinth','ore-bin cast base'
        if any(s in ident for s in ('cap','hood')): return 'R6 / machine','ore-bin dark hood'
    if ident.startswith('G1.') and any(s in ident for s in ('gear','hook','shoe')): return 'R6 / ore-shell','localized handling wear'
    if ident.startswith('G2.') and any(s in ident for s in ('casing','tap')): return 'R6 / machine','furnace service machinery'
    if ident.startswith('G3.') and any(s in ident for s in ('arch','jamb')): return 'R6 / refractory','tipple masonry frame'
    if ident.startswith('cooling-nave-'):
        if 'vault' in ident: return old,'cooling copper vault retained'
        if any(s in ident for s in ('pier','header')): return 'R6 / wall','cooling mineral structure'
        if any(s in ident for s in ('sill','jamb')): return 'R6 / plinth','cooling splash-resistant base'
    if ident.startswith('assay-') and 'roof' not in ident: return old,'assay guidance retained'
    # Never recolor copper by assuming its name means rust. Furnace vessels and
    # cooling vault retain brand green; only identified crusher roofing changes.
    if node=='Gravemill / mineral' and abs(normal[1])>.8 and not ident:
        return 'R6 / ground','quiet aggregate ground instead of giant cast grid'
    if node=='Gravemill / soot' and not ident:
        if abs(normal[1])<.65: return 'R6 / machine','legacy steel trim, not plaster'
    return old,'retained R5 role'

def plan():
    raw=GLB.read_bytes();doc,blob=glb_parts(raw);r5=read(R5/'export-report.json')
    assert sha(raw)==r5['glb']['sha256']
    assert sha((R5/'gravemill-foundry-revision5.blend').read_bytes())==r5['master']['sha256']
    bindings=read(HERE/'bindings.json');resources,pack=load_pack(ROOT)
    assert all(b['resource'] in resources for b in bindings.values())
    prov=provenance();rows=[];counts=collections.Counter();areas=collections.Counter();reasons=collections.Counter();batches=0
    old_density={n:1/b['tileMeters'] for n,b in r5['moth']['materials'].items()}
    for node,pi,p,streams,faces in primitives(doc,blob):
        old=doc['materials'][p['material']]['name'];roles=[];ids=[];used=set()
        for face in faces:
            tri=[streams['POSITION'][i] for i in face];matches=sorted(prov.get(key(tri),()))
            # Source contact aliases can coincide. Prefer visible surface names.
            ident=next((s for s in matches if 'contact' not in s),matches[0] if matches else '')
            normal=cross(sub(tri[1],tri[0]),sub(tri[2],tri[0]));size=length(normal)
            unit=tuple(x/size for x in normal) if size else (0,1,0)
            center=tuple(sum(v[k] for v in tri)/3 for k in range(3))
            role,reason=choose(ident,old,node['name'],center,unit)
            roles.append(role);ids.append(ident);used.add(role);counts[role]+=1;areas[role]+=size/2;reasons[reason]+=1
        scales={role:(1/resources[bindings[role]['resource']]['tileMeters'])/old_density[old] if role in bindings else 1 for role in used}
        batches+=len(used)
        rows.append({'node':node['name'],'primitive':pi,'oldMaterial':old,'roles':roles,'sourceIds':ids,'uvScale':scales})
    return {'visualRevision':6,'status':'source plan; build/native visual acceptance pending','geometryHash':read(R5/'candidate.json')['geometryHash'],
        'sourceGLBSha256':sha(raw),'sourceMasterSha256':r5['master']['sha256'],'authoritySha256':sha((R5/'candidate.json').read_bytes()),
        'bindingsSha256':sha((HERE/'bindings.json').read_bytes()),'pack':pack,'triangles':sum(counts.values()),'plannedPrimitives':batches,
        'trianglesByRole':dict(counts),'squareMetresByRole':dict(areas),'reasons':dict(reasons),'assignments':rows}

if __name__=='__main__':
    result=plan();write(HERE/'finish-plan.json',result)
    print(json.dumps({k:v for k,v in result.items() if k!='assignments'},indent=2))
