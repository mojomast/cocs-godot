"""Seeded editable Observatory master and seven-material production GLB.

HEAVY SLOT REQUIRED:
  LP_NUM_THREADS=1 blender -b -t 1 --python <this file> -- --slot-granted [--render]
No collision is inferred from art. The generated source arena is authority.
"""
import sys
if '--slot-granted' not in sys.argv:
    raise SystemExit('Explicit parent Blender/engine slot grant required')
import bpy
import math
import json
import random
import hashlib
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[4]
ID = 'parallax-observatory'
DATA = json.loads((ROOT / 'godot/multiplayer_worlds/generated' / (ID + '.json')).read_text())
A, ART = DATA['arena'], DATA['art']
random.seed(ART['seed'])
OUT = ROOT / 'godot/multiplayer_worlds/art' / ID
OUT.mkdir(parents=True, exist_ok=True)
MASTER = Path(__file__).parent / (ID + '.blend')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene['geometryHash'] = DATA['geometryHash']
scene['recipeHash'] = DATA['recipeHash']
scene['source_authority'] = 'port/multiplayer-worlds/derived/core.mjs'
source = bpy.data.collections.new('EDITABLE - authority and architectural craft')
scene.collection.children.link(source)
export = bpy.data.collections.new('EXPORT - seven material batches')
scene.collection.children.link(export)
materials, groups = {}, {}
for name, value in ART['palette'].items():
    color = tuple(int(value[i:i+2], 16) / 255 for i in (1, 3, 5))
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = tuple(c ** 2.2 for c in color) + (1,)
    node.inputs['Roughness'].default_value = .28 if name == 'mirror' else .78
    node.inputs['Metallic'].default_value = .72 if name in ('mirror', 'metal') else .05
    materials[name] = mat

def emit(name, vertices, faces, material='saltstone', authority=False):
    # Source Y-up -> Blender Z-up -> glTF Y-up, with no native collider bake.
    verts = [(x, -z, y) for x, y, z in vertices]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    source.objects.link(obj)
    obj.data.materials.append(materials[material])
    obj['geometryHash'] = DATA['geometryHash']
    obj['source_collision'] = authority
    batch = groups.setdefault(material, [[], []])
    start = len(batch[0])
    batch[0].extend(verts)
    batch[1].extend([tuple(start+i for i in f) for f in faces])
    return obj

def box(name, x, y, z, w, h, d, material='metal', authority=False):
    v = [(x+sx*w/2, y+sy*h/2, z+sz*d/2) for sy in (-1, 1) for sz in (-1, 1) for sx in (-1, 1)]
    return emit(name, v, [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)], material, authority)

def beam(name, a, b, width, material='metal'):
    a, b = Vector(a), Vector(b)
    direction = (b-a).normalized()
    u = direction.cross(Vector((0,1,0)))
    if u.length < .01:
        u = direction.cross(Vector((1,0,0)))
    u.normalize()
    v = direction.cross(u).normalized()
    verts = [tuple(p+u*s*width/2+v*t*width/2) for p in (a,b) for s,t in ((-1,-1),(1,-1),(1,1),(-1,1))]
    emit(name, verts, [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)], material)

def ring(name, center, radius, width, u=(1,0,0), v=(0,0,1), material='metal', n=64):
    c, u, v = Vector(center), Vector(u), Vector(v)
    points = [c+radius*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)) for i in range(n)]
    for i in range(n):
        beam(name+'.%02d'%i, points[i], points[(i+1)%n], width, material)

def inscription(name,text,x,y,z,side,size=.45):
    bpy.ops.object.text_add()
    obj=bpy.context.object
    obj.data.body=text
    obj.data.align_x='CENTER'
    obj.data.size=size
    obj.data.extrude=.006
    obj.data.resolution_u=3
    bpy.ops.object.convert(target='MESH')
    mesh=obj.data
    verts=[(x+side*v.co.z,y+v.co.y,z-side*v.co.x) for v in mesh.vertices]
    faces=[tuple(p.vertices) for p in mesh.polygons]
    emit(name,verts,faces,'ochre')
    bpy.data.objects.remove(obj,do_unlink=True)

def clip(poly,a,b,inside=True):
    # All floor regions share the source's piecewise planar height function.
    # Subtract earlier footprints to render their union without coplanar faces.
    sign=1 if inside else -1
    def dist(p): return sign*((b[0]-a[0])*(p[2]-a[2])-(b[2]-a[2])*(p[0]-a[0]))
    out=[]
    for i,p in enumerate(poly):
        q=poly[(i+1)%len(poly)];dp,dq=dist(p),dist(q)
        if dp>=-1e-7: out.append(p)
        if dp*dq<0:
            t=dp/(dp-dq);out.append([p[k]+t*(q[k]-p[k]) for k in range(3)])
    return out
def area(poly):
    return abs(sum(p[0]*poly[(i+1)%len(poly)][2]-poly[(i+1)%len(poly)][0]*p[2] for i,p in enumerate(poly)))/2 if len(poly)>2 else 0
covered=[]
for s in A['terrain']['surfaces']:
    if not s.get('walkable',True):
        emit('SOURCE.floor.'+s['id'],s['vertices'],s['triangles'],s['material'],True)
        continue
    pieces=[s['vertices']]
    for old in covered:
        updated=[]
        for piece in pieces:
            if max(p[0] for p in piece)<min(p[0] for p in old) or min(p[0] for p in piece)>max(p[0] for p in old) or max(p[2] for p in piece)<min(p[2] for p in old) or min(p[2] for p in piece)>max(p[2] for p in old):
                updated.append(piece);continue
            remainder=piece
            for i,a in enumerate(old):
                if len(remainder)<3: break
                b=old[(i+1)%len(old)]
                outside=clip(remainder,a,b,False)
                if area(outside)>1e-6: updated.append(outside)
                remainder=clip(remainder,a,b,True)
        pieces=updated
    # clip expects positive XZ orientation; source upward faces are clockwise.
    covered.append(list(reversed(s['vertices'])))
    for i,piece in enumerate(pieces):
        if area(piece)>1e-6: emit('SOURCE.union.'+s['id']+'.'+str(i),piece,[(0,j,j+1) for j in range(1,len(piece)-1)],s['material'],True)
for wall in A['terrain']['walls']:
    if wall['id'].startswith('cliff-'):
        continue  # Exact same source cliff plane is split into strata below.
    emit('SOURCE.wall.'+wall['id'], wall['vertices'], [(0,i,i+1) for i in range(1,len(wall['vertices'])-1)], wall['material'], True)
    if wall['id'].startswith('parapet') and wall['id'].endswith('-tri-1'):
        p,q = wall['vertices'][1:3]
        beam('ochre-edge.'+wall['id'], p,q,.12,'ochre')
    if wall['id'].startswith('parapet') and wall['id'].endswith('-tri-0'):
        p,q=wall['vertices'][:2]
        # Salt-cliff masonry strata with dark sea-weathered footing. Each
        # boundary strip terminates in the water, not a floating platform.
        last=[p,q]
        for j in range(1,7):
            t=j/6
            lower=[[v[0],v[1]*(1-t)-17*t,v[2]] for v in [p,q]]
            emit('chalk-stratum.'+wall['id']+'.'+str(j),last+list(reversed(lower)),[(0,1,2,3)],'saltstone' if j%3 else 'paving')
            if j%2==0: beam('salt-layer.'+wall['id']+'.'+str(j),*lower,.045,'paving')
            last=lower
        # Recessed blind instrument bays make the coastal retaining walls read
        # as inhabited institute foundations. Panels remain flush against the
        # authoritative cliff plane, with solid backing and no false doorway.
        a,b=Vector(p),Vector(q)
        length=(b-a).length
        if length>1.8:
            tangent=(b-a).normalized()
            normal=Vector((-tangent.z,0,tangent.x))*.035
            center=(a+b)*.5
            for level in [center.y-4,center.y-10]:
                center.y=level
                if level < -13: continue
                u=Vector((tangent.x,0,tangent.z))*min(length*.37,1.05)
                v=Vector((0,1.35,0))
                emit('blind-cliff-bay.'+wall['id']+str(level),[tuple(center-u-v+normal),tuple(center+u-v+normal),tuple(center+u+v+normal),tuple(center-u+v+normal)],[(0,1,2,3)],'metal')
                for h in [-.8,0,.8]:
                    c=center+Vector((0,h,0))+normal*2
                    emit('bay-transom.'+wall['id']+str(level)+str(h),[tuple(c-u),tuple(c+u),tuple(c+u+Vector((0,.09,0))),tuple(c-u+Vector((0,.09,0)))],[(0,1,2,3)],'ochre')
            # Projecting vertical pier stays below the playable deck.
            beam('cliff-pilaster.'+wall['id'],(p[0],-16,p[2]),(p[0],p[1]-.12,p[2]),.22,'paving')
for b in A['blocks']:
    bottom = b.get('baseY',0)
    box('SOURCE.block.'+b['id'], b['x'],(bottom+b['h'])/2,b['z'],b['w'],b['h']-bottom,b['d'],b['material'],True)
    # Flush ribs on source-solid instrument cabinets, no extra player blocker.
    if 'vault-jamb' in b['id']:
        side=-1 if b['x'] < (-36 if 'ephemeris' in b['id'] else 24) else 1
        xx=b['x']+side*(b['w']/2+.03)
        box('portal-recess.'+b['id'],xx,bottom+2.35,b['z'],.045,3.8,3.3,'metal')
        for j in range(5):
            zz=b['z']-1.45+j*.725
            box('portal-flute.'+b['id']+str(j),xx+side*.025,bottom+2.35,zz,.035,3.6,.065,'ochre')
        for yy in [bottom+.3,bottom+4.4]:
            box('portal-plinth.'+b['id']+str(yy),xx,yy,b['z'],.12,.2,4.4,'paving')
    if b['material'] == 'metal':
        for i in range(5):
            box('cabinet-rib.'+b['id']+'.'+str(i),b['x']-b['w']*.4+i*b['w']*.2,bottom+.6,b['z']-b['d']/2-.012,.035,.7,.02,'ochre')
    if b['id'].startswith('institute-wing'):
        # Deep cornices, recessed window bands and service hatches sit on the
        # actual source-solid tower skin. No transparent visual airwall.
        for level in range(14,int(b['h']),3):
            for side in (-1,1):
                for j in range(int(b['w']/2)):
                    xx=b['x']-b['w']/2+1+j*2
                    zz=b['z']+side*(b['d']/2+.018)
                    box('recessed-optics.'+b['id']+'.%d.%d.%d'%(level,side,j),xx,level,zz,1.3,1.5,.028,'mirror')
                    box('window-mullion.'+b['id']+'.%d.%d.%d'%(level,side,j),xx,level,zz+side*.02,.08,1.5,.04,'ochre')
            box('wing-cornice.'+b['id']+'.'+str(level),b['x'],level+1,b['z'],b['w']+.12,.16,b['d']+.12,'saltstone')
        box('wing-attic.'+b['id'],b['x'],b['h']+.6,b['z'],b['w']*.7,1.2,b['d']*.7,'metal')
        for j in range(6):
            xx=b['x']-b['w']*.4+j*b['w']*.16
            beam('wing-roof-fins.'+b['id']+'.'+str(j),(xx,b['h']+1.2,b['z']-1),(xx,b['h']+2.4,b['z']+1),.18,'ochre')

def transform(local, spec):
    x,y,z = local
    t = spec.get('tilt',.2)
    return (spec['x']+x, spec['y']+y*math.cos(t)-z*math.sin(t), spec['z']+y*math.sin(t)+z*math.cos(t))

for spec in ART['landmarks']:
    name, r = spec['id'], spec['r']
    if spec['kind'] == 'dish':
        # Folded panel paraboloid: broken outer petals, dark radial trusses,
        # ochre calibration fiducials and a real receiver tripod silhouette.
        n, bands = 40, 7
        for band in range(bands):
            for i in range(n):
                if band >= 5 and i in (7,8,9,25,26):
                    continue
                vertices=[]
                for radial, angular in ((band,i),(band+1,i),(band+1,i+1),(band,i+1)):
                    rr=max(.25,radial*r/bands)
                    ang=angular*math.tau/n
                    yy=rr*rr/(r*2.6)
                    if band>=5 and i in (6,10,24,27):
                        yy += (radial-5)*2.1
                    vertices.append(transform((rr*math.cos(ang),yy,rr*math.sin(ang)),spec))
                emit(name+'.mirror-petal.%d.%d'%(band,i),vertices,[(0,1,2,3)],'mirror' if i%5 else 'metal')
        for i in range(20):
            ang=i*math.tau/20
            for j in range(1,7):
                def p(k):
                    rr=k*r/7
                    return transform((rr*math.cos(ang),rr*rr/(r*2.6)-.35,rr*math.sin(ang)),spec)
                beam(name+'.back-truss.%d.%d'%(i,j),p(j),p(j+1),.35)
        focus=transform((0,r*.69,0),spec)
        for ang in (0,math.tau/3,math.tau*2/3):
            beam(name+'.receiver-tripod',transform((r*.7*math.cos(ang),r*.2,r*.7*math.sin(ang)),spec),focus,.55)
        box(name+'.receiver',*focus,2.3,3,2.3,'ochre')
        # Non-accessible cliff anchor entirely beyond the playable deck.
        box(name+'.concrete-foundation',spec['x'],-2,spec['z'],12,30,12,'saltstone')
        beam(name+'.azimuth-yoke',(spec['x'],12,spec['z']),transform((0,-1,0),spec),4)
        ring(name+'.azimuth-gear',(spec['x'],14,spec['z']),8,.8,material='ochre',n=48)
        for level,rad in [(13,10),(18,10),(23,8),(27,6)]:
            ring(name+'.instrument-drum-'+str(level),(spec['x'],level,spec['z']),rad,.35,material='saltstone',n=32)
        for j in range(24):
            a=j*math.tau/24;b=(j+1)*math.tau/24
            vertices=[]
            for y,rad in [(13,10),(23,8)]:
                vertices.extend([(spec['x']+rad*math.cos(t),y,spec['z']+rad*math.sin(t)) for t in [a,b]])
            emit(name+'.faceted-instrument-drum-'+str(j),vertices,[(0,1,3,2)],'metal' if j%3 else 'mirror')
            beam(name+'.drum-buttress-'+str(j),vertices[0],vertices[2],.28,'ochre')
    elif spec['kind'] == 'armillary':
        center=(spec['x'],spec['y']+8,spec['z'])
        for i,(u,v) in enumerate([((1,0,0),(0,1,0)),((0,0,1),(0,1,0)),((1,0,0),(0,.65,.76))]):
            ring(name+'.orbital-'+str(i),center,r-i,.4,u,v,'ochre' if i==2 else 'metal')
        # All overhead ring geometry is > player height; no center pedestal.
        for x in (-15,15):
            beam(name+'.canted-support',(x,33,-93),(x*.6,45,-87),1.1)
    else:
        # Slanted segmented copperless observatory dome, with open shutter slot.
        for j in range(6):
            for i in range(24):
                if i in (5,6):
                    continue
                verts=[]
                for band,sector in ((j,i),(j,i+1),(j+1,i+1),(j+1,i)):
                    ph=band*math.pi/12;ang=sector*math.tau/24
                    verts.append(transform((r*math.cos(ph)*math.cos(ang),r*math.sin(ph),r*math.cos(ph)*math.sin(ang)),spec))
                emit(name+'.shell.%d.%d'%(j,i),verts,[(0,1,2,3)],'metal' if i%3 else 'saltstone')

# Calibration inlays, star-chart rings and mirror fiducials are flush paint.
for radius in (5,10,16):
    ring('lens-dais.inlay-'+str(radius),(0,12.025,0),radius,.055,material='ochre',n=64)
for route in DATA['routes']:
    for i,p in enumerate(route['points']):
        box(route['id']+'.route-marker.'+str(i),p['x'],p['y']+.018,p['z'],.3,.015,1.4,'ochre')
    for i,(a,b) in enumerate(zip(route['points'],route['points'][1:])):
        dx,dz=b['x']-a['x'],b['z']-a['z'];length=math.hypot(dx,dz)
        nx,nz=-dz/length,dx/length
        for j in range(int(length/3)):
            t=(j+.5)/int(length/3);x=a['x']+dx*t;z=a['z']+dz*t
            def floor_y(zz): return 24 if zz < -60 else 12+(-zz-12)/4 if zz < -12 else 12 if zz<=12 else 12-(zz-12)/4 if zz<60 else 0
            for side in (-1,1):
                xx,zz=x+nx*side*route['width']*.32,z+nz*side*route['width']*.32
                beam(route['id']+'.survey-tick.%d.%d.%d'%(i,j,side),(xx-nx*.7,floor_y(zz-nz*.7)+.025,zz-nz*.7),(xx+nx*.7,floor_y(zz+nz*.7)+.025,zz+nz*.7),.035,'ochre')
for name,x,z,y in [('ephemeris',-36,0,12),('pump',24,78,0)]:
    for i in range(7):
        # Ceiling ribs and instrument pipe runs sit above source head clearance.
        box(name+'.ceiling-coffer.'+str(i),x-11+i*3.6,y+4.73,z,.2,.12,14,'ochre')
    for dz in (-6.8,6.8):
        beam(name+'.conduit',(x-12,y+3.8,z+dz),(x+12,y+3.8,z+dz),.22,'metal')
    for side in (-1,1):
        for i in range(8):
            box(name+'.datum-tile.'+str(side)+'.'+str(i),x-10+i*2.8,y+1.8,z+side*7.17,.65,.36,.025,'mirror')

# Monumental roof lanterns, nested ribs and instrument galleries. Each roof
# begins above the checked source slab; interiors keep every clear doorway.
for name,x,z,y,w,d in [('ephemeris',-36,0,12,26,16),('pump',24,78,0,26,16),('polar',0,-84,24,37,25),('arcade',69,0,12,30,17)]:
    roof=next(r for r in A['overhead'] if (name=='ephemeris' and r['id'].startswith('ephemeris')) or (name=='pump' and r['id'].startswith('tidal')) or (name=='polar' and r['id'].startswith('polar')) or (name=='arcade' and r['id'].startswith('optical')))
    top=roof['maxY'];underside=roof['minY']
    for j in range(9):
        xx=x-w/2+j*w/8
        for k in range(12):
            a=k*math.pi/12;b=(k+1)*math.pi/12
            p=(xx,top+3.4*math.sin(a),z+d*.46*math.cos(a))
            q=(xx,top+3.4*math.sin(b),z+d*.46*math.cos(b))
            beam(name+'.vault-roof-rib.%d.%d'%(j,k),p,q,.2,'ochre')
            if j<8:
                emit(name+'.faceted-roof.%d.%d'%(j,k),[p,q,(q[0]+w/8,q[1],q[2]),(p[0]+w/8,p[1],p[2])],[(0,1,2,3)],'metal' if k%3 else 'mirror')
        # Intrados coffers remain directly below the source ceiling at head-safe height.
        beam(name+'.ceiling-beam.'+str(j),(xx,underside-.12,z-d*.44),(xx,underside-.12,z+d*.44),.22,'ochre')
    for side in (-1,1):
        for j in range(9):
            xx=x-w*.44+j*w*.11
            zz=z+side*(d/2-.86)
            # Wall engravings and deep display stacks only in the two sealed
            # side-wall vaults; polar/arcade open portals remain entirely clear.
            if name in ('ephemeris','pump'):
                for level in range(3):
                    box(name+'.archive-panel.%d.%d.%d'%(side,j,level),xx,y+.8+level,zz,1.8,.8,.045,'mirror' if name=='ephemeris' else 'ochre')
                    for m in range(4):
                        box(name+'.instrument-slot.%d.%d.%d.%d'%(side,j,level,m),xx-.3+m*.2,y+.8+level,zz-side*.035,.025,.4,.04,'metal')
            beam(name+'.roof-eave.%d.%d'%(side,j),(xx,top+.08,zz),(xx,top+.08,zz+side*.25),.18,'saltstone')
    for side in (-1,1):
        xx=x+side*(w/2+.035)
        # Layered lintel and calibration inscription, well above real opening.
        box(name+'.portal-frieze.'+str(side),xx,underside+.28,z,.08,.3,d*.82,'ochre')
        for k in range(17):
            box(name+'.portal-scale.%d.%d'%(side,k),xx+side*.055,underside+.29,z-d*.36+k*d*.045,.03,.15,.04,'metal')
        inscription(name+'.title.'+str(side),{'ephemeris':'EPHEMERIS  /  PLATE ARCHIVE','pump':'TIDAL HYDROMETRY  /  03','polar':'POLAR  SPECTROMETER','arcade':'OPTICAL CALIBRATION'}[name],xx+side*.12,underside+.55,z,side,.48 if name!='polar' else .65)
    # Repeated overhead lamps are visual fixtures, with matching native light
    # placements installed by the scoped presentation helper.
    for j in (-1,0,1):
        box(name+'.luminaire.'+str(j),x+j*w*.3,underside-.18,z,1.3,.14,.65,'ochre')

# Wall-hugging ribbed service plumbing gives the lower vault a different use
# and rhythm from the flat photographic plate cabinets of the archive.
for side in (-1,1):
    z=78+side*7.08
    for j in range(8):
        x=14+j*2.8
        beam('cistern-pressure-pipe',(x,.35,z),(x,3.9,z),.14,'metal')
        ring('cistern-pressure-dial',(x,2.8,z-side*.08),.36,.07,(1,0,0),(0,1,0),'mirror',16)
        beam('cistern-needle',(x,2.8,z-side*.12),(x+.2,3,z-side*.12),.035,'ochre')

# Large calibration yard instruments are bound to the actual source cover
# cabinets. Vertical faceted reflectors break monotony without a phantom wall.
for b in A['blocks']:
    if 'meridian-calibrator' in b['id']:
        x,z,y=b['x'],b['z'],b['h']
        for j in range(5):
            box(b['id']+'.datum-grid-'+str(j),x-1.2+j*.6,y-.8,z-b['d']/2-.012,.045,1.3,.018,'ochre')
        box(b['id']+'.inset-mirror',x,y-.8,z-b['d']/2-.02,2.6,1.3,.012,'mirror')

# Polar hall's four wall-mounted optical benches and radial spectrometer
# plates make a dedicated scientific interior, not an empty roofed junction.
for x in (-12,12):
    for side in (-1,1):
        z=-84+side*11.48
        center=(x,28,z)
        ring('polar-wall-spectrometer',center,2.3,.13,(1,0,0),(0,1,0),'ochre',48)
        for j in range(12):
            a=j*math.tau/12
            beam('spectral-spoke',(x+.65*math.cos(a),28+.65*math.sin(a),z),(x+2.1*math.cos(a),28+2.1*math.sin(a),z),.065,'mirror')
        for level in (25.5,30.5):
            box('polar-data-band',x,level,z,9,.26,.04,'metal')
            for j in range(12):
                box('polar-spectral-tick',x-4+j*.72,level,z-side*.025,.05,.19,.02,'ochre')

# A radial datum court is the hall's measuring instrument, with overhead
# coaxial rings and a ribbed ceiling. Everything stays flush to its source
# floor or safely attached just beneath the inaccessible ceiling slab.
for j in range(32):
    a=j*math.tau/32;b=(j+1)*math.tau/32
    vertices=[(r*math.cos(t),24.019,-84+r*math.sin(t)) for r,t in [(3,a),(8,a),(8,b),(3,b)]]
    emit('polar-azimuth-floor-'+str(j),vertices,[(0,1,2,3)],'paving' if j%2 else 'metal')
    beam('polar-ceiling-radius-'+str(j),(2*math.cos(a),31.8,-84+2*math.sin(a)),(10*math.cos(a),31.8,-84+10*math.sin(a)),.11,'ochre')
for r in [3,5.5,8]:
    ring('polar-survey-circle-'+str(r),(0,24.025,-84),r,.025,material='ochre',n=64)
    ring('polar-ceiling-coffer-'+str(r),(0,31.8,-84),r,.15,material='metal',n=48)

# Deeply articulated engaged piers and wall dados distinguish supported
# interior walls from generic boxes, without narrowing their real portals.
for name,x,z,y,half,ceiling in [('archive',-36,0,12,7.18,16.8),('pump',24,78,0,7.18,4.8)]:
    for side in [-1,1]:
        zz=z+side*half
        for j in range(9):
            xx=x-11.5+j*2.875
            box(name+'.engaged-pier-'+str(side)+str(j),xx,y+2,zz,.19,4,.08,'paving')
            box(name+'.pier-capital-'+str(side)+str(j),xx,ceiling-.35,zz,.5,.25,.12,'ochre')
        for level in [.25,3.7]:
            box(name+'.wall-dado-'+str(side)+str(level),x,y+level,zz,24,.12,.08,'paving')

# Non-accessible coastal foundation fins articulate the exposed cliffs. These
# lie below all playable floors and read as engineered buttresses, not props.
for route in DATA['routes'][:3]:
    for p in route['points']:
        for side in (-1,1):
            box(route['id']+'.foundation-fin',p['x']+side*4,(p['y']-17)/2-.08,p['z'],.7,p['y']+17-.16,2.5,'paving')

# Flush calibration paving is source-height-following and deliberately
# district-specific. These inlays break long empty ramps into legible bays.
def ground(zz): return 24 if zz < -60 else 12+(-zz-12)/4 if zz < -12 else 12 if zz<=12 else 12-(zz-12)/4 if zz<60 else 0
for route in DATA['routes'][:3]:
    for i,(a,b) in enumerate(zip(route['points'],route['points'][1:])):
        dx,dz=b['x']-a['x'],b['z']-a['z'];length=math.hypot(dx,dz)
        ux,uz=dx/length,dz/length;nx,nz=-uz,ux
        for j in range(max(1,int(length/4))):
            t=(j+.5)/max(1,int(length/4));x,z=a['x']+dx*t,a['z']+dz*t
            for side in [-1,1]:
                cx,cz=x+nx*side*route['width']*.27,z+nz*side*route['width']*.27
                points=[(cx+nx*s+ux*h,cz+nz*s+uz*h) for s,h in [(-1.2,-1.3),(1.2,-1.3),(1.2,1.3),(-1.2,1.3)]]
                if any(min(zz for xx,zz in points)<edge<max(zz for xx,zz in points) for edge in [-60,-12,12,60]): continue
                emit('survey-inlay.'+route['id']+str(i)+str(j)+str(side),[(xx,ground(zz)+.009,zz) for xx,zz in points],[(0,1,2,3)],'paving' if route['id']!='tidal-cistern' else 'metal')
                # Small central datum facet gives each broad slab a readable
                # optical alignment rather than an arbitrary checkerboard.
                emit('survey-diamond.'+route['id']+str(i)+str(j)+str(side),[(cx+nx*s+ux*h,ground(cz+nz*s+uz*h)+.012,cz+nz*s+uz*h) for s,h in [(-.4,0),(0,-.7),(.4,0),(0,.7)]],[(0,1,2,3)],'ochre')

# Chasm water is below lethal source void height; a presentation plane only.
box('moonlit-tidal-chasm',0,-20,0,480,.1,400,'sea')
for i in range(34):
    x=random.uniform(-175,175);z=random.uniform(-110,110)
    box('tidal-current-'+str(i),x,-19.92,z,random.uniform(3,20),.015,.08,'mirror')

triangles=sum(sum(len(f)-2 for f in faces) for verts,faces in groups.values())
assert triangles <= ART['budgets']['triangles'], triangles
assert len(groups) <= ART['budgets']['materialBatches']
for material,(verts,faces) in groups.items():
    mesh=bpy.data.meshes.new('batch.'+material)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new('PARALLAX.'+material,mesh)
    export.objects.link(obj)
    obj.data.materials.append(materials[material])
    obj['geometryHash']=DATA['geometryHash']
    obj['recipeHash']=DATA['recipeHash']
source.hide_render=True
source.hide_viewport=True
for obj in bpy.context.selected_objects:
    obj.select_set(False)
for obj in export.objects:
    obj.select_set(True)
glb=OUT/(ID+'.glb')
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_extras=True,export_yup=True)
assert glb.stat().st_size <= ART['budgets']['glbBytes']

scene.world.use_nodes=True
scene.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.22,.28,.42,1)
scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.65
for roof in A['overhead']:
    for j in (-1,0,1):
        ld=bpy.data.lights.new(roof['id']+'.review-light.'+str(j),'AREA')
        ld.energy=350
        ld.shape='DISK'
        ld.size=4
        ob=bpy.data.objects.new(ld.name,ld)
        scene.collection.objects.link(ob)
        ob.location=(roof['x']+j*roof['w']*.3,-roof['z'],roof['minY']-.4)
scene.render.engine='CYCLES'
scene.cycles.device='CPU'
scene.cycles.samples=12
scene.render.threads_mode='FIXED'
scene.render.threads=1
scene.render.resolution_x=1600
scene.render.resolution_y=1000
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
light_data=bpy.data.lights.new('moon','SUN')
light_data.energy=2.2
light=bpy.data.objects.new('moon',light_data)
scene.collection.objects.link(light)
light.rotation_euler=(.55,-.45,-.6)
for spec in ART['cameras']:
    camera_data=bpy.data.cameras.new(spec['id'])
    camera_data.clip_end=1000
    camera_data.lens=32 if spec['id']=='overview' else 22
    camera=bpy.data.objects.new(spec['id'],camera_data)
    scene.collection.objects.link(camera)
    x,y,z=spec['eye'];camera.location=(x,-z,y)
    x,y,z=spec['target'];target=Vector((x,-z,y))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    if '--render' in sys.argv:
        scene.camera=camera
        evidence=Path('/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002/blender-review')
        evidence.mkdir(parents=True,exist_ok=True)
        scene.render.filepath=str(evidence/(spec['id']+'.png'))
        bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(MASTER),compress=True)
report={'id':ID,'geometryHash':DATA['geometryHash'],'recipeHash':DATA['recipeHash'],'seed':ART['seed'],'triangles':triangles,'materialBatches':len(groups),'editableObjects':len(source.objects),'glbBytes':glb.stat().st_size,'glbSha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'blendSha256':hashlib.sha256(MASTER.read_bytes()).hexdigest(),'nativeAcceptance':'pending'}
(OUT/'asset-manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
