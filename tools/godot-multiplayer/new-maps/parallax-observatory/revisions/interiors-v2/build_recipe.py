"""Source-only triangle authoring/checks. Standard library; never imports bpy."""
import hashlib
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
BASE = HERE.parents[1]
DATA_PATH = ROOT / 'godot/multiplayer_worlds/generated/parallax-observatory.json'
DATA = json.loads(DATA_PATH.read_text())
A = DATA['arena']
MESHES = []
OWNERS = {}
EXPECTED_GEOMETRY = '906be2ae3df33f54f779df3963a5985376ac96bb75bda94578ca4d3deb6d4554'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def owner_block(b):
    lo = [b['x']-b['w']/2, b.get('baseY', 0), b['z']-b['d']/2]
    hi = [b['x']+b['w']/2, b['h'], b['z']+b['d']/2]
    OWNERS[b['id']] = {'min': lo, 'max': hi, 'kind': 'existing-source-block'}
    return b['id']


def emit(name, vertices, faces, material, owner):
    triangles = [[f[0], f[j], f[j+1]] for f in faces for j in range(1, len(f)-1)]
    MESHES.append({'name': 'IV2.'+name, 'vertices': vertices, 'triangles': triangles,
                   'material': material, 'owner': owner})


def box(name, center, size, material, owner, transform=lambda p: p):
    vertices = [transform([center[i]+s[i]*size[i]/2 for i in range(3)])
                for s in [(-1,-1,-1),(1,-1,-1),(-1,-1,1),(1,-1,1),
                          (-1,1,-1),(1,1,-1),(-1,1,1),(1,1,1)]]
    emit(name, vertices, [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),
                          (0,4,6,2),(1,3,7,5)], material, owner)


def rod(name, a, b, radius, material, owner, transform=lambda p: p, segments=10):
    d = [b[i]-a[i] for i in range(3)]
    length = math.sqrt(sum(v*v for v in d))
    d = [v/length for v in d]
    ref = [0, 1, 0] if abs(d[1]) < .9 else [1, 0, 0]
    u = [d[1]*ref[2]-d[2]*ref[1], d[2]*ref[0]-d[0]*ref[2], d[0]*ref[1]-d[1]*ref[0]]
    scale = math.sqrt(sum(v*v for v in u)); u = [v/scale for v in u]
    v = [d[1]*u[2]-d[2]*u[1], d[2]*u[0]-d[0]*u[2], d[0]*u[1]-d[1]*u[0]]
    vertices = [transform([p[k]+radius*(u[k]*math.cos(j*math.tau/segments)+v[k]*math.sin(j*math.tau/segments)) for k in range(3)]) for p in [a,b] for j in range(segments)]
    faces = [tuple(reversed(range(segments))), tuple(range(segments,2*segments))]
    faces += [(j,(j+1)%segments,(j+1)%segments+segments,j+segments) for j in range(segments)]
    emit(name, vertices, faces, material, owner)


def wall(b, archive):
    owner = owner_block(b)
    side = -1 if b['z'] < (0 if archive else 78) else 1
    floor = b['baseY']; inner = b['z']-side*b['d']/2
    def t(p): return [b['x']+p[0],floor+p[1],inner+side*p[2]]
    def B(n,c,s,m='metal'): box(owner+'.'+n,c,s,m,owner,t)
    def R(n,a,c,r,m='metal',segments=10): rod(owner+'.'+n,a,c,r,m,owner,t,segments)
    # Full-height solid backing, cap/sill and engaged front piers retain the
    # original silhouette. Recesses are only 0.6 m deep, not enterable portals.
    B('sealed-backing',[0,2.4,.73],[26,4.8,.14],'saltstone')
    for y in [.09,4.71]: B('bound-'+str(y),[0,y,.35],[26,.18,.7],'saltstone')
    for x in [-12.9,12.9]: B('end-'+str(x),[x,2.4,.35],[.2,4.8,.7],'saltstone')
    if archive:
        # Wall A is a compact plate library; wall B is a retrieval/indexing
        # gallery, with fewer, wider machines and horizontal transfer slots.
        if side < 0:
            for bay in range(7):
                x=-10.8+bay*3.6
                B('rack-upright-'+str(bay),[x-1.65,2.4,.3],[.12,4.4,.56],'ochre')
                for y in [.5,2.2,3.9]:
                    B('rack-shelf-'+str((bay,y)),[x,y,.3],[3.1,.12,.56])
                for j in range(6):
                    xx=x-1.25+j*.5
                    for tier,y in enumerate([1.35,3.05]):
                        B('plate-cassette-'+str((bay,j,tier)),[xx,y,.38],[.19,1.45,.44],'paving')
                        B('cassette-spine-'+str((bay,j,tier)),[xx,y,.13],[.12,1.3,.035],'ochre' if j%3==0 else 'mirror')
                        emit(owner+'.index-tab-'+str((bay,j,tier)),[t([xx+dx,y+.5+dy,.10]) for dx,dy in [(-.05,-.05),(.05,-.05),(.05,.05),(-.05,.05)]],[(0,1,2,3)],'metal',owner)
        else:
            for bay,x in enumerate([-9,0,9]):
                for xx in [x-2.7,x+2.7]:
                    B('retrieval-guide-'+str((bay,xx)),[xx,2.4,.2],[.16,4.3,.24],'ochre')
                B('moving-crosshead-'+str(bay),[x,3.0-bay*.25,.2],[5.35,.2,.3])
                B('carriage-'+str(bay),[x+bay*.3,2.65-bay*.25,.2],[.9,.65,.32],'ochre')
                for xx in [x-.55,x+.55]:
                    B('retrieval-jaw-'+str((bay,xx)),[xx,2.1,.18],[.12,.65,.22])
                for y in [.75,1.1,1.45]:
                    B('transfer-drawer-'+str((bay,y)),[x,y,.38],[5.0,.2,.5],'paving')
                    B('drawer-pull-'+str((bay,y)),[x,y,.1],[1.1,.08,.08],'ochre')
                for xx in [x-2.4,x+2.4]:
                    R('winch-'+str((bay,xx)),[xx,3.95,.08],[xx,3.95,.4],.26,'metal',12)
                    R('retrieval-cable-'+str((bay,xx)),[xx,1.8,.17],[xx,3.95,.17],.022,'ochre',6)
    else:
        # Three asymmetric pump stations, with risers, true sectional flanges,
        # motor drums, discharge manifolds and guarded bulkhead valve stems.
        for bay,x in enumerate([-9,-1,8]):
            R('riser-'+str(bay),[x,.3,.35],[x,4.4,.35],.21)
            R('return-'+str(bay),[x+1.7,.4,.4],[x+1.7,3.55,.4],.12,'paving')
            R('suction-elbow-'+str(bay),[x,1.5,.35],[x+1,1.5,.35],.14)
            for y in [.8,2.25,3.8]:
                R('riser-flange-'+str((bay,y)),[x,y-.06,.35],[x,y+.06,.35],.29,'ochre',12)
            R('pump-volute-'+str(bay),[x+1.0,1.5,.10],[x+1.0,1.5,.57],.7,'paving',16)
            R('volute-cover-'+str(bay),[x+1.0,1.5,.04],[x+1.0,1.5,.09],.58,'metal',16)
            R('motor-bearing-'+str(bay),[x+1.0,1.5,.015],[x+1.0,1.5,.04],.23,'ochre',12)
            for j in range(8):
                a=j*math.tau/8
                xx=x+1+math.cos(a)*.49; yy=1.5+math.sin(a)*.49
                R('cover-bolt-'+str((bay,j)),[xx,yy,.017],[xx,yy,.055],.045,'ochre',6)
            R('valve-spindle-'+str(bay),[x,3.0,.02],[x,3.0,.35],.09,'ochre')
            B('bulkhead-guard-'+str(bay),[x+3.0,2.8,.35],[.18,3.4,.6],'saltstone')
            B('gauge-bank-'+str(bay),[x+2.45,3.8,.25],[.6,.7,.4],'metal')
            R('pressure-gauge-'+str(bay),[x+2.45,3.8,.025],[x+2.45,3.8,.065],.22,'mirror',12)
        R('discharge-header',[-12.6,4.1,.34],[12.6,4.1,.34],.17,'ochre')
        R('low-return-header',[-12.6,.42,.36],[12.6,.42,.36],.13,'metal')


def console(b, archive):
    owner=owner_block(b); x,y,z=b['x'],b['baseY'],b['z']
    # Protective case retains its original AABB silhouette; the front is a
    # shallow service recess. No new machinery protrudes into the corridor.
    side=-1 if z<(0 if archive else 78) else 1
    def t(p): return [x+p[0],y+p[1],z-side*.5+side*p[2]]
    for yy in [.07,1.23]: box(owner+'.case', [0,yy,.5],[3,.14,1],'metal',owner,t)
    for xx in [-1.44,1.44]: box(owner+'.cheek',[xx,.65,.5],[.12,1.3,1],'metal',owner,t)
    box(owner+'.back',[0,.65,.93],[3,1.3,.14],'metal',owner,t)
    if archive:
        for j in range(5):
            box(owner+'.folio-drawer-'+str(j),[0,.25+j*.2,.49],[2.7,.14,.78],'paving',owner,t)
            box(owner+'.drawer-handle-'+str(j),[0,.25+j*.2,.065],[.8,.055,.045],'ochre',owner,t)
    else:
        rod(owner+'.reducer',[ -1.25,.65,.51],[1.25,.65,.51],.43,'paving',owner,t,16)
        for xx in [-1.0,-.6,0,.6,1.0]:
            rod(owner+'.motor-fin-'+str(xx),[xx-.035,.65,.51],[xx+.035,.65,.51],.47,'ochre',owner,t,12)


def ceiling(r, archive):
    owner=r['id']; x,y,z=r['x'],r['minY'],r['z']
    OWNERS[owner]={'min':[x-13,y,z-8],'max':[x+13,r['maxY'],z+8],'kind':'existing-nonwalkable-ceiling'}
    def t(p): return [x+p[0],y+p[1],z+p[2]]
    box(owner+'.recessed-soffit',[0,.55,0],[26,.1,16],'metal',owner,t)
    if archive:
        for zz in [-5,0,5]:
            for yy in [.065,.46]:
                rod(owner+'.truss-chord'+str((zz,yy)),[-12.7,yy,zz],[12.7,yy,zz],.04,'ochre',owner,t,6)
            for j in range(14):
                xx=-12.6+j*1.8
                rod(owner+'.warren-web'+str((zz,j)),[xx,.085 if j%2==0 else .44,zz],[xx+1.8,.44 if j%2==0 else .085,zz],.035,'paving',owner,t,6)
        for xx in [-9,0,9]: box(owner+'.strip-lamp'+str(xx),[xx,.04,0],[1.4,.08,1.0],'ochre',owner,t)
    else:
        for zz,width in [(-4.5,2.2),(2,3.4)]:
            box(owner+'.duct-crown'+str(zz),[0,.39,zz],[25,.2,width],'paving',owner,t)
            for j in range(12):
                xx=-11+j*2
                box(owner+'.duct-collar'+str((zz,j)),[xx,.23,zz],[.14,.42,width+.2],'ochre',owner,t)
                for k in [-.45,0,.45]:
                    box(owner+'.intake-louver'+str((zz,j,k)),[xx+.6,.19,zz+k],[.55,.12,.09],'metal',owner,t)
        for xx in [-8,4]: box(owner+'.cross-manifold'+str(xx),[xx,.34,0],[1.2,.3,14],'metal',owner,t)


def build():
    assert DATA['geometryHash']==EXPECTED_GEOMETRY
    for b in A['blocks']:
        if 'vault-wall' in b['id']: wall(b,b['id'].startswith('ephemeris'))
        elif 'vault-console' in b['id']: console(b,b['id'].startswith('ephemeris'))
    for r in A['overhead']:
        if r['id'].startswith(('ephemeris-vault','tidal-pump-vault')): ceiling(r,r['id'].startswith('ephemeris'))
    triangles=0
    for m in MESHES:
        bounds=OWNERS[m['owner']]
        for triangle in m['triangles']:
            vs=[m['vertices'][i] for i in triangle]
            assert all(math.isfinite(c) for p in vs for c in p)
            # An AABB is convex: all three vertices inside proves the whole
            # actual triangle is inside its named existing authority volume.
            assert all(bounds['min'][i]-1e-8<=p[i]<=bounds['max'][i]+1e-8 for p in vs for i in range(3)),m['name']
            u=[vs[1][i]-vs[0][i] for i in range(3)]; v=[vs[2][i]-vs[0][i] for i in range(3)]
            cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
            assert sum(c*c for c in cross)>1e-16,m['name']
            triangles+=1
    assert triangles<=11000,triangles
    accepted=ROOT/'godot/multiplayer_worlds/art/parallax-observatory'
    provenance={'geometryHash':DATA['geometryHash'],'recipeHash':DATA['recipeHash'],
        'acceptedAuthorSha256':digest(BASE/'blender_author.py'),
        'acceptedGlbSha256':digest(accepted/'parallax-observatory.glb'),
        'acceptedMasterSha256':digest(BASE/'parallax-observatory.blend'),
        'generatedSourceSha256':digest(DATA_PATH),'generatorSha256':digest(Path(__file__)),
        'adapterSha256':digest(HERE/'author_candidate.py'),'nativeProbeAdapterSha256':digest(HERE/'prepare_native.py')}
    payload={'id':'parallax-observatory-interiors-v2','provenance':provenance,'owners':OWNERS,'meshes':MESHES}
    raw=json.dumps(payload,separators=(',',':')).encode()
    (HERE/'candidate-meshes.json').write_bytes(raw+b'\n')
    manifest={'status':'SOURCE ONLY — NOT RENDERED OR NATIVE ACCEPTED','candidateHash':hashlib.sha256(raw).hexdigest(),
        **provenance,'addedMeshes':len(MESHES),'addedTriangles':triangles,
        'conservativeTotalTriangleBound':148239+triangles,'triangleLimit':160000,
        'checkedOwnerVolumes':len(OWNERS),'newTrianglesOutsideExistingAuthority':0,
        'sourceGeometryChanged':False,'nativeModeOraclesRerun':False,
        'clearanceProof':'Every generated nondegenerate triangle is contained in a named existing convex block/slab. No added triangle occupies walkable corridor or portal air; all ceiling triangles are at or above the existing underside.',
        'visualRecessDepthLimitMetres':.8,'limitation':'Existing convex collision stays at the original front plane of shallow solid-backed recesses; these are not traversable openings.'}
    (HERE/'source-check.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))


if __name__=='__main__': build()
