"""Editable Rootfall wreck and Crown receiver. Blender 4.5, world Y up.

Meshes are authored in the original recipe's dimensionless scale: the fallen
mast uses (26,4,4), the Crown receiver (30,12,30). Save the editable separate
parts before coalescing same-material export meshes into a small GLB.
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[3]
bpy.context.preferences.filepaths.save_version = 0
SOURCES = Path(__file__).resolve().parent / 'blend'
OUTPUT = ROOT / 'godot/campaign/art/landmarks'
SOURCES.mkdir(parents=True, exist_ok=True)
OUTPUT.mkdir(parents=True, exist_ok=True)


def mat(name, color, metal=.65):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    shader = m.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Metallic'].default_value = metal
    shader.inputs['Roughness'].default_value = .68
    return m


def bar(name, a, b, radius, material, vertices=6):
    a, b = Vector(a), Vector(b)
    direction = b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                        depth=direction.length, location=(a+b)*.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat('Z', 'Y').to_euler()
    obj.data.materials.append(material)
    return obj


def cylinder(name, pos, radius, depth, material, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                        depth=depth, location=pos)
    bpy.context.object.name = name
    bpy.context.object.data.materials.append(material)


def wedge(name, corners, depth, material):
    # Closed, two-sided formed sheet; no invisible underside from below.
    vertices = [(x,y,z) for x,y,z in corners] + [(x,y-depth,z) for x,y,z in corners]
    n = len(corners)
    faces = [tuple(range(n)), tuple(reversed(range(n,2*n)))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)


def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)


def wreck():
    clear()
    steel = mat('Wreck / oxidized gunmetal', (.16,.24,.25))
    edge = mat('Wreck / exposed fractured alloy', (.55,.55,.43))
    hardware = mat('Wreck / weathered copper', (.39,.26,.14))
    # Six triangular, tapering bays. The saddle in the bottom chord rests on
    # the existing relay cabin roof; the two broken ends descend to terrain.
    xs = [-.48,-.34,-.18,0,.15,.30]
    bottom = [.025,.15,.34,.54,.45,.34]
    width = [.23,.28,.29,.25,.21,.16]
    # Sweep the snapped western end away from the encounter-1 flank loop.
    # The saddle returns to the unchanged cabin centre / supported roof.
    bends = [-.55,-.35,-.15,0,0,0]
    points = []
    for x,y,w,z in zip(xs,bottom,width,bends):
        points.append([(x,y,z-w),(x,y,z+w),(x,y+.42,z)])
    for i, triangle in enumerate(points):
        for j in range(3):
            bar('Riveted triangular bulkhead %d'%i,triangle[j],triangle[(j+1)%3],.019,steel)
            cylinder('Gusset boss',triangle[j],.033,.035,hardware,8)
    for i in range(len(points)-1):
        for j in range(3):
            bar('Continuous tapered main chord',points[i][j],points[i+1][j],.027,steel)
        for side in (0,1):
            # Opposed side-face diagonals are part of a spatial triangle, not
            # the old flat parallel ladder. Leave alternating open voids.
            bar('Staggered shear diagonal',points[i][side],points[i+1][2],.013,steel)
            if i%2 == 0:
                bar('Counterbrace',points[i][2],points[i+1][side],.011,steel)
    # Bent antenna stays attached to the tower frame, and jagged break plates
    # show where the remaining mast tore away. All within the old prop envelope.
    for xidx in (0,-1):
        tri=points[xidx]
        wedge('Torn termination flange',[(tri[0][0],tri[0][1],tri[0][2]),
              (tri[1][0],tri[1][1],tri[1][2]),(tri[2][0],tri[2][1],tri[2][2])],.018,edge)
    bar('Broken aerial feed',points[1][2],(-.31,.86,.12),.017,hardware)
    bar('Bent aerial tip',(-.31,.86,.12),(-.24,.76,.20),.012,hardware)
    cylinder('Ceramic feed isolator',(-.31,.86,.12),.041,.085,edge,8)
    return 'fallen-relay'


def receiver():
    clear()
    frame = mat('Receiver / structural graphite', (.12,.19,.23))
    fascia = mat('Receiver / segmented pale reflectors', (.52,.60,.59),.34)
    trim = mat('Receiver / copper contact hardware', (.45,.31,.18))
    # Anchor exactly over the two existing court buttresses (top y 84.02/84.31).
    # In the recipe frame, their offsets are (-7.155,+8.050) and (+10.733,-.894).
    anchors = [(-7.155/30,(84.02243-86.89758)/12,8.050/30),
               (10.733/30,(84.30718-86.89758)/12,-.894/30)]
    hub=(0,.39,0)
    for i,anchor in enumerate(anchors):
        bar('Buttress-to-hub compression truss %d'%i,anchor,hub,.025,frame,8)
        for side in (-1,1):
            foot=(anchor[0]+side*.028,anchor[1],anchor[2])
            bar('Splayed bearing leg',foot,(0,.29,0),.012,frame)
        cylinder('Bearing shoe %d'%i,(anchor[0],anchor[1]+.012,anchor[2]),.057,.025,trim)
    cylinder('Azimuth bearing drum',(0,.41,0),.09,.14,frame,16)
    cylinder('Gimbal collar',(0,.51,0),.135,.035,trim,16)
    # Open parabolic lattice rather than an opaque slab. Radial ribs curve from
    # hub to rim; individual reflector petals leave ample sky visible below.
    n=24
    def ring(angle,r):
        return (r*math.cos(angle),.49+.48*(r/.49)**2,r*math.sin(angle))
    for i in range(n):
        a=2*math.pi*i/n
        b=2*math.pi*(i+1)/n
        mid=2*math.pi*(i+.5)/n
        root=ring(a,.11); middle=ring(a,.31); outer=ring(a,.49)
        # The original Crown-fin skyline rises through this southern sector.
        # A genuine open service aperture gives the tall fins an unobstructed
        # envelope; the two cut ends have their own load-bearing radial edges.
        if 12 <= i <= 20:
            if i in (12,20):
                bar('Service-aperture terminal spar',ring(a if i==12 else b,.11),
                    ring(a if i==12 else b,.49),.021,frame)
            continue
        bar('Curved dish radial inner rib',root,middle,.009,frame)
        bar('Curved dish radial outer rib',middle,outer,.009,frame)
        bar('Continuous lip ring',outer,ring(b,.49),.014,trim)
        bar('Intermediate circumferential stringer',middle,ring(b,.31),.007,frame)
        if i%3 != 1:
            # Individual angled reflectors occupy only outer annulus, with an
            # open gap between each; narrow segmented geometry from underneath.
            corners=[ring(a+.025,.335),ring(b-.025,.335),
                     ring(b-.025,.465),ring(a+.025,.465)]
            wedge('Separated reflector petal %02d'%i,corners,.012,fascia)
        if i%4==0:
            bar('Rear spider arm',ring(mid,.31),(0,.34,0),.009,frame)
    bar('Central focal boom',(0,.54,0),(0,1.12,0),.016,frame)
    cylinder('Focal pickup',(0,1.11,0),.068,.09,trim,12)
    for i in range(3):
        a=2*math.pi*i/3
        bar('Tripod feed stay',ring(a,.26),(0,1.06,0),.009,frame)
    return 'crown-receiver'


for builder in (wreck,receiver):
    name=builder()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCES/(name+'.blend')))
    # Material-separated merged surfaces cap runtime draw calls at three.
    for obj in list(bpy.context.scene.objects):
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    for material in list(bpy.data.materials):
        objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials and o.data.materials[0]==material]
        if not objects: continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.convert(target='MESH')
        bpy.ops.object.join()
        bpy.context.object.name=material.name
    # Geometry was described Y-up in the campaign's metre frame. Undo glTF's
    # Blender Z-up conversion explicitly, matching the existing structure kit.
    upright=Matrix.Rotation(math.pi/2,4,'X')
    for obj in bpy.context.scene.objects:
        obj.matrix_world=upright @ obj.matrix_world
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT/(name+'.glb')),export_format='GLB',
                              use_selection=True,export_yup=True,export_apply=True)
