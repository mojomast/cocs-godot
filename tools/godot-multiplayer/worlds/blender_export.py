"""Deterministic, editable Blender master + batched glTF render mesh.

Invoke only after parent grants heavy work:
  blender -b -t 1 --python tools/godot-multiplayer/worlds/blender_export.py -- <map-id>
Each material has one mesh object (limited draw calls); the master preserves
named, individually editable mesh components in source collections.
"""
import json
import math
import pathlib
import sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from authored_detail import build as build_architecture
import bpy

ROOT = pathlib.Path(__file__).resolve().parents[3]
ID = sys.argv[sys.argv.index('--') + 1]
DATA = json.loads((ROOT / 'port/native-multiplayer-worlds/worlds' / (ID + '.json')).read_text())
ART = ROOT / 'godot/multiplayer_worlds/art/worlds'
ART.mkdir(parents=True, exist_ok=True)
MASTER = ROOT / 'tools/godot-multiplayer/worlds/masters'
MASTER.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0

COLORS = {
    'quay': (.34,.45,.48,1), 'tidal-silt': (.2,.39,.47,1), 'granite': (.51,.53,.54,1),
    'spillway': (.37,.55,.61,1), 'iron': (.26,.35,.38,1), 'coral': (.68,.29,.19,1),
    'teal': (.1,.42,.45,1), 'plaster': (.67,.7,.65,1), 'roof': (.24,.32,.37,1),
    'retaining': (.36,.39,.38,1), 'seawall': (.58,.57,.52,1), 'basalt': (.24,.29,.3,1),
    'snowcap': (.82,.88,.87,1), 'sandstone': (.69,.47,.29,1), 'ochre': (.65,.29,.14,1),
    'copper': (.58,.31,.19,1), 'pitch': (.13,.46,.41,1), 'water': (.09,.31,.43,1),
    'island-ground': (.34,.46,.35,1), 'causeway': (.56,.54,.43,1),
    'limestone': (.64,.6,.48,1),
    'safety-yellow': (.92,.61,.13,1), 'hazard-white': (.85,.85,.71,1),
    'rust': (.42,.21,.13,1), 'signal-red': (.82,.14,.1,1),
    'ice-blue': (.38,.71,.78,1), 'field-line': (.78,.86,.75,1),
    'deep-water': (.06,.22,.34,1), 'charcoal': (.08,.13,.17,1),
    'bronze': (.5,.32,.13,1), 'glow-amber': (.94,.54,.09,1),
    'sediment': (.30,.34,.32,1), 'cedar': (.18,.28,.25,1),
    'red-earth': (.43,.21,.13,1), 'salt': (.55,.66,.68,1),
}
materials={}
for name, color in COLORS.items():
    material=bpy.data.materials.new(name)
    material.diffuse_color=color
    material.use_nodes=True
    principled=material.node_tree.nodes.get('Principled BSDF')
    # Blender node colors are linear. Keep the port's non-photometric kit below
    # clipping under the actual Godot sun rather than flooding every slab white.
    # Avoid washed-out overhead slabs in the native daytime sun. Distinct
    # deliberately dark structural colors preserve form in ground-level views.
    factor=.37 if name in ('granite','plaster','sandstone','quay') else .55
    principled.inputs['Base Color'].default_value=tuple(c*factor for c in color[:3])+(1,)
    principled.inputs['Roughness'].default_value=.84 if name not in ('iron','water') else .42
    materials[name]=material

def collection(name):
    c=bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c

master=collection('SOURCE - editable architectural pieces')
render=collection('EXPORT - material batches')
groups={}
def emit(name, verts, faces, material, metadata=None):
    material=material if material in materials else 'retaining'
    # Recipes are Y-up, Blender is Z-up. glTF's export_yup rotates Blender Z
    # back into glTF Y; pre-rotate horizontal source Z into negative Blender Y.
    verts=[(x,-z,y) for x,y,z in verts]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj=bpy.data.objects.new(name, mesh)
    master.objects.link(obj)
    obj.data.materials.append(materials[material])
    obj['authoritative_geometry']='recipe'
    for key,value in (metadata or {}).items():
        if isinstance(value,(str,int,float,bool)): obj[key]=value
    group=groups.setdefault(material, [[],[]])
    start=len(group[0]);group[0].extend(verts)
    group[1].extend([tuple(start+i for i in face) for face in faces])

def cube(p, name):
    x,y,z,w,h,d=[p[k] for k in ('x','y','z','w','h','d')]
    verts=[(x+sx*w/2,y+sy*h/2,z+sz*d/2) for sy in (-1,1) for sz in (-1,1) for sx in (-1,1)]
    faces=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
    emit(name,verts,faces,p['material'],p)

def cone(p,name):
    x,y,z,w,h,d=[p[k] for k in ('x','y','z','w','h','d')]
    n=8;bottom=y-h/2
    ring=[(x+math.cos(i*math.tau/n)*w/2,bottom,z+math.sin(i*math.tau/n)*d/2) for i in range(n)]
    emit(name,ring+[(x,y+h/2,z)],[(i,(i+1)%n,n) for i in range(n)]+[tuple(reversed(range(n)))],p['material'],p)

def ramp(p,name):
    x,z,w,d=[p[k] for k in ('x','z','w','d')]
    a,b=p['y0'],p['y1']
    # End plates are vertical, top is a single continuous support strip.
    v=[(x-w/2,0,z-d/2),(x-w/2,0,z+d/2),(x+w/2,0,z+d/2),(x+w/2,0,z-d/2),
       (x-w/2,a,z-d/2),(x-w/2,a,z+d/2),(x+w/2,b,z+d/2),(x+w/2,b,z-d/2)]
    emit(name,v,[(4,5,6,7),(0,4,7,3),(1,2,6,5),(0,1,5,4),(3,7,6,2)],p['material'],p)

for index, ground in enumerate(DATA['art']['ground']):
    cube({**ground,'y':-.17 if index==0 else .005,'h':.3 if index==0 else .02},'ground.%03d'%index)

if ID=='tern-archipelago':
    def island(label,x,z,rx,rz,phase):
        outline=[]
        for i in range(14):
            a=math.tau*i/14
            r=.88+.10*math.sin(i*2.7+phase)+.04*math.cos(i*1.31+phase)
            outline.append((x+rx*math.cos(a)*r,z+rz*math.sin(a)*r))
        top=[(x,.034,z)]+[(px,.034,pz) for px,pz in outline]
        faces=[(0,i+1,(i+1)%14+1) for i in range(14)]
        emit(label+'.high-tide-bank',top,faces,'island-ground')
        outer=[(x+(px-x)*1.22,z+(pz-z)*1.22) for px,pz in outline]
        for i in range(14):
            j=(i+1)%14
            emit(label+'.faceted-shore.%02d'%i,
                 [(outline[i][0],.03,outline[i][1]),(outline[j][0],.03,outline[j][1]),
                  (outer[j][0],-.145,outer[j][1]),(outer[i][0],-.145,outer[i][1])],
                 [(0,1,2),(0,2,3)],'limestone' if i%3 else 'sediment')
        for i in range(14):
            a=outline[i];b=outline[(i+1)%14]
            emit(label+'.retaining-face.%02d'%i,
                 [(a[0],-.11,a[1]),(b[0],-.11,b[1]),(b[0],.034,b[1]),(a[0],.034,a[1])],
                 [(0,1,2,3)],'limestone')
    def link(label,a,b,width,level=.041,material='causeway'):
        dx=b[0]-a[0];dz=b[1]-a[1];length=math.hypot(dx,dz)
        if length<.001:return
        nx=-dz/length*width/2;nz=dx/length*width/2
        emit(label,[(a[0]+nx,level,a[1]+nz),(a[0]-nx,level,a[1]-nz),
                    (b[0]-nx,level,b[1]-nz),(b[0]+nx,level,b[1]+nz)],
             [(0,1,2,3)],material)
    for i,n in enumerate(DATA['nodes']):
        radius=(18,15) if n['archetype']=='hq' else (16,14) if n['archetype']=='front' else (16,16)
        island(n['id'],n['x'],n['z'],*radius,i*.7)
    # Physical source walk and vehicle lanes already exist at all these XZs.
    # Here the narrow dry crests expose the topology against low-tide shallows.
    for lane_index,lane in enumerate(DATA['lanes']):
        for i,(a,b) in enumerate(zip(lane['waypoints'],lane['waypoints'][1:])):
            link(lane['id']+'.%02d'%i,a,b,10 if lane_index==0 else 6,.041+lane_index*.004)
    for sign in (-1,1):
        for i,(a,b) in enumerate([((104*sign,-55),(104*sign,0)),
                    ((54*sign,8*sign),(8*sign,31*sign)),
                    ((54*sign,8*sign),(-8*sign,-31*sign))]):
            link('supply-crossing.%d.%d'%(sign,i),a,b,5,.055,'limestone')
for index,p in enumerate(DATA['art']['pieces']):
    # Four cisterns replace their source proxy boxes with radial tanks entirely
    # INSIDE the same authoritative 3.6 m square collision footprint.
    if ID=='breakwater-exchange' and p['kind']=='box' and p['z']==58 and p['h']==6 and abs(p['x']) in (70,79):
        continue
    # The three unsupported infield cones read as isolated traffic cones at
    # arena scale. Out-of-bound canyon landforms replace them below.
    if ID=='sirocco-circuit' and p['kind']=='cone':
        continue
    # Goal backboard remains source-solid collision, but the opaque proxy hid
    # the entire mouth from the actual player camera. Render its back wall as
    # an open framed net pocket in the detail pass instead.
    if ID=='copper-bowl' and p['kind']=='box' and p['w']==1 and p['d']==16 and p['h']==5:
        continue
    {'box':cube,'roof':cube,'cone':cone,'ramp':ramp}[p['kind']](p,'%s.%04d'%(p['kind'],index))

def detail(label,x,y,z,w,h,d,material):
    cube({'x':x,'y':y,'z':z,'w':w,'h':h,'d':d,'material':material},label)

def tube(label,x,y,z,radius,height,material,sides=12):
    vertices=[]
    for level in (-1,1):
        for i in range(sides):
            a=i*math.tau/sides
            vertices.append((x+radius*math.cos(a),y+level*height/2,z+radius*math.sin(a)))
    faces=[]
    for i in range(sides): faces.append((i,(i+1)%sides,(i+1)%sides+sides,i+sides))
    faces.extend([tuple(reversed(range(sides))),tuple(range(sides,sides*2))])
    emit(label,vertices,faces,material)

def surface_stripes(label,axis,at,start,end,step,width,material):
    count=0
    value=start
    while value<=end:
        x,z=(value,at) if axis=='x' else (at,value)
        detail(label+'.%02d'%count,x,-.015,z,width if axis=='x' else .18,.006,.18 if axis=='x' else width,material)
        value+=step;count+=1

def architecture():
    # Visual detail remains attached to a source-solid footprint, above its
    # unreachable roof, or flush as ground paint. No new phantom blocking prop.
    if ID=='breakwater-exchange':
        # Quay road dashed line and lateral gantry clearance markings.
        for z in (-14,18): surface_stripes('quay-freight-stripe','x',z,-86,86,9,3.5,'safety-yellow')
        for side in (-1,1):
            x=side*31
            for bx in (side*70,side*79):
                tube('ferry-pressure-tank',bx,3,58,1.72,6,'iron',16)
                for y in (.6,2.7,5.2): tube('ferry-tank-collar',bx,y,58,1.77,.12,'safety-yellow',16)
            # Nine corrugations per solid shipping container: face relief is
            # 4 cm, retaining its authoritative collision silhouette.
            for bx,bz in ((side*65,8),(side*37,-31)):
                for i in range(7):
                    zz=bz-4.1+i*1.35
                    detail('container-rib',bx-2.03,1.55,zz,.045,2.8,.11,'iron')
                    detail('container-rib',bx+2.03,1.55,zz,.045,2.8,.11,'iron')
                detail('container-rim',bx,2.93,bz,4.1,.12,10.1,'rust')
            # Two robust I-beams and pulley heads sit within the authored
            # overhead gantry slab; hoist cable ends well above Puma height.
            for zz in (-60,-52):
                detail('crane-lattice',x,12.9,zz,24,.32,.34,'safety-yellow')
                for px in (side*21,side*41):
                    detail('crane-corner-brace',px,10.7,zz,.32,3.2,.32,'rust')
            tube('hoist-wheel',x,12,-56,.9,.25,'safety-yellow')
            detail('crane-control-cab',x,13.3,-56,3,.55,3,'signal-red')
            # Seawall cap on existing merlon footprint.
            for px in (side*14,side*50,side*75):
                detail('dock-light-sill',px,2.62,66,9.8,.08,4.9,'hazard-white')
        for side in (-1,1):
            for xx in (side*26,side*36):
                tube('warehouse-exhaust',xx,7.35,41,.36,.6,'rust')
            # Warehouse wall signage and steel corner trim are inset onto
            # source wall coordinates; passages stay 6 m clear.
            detail('warehouse-id',side*31,4.8,32.95,7,1.3,.09,'safety-yellow')
    elif ID=='thermal-divide':
        for side in (-1,1):
            for x in (side*16,side*44,side*72):
                # Basalt blocks already provide full-height solid abutments.
                for y in (2.5,5.5,7.8):
                    detail('basalt-strata',x,y,55.48,6.8,.16,.08,'hazard-white')
            # Roof machines stay above a closed, nonwalkable roof slab.
            x=side*49
            for px in (x-5,x+5):
                tube('turbine-exhaust',px,7.5,15,1,.9,'iron')
                tube('thermal-collar',px,7.95,15,1.12,.12,'ice-blue')
            detail('turbine-pipe',x,8.2,15,14,.36,.36,'iron')
            detail('station-wayfinding',x,4.4,7.46,7,1.1,.09,'safety-yellow')
        # Narrow nonsolid parapet paint reinforces the actual bridge crown.
        for z in (35.22,42.78):
            detail('bridge-edge',0,4.015,z,54,.025,.13,'safety-yellow')
        for x in (-27,27):
            detail('bridge-expansion-joint',x,4.03,39,.18,.025,7.8,'rust')
    elif ID=='sirocco-circuit':
        line=DATA['race']['centerline']
        for i,a in enumerate(line):
            b=line[(i+1)%len(line)]
            dx=b['x']-a['x'];dz=b['z']-a['z'];length=math.hypot(dx,dz)
            for k in range(1,max(2,int(length//8))):
                t=k/max(2,int(length//8));x=a['x']+dx*t;z=a['z']+dz*t
                detail('centerline.%d.%d'%(i,k),x,.032,z,1.2,.02,1.2,'hazard-white')
            # Unique checkpoint gate stripe is ground paint across the road,
            # not a blocking arch masquerading as a checkpoint.
            detail('gate-dash.%02d'%i,a['x'],.042,a['z'],2.4,.02,2.4,'safety-yellow')
        for i,x in enumerate((-46,-29,-12,5,22)):
            detail('pit-canopy.%d'%i,x,3.18,-93,14,.28,6,'ochre')
            detail('pit-bay-number.%d'%i,x,2.92,-96.02,5,.09,.06,'hazard-white')
        # Slim infield route arrows painted onto the non-driving canyon rock.
        for x,z in ((-45,8),(-12,2),(36,5)):
            for n in range(3): detail('canyon-strata',x,2+n*1.7,z-7.8,8,.11,.12,'rust')
    elif ID=='copper-bowl':
        # At grade: halfway stripe, centre circle approximation and penalty
        # boxes. The analytic ball still sees a perfectly level pitch.
        detail('halfway',0,.035,0,.12,.02,53,'field-line')
        for i in range(32):
            a=i*math.tau/32
            detail('centre-circle.%02d'%i,math.cos(a)*9,.035,math.sin(a)*9,.7,.02,.16,'field-line')
        for side in (-1,1):
            for z in (-16,16):
                detail('goal-area-edge',side*40,.035,z,14,.02,.11,'field-line')
            detail('goal-area-back',side*34,.035,0,.11,.02,32,'field-line')
            # Mesh net is behind the source scoring plane and inside the
            # existing back-board; thin fibres cannot affect ball physics.
            for z in range(-7,8,2):
                detail('net-vertical',side*51.75,2.5,z,.04,4.6,.04,'hazard-white')
            for y in (1,2,3,4):
                detail('net-horizontal',side*51.75,y,0,.04,.035,15.9,'hazard-white')
            for tier in range(4):
                detail('seat-lip',0,2.58+tier*1.7,side*(34+tier*4),106,.1,3.8,'copper')
    elif ID=='tern-archipelago':
        for i,z in enumerate((-32,24,66)):
            # Tidal wash lines are planar, and strategic causeways remain dry.
            for x in range(-108,109,18):
                detail('tide-foam.%d.%d'%(i,x),x,.043,z+(i%2)*2,8,.015,.12,'hazard-white')
        for n in DATA['nodes']:
            # Low-key territory colors over existing command-hall colliders.
            accent='signal-red' if n['archetype']=='hq' else 'safety-yellow' if n['archetype']=='relay' else 'ice-blue'
            x=n['x'];z=n['z'];w=23 if n['archetype']=='hq' else 18
            for side in (-1,1):
                detail('sector-sill',x+side*w/2,5.06,z,.52,.1,10,accent)
            detail('sector-sigil',x,.028,z,3,.02,3,accent)
        for d in DATA['depots']:
            x=d['x'];z=d['z'];
            detail('depot-parking-line',x,.03,z-4,7,.02,.13,'hazard-white')
            detail('depot-parking-line',x,.03,z+4,7,.02,.13,'hazard-white')
            detail('depot-sign',x,.035,z,2,.02,2,'safety-yellow')

architecture()
build_architecture(ID,DATA,emit,detail,tube)

# Preserve editable components in the .blend; export only the per-material batches.
for name,(verts,faces) in groups.items():
    mesh=bpy.data.meshes.new('batch.'+name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new('batch.'+name,mesh)
    render.objects.link(obj)
    obj.data.materials.append(materials[name])
    obj['recipe_id']=ID

bpy.ops.wm.save_as_mainfile(filepath=str(MASTER/(ID+'.blend')))
bpy.ops.object.select_all(action='DESELECT')
for obj in render.objects: obj.select_set(True)
bpy.context.view_layer.objects.active=next(iter(render.objects))
bpy.ops.export_scene.gltf(filepath=str(ART/(ID+'.glb')),export_format='GLB',use_selection=True,
    export_apply=True,export_yup=True,export_materials='EXPORT')
print('WORLD_EXPORT',ID,'pieces',len(master.objects),'batches',len(render.objects))
