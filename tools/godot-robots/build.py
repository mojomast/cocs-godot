"""Run ONLY after parent grants Blender slot: blender -b -t 1 --python build.py.

Writes editable assembled skeletal masters outside Godot, runtime rigid GLBs,
and measured build receipts. Never run this via an editor auto-import hook.
"""
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from recipe import SKINS, PALETTE, SEED, robot, props, manifest

ROOT = HERE.parents[1]
OUT = ROOT / 'godot/robot_assets/switchyard/generated'
MASTERS = HERE / 'masters'


def xyz(v):
    return Vector((v[0], -v[2], v[1]))


def reset():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    # New file payloads must not inherit a prior skin's action library.
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    mat = bpy.data.materials.new('Switchyard_vertex_enamel')
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Metallic'].default_value = .6
    bsdf.inputs['Roughness'].default_value = .46
    col = mat.node_tree.nodes.new('ShaderNodeVertexColor')
    col.layer_name = 'Col'
    mat.node_tree.links.new(col.outputs['Color'], bsdf.inputs['Base Color'])
    return mat


def piece(spec, material):
    if spec['shape'] == 'box':
        bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(spec['p']))
        obj = bpy.context.object
        obj.dimensions = (spec['size'][0], spec['size'][2], spec['size'][1])
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    else:
        a, b = xyz(spec['a']), xyz(spec['b'])
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=spec['radius'],
                                           depth=(b-a).length, location=(a+b)/2)
        obj = bpy.context.object
        obj.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    obj.name = spec['name']
    bevel = obj.modifiers.new('machined_edge', 'BEVEL')
    bevel.width = spec['bevel']; bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.data.materials.append(material)
    colors = obj.data.color_attributes.new(name='Col', type='FLOAT_COLOR', domain='CORNER')
    for c in colors.data:
        c.color = PALETTE[spec['material']]
    return obj


def assemblies(specs, prefix, material):
    groups = {}
    for spec in specs:
        groups.setdefault(spec['joint'], []).append(piece(spec, material))
    out = {}
    for joint, objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        obj = bpy.context.object
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        obj.name = prefix + joint
        obj.data.name = obj.name
        obj.data.calc_loop_triangles()
        out[joint] = obj
    return out


def export(path):
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB',
        export_yup=True, export_animations=True, export_extras=True,
        export_materials='EXPORT', export_all_vertex_colors=True,
        export_animation_mode='ACTIONS')


def skeleton(joints, meshes):
    armature = bpy.data.armatures.new('Switchyard_rigid_skeleton')
    rig = bpy.data.objects.new('SwitchyardRig', armature)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    absolute = {}
    def position(name):
        if name not in absolute:
            j = joints[name]
            absolute[name] = xyz(j['at']) + (position(j['parent']) if j['parent'] else Vector())
        return absolute[name]
    for name in joints:
        bone = armature.edit_bones.new(name)
        bone.head = position(name)
        bone.tail = bone.head + Vector((0, 0, .08))
    for name, j in joints.items():
        if j['parent']:
            armature.edit_bones[name].parent = armature.edit_bones[j['parent']]
    bpy.ops.object.mode_set(mode='OBJECT')
    for name, obj in meshes.items():
        obj.location = position(name)
        group = obj.vertex_groups.new(name=name)
        group.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
        mod = obj.modifiers.new('rigid_joint_weights', 'ARMATURE')
        mod.object = rig
        obj.parent = rig
    return rig


def author_clips(rig, role):
    """Editable bounded reference clips. Native Motion.contact/IK is authoritative
    for presentation cadence, and supersedes these reference poses at runtime.
    Clips are in masters/inspection GLBs, never simultaneously played by adapter.
    """
    rig.animation_data_create()
    for clip, duration in [('idle', 2), ('walk', 1), ('attack', .6), ('react', .3), ('death', .8)]:
        action = bpy.data.actions.new(clip)
        rig.animation_data.action = action
        for frame in range(round(duration*30)+1):
            t = frame/(duration*30)
            for bone in rig.pose.bones:
                bone.rotation_mode = 'XYZ'
                bone.rotation_euler = (0, 0, 0)
                bone.location = (0, 0, 0)
                if clip == 'idle' and bone.name == 'Weapon':
                    amplitude = {'skirmisher': .014, 'bulwark': .006, 'mortar': .01}[role]
                    bone.rotation_euler.x = amplitude*math.sin(t*math.tau)
                if clip == 'walk' and bone.name.startswith(('Hip', 'Shin')):
                    phase = t*math.tau + int(bone.name[-1])*math.pi
                    bone.rotation_euler.x = (.12 if role == 'skirmisher' else .075)*math.sin(phase)
                    if bone.name.startswith('Shin'):
                        bone.rotation_euler.x *= -.8
                if clip == 'attack' and bone.name == 'Weapon':
                    bone.rotation_euler.x = -(.45 if role == 'mortar' else .2)*math.sin(math.pi*t)
                    bone.location.y = -.13*math.sin(math.pi*t)**4
                if clip == 'attack' and bone.name == 'Shield':
                    bone.rotation_euler.x = -.2*math.sin(math.pi*t)
                if clip == 'react' and bone.name == 'Chassis':
                    bone.location.y = -.012*math.sin(math.pi*t)
                if clip == 'death' and bone.name == 'Chassis':
                    s = min(1, duration*t/.65); s = s*s*s*(s*(s*6-15)+10)
                    bone.location.z = -.32*s
                    bone.rotation_euler.y = -.22*s
                bone.keyframe_insert('location', frame=frame+1)
                bone.keyframe_insert('rotation_euler', frame=frame+1)
        track = rig.animation_data.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, 1, action)
        track.mute = True
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.location = (0, 0, 0); bone.rotation_euler = (0, 0, 0)


def metrics(meshes):
    return {name: {'vertices': len(o.data.vertices), 'triangles': len(o.data.loop_triangles),
                   'surfaces': len(o.data.materials),
                   'boundsBlender': [[min(v.co[i] for v in o.data.vertices) for i in range(3)],
                                     [max(v.co[i] for v in o.data.vertices) for i in range(3)]]}
            for name, o in meshes.items()}


def main():
    OUT.mkdir(parents=True, exist_ok=True); MASTERS.mkdir(parents=True, exist_ok=True)
    receipt = {'seed': SEED, 'blender': bpy.app.version_string, 'assets': {},
               'recipeSHA256': hashlib.sha256(json.dumps(manifest(), sort_keys=True).encode()).hexdigest(),
               'generatorSHA256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    for skin, role in SKINS.items():
        mat = reset(); measured = {}
        for lod in range(3):
            source = robot(skin, lod)
            objects = assemblies(source['pieces'], f'L{lod}_', mat)
            measured[f'LOD{lod}'] = metrics(objects)
        target = OUT / f'{skin}.glb'
        export(target)
        receipt['assets'][skin] = {'sha256': hashlib.sha256(target.read_bytes()).hexdigest(), 'lods': measured}
        mat = reset(); source = robot(skin)
        objects = assemblies(source['pieces'], '', mat)
        rig = skeleton(source['joints'], objects)
        author_clips(rig, role)
        bpy.context.scene.render.fps = 30
        bpy.ops.wm.save_as_mainfile(filepath=str(MASTERS / f'{skin}.blend'))
        export(MASTERS / f'{skin}_skeletal.glb')
    for name, specs in props().items():
        mat = reset(); objects = assemblies(specs, '', mat)
        bpy.ops.wm.save_as_mainfile(filepath=str(MASTERS / f'{name}.blend'))
        target = OUT / f'{name}.glb'; export(target)
        receipt['assets'][name] = {'sha256': hashlib.sha256(target.read_bytes()).hexdigest(), 'meshes': metrics(objects), 'collision': None}
    (OUT / 'build-receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')


if __name__ == '__main__':
    main()
