"""Grant-only authoring. Run with Blender --background --python ... -- build.

Meshes are authored from the identical JSON authority, in named editable
collections. Decoration never becomes Godot collision. No engine runs on import.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
ID = 'vesper-viaduct'
MASTER = HERE / 'masters' / (ID + '.blend')
ART = ROOT / 'godot/multiplayer_worlds/art/worlds'
EVIDENCE = Path('/home/mojo/.tmp-on-disk/cocs-expansion-three-vesper-evidence-20261002')
COLORS = {'brick': '#984e36', 'plaster': '#b1816b', 'slate': '#293449',
          'iron': '#252d37', 'quay': '#535969', 'cobbles': '#77605b',
          'asphalt': '#3e424c', 'sandstone': '#bb9370', 'glass': '#243c58',
          'water': '#224675', 'letter': '#f1c27b'}


def main():
    import bpy
    sys.path.insert(0, str(ROOT / 'tools/asset-production'))
    from moth_finish import finish_scene
    from mathutils import Vector
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['build', 'reopen-export', 'inspect'])
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    raw = (ROOT / f'port/native-multiplayer-worlds/worlds/{ID}.json').read_bytes()
    recipe = json.loads(raw)
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    ART.mkdir(parents=True, exist_ok=True)
    MASTER.parent.mkdir(parents=True, exist_ok=True)
    if args.action != 'build':
        bpy.ops.wm.open_mainfile(filepath=str(MASTER))
        assert bpy.context.scene['recipe_sha256'] == hashlib.sha256(raw).hexdigest(), 'Stale master'
    else:
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.delete(use_global=False)
        scene = bpy.context.scene
        scene['recipe_sha256'] = hashlib.sha256(raw).hexdigest()
        scene['authority'] = f'port/native-multiplayer-worlds/worlds/{ID}.json'
        scene['source_axes'] = 'source X/Y-up/Z -> Blender X/-Z/Y; glTF Y-up'
        materials = {}
        for name, color in COLORS.items():
            mat = bpy.data.materials.new(name)
            # Authored palette is sRGB; Blender Principled inputs are linear.
            # Treating these bytes as linear made the first native brick orange.
            def linear(v):
                return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4
            rgb = tuple(linear(int(color[i:i+2], 16) / 255) for i in (1, 3, 5))
            mat.diffuse_color = (*rgb, 1)
            mat.use_nodes = True
            bsdf = mat.node_tree.nodes.get('Principled BSDF')
            bsdf.inputs['Base Color'].default_value = (*rgb, 1)
            bsdf.inputs['Roughness'].default_value = .36 if name in ('water', 'iron') else .83
            bsdf.inputs['Metallic'].default_value = .65 if name == 'iron' else 0
            materials[name] = mat
        collections = {}
        for name in ['AUTHORITY-surfaces', 'AUTHORITY-walls', 'Facade-detail', 'Tram-and-wayfinding', 'Inspection']:
            collection = bpy.data.collections.new(name)
            scene.collection.children.link(collection)
            collections[name] = collection

        def link(obj, collection):
            for owner in list(obj.users_collection):
                owner.objects.unlink(obj)
            collections[collection].objects.link(obj)

        def coord(p):
            return (p[0], -p[2], p[1])

        def mesh(name, vertices, faces, material, collection, authority=False):
            data = bpy.data.meshes.new(name)
            data.from_pydata([coord(v) for v in vertices], [], faces)
            data.update()
            obj = bpy.data.objects.new(name, data)
            collections[collection].objects.link(obj)
            data.materials.append(materials[material])
            obj['source_authority'] = authority
            return obj

        def cube(name, x, y, z, w, h, d, material, collection='Facade-detail'):
            vertices=[(x+dx*w/2,y+dy*h/2,z+dz*d/2) for dy in (-1,1) for dx,dz in [(-1,-1),(1,-1),(1,1),(-1,1)]]
            return mesh(name,vertices,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],material,collection)

        for surface in recipe['terrain']['surfaces']:
            mesh(surface['id'], surface['vertices'], surface['triangles'], surface['material'], 'AUTHORITY-surfaces', True)
        # Individual triangle wall objects retain source identifiers for diagnosis.
        for wall in recipe['terrain']['walls']:
            mesh(wall['id'], wall['vertices'], [(0, 1, 2)], wall['material'], 'AUTHORITY-walls', True)
        for piece in recipe['art']['pieces']:
            cube(piece['kind'], piece['x'], piece['y'], piece['z'], piece['w'], piece['h'], piece['d'], piece['material'])
            if 'window' in piece['kind']:
                for side in (-1,1):
                    cube('window-reveal',piece['x']+side*(piece['w']/2+.12),piece['y'],piece['z']-.08,.22,piece['h']+.35,.26,'sandstone')
                cube('window-sill',piece['x'],piece['y']-piece['h']/2-.12,piece['z']-.2,piece['w']+.5,.24,.5,'sandstone')

        def beam(name, a, b, width=.16, material='iron'):
            start, end = Vector(coord(a)), Vector(coord(b))
            rotation=(end-start).to_track_quat('Z','Y')
            points=[]
            for center in (start,end):
                for i in range(6):
                    p=center+rotation@Vector((math.cos(i*math.tau/6)*width,math.sin(i*math.tau/6)*width,0))
                    points.append((p.x,p.z,-p.y))
            faces=[tuple(reversed(range(6))),tuple(range(6,12))]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
            return mesh(name,points,faces,material,'Facade-detail')

        # Handbuilt window reveals and lintel trim remain outside actual apertures.
        for hall in recipe['structures']:
            y = 24 if hall['z'] > 65 else 0 if hall['z'] < -65 else 12
            x0,x1 = hall['x']-hall['w']/2,hall['x']+hall['w']/2
            for side in (-1, 1):
                z = hall['z'] + side * hall['d'] / 2
                cube(hall['id'] + '-cornice', hall['x'], y + hall['height'] - .2, z, hall['w'], .4, .5, 'sandstone')
                # Structural rhythm and deep reveals, aligned to real window bays.
                for x in range(int(x0),int(x1)+1,8):
                    if hall['id']=='platform-gallery' and -10 < x < 6:
                        continue
                    cube('brick-bay-buttress',x,y+hall['height']/2,z+side*.23,.75,hall['height'],.5,'brick')
                    cube('pier-cap',x,y+hall['height']-.6,z+side*.35,1,.4,.7,'sandstone')
                for left,right in ([(x0,-10),(6,x1)] if hall['id']=='platform-gallery' else [(x0,x1)]):
                    cube('window-stone-sill',(left+right)/2,y+.95,z,right-left,.18,.5,'sandstone')
                    cube('window-stone-header',(left+right)/2,y+3.9,z,right-left,.22,.45,'sandstone')
                    # Bases never span the actual central north/south portals.
                    cube('interior-dado',(left+right)/2,y+.35,z-side*.08,right-left,.7,.12,'sandstone')
            for x in (x0,x1):
                for side in (-1,1):
                    cube('portal-stone-jamb',x,y+2.5,hall['z']+side*4.3,.7,5,.6,'sandstone')
                    cube('portal-capital',x,y+4.7,hall['z']+side*4.3,1,.5,1,'sandstone')
                cube('portal-stone-lintel',x,y+5.3,hall['z'],.8,.6,9.2,'sandstone')
                cube('gable-stringcourse',x,y+hall['height']-.25,hall['z'],.5,.35,hall['d'],'sandstone')
            for x in range(int(x0+4),int(x1),8):
                low=y+hall['height']-.6
                beam('roof-principal-rafter',(x,low,hall['z']-hall['d']/2),(x,low+4,hall['z']),.18)
                beam('roof-principal-rafter',(x,low+4,hall['z']),(x,low,hall['z']+hall['d']/2),.18)
                beam('king-post',(x,low,hall['z']),(x,low+4,hall['z']),.12)
                beam('roof-tension-tie',(x,low,hall['z']-hall['d']/2),(x,low,hall['z']+hall['d']/2),.1)
            # Purposeful furniture sits on the source side counters, leaving the
            # six-metre central passage and every tested doorway clear.
            for x in (hall['x']-hall['w']/3,hall['x'],hall['x']+hall['w']/3):
                if hall['id']=='platform-gallery' and x==0:
                    continue
                for side in (-1,1):
                    z=hall['z']+side*(hall['d']/2-4)
                    cube('counter-worktop',x,y+1.14,z,5.1,.1,1.6,'sandstone')
                    if 'station' in hall['id'] or 'ticket' in hall['id'] or 'gallery' in hall['id']:
                        for dx in (-1.7,0,1.7):
                            cube('ticket-desk-divider',x+dx,y+1.48,z+side*.6,.08,.65,1.1,'iron')
                    else:
                        cube('parcel-bay-label',x,y+.7,z-side*.77,3,.3,.03,'sandstone')
            # Deep steel roof trusses, supported on the actual wall line.
            for offset in (-hall['w']/3, 0, hall['w']/3):
                cube(hall['id'] + '-tiebeam', hall['x'] + offset, y + hall['height'] - .5, hall['z'], .4, .5, hall['d'], 'iron')
        # Attached row blocks have actual rear and side elevations, not one
        # windowed face and three blank slabs. Source keeps these buildings solid.
        for z in (-47,45,112):
            depth=14 if z==112 else 22
            base=24 if z>65 else 18 if z>25 else 6
            for center in (-68,68):
                for j in range(5):
                    x=center+(j-2)*8
                    top=(24 if z>65 else 12+(z+7-25)*.3 if z>25 else (z+7+65)*.3)+13+(j%3)*3
                    for zz in (z-depth/2,z+depth/2):
                        cube('row-roof-parapet',x,top+.35,zz,8,.7,.45,'brick')
                        cube('row-ground-stringcourse',x,base+1,zz,8,.25,.4,'sandstone')
                    for xx in (x-3.8,x+3.8):
                        cube('row-corner-quoin',xx,(base+top)/2,z-depth/2-.14,.35,top-base,.3,'sandstone')
                    for dx in (-2,2):
                        for level in range(3):
                            yy=top-3-level*3
                            cube('rear-window',x+dx,yy,z+depth/2+.03,1.5,2,.08,'glass')
                            cube('rear-window-lintel',x+dx,yy+1.15,z+depth/2+.08,1.9,.2,.26,'sandstone')
                    if j in (0,4):
                        side=-1 if j==0 else 1
                        for zz in (z-5,z+2,z+7):
                            for level in range(3):
                                cube('end-elevation-window',x+side*4.03,top-3-level*3,zz,.08,2,1.6,'glass')
        # Clock stages, masonry shoulders, and rail infrastructure reinforce the
        # civic/industrial skyline rather than a lone unarticulated rectangular pole.
        for y in (17,28,40,51):
            cube('clock-belt-course',22,y,20,12.6,.45,12.6,'sandstone')
        for x in (16.1,27.9):
            cube('clock-quoin',x,35,14,.45,45,.55,'sandstone')
        for z in range(28,65,4):
            y=12+(z-25)*.3
            for x in (29.6,34.4):
                beam('stair-baluster',(x,y,z),(x,y+1,z),.055)
        for x in (29.6,34.4):
            beam('stair-handrail',(x,13.9,28),(x,24.7,64),.075)
        # Stair risers are visual infill of the actual source step elevations;
        # source movement intentionally uses treads, not blocking vertical walls.
        for i in range(80):
            cube('stair-riser-infill', 32, 12 + i*.15 + .075, 25+i*.5, 4, .15, .025, 'sandstone')
        water = recipe['art']['water']
        cube('NONPLAYABLE-CANAL', water['x'], water['y'], water['z'], water['w'], .04, water['d'], 'water')
        for offset in (-1.1, 1.1):
            curve = bpy.data.curves.new('curved-tram-rail', 'CURVE')
            curve.dimensions = '3D'
            curve.bevel_depth = .045
            curve.bevel_resolution = 2
            spline = curve.splines.new('POLY')
            points = recipe['art']['tram']
            spline.points.add(len(points)-1)
            for p, source in zip(spline.points, points):
                z = source[2] + offset
                y = 0 if z <= -65 else (z+65)*.3 if z < -25 else 12 if z <= 25 else 12+(z-25)*.3 if z < 65 else 24
                p.co = (*coord((source[0], y+.045, z)), 1)
            obj = bpy.data.objects.new('tram-rail', curve)
            collections['Tram-and-wayfinding'].objects.link(obj)
            curve.materials.append(materials['iron'])
        for label in recipe['art']['labels']:
            curve = bpy.data.curves.new(label['text'], 'FONT')
            curve.body = label['text']
            curve.align_x = 'CENTER'
            curve.size = .7
            curve.extrude = .015
            obj = bpy.data.objects.new(label['text'], curve)
            obj.location = coord((label['x'], label['y'], label['z']))
            obj.rotation_euler = (-math.pi/2, 0, 0)
            collections['Tram-and-wayfinding'].objects.link(obj)
            curve.materials.append(materials['letter'])
        clock = recipe['art']['clock']
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=clock['radius'], depth=.12, location=coord((clock['x'], clock['y'], clock['z'])), rotation=(math.pi/2, 0, 0))
        dial = bpy.context.object
        dial.name = 'civic-clock-dial'
        dial.data.materials.append(materials['letter'])
        link(dial, 'Tram-and-wayfinding')
        cube('clock-minute', 22, 56, 12.25, .15, 2.2, .13, 'iron')
        cube('clock-hour', 22.65, 55, 12.23, 1.4, .18, .14, 'iron')
        for view in recipe['art']['inspectionViews']:
            bpy.ops.object.camera_add(location=coord(view['eye']))
            camera = bpy.context.object
            camera.name = view['id']
            camera.rotation_euler = (Vector(coord(view['target'])) - camera.location).to_track_quat('-Z', 'Y').to_euler()
            camera.data.lens = 23 if view['id'] != 'overview' else 38
            link(camera, 'Inspection')
        bpy.ops.object.light_add(type='SUN', location=(0, 0, 100))
        sun = bpy.context.object
        sun.rotation_euler = (.5, -.5, -.6)
        sun.data.energy = 3
        link(sun, 'Inspection')
        scene.world.color = (.13, .17, .24)
        finish_scene(ROOT, ID)
        bpy.ops.wm.save_as_mainfile(filepath=str(MASTER))
    if args.action in ('build', 'reopen-export'):
        # Keep named editable pieces in the saved master. Runtime copies are
        # converted/joined per material so every wall triangle is not a draw call.
        groups = {}
        for obj in list(bpy.context.scene.objects):
            if obj.type not in ('MESH', 'CURVE', 'FONT'):
                continue
            assert len(obj.data.materials) == 1, obj.name
            copy = obj.copy()
            copy.data = obj.data.copy()
            bpy.context.collection.objects.link(copy)
            groups.setdefault(copy.data.materials[0].name, []).append(copy)
        export_objects = []
        for material_name, objects in groups.items():
            bpy.ops.object.select_all(action='DESELECT')
            for obj in objects:
                obj.select_set(True)
            bpy.context.view_layer.objects.active = objects[0]
            bpy.ops.object.convert(target='MESH')
            bpy.ops.object.join()
            obj = bpy.context.object
            obj.name = 'batch-' + material_name
            export_objects.append(obj)
        finish_scene(ROOT, ID)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in export_objects:
            obj.select_set(True)
        output = ART / (ID + '.glb')
        bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True, export_yup=True, export_extras=True)
        counts = {'objects': len(bpy.context.scene.objects), 'sourceWalls': len(recipe['terrain']['walls']), 'sourceSurfaces': len(recipe['terrain']['surfaces']), 'glbBytes': output.stat().st_size, 'recipeSHA256': hashlib.sha256(raw).hexdigest(), 'masterSHA256': hashlib.sha256(MASTER.read_bytes()).hexdigest(), 'glbSHA256': hashlib.sha256(output.read_bytes()).hexdigest(), 'action': args.action}
        (EVIDENCE / (args.action + '-provenance.json')).write_text(json.dumps(counts, indent=2)+'\n')
        print(json.dumps(counts))
        for obj in export_objects:
            bpy.data.objects.remove(obj, do_unlink=True)
    if args.action == 'inspect':
        scene = bpy.context.scene
        scene.render.engine = 'BLENDER_EEVEE_NEXT'
        scene.render.resolution_x, scene.render.resolution_y = 1280, 800
        scene.render.resolution_percentage = 100
        for view in recipe['art']['inspectionViews']:
            scene.camera = bpy.data.objects[view['id']]
            scene.render.filepath = str(EVIDENCE / (view['id'] + '.png'))
            bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    main()
