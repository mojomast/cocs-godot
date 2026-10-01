"""Editable urban masters plus per-material-batched art-only GLBs.

LP_NUM_THREADS=1 blender -b -t 1 --python tools/godot-multiplayer/urban/export.py
All playable cover, wall, sidewalk, rail, ramp and roof volumes are generated
from the authoritative JSON. Thin trim, paint, glazing and signage are cosmetic.
"""
import bpy
import bmesh
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DATA = ROOT / 'godot/multiplayer_worlds/generated'
ART = ROOT / 'godot/multiplayer_worlds/art'
MASTERS = ROOT / 'tools/godot-multiplayer/urban'
ART.mkdir(parents=True, exist_ok=True)

def material(name, rgb, metal=0, rough=.75, emission=0, alpha=1):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, alpha)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*rgb, alpha)
    shader.inputs['Metallic'].default_value = metal
    shader.inputs['Roughness'].default_value = rough
    if emission:
        shader.inputs['Emission Color'].default_value = (*rgb, 1)
        shader.inputs['Emission Strength'].default_value = emission
    if alpha < 1:
        mat.surface_render_method = 'DITHERED'
        shader.inputs['Alpha'].default_value = alpha
    return mat

def cube(name, x, y, z, w, h, d, mat, bevel=0):
    # Godot glTF importer maps Blender (X,Y,Z) to (X,Z,-Y). Negate world Z
    # here so asymmetrical collision/art landmarks coincide after import.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x,-z,y))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (w,d,h)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new('fabricated edge', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj

def disc(name, x, z, rx, rz, mat, height=.014):
    # Flush stain/puddle: no visual gameplay step, no phantom collision.
    verts = [(x + rx*math.cos(i*math.tau/12),-z + rz*math.sin(i*math.tau/12),height) for i in range(12)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], [tuple(range(12))])
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj

def sign(name, text, x, y, z, mat, size=.55, side='south'):
    # On a wall plane; letters are mesh and travel with the master/GLB.
    angle = math.pi/2 if side == 'south' else -math.pi/2
    bpy.ops.object.text_add(location=(x,-z,y), rotation=(angle,0,0))
    obj = bpy.context.object
    obj.name = name
    obj.data.body = text
    obj.data.size = size
    obj.data.resolution_u = 2
    obj.data.extrude = 0
    obj.data.bevel_depth = 0
    obj.data.materials.append(mat)
    bpy.ops.object.convert(target='MESH')

def palette(market):
    if market:
        return {
            'body':material('market warm limestone',(.52,.44,.37)),
            'accent':material('market painted teal',(.06,.38,.42),.21,.47),
            'metal':material('market oxidized copper',(.36,.46,.41),.64,.38),
            'trim':material('market polished ceramic',(.75,.69,.54),.08,.52),
            'glass':material('market cobalt glazing',(.08,.23,.31),.23,.18),
            'roof':material('market tiled awning red',(.55,.2,.14),.08,.72),
            'light':material('market amber lamp',(.99,.64,.23),.13,.3,2.2),
            'ground':material('market rain-dark basalt paving',(.19,.26,.28),.03,.46),
            'mark':material('market transit cream line',(.76,.71,.49)),
            'puddle':material('market rain reflection',(.12,.32,.42),.2,.1,alpha=.68),
            'crate':material('market spice/wood stalls',(.4,.25,.14)),
        }
    return {
        'body':material('ward kiln-fired red brick',(.34,.16,.105)),
        'accent':material('ward utility concrete',(.52,.48,.41)),
        'metal':material('ward blue-black steel',(.105,.21,.27),.72,.35),
        'trim':material('ward bleached sandstone lintel',(.67,.58,.43)),
        'glass':material('ward tinted workshop windows',(.09,.24,.3),.14,.2),
        'roof':material('ward yellow safety enamel',(.71,.46,.11),.28,.52),
        'light':material('ward warm sodium bulb',(.96,.54,.16),.04,.42,2),
        'ground':material('ward oiled street patch',(.14,.19,.21)),
        'mark':material('ward weathered crosswalk',(.76,.68,.51)),
        'puddle':material('ward oily rain stain',(.12,.20,.22),.2,.2,alpha=.74),
        'crate':material('ward freight timber',(.42,.31,.21)),
    }

def bay(name, x, z, outside_z, i, width, p, market, height=3.8):
    # Nearly flush against a *real* wall or mass; millimetric accents do not
    # visually promise a collision volume different from the authority.
    side = 1 if outside_z else -1
    yy = 1.75 if i%2 else 1.62
    cube(name+'-inset',x,yy,z+side*.037,width,1.65,.018,p['accent'])
    cube(name+'-glass',x,yy,z+side*.052,width-.18,1.26,.018,p['glass'])
    for off in (-width/2+.07, width/2-.07):
        cube(name+'-mullion',x+off,yy,z+side*.07,.09,1.6,.06,p['metal'])
    cube(name+'-sill',x,yy-.77,z+side*.085,width+.14,.13,.12,p['trim'])
    cube(name+'-lintel',x,yy+.82,z+side*.085,width+.17,.13,.12,p['trim'])
    cube(name+'-transom',x,yy+.58,z+side*.076,width-.18,.065,.07,p['metal'])
    if market:
        # Colour-striped drop cloth on the facade, outside head/shoulder line.
        cube(name+'-shade',x,3.24,z+side*.19,width+.32,.09,.32,p['roof'])
        for n in range(4):
            cube(name+f'-shade-edge-{n}',x-width/2+(n+.5)*width/4,3.2,z+side*.35,width/4-.06,.06,.04,p['trim'])
    else:
        cube(name+'-service-shutter',x,3.09,z+side*.06,width+.18,.29,.07,p['metal'])
        for n in range(3):
            cube(name+f'-service-slot-{n}',x-width/2+(n+.5)*width/3,3.1,z+side*.107,width/3-.08,.035,.022,p['roof'])

def wall_detail(b, p, market):
    key,x,z,w,d,h = b['id'],b['x'],b['z'],b['w'],b['d'],b['h']
    base = b.get('baseY',0)
    # Strong wall volumes are always the exact source AABB footprint.
    body = p['body'] if b['material']=='brick' else p['metal'] if b['material']=='steel' else p['accent']
    cube(key+'-authoritative-body',x,(h+base)/2,z,w,h-base,d,body)
    if h-base < 3 or not (w>2 and d<1 or d>2 and w<1): return
    if w>2 and d<1:
        for side in (-1,1):
            count=max(1,int(w/2.6))
            for i in range(count):
                xx=x-w/2+(i+.5)*w/count
                bay(f'{key}-bay-{side}-{i}',xx,z+side*d/2,side>0,i,min(1.8,w/count-.25),p,market)
            cube(key+f'-belt-{side}',x,3.41,z+side*(d/2+.09),w,.12,.13,p['trim'])
    elif d>2 and w<1:
        for side in (-1,1):
            # Narrow vertical bays on side walls, along Z (not floating frames).
            count=max(1,int(d/2.8))
            for i in range(count):
                zz=z-d/2+(i+.5)*d/count
                cube(key+f'-side-inset-{side}-{i}',x+side*(w/2+.024),1.78,zz,.027,1.65,min(1.75,d/count-.3),p['glass'])
                cube(key+f'-side-pier-{side}-{i}',x+side*(w/2+.06),1.8,zz,.06,2,.1,p['metal'])
    # Beam faces are integrated with the solid wall, not overhead fake cover.
    cube(key+'-cap',x,h-.09,z,w+.04,.17,d+.04,p['trim'])

def shop_details(arena,p,market):
    # Equipment is either an exact authored counter AABB or a thin face at the
    # back/side wall; the central 4m entry corridor remains entirely clear.
    for name,x,z,w,d,entry in ([('west-toolshop',-18,0,11,9,'east'),('east-service',18,0,11,9,'west'),
                                ('north-ticket',0,-24,10,9,'south'),('south-depot',0,24,10,9,'north')]
                               if not market else
                               [('east-kiosk',26,19,13,11,'west'),('west-foodhall',-25,20,12,9,'east'),
                                ('north-station',11,-25,15,11,'south'),('east-warehouse',28,-17,12,11,'west')]):
        # Polished beam grid above player collision height, tied into side walls.
        for j in range(4):
            if entry in ('east','west'):
                xx=x-w/2+.65+j*(w-1.3)/3
                cube(f'{name}-interior-rib-{j}',xx,3.33,z,.16,.18,d-.98,p['metal'])
                cube(f'{name}-interior-inlay-{j}',xx,3.18,z,.09,.055,d-.98,p['trim'])
                for side in (-1,1):
                    cube(f'{name}-rib-wall-corbel-{j}-{side}',xx,3.52,z+side*(d/2-.53),.18,.52,.18,p['metal'])
            else:
                zz=z-d/2+.65+j*(d-1.3)/3
                cube(f'{name}-interior-rib-{j}',x,3.33,zz,w-.98,.18,.16,p['metal'])
                cube(f'{name}-interior-inlay-{j}',x,3.18,zz,w-.98,.055,.09,p['trim'])
                for side in (-1,1):
                    cube(f'{name}-rib-wall-corbel-{j}-{side}',x+side*(w/2-.53),3.52,zz,.18,.52,.18,p['metal'])
        for side in (-1,1):
            xx=x+side*(w/2-.48)
            for j in range(4):
                zz=z-d/2+1+j*(d-2)/3
                cube(f'{name}-wall-pier-{side}-{j}',xx,1.84,zz,.09,2.65,.12,p['trim'])
                cube(f'{name}-cage-glow-{side}-{j}',xx,2.91,zz,.14,.15,.14,p['light'])
            # Shallow shelving relief stays inside the authored wall volume's
            # collision tolerance and is not a disguised mid-room barrier.
            for j in range(3):
                cube(f'{name}-side-shelf-{side}-{j}',xx-side*.09,.89+j*.62,z,.16,.065,d*.38,p['crate'])
                for k in (-1,0,1):
                    cube(f'{name}-side-stock-{side}-{j}-{k}',xx-side*.12,1.04+j*.62,z+k*d*.12,.17,.24,.22,p['metal'] if not market else p['roof'])
        # Source equipment sits against the rear wall, leaving the door axis free.
        for i in range(3):
            x0=x+(i-1)*w*.24
            z0=z+(-d/2+.58 if entry=='north' else d/2-.58)
            if entry in ('east','west'):
                x0=x+(-w/2+.58 if entry=='east' else w/2-.58)
                z0=z+(i-1)*d*.24
            if entry in ('east','west'):
                cube(f'{name}-rear-cabinet-face-{i}',x0,1.88,z0,.025,1.1,.75,p['metal'])
                cube(f'{name}-rear-cabinet-glass-{i}',x0,1.92,z0,.028,.7,.53,p['glass'])
            else:
                cube(f'{name}-rear-cabinet-face-{i}',x0,1.88,z0,.75,1.1,.025,p['metal'])
                cube(f'{name}-rear-cabinet-glass-{i}',x0,1.92,z0,.53,.7,.028,p['glass'])
        for j in range(3):
            zz=z-d*.30+j*d*.3
            xx=x+(-.8 if entry in ('north','south') else 0)
            cube(f'{name}-ceiling-rail-{j}',xx,3.04,zz,1.55,.08,.08,p['metal'])
            cube(f'{name}-ceiling-bulb-{j}',xx,2.87,zz,.42,.13,.3,p['light'])
            cube(f'{name}-ceiling-glass-{j}',xx,2.78,zz,.34,.025,.2,p['trim'])
        # Scuffed tiles are paint-depth and share the real arena ground floor.
        for i in range(4):
            for j in range(4):
                if (i+j)%3!=0:continue
                cube(f'{name}-floor-inlay-{i}-{j}',x+(i-1.5)*w*.22,.011,z+(j-1.5)*d*.2,w*.16,.012,d*.13,p['ground'])
        if market:
            for i in range(4):
                cube(f'{name}-woven-wall-fabric-{i}',x-w*.29+i*w*.19,2.23,z+d/2-.48,.42,.65,.028,p['roof'] if i%2 else p['trim'])
        else:
            for i in range(4):
                cube(f'{name}-wall-safety-diagonal-{i}',x-w*.29+i*w*.19,2.23,z+d/2-.48,.24,.58,.025,p['roof'])

def roof_mass(b,p,market):
    key,x,z,w,d,h=b['id'],b['x'],b['z'],b['w'],b['d'],b['h']
    cube(key+'-loadbearing-brick',x,h/2,z,w-.06,h-.04,d-.06,p['body'])
    for side in (-1,1):
        for i in range(4):
            xx=x-w*.39+i*w*.26
            bay(f'{key}-street-level-{side}-{i}',xx,z+side*d/2,side>0,i,1.85,p,market)
            # Solid masonry spandrels and depth at the bay joints, flush with
            # the parent source mass rather than separate collision props.
            cube(f'{key}-ground-pier-{side}-{i}',xx+w*.13,1.6,z+side*(d/2+.08),.16,2.8,.16,p['trim'])
            cube(f'{key}-upper-panel-{side}-{i}',xx,2.78,z+side*(d/2+.07),1.5,.17,.11,p['metal'])
        cube(key+f'-stringcourse-{side}',x,2.89,z+side*(d/2+.04),w+.03,.17,.11,p['trim'])
        cube(key+f'-cornice-{side}',x,3.14,z+side*(d/2+.03),w+.1,.13,.16,p['metal'])
    for i in range(5):
        zz=z-d*.42+i*d*.21
        for side in (-1,1):
            xx=x+side*w/2
            cube(f'{key}-end-panel-{side}-{i}',xx+side*.04,1.78,zz,.04,1.6,1.25,p['accent'])
            cube(f'{key}-end-glass-{side}-{i}',xx+side*.07,1.81,zz,.025,1.1,.92,p['glass'])
            cube(f'{key}-end-sill-{side}-{i}',xx+side*.12,1.15,zz,.16,.11,1.37,p['trim'])

def actual_cover(b,p):
    key,x,z,w,d,h=b['id'],b['x'],b['z'],b['w'],b['d'],b['h']
    low=b.get('baseY',0)
    mat=p['metal'] if b['material']=='steel' else p['crate'] if b['material']=='brick' else p['accent']
    cube(key+'-collision-visible',x,(h+low)/2,z,w,h-low,d,mat,bevel=.035 if w<5 and d<5 else 0)
    if 'roof-cover' in key:
        # Raised HVAC skin sits entirely on a roof that source nav can reach.
        cube(key+'-fan-grill',x,h+.018,z,w-.16,.035,d-.16,p['ground'])
        for i in range(5):
            cube(key+f'-fan-fin-{i}',x-w*.37+i*w*.18,h+.048,z,w*.08,.04,d-.25,p['metal'])
    if 'counter-' in key or key.startswith('stall-'):
        cube(key+'-working-top',x,h+.012,z,w+.04,.035,d+.04,p['trim'])
        for i in range(3):
            xx=x+(i-1)*w*.22
            cube(key+f'-display-{i}',xx,h+.05,z,.12,.065,min(.25,d*.38),p['light'])
    if key.startswith(('rail-','tram-platform')):
        for i in range(max(1,int(max(w,d)/1.2))):
            if w>d:
                cube(key+f'-segment-{i}',x-w/2+(i+.5)*w/max(1,int(w/1.2)),h+.015,z,.06,.035,d-.09,p['roof'])
            else:
                cube(key+f'-segment-{i}',x,h+.015,z-d/2+(i+.5)*d/max(1,int(d/1.2)),w-.09,.035,.06,p['roof'])
    if key.startswith('route-wall-'):
        length=d if d>w else w
        count=max(2,int(length/2.5))
        for side in (-1,1):
            for i in range(count):
                t=(i+.5)/count-.5
                if d>w:
                    zz=z+t*d
                    cube(key+f'-recess-{side}-{i}',x+side*(w/2+.02),h*.61,zz,.035,h*.45,d/count-.2,p['ground'])
                    cube(key+f'-inset-{side}-{i}',x+side*(w/2+.04),h*.61,zz,.025,h*.31,d/count-.45,p['glass'])
                    cube(key+f'-cap-{side}-{i}',x+side*(w/2+.05),h*.87,zz,.09,.11,d/count-.12,p['trim'])
                else:
                    xx=x+t*w
                    cube(key+f'-recess-{side}-{i}',xx,h*.61,z+side*(d/2+.02),w/count-.2,h*.45,.035,p['ground'])
                    cube(key+f'-cap-{side}-{i}',xx,h*.87,z+side*(d/2+.05),w/count-.1,.11,.09,p['trim'])
        cube(key+'-crest',x,h-.08,z,w+.05,.13,d+.05,p['roof'])
    if 'guard' in key:
        cube(key+'-guard-top',x,h-.05,z,w,.08,d,p['roof'])
        if w>d:
            for i in range(max(2,int(w/1.45))):
                cube(key+f'-stanchion-{i}',x-w/2+(i+.5)*w/max(2,int(w/1.45)),(h+low)/2,z,.09,h-low,.09,p['metal'])
        else:
            for i in range(max(2,int(d/1.45))):
                cube(key+f'-stanchion-{i}',x,(h+low)/2,z-d/2+(i+.5)*d/max(2,int(d/1.45)),.09,h-low,.09,p['metal'])

def street_details(arena,p,market):
    # Pavement mesh matches the authored 12cm surface. Crosswalks, manholes,
    # stains and lane paint have <2cm relief, below actor step / collision.
    for s in arena['terrain']['surfaces']:
        if s['id'].endswith('sidewalk') or 'promenade' in s['id'] or 'boardwalk' in s['id']:
            verts=s['vertices'];x0=min(v[0] for v in verts);x1=max(v[0] for v in verts)
            z0=min(v[2] for v in verts);z1=max(v[2] for v in verts)
            cube(s['id']+'-stone-tops',(x0+x1)/2,.125,(z0+z1)/2,x1-x0,.012,z1-z0,p['trim'])
            long_x=x1-x0>z1-z0
            count=max(2,int((x1-x0 if long_x else z1-z0)/2.6))
            for i in range(1,count):
                if long_x: cube(s['id']+f'-joint-{i}',x0+(x1-x0)*i/count,.133,(z0+z1)/2,.025,.008,z1-z0-.2,p['ground'])
                else: cube(s['id']+f'-joint-{i}',(x0+x1)/2,.133,z0+(z1-z0)*i/count,x1-x0-.2,.008,.025,p['ground'])
            # The 12cm lip is already part of the source terrain step.
            if long_x: cube(s['id']+'-kerb',(x0+x1)/2,.06,z0+.045,x1-x0,.12,.09,p['accent'])
            else: cube(s['id']+'-kerb',x0+.045,.06,(z0+z1)/2,.09,.12,z1-z0,p['accent'])
    for crossing,z in enumerate((-15,0,15) if not market else (-24,-7,15)):
        for i in range(8):
            xx=(i-3.5)*.74
            cube(f'crosswalk-{crossing}-{i}',xx,.012,z, .49,.012,2.4,p['mark'])
    for i in range(-5,6):
        cube(f'offset-lane-dash-{i}',i*6,.009,3.8 if market else -3.8,2,.012,.09,p['mark'])
    for i,(x,z) in enumerate([(-16,-13),(13,-13),(-12,11),(16,18),(-30,8),(29,-4)]):
        cube(f'drain-frame-{i}',x,.008,z,1.45,.014,.72,p['metal'])
        for q in range(7):cube(f'drain-slat-{i}-{q}',x-.6+q*.2,.021,z,.055,.012,.57,p['ground'])
    for i,(x,z,rx,rz) in enumerate([(-7,-24,2.9,.75),(11,-8,1.7,.9),(-28,13,2.1,.52),(25,27,1.8,1.2),(4,18,1.1,.65)]):
        disc(f'low-profile-wet-patch-{i}',x,z,rx,rz,p['puddle'])
    if market:
        # Real source transit platform below; yellow edge paint and rails lie
        # within its top footprint, not across a phantom traversable deck.
        for z in (-19.1,-14.9):
            cube(f'tram-running-rail-{z}',0,.024,z,64,.045,.12,p['metal'])
            for x in range(-30,31,2):
                cube(f'tram-sleeper-{x}-{z}',x,.013,z,.23,.02,.67,p['crate'])
        for i in range(6):
            cube(f'market-tile-inlay-{i}',-26+i*9,.012,28,2.7,.012,.18,p['mark'])
    else:
        for z in (-2.5,2.5):
            cube(f'freight-rail-{z}',0,.028,z,64,.05,.11,p['metal'])
        for x in range(-30,31,2):
            cube(f'freight-sleeper-{x}',x,.012,0,.22,.02,5.4,p['crate'])
        for i in range(-5,6):
            cube(f'painted-switch-point-{i}',i*5.6,.013,-12,1.5,.012,.12,p['roof'])

def localized_details(arena,p,market):
    # Surface-only detail on the four source-supported ramps. No art bridge is
    # drawn where the source terrain lacks height/collision.
    for s in arena['terrain']['surfaces']:
        if 'ramp' not in s['id']: continue
        verts=s['vertices'];x0=min(v[0] for v in verts);x1=max(v[0] for v in verts)
        z0=min(v[2] for v in verts);z1=max(v[2] for v in verts)
        y0=verts[0][1];y1=verts[2][1]
        for i in range(1,9):
            t=i/9
            x=x0+(x1-x0)*t
            y=y0+(y1-y0)*t+.025
            cube(s['id']+f'-traction-bar-{i}',x,y,(z0+z1)/2,.075,.026,z1-z0-.45,p['roof'])
    if market:
        for x,z,name in [(-25,20,'NIGHT MARKET'),(26,19,'EXCHANGE'),(11,-25,'TRAM HALL'),(28,-17,'WAREHOUSE')]:
            sign(name+'-marquee',name,x-2.2,3.33,z-5.6,p['light'],.44)
        for x,z,number in [(-5,13,'01'),(2,17,'02'),(8,11,'03')]:
            sign(f'stall-{number}-number',number,x-.35,2.05,z-1.14,p['light'],.34)
            # Awning cloth folds, suspended above the source stall cover; thin
            # textile does not claim rigid collision or elevated walkability.
            for i in range(7):
                cube(f'stall-{number}-fabric-{i}',x-1.65+i*.55,2.76,z,.49,.07,2.45,p['roof'] if i%2 else p['trim'])
            cube(f'stall-{number}-lantern',x,2.45,z-.68,.22,.3,.19,p['light'])
    else:
        for x,z,name in [(-18,0,'WARD TOOLWORKS'),(18,0,'SERVICE BAY'),(0,-24,'TICKET HALL'),(0,24,'SWITCH DEPOT')]:
            sign(name+'-facia',name,x-2.25,3.34,z-4.53,p['light'],.42)
        for x,z in [(-27,-19),(-27,19),(27,-19),(27,19)]:
            # Rooftop vents sit *inside* the two actual raised source cover AABBs.
            for i in range(5):
                cube(f'roof-service-vent-{x}-{z}-{i}',x-3.8+i*.27,4.35,z-3.8,.13,.025,.6,p['ground'])
    # Far visual context lies outside authoritative bounds, so players can
    # never reach these silhouettes or mistake them for gameplay cover.
    for i,(x,z,w,d,h) in enumerate([(-47,-19,10,13,6.7),(48,-17,9,15,7.3),(-48,21,12,10,6.3),(48,25,10,12,6.8),(0,-45,17,7,7.1),(5,47,14,7,6.2)]):
        cube(f'outside-bounds-skyline-{i}',x,h/2,z,w,h,d,p['metal'] if i%2 else p['body'])
        for side in (-1,1):
            cube(f'outside-bounds-cornice-{i}-{side}',x,h-.21,z+side*(d/2+.055),w+.18,.22,.17,p['trim'])
            for floor in (0,1):
                for j in range(4):
                    bx=x+(j-1.5)*w*.23
                    by=1.6+floor*2.48
                    cube(f'outside-bounds-inset-{i}-{side}-{floor}-{j}',bx,by,z+side*(d/2+.025),w*.13,1.31,.04,p['glass'])
                    cube(f'outside-bounds-head-{i}-{side}-{floor}-{j}',bx,by+.73,z+side*(d/2+.07),w*.15,.12,.12,p['trim'])
                    cube(f'outside-bounds-sill-{i}-{side}-{floor}-{j}',bx,by-.73,z+side*(d/2+.07),w*.15,.12,.12,p['trim'])
            for j in (-1,1):
                cube(f'outside-bounds-pier-{i}-{side}-{j}',x+j*w*.465,h*.48,z+side*(d/2+.07),.16,h*.9,.15,p['metal'])

selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ('switchyard-ward','rainmarket-exchange')
for map_id in selected:
    market=map_id=='rainmarket-exchange'
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for old in list(bpy.data.materials):bpy.data.materials.remove(old)
    arena=json.loads((DATA/f'{map_id}.json').read_text())['arena']
    p=palette(market)
    for block in arena['blocks']:
        key=block['id']
        if key.endswith('-mass'):roof_mass(block,p,market)
        elif block['h']-block.get('baseY',0)>=3 and (block['w']<1 or block['d']<1):wall_detail(block,p,market)
        else:actual_cover(block,p)
    for slab in arena['overhead']:
        # Art exceeds each source top and underside by 2cm. The shared Godot
        # renderer still draws collision planes, but neither is coplanar with
        # the visible two-sided box faces; the room stays sealed in graphics.
        height=slab['maxY']-slab['minY']+.04
        cube(slab['id']+'-sealed-roof-and-ceiling',slab['x'],(slab['minY']+slab['maxY'])/2,slab['z'],slab['w'],height,slab['d'],p['roof'] if market else p['metal'])
        for i in range(1,5):
            xx=slab['x']-slab['w']/2+i*slab['w']/5
            cube(slab['id']+f'-roof-seam-{i}',xx,slab['maxY']+.025,slab['z'],.035,.01,slab['d']-.2,p['trim'])
    street_details(arena,p,market)
    shop_details(arena,p,market)
    localized_details(arena,p,market)
    mesh_objects=[o for o in bpy.data.objects if o.type=='MESH']
    raw_triangles=sum(len(o.data.polygons)*2 for o in mesh_objects)
    print(f'URBAN_BUDGET {map_id} meshes={len(mesh_objects)} triangles_upper_bound={raw_triangles}',flush=True)
    print('URBAN_HEAVY',[(o.name,len(o.data.polygons)) for o in sorted(mesh_objects,key=lambda v:len(v.data.polygons),reverse=True)[:12]],flush=True)
    if raw_triangles>38000:raise RuntimeError(f'Urban art triangle budget exceeded: {raw_triangles}')
    # Master stays individually named/editable. Export replaces the in-memory
    # objects with one batch per material (no large per-bay draw-call budget).
    bpy.ops.wm.save_as_mainfile(filepath=str(MASTERS/f'{map_id}.blend'))
    groups=defaultdict(list)
    for obj in mesh_objects:groups[obj.data.materials[0].name].append(obj)
    # bmesh accumulates each material linearly; Blender's iterative Object
    # Join copies the growing mesh N times for these thousands of parts.
    combined=[]
    for name,objects in groups.items():
        bm=bmesh.new()
        for obj in objects:
            # from_mesh appends to the current bmesh; transform only the new
            # vertices, including meshes converted from signage curves.
            before=len(bm.verts)
            bm.from_mesh(obj.data)
            bm.verts.ensure_lookup_table()
            for vertex in list(bm.verts)[before:]:vertex.co=obj.matrix_world @ vertex.co
        mesh=bpy.data.meshes.new(f'batched-{name}')
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(objects[0].data.materials[0])
        batch=bpy.data.objects.new(f'batched-{name}',mesh)
        bpy.context.collection.objects.link(batch)
        combined.append(batch)
    for obj in mesh_objects:bpy.data.objects.remove(obj,do_unlink=True)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in combined:obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ART/f'{map_id}.glb'),export_format='GLB',
                              use_selection=True,export_apply=True,export_materials='EXPORT')
    print(f'URBAN_EXPORTED {map_id} editable_meshes={len(mesh_objects)} triangles_upper_bound={raw_triangles} draw_batches={len(groups)}',flush=True)
