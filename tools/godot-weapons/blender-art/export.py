"""Ten original hard-surface weapon sculpts, two native LODs each.

Run with Blender 4.5: blender -b -t 1 --python export.py. Deterministic mesh
construction, no add-ons, procedural textures, downloaded models or randomness.
Coordinates/assembly names come from the checked-in source-export manifest; it
is READ ONLY. The blend files are editable high-resolution master assets.
"""
import bpy
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'godot/first_person/art'
OUT.mkdir(parents=True, exist_ok=True)
MASTER = Path(__file__).parent / 'masters'
MASTER.mkdir(exist_ok=True)
CAT = json.loads((ROOT / 'godot/first_person/generated/manifest.json').read_text())['weapons']
WORLD = json.loads((ROOT / 'godot/source_operators/generated/world_weapons/manifest.json').read_text())['weapons']
ACCENTS = ['#21d9c7','#ee9650','#78cdfa','#eab86c','#66d5df','#e6a952','#a785f5','#f18550','#d4e6b4','#f197c2']
NAMES = ['Pulse Rifle','Rocket Launcher','Rail Lance','Scattergun','Plasma Driver','Grenade Launcher','Shock Beam','Flak Cannon','Marksman Rifle','Submachine Gun']

def color(hexcode):
    values = [int(hexcode[i:i+2],16)/255 for i in (1,3,5)]
    return tuple((v/12.92 if v < .04045 else ((v+.055)/1.055)**2.4) for v in values)+(1,)

def reset(id, low):
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    for m in list(bpy.data.materials): bpy.data.materials.remove(m)
    global mats, parents, counter, lod
    lod = low; parents = {}; counter = 0
    palette = {'dark':'#202b34','light':'#617886','glow':ACCENTS[id],
               'trim':'#c5d6d8','cavity':'#09151d','rubber':'#111f29','ceramic':'#a8b9aa'}
    mats = {}
    for role, shade in palette.items():
        m=bpy.data.materials.new(role); m.diffuse_color=color(shade); m.use_nodes=True
        bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=color(shade)
        bs.inputs['Metallic'].default_value= .72 if role in ('light','trim') else .28
        bs.inputs['Roughness'].default_value= .3 if role=='trim' else .55
        if role=='glow':
            bs.inputs['Emission Color'].default_value=color(shade)
            bs.inputs['Emission Strength'].default_value=1.8
        mats[role]=m
    for n in ('body','feed','bolt','barrel-assembly' if id not in (6,7) else ('shock-emitter' if id==6 else 'flak-barrel')):
        e=bpy.data.objects.new(n,None); bpy.context.collection.objects.link(e); parents[n]=e

def add(obj, role, assembly='body'):
    global counter
    counter+=1; obj.name=f'{counter:03d}-{role}'; obj.data.materials.append(mats[role]); obj.parent=parents[assembly]
    return obj

def block(pos, scale, role='light', assembly='body', bevel=.01):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos); obj=bpy.context.object
    obj.dimensions=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel and not lod:
        mod=obj.modifiers.new('CNC edge radius','BEVEL'); mod.width=min(bevel,min(scale)*.28); mod.segments=2
        bpy.context.view_layer.objects.active=obj; bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=obj.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL'); mod.keep_sharp=True
    return add(obj,role,assembly)

def tube(pos, radius, length, role='light', assembly='body', vertices=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices or (10 if lod else 20),radius=radius,depth=length,location=pos)
    return add(bpy.context.object,role,assembly)

def collar(z, radius, width=.015, role='trim', y=0, x=0, assembly='body'):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius,minor_radius=width/2,
        major_segments=10 if lod else 24,minor_segments=4 if lod else 8,location=(x,y,z))
    return add(bpy.context.object,role,assembly)

def rod(a,b,r,role='trim',assembly='body'):
    from mathutils import Vector
    a=Vector(a); b=Vector(b); d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=8 if lod else 12,radius=r,depth=d.length,location=(a+b)/2)
    bpy.context.object.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    return add(bpy.context.object,role,assembly)

def plate(x,y,z,w,h,d,role='dark',bevel=.009):
    return block((x,y,z),(w,h,d),role,bevel=bevel)

def architecture(id, record):
    a=record['anchors']; sight=a['SightRear']['weaponPosition']; front=a['SightFront']['weaponPosition']
    muzzle=record['muzzles'][0]; tip=muzzle[2]; core_y=muzzle[1]
    grip=a['GripRight']['weaponPosition']; support=a['GripSupport']['weaponPosition']; mag=a['GripReload']['weaponPosition']
    # A common scale and handedness, but the receiver, action and stock are
    # composed separately for each class below rather than a recoloured blank.
    return sight,front,tip,core_y,grip,support,mag

def sights(id,sight,front):
    if id in (2,8):
        # The actual original optical axis is sight.y. Hollow objective/ocular
        # rings keep the camera ray free even with the canonical optics hidden.
        for z,r in ((sight[2]-.06,.042),(sight[2]-.21,.053),(front[2]+.025,.048)):
            collar(z,r,.013,'dark',sight[1]); collar(z,r-.008,.005,'trim',sight[1])
        for sx in (-1,1): rod((sx*.052,sight[1],sight[2]-.08),(sx*.056,sight[1],front[2]+.025),.006,'light')
        block((0,sight[1]-.062,sight[2]-.17),(.075,.045,.14),'dark')
        # Scope tube cradle: real clamped feet into the receiver top, not an
        # isolated optic hovering over the action. The center ray stays hollow.
        roof=(.055 if id==2 else .067)
        foot_top=sight[1]-.078
        for sx in (-1,1):
            block((sx*.033,(roof+foot_top)*.5,sight[2]-.17),(.020,foot_top-roof+.022,.105),'trim')
            block((sx*.043,roof+.010,sight[2]-.17),(.046,.018,.13),'dark')
        # The front ring rides the rail/handguard through lateral cantilevers.
        front_rail=(.049 if id==2 else .039)
        if id==8:
            block((0,.050,front[2]+.025),(.178,.017,.047),'dark')
        for sx in (-1,1):
            rod((sx*.092,front_rail-.006,front[2]+.025),
                (sx*.057,sight[1]-.025,front[2]+.025),.008,'trim')
    else:
        roofs=(.065,.057,.055,.057,.087,.075,.025,.118,.067,.119)
        roof=roofs[id]
        post_bottom=sight[1]-.048
        # Full-width saddle is mechanically seated on the receiver, then two
        # separate side ears rise into the open notch (no central ADS occluder).
        block((0,roof+.007,sight[2]),(.122,.016,.065),'dark')
        for sx in (-1,1):
            span=max(.012,post_bottom-roof+.012)
            block((sx*.039,(roof+post_bottom)*.5,sight[2]),(.019,span,.034),'light')
            block((sx*.039,sight[1]-.018,sight[2]),(.012,.06,.014),'trim')
        # Front blade terminates at, never above, the authored ADS target ray.
        block((0,front[1]-.042,front[2]),(.011,.084,.012),'trim')
        block((0,front[1]-.058,front[2]),(.085,.012,.05),'dark')
        # Front sight shoe goes down to the *actual* local barrel/hood roof.
        # On the double barrel a cross-brace spans the two separate tubes.
        front_roofs=(.073,.137,.050,.098,.085,.142,.048,.095,.048,.100)
        if id==3:
            block((0,.101,front[2]),(.26,.018,.055),'light')
        gap=max(.008,front[1]-.055-front_roofs[id])
        if gap>.012:
            block((0,(front[1]-.055+front_roofs[id])*.5,front[2]),
                  (.037,gap+.018,.041),'trim')

def action_cap(id):
    """Camera-facing breech/stock mechanisms, visible in the shipping hip pose.

    Every class has a different rear action, not a common flat square end cap.
    Placed under the sight height, behind the loaded source pivot geometry.
    """
    z=(.29,.225,.285,.29,.19,.265,.245,.23,.315,.235)[id]
    if id==0:
        for x in (-.052,.052):
            block((x,-.065,z),(.027,.11,.026),'trim')
            block((x,-.065,z+.016),(.011,.076,.009),'cavity',bevel=0)
        block((0,-.12,z),(.15,.022,.03),'rubber')
    elif id==1:
        collar(z,.083,.020,'trim',-.04)
        collar(z+.007,.058,.012,'glow',-.04)
        tube((0,-.04,z-.003),.036,.008,'cavity')
    elif id==2:
        for x in (-.059,.059):
            block((x,-.048,z),(.020,.12,.021),'ceramic')
            block((x,-.045,z+.013),(.007,.078,.007),'glow',bevel=0)
        block((0,-.109,z),(.096,.019,.024),'trim')
    elif id==3:
        # Closed twin breech plates with exposed locking dogs, not rearward
        # hollow muzzle rings aimed into the player's face.
        for x in (-.065,.065):
            block((x,-.04,z),(.091,.101,.027),'dark')
            block((x,-.04,z+.017),(.072,.077,.009),'trim')
            block((x,-.04,z+.024),(.011,.063,.006),'cavity',bevel=0)
        block((0,-.105,z+.018),(.035,.024,.016),'glow')
    elif id==4:
        collar(z,.074,.018,'ceramic',-.055)
        collar(z+.009,.050,.010,'glow',-.055)
        for x in (-.092,.092): block((x,-.055,z),(.019,.10,.027),'trim')
    elif id==5:
        block((0,-.055,z),(.17,.145,.025),'dark')
        block((0,-.055,z+.016),(.145,.115,.010),'trim')
        for x in (-.051,0,.051):
            block((x,-.052,z+.025),(.026,.076,.006),'cavity',bevel=0)
        block((0,-.117,z+.026),(.092,.009,.008),'glow',bevel=0)
    elif id==6:
        for x in (-.066,.066):
            block((x,-.047,z),(.028,.125,.026),'light')
            block((x,-.047,z+.016),(.012,.082,.009),'glow',bevel=0)
        block((0,-.12,z),(.18,.017,.027),'cavity')
    elif id==7:
        block((0,-.045,z),(.245,.155,.025),'dark')
        for y in (-.10,-.065,-.03,.005):
            block((0,y,z+.018),(.195,.011,.008),'trim',bevel=0)
        for x in (-.108,.108): block((x,-.044,z+.015),(.011,.115,.009),'glow')
    elif id==8:
        block((0,-.050,z),(.11,.07,.021),'rubber')
        for x in (-.031,0,.031):
            block((x,-.047,z+.014),(.008,.043,.007),'trim',bevel=0)
    else:
        block((0,-.055,z),(.11,.11,.027),'dark')
        for side in (-1,1):
            rod((side*.058,-.102,z+.02),(side*.013,-.030,z+.02),.008,'trim')
        block((0,-.110,z+.017),(.090,.010,.010),'glow',bevel=0)

def build(id, low):
    reset(id,low)
    s,f,tip,y,gr,sup,mg=architecture(id,CAT[id])
    if id==0: # pulse: narrow modular burst rifle / long floating vented handguard
        plate(0,-.015,-.12,.17,.16,.42,'light'); plate(0,.049,-.12,.145,.016,.34,'dark')
        # Service hatch on the *visible near side*: deep polymer insert,
        # exposed bolt track, engraved cooling mouths and captive latch screws.
        # It breaks up the large blank slab seen during first-person hip fire.
        plate(-.093,-.013,-.123,.017,.109,.266,'dark')
        plate(-.104,.043,-.125,.009,.011,.242,'trim',.002)
        plate(-.105,-.073,-.125,.009,.009,.242,'trim',.002)
        for z in (-.225,-.165,-.105):
            plate(-.105,.009,z,.010,.028,.034,'cavity',.002)
            plate(-.111,.027,z,.006,.006,.022,'trim',.001)
        for z in (-.235,-.012):
            plate(-.107,-.055,z,.008,.012,.012,'ceramic',.001)
        plate(-.083,.065,-.083,.040,.023,.16,'light')
        plate(-.091,.079,-.083,.012,.008,.115,'glow',.002)
        # Broad rear action face is an inset machined service door, not an
        # unbroken light-coloured cuboid. Captive latch and paired witness bars
        # remain visible from the actual first-person normal pose.
        plate(0,-.022,.102,.137,.125,.013,'dark',.004)
        plate(0,-.022,.111,.112,.100,.006,'cavity',0)
        plate(0,.024,.117,.094,.009,.006,'trim',0)
        for x in (-.032,.032):
            plate(x,-.035,.117,.034,.043,.007,'light',0)
            plate(x,-.035,.122,.010,.021,.005,'dark',0)
        plate(0,-.079,.119,.078,.007,.006,'glow',0)
        tube((0,y,tip+.15),.041,.31,'cavity','barrel-assembly')
        for side in (-1,1):
            rod((side*.097,-.018,-.67),(side*.097,-.018,-.25),.01,'trim')
            for z in (-.32,-.42,-.52,-.62): plate(side*.091,-.015,z,.013,.085,.018,'dark')
        for z in (-.60,-.50,-.40): collar(z,.063,.009,'glow',y)
        collar(tip+.02,.053,.014,'trim',y)
        rod((-.061,-.015,.11),(-.087,-.025,.28),.014,'trim'); rod((.061,-.015,.11),(.087,-.025,.28),.014,'trim')
    elif id==1: # shoulder rocket: oversized open exhaust and side loading canister
        tube((0,y,-.35),.137,.7,'light'); tube((0,y,tip+.016),.107,.045,'cavity')
        for z in (-.69,-.45,-.21): collar(z,.139,.023,'trim',y)
        for side in (-1,1):
            plate(side*.139,-.012,-.38,.027,.09,.45,'dark'); plate(side*.15,.035,-.37,.012,.016,.36,'glow')
        plate(0,-.14,-.06,.18,.13,.22,'dark'); tube((-.145,-.09,-.3),.048,.27,'glow','feed')
        plate(0,-.038,.16,.20,.19,.11,'rubber')
    elif id==2: # rail lance: twin prismatic accelerator rails and open central channel
        plate(0,-.015,-.09,.16,.14,.35,'dark')
        for side in (-1,1):
            plate(side*.095,.016,-.67,.038,.065,.79,'light'); plate(side*.092,.056,-.69,.019,.013,.71,'glow')
            for z in (-.36,-.55,-.74,-.93): plate(side*.093,-.04,z,.071,.013,.022,'trim')
        tube((0,y,tip+.23),.032,.46,'cavity','barrel-assembly'); collar(tip+.05,.060,.013,'trim',y)
        plate(0,-.06,.16,.12,.08,.23,'rubber')
    elif id==3: # break scattergun: twin separate bore modules / hinged receiver
        plate(0,-.018,-.08,.22,.15,.29,'dark')
        for side in (-1,1):
            tube((side*.12,.03,-.57),.068,.5,'light','barrel-assembly')
            collar(tip+.025,.071,.015,'trim',.03,side*.12,'barrel-assembly')
            tube((side*.12,.03,tip+.015),.046,.022,'cavity','barrel-assembly')
            plate(side*.12,.089,-.39,.075,.015,.26,'dark')
        rod((-.09,-.08,.025),(.09,-.08,.025),.022,'trim')
        plate(0,-.075,.16,.16,.12,.24,'rubber')
        plate(.107,-.016,-.06,.012,.018,.10,'glow')
    elif id==4: # plasma driver: thick opposed radiator vanes / contained reactor
        plate(0,-.018,-.12,.23,.21,.35,'dark'); tube((0,y,-.4),.085,.52,'light')
        for side in (-1,1):
            plate(side*.13,.022,-.43,.048,.14,.43,'ceramic')
            for z in (-.27,-.35,-.43,-.51,-.59): plate(side*.16,.014,z,.015,.105,.028,'trim')
            plate(side*.13,.103,-.41,.014,.018,.36,'glow')
        collar(tip+.035,.107,.029,'light',y); collar(tip+.014,.082,.012,'glow',y)
        tube((0,-.13,-.19),.056,.16,'glow','feed')
    elif id==5: # grenade: tall revolver drum / very large shell bore
        plate(0,-.02,-.10,.20,.19,.34,'dark'); tube((0,.04,-.64),.102,.56,'light','barrel-assembly')
        tube((0,.04,tip+.015),.072,.024,'cavity','barrel-assembly')
        for z in (-.83,-.6): collar(z,.109,.026,'trim',.04)
        tube((0,-.105,-.28),.108,.2,'light','feed')
        for x in (-.065,.065):
            plate(x,-.107,-.28,.012,.13,.15,'cavity')
        plate(0,-.08,.16,.16,.11,.19,'rubber')
        plate(.105,.002,-.08,.014,.020,.09,'glow')
    elif id==6: # shock beam: split capacitor prongs and longitudinal exposed conduit
        plate(0,-.04,-.10,.22,.13,.36,'dark')
        for side in (-1,1):
            plate(side*.135,.002,-.67,.043,.079,.94,'light')
            plate(side*.14,.05,-.70,.013,.014,.80,'glow')
            for z in (-.32,-.50,-.68,-.86):
                rod((side*.136,-.05,z),(side*.078,-.088,z-.06),.011,'trim')
        tube((0,y,-.68),.048,.61,'cavity','shock-emitter')
        collar(-.88,.065,.016,'glow',y)
        plate(0,-.05,.11,.17,.08,.24,'rubber')
    elif id==7: # flak: armoured chunky rotary chamber and vented heat hood
        plate(0,-.014,-.15,.31,.22,.4,'light'); plate(0,.105,-.17,.27,.026,.33,'dark')
        for side in (-1,1):
            plate(side*.166,.013,-.60,.05,.15,.48,'dark')
            for z in (-.42,-.51,-.60,-.69): plate(side*.172,.028,z,.014,.089,.025,'trim')
        tube((0,y,-.73),.095,.48,'light','flak-barrel')
        collar(tip+.036,.114,.032,'trim',y)
        plate(0,-.17,-.30,.17,.16,.20,'dark')
        plate(.158,.077,-.22,.012,.018,.11,'glow')
    elif id==8: # marksman: long pencil barrel and deliberate skeleton cheek stock
        plate(0,-.016,-.13,.145,.13,.38,'light'); plate(0,.059,-.15,.13,.016,.4,'dark')
        tube((0,y,-.62),.032,.48,'trim','barrel-assembly')
        tube((0,y,tip+.012),.046,.16,'dark','barrel-assembly')
        for side in (-1,1):
            rod((side*.057,-.02,.06),(side*.087,-.08,.29),.009,'trim')
            rod((side*.087,-.08,.29),(side*.04,.055,.14),.009,'trim')
        plate(0,.074,.17,.105,.022,.17,'rubber')
        for z in (-.42,-.50,-.58): plate(0,-.048,z,.14,.027,.024,'dark')
        plate(.076,.015,-.16,.010,.014,.115,'glow')
    else: # SMG: very short shroud / forward vertical grip / collapsible side stock
        plate(0,-.004,-.12,.18,.20,.34,'light'); plate(0,.11,-.14,.18,.018,.32,'dark')
        tube((0,y,-.59),.050,.23,'cavity','barrel-assembly')
        for side in (-1,1): plate(side*.077,.005,-.52,.015,.095,.22,'dark')
        collar(tip+.026,.065,.017,'trim',y)
        plate(-.035,-.205,-.48,.075,.22,.065,'rubber')
        rod((-.07,-.02,.03),(-.14,-.018,.16),.009,'trim'); rod((-.14,-.018,.16),(-.14,-.07,.23),.009,'trim')
        plate(.091,-.014,-.16,.011,.013,.10,'glow')
    # Purpose-built live magazine and bolt carrier, sharing the source-export
    # feed/bolt assembly transforms. Their rest mesh is expressed in weapon space.
    if id not in (1,4,5):
        width=.13 if id not in (2,8,9) else .105
        depth=.17 if id!=9 else .24
        block((mg[0],mg[1]-.013,mg[2]),(width,.13,depth),'dark','feed')
        for z in (mg[2]-.045,mg[2]+.045):
            block((mg[0]-.001,mg[1]-.019,z),(width+.005,.009,.012),'trim','feed')
        block((mg[0],mg[1]-.085,mg[2]),(width+.012,.015,depth),'light','feed')
    block((.069,-.006,-.135),(.019,.034,.13),'trim','bolt')
    if id==0:
        block((-.106,-.012,-.018),(.018,.034,.071),'trim','bolt')
        block((-.119,-.012,-.017),(.007,.015,.043),'cavity','bolt',bevel=.002)
    # Palm-indexed angled grip, trigger cage and unobstructed support station.
    plate(gr[0],gr[1]-.015,gr[2]+.013,.09,.165,.10,'rubber')
    for n in range(3 if not lod else 1):
        plate(gr[0],gr[1]-.06+n*.038,gr[2]+.068,.094,.008,.013,'trim',.003)
    rod((-.043,gr[1]+.065,-.02),(-.043,gr[1]+.005,-.085),.007,'trim')
    sights(id,s,f)
    action_cap(id)
    # Class-specific side vent clusters, staggered so the silhouette never
    # reduces to a shared recoloured receiver.
    for i in range(2 if lod else 4):
        z=-.10-i*.043
        plate(.071 if id in (2,8,9) else -.102 if id==0 else -.081,.026,z,.011,.028,.015,'cavity',.002)

def export(id, low):
    build(id,low)
    bpy.context.preferences.filepaths.save_version=0
    # One mesh per (moving assembly, finish role). Joining occurs after master
    # modeling, so each .blend remains editable while native draw calls stay low.
    for assembly in parents.values():
        for role in mats:
            members=[o for o in assembly.children if o.type=='MESH' and o.data.materials[0]==mats[role]]
            if not members: continue
            bpy.ops.object.select_all(action='DESELECT')
            for obj in members: obj.select_set(True)
            bpy.context.view_layer.objects.active=members[0]
            bpy.ops.object.join()
            members[0].name=assembly.name+'-'+role
    bpy.context.view_layer.update()
    triangles=0
    for obj in bpy.data.objects:
        if obj.type=='MESH':
            mesh=obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
            mesh.calc_loop_triangles(); triangles+=len(mesh.loop_triangles)
    bpy.ops.wm.save_as_mainfile(filepath=str(MASTER / (f'world-{id}.blend' if low else f'weapon-{id}.blend')),compress=True)
    bpy.ops.object.select_all(action='SELECT')
    target=OUT / (f'world-{id}.glb' if low else f'weapon-{id}.glb')
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_apply=True,
        export_materials='EXPORT',export_yup=False,export_extras=False)
    return {'id':id,'name':NAMES[id],'lod':'world' if low else 'first-person',
            'triangles':triangles,'bytes':target.stat().st_size}

if __name__=='__main__':
    print(json.dumps([export(id,low) for id in range(10) for low in (False,True)],indent=2))
