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
            rgb = tuple(int(color[i:i+2], 16) / 255 for i in (1, 3, 5))
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
            bpy.ops.mesh.primitive_cube_add(size=1, location=coord((x, y, z)))
            obj = bpy.context.object
            obj.name = name
            obj.scale = (w, d, h)
            obj.data.materials.append(materials[material])
            link(obj, collection)
            return obj

        for surface in recipe['terrain']['surfaces']:
            mesh(surface['id'], surface['vertices'], surface['triangles'], surface['material'], 'AUTHORITY-surfaces', True)
        # Individual triangle wall objects retain source identifiers for diagnosis.
        for wall in recipe['terrain']['walls']:
            mesh(wall['id'], wall['vertices'], [(0, 1, 2)], wall['material'], 'AUTHORITY-walls', True)
        for piece in recipe['art']['pieces']:
            cube(piece['kind'], piece['x'], piece['y'], piece['z'], piece['w'], piece['h'], piece['d'], piece['material'])
        # Handbuilt window reveals and lintel trim remain outside actual apertures.
        for hall in recipe['structures']:
            y = 24 if hall['z'] > 65 else 0 if hall['z'] < -65 else 12
            for side in (-1, 1):
                z = hall['z'] + side * hall['d'] / 2
                cube(hall['id'] + '-cornice', hall['x'], y + hall['height'] - .2, z, hall['w'], .4, .5, 'sandstone')
            # Deep steel roof trusses, supported on the actual wall line.
            for offset in (-hall['w']/3, 0, hall['w']/3):
                cube(hall['id'] + '-tiebeam', hall['x'] + offset, y + hall['height'] - .5, hall['z'], .4, .5, hall['d'], 'iron')
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
            obj.rotation_euler = (math.pi/2, 0, 0)
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
