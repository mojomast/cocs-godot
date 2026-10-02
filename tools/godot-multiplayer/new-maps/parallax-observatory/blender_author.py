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

for s in A['terrain']['surfaces']:
    emit('SOURCE.floor.'+s['id'], s['vertices'], s['triangles'], s['material'], True)
    if s.get('walkable', True):
        # Structural chalk footings terminate below the void plane. Faceted
        # stripes are attached to the exact deck outline, never floating islands.
        for i, p in enumerate(s['vertices']):
            q = s['vertices'][(i+1)%len(s['vertices'])]
            if math.hypot(q[0]-p[0],q[2]-p[2]) < .01:
                continue
            emit('chalk-footing.'+s['id']+'.'+str(i), [p,q,[q[0],-17,q[2]],[p[0],-17,p[2]]], [(0,1,2,3)], 'saltstone')
for wall in A['terrain']['walls']:
    emit('SOURCE.wall.'+wall['id'], wall['vertices'], [(0,1,2),(0,2,3)], wall['material'], True)
    if wall['id'].startswith('parapet'):
        p,q = wall['vertices'][2:4]
        beam('ochre-edge.'+wall['id'], p,q,.12,'ochre')
for b in A['blocks']:
    bottom = b.get('baseY',0)
    box('SOURCE.block.'+b['id'], b['x'],(bottom+b['h'])/2,b['z'],b['w'],b['h']-bottom,b['d'],b['material'],True)
    # Flush ribs on source-solid instrument cabinets, no extra player blocker.
    if b['material'] == 'metal':
        for i in range(5):
            box('cabinet-rib.'+b['id']+'.'+str(i),b['x']-b['w']*.4+i*b['w']*.2,bottom+.6,b['z']-b['d']/2-.012,.035,.7,.02,'ochre')

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
    elif spec['kind'] == 'armillary':
        center=(spec['x'],spec['y'],spec['z'])
        for i,(u,v) in enumerate([((1,0,0),(0,1,0)),((0,0,1),(0,1,0)),((1,0,0),(0,.65,.76))]):
            ring(name+'.orbital-'+str(i),center,r-i,.4,u,v,'ochre' if i==2 else 'metal')
        # All overhead ring geometry is > player height; no center pedestal.
        for x in (-10,10):
            beam(name+'.canted-support',(x,25,-91),(x*.6,34,-87),.65)
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
for name,x,z,y in [('ephemeris',-36,0,12),('pump',24,78,0)]:
    for i in range(7):
        # Ceiling ribs and instrument pipe runs sit above source head clearance.
        box(name+'.ceiling-coffer.'+str(i),x-11+i*3.6,y+4.73,z,.2,.12,14,'ochre')
    for dz in (-6.8,6.8):
        beam(name+'.conduit',(x-12,y+3.8,z+dz),(x+12,y+3.8,z+dz),.22,'metal')
    for side in (-1,1):
        for i in range(8):
            box(name+'.datum-tile.'+str(side)+'.'+str(i),x-10+i*2.8,y+1.8,z+side*7.17,.65,.36,.025,'mirror')

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

scene.world.color=(.07,.08,.13)
scene.render.engine='BLENDER_EEVEE_NEXT'
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
    camera_data.lens=24 if spec['id']=='overview' else 22
    camera=bpy.data.objects.new(spec['id'],camera_data)
    scene.collection.objects.link(camera)
    x,y,z=spec['eye'];camera.location=(x,-z,y)
    x,y,z=spec['target'];target=Vector((x,-z,y))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    if '--render' in sys.argv:
        scene.camera=camera
        scene.render.filepath=str(OUT/(spec['id']+'.png'))
        bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(MASTER))
report={'id':ID,'geometryHash':DATA['geometryHash'],'recipeHash':DATA['recipeHash'],'seed':ART['seed'],'triangles':triangles,'materialBatches':len(groups),'editableObjects':len(source.objects),'glbBytes':glb.stat().st_size,'glbSha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'blendSha256':hashlib.sha256(MASTER.read_bytes()).hexdigest(),'nativeAcceptance':'pending'}
(OUT/'asset-manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
