"""Blender 4.5.14: build -> save -> separate-process reopen -> export.

Run only during the parent-assigned serial heavy slot. See animation/README.md.
This file has been syntax checked, not executed in Blender yet.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from glb import GLB, OWNER_MAP, source_rig
from kinematics import solve
from recipes import OPERATORS, MOVES, THROWS, library, sample, curve_hash, timing


def args():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode',choices=['build','reopen-export'])
    parser.add_argument('--operator',required=True,choices=OPERATORS)
    parser.add_argument('--root',type=Path,default=HERE.parents[2])
    parser.add_argument('--evidence',type=Path,required=True)
    parser.add_argument('--roster',type=Path)
    parser.add_argument('--draft-timing',action='store_true')
    return parser.parse_args(sys.argv[sys.argv.index('--')+1:])


def ordered(rig):
    done = []
    while len(done)<len(rig['heads']):
        for name,parent in rig['parents'].items():
            if name not in done and (parent is None or parent in done): done.append(name)
    return done


def sockets(rig):
    result = {'Chest':{'bone':'Chest','offset':[0,0,-.12]},
              'Hips':{'bone':'Hips','offset':[0,0,0]}}
    # Offsets are in exported Godot bone-local coordinates. Limb sockets use
    # +Y along the bone; knuckles extend towards the hand tip, not an FPS muzzle.
    for side,letter in (('Left','L'),('Right','R')):
        for name,bone,offset in (
            ('Hand',side+'Hand',[0,.035,0]),('Knuckle',side+'Hand',[0,.085,0]),
            ('Grip',side+'Hand',[0,.045,.025]),('Foot',side+'Foot',[0,.07,0]),
            ('Streak',side+'LowerArm',[0,.15,0]),('Elbow',side+'LowerArm',[0,0,0]),
            ('Knee',side+'LowerLeg',[0,0,0]),('Guard',side+'LowerArm',[0,.12,0])):
            result[name+letter] = {'bone':bone,'offset':offset}
    return result


def build(options,bpy):
    from mathutils import Vector
    src = options.root/'godot/source_operators/generated'/f'{options.operator}.glb'
    oracle = GLB(src)
    rig = source_rig(oracle)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(src))
    imported = list(bpy.context.scene.objects)
    scene = bpy.context.scene
    scene.render.fps = 60
    scene.frame_start,scene.frame_end = 0,60
    # Capture nearest source owner before removing the FPS hierarchy.
    kept = []
    for obj in imported:
        if obj.type != 'MESH': continue
        names = []
        parent = obj.parent
        while parent:
            names.append(parent.name)
            parent = parent.parent
        if any(n in ('weapon','gunAnchor','Muzzle') for n in names):
            bpy.data.objects.remove(obj,do_unlink=True)
            continue
        owner = next((OWNER_MAP[n] for n in names if n in OWNER_MAP),None)
        if owner is None: raise ValueError(f'unmapped body batch {obj.name}: {names}')
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.data.transform(world)
        obj.matrix_world.identity()
        obj.vertex_groups.clear()
        obj.vertex_groups.new(name=owner).add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
        obj['source_owner'] = owner
        kept.append(obj)
    for obj in imported:
        if obj.type != 'MESH' and obj.name in bpy.data.objects:
            bpy.data.objects.remove(obj,do_unlink=True)
    arm_data = bpy.data.armatures.new('FighterSkeleton')
    arm = bpy.data.objects.new('FighterSkeleton',arm_data)
    scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name in ordered(rig):
        bone = arm_data.edit_bones.new(name)
        bone.head, bone.tail = rig['heads'][name],rig['tails'][name]
        bone.use_connect = False
        parent = rig['parents'][name]
        if parent: bone.parent = arm_data.edit_bones[parent]
        # Rest geometry carries actual imported joint locations. No T-pose
        # overwrite or invented finger/toe bones on these hard-surface robots.
        bone.align_roll(Vector((0,1,0)) if not name.endswith('Foot') else Vector((0,0,1)))
    bpy.ops.object.mode_set(mode='OBJECT')
    for obj in kept:
        modifier = obj.modifiers.new('RigidSkin','ARMATURE')
        modifier.object = arm
        obj.parent = arm
    # Join across owner bones only when material/LOD/shadow agree. Vertex groups
    # retain weight=1 and disconnected rigid plates keep authored normals/colors.
    groups = {}
    for obj in kept:
        key = (tuple(m.name if m else '' for m in obj.data.materials),int(obj.get('sourceLodMask',7)),bool(obj.get('sourceCastShadow',True)))
        groups.setdefault(key,[]).append(obj)
    for index,((materials,mask,shadow),objects) in enumerate(groups.items()):
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects)>1: bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        obj.name = f'LOD{mask}_SkinBatch{index}'
        obj['sourceLodMask'],obj['sourceCastShadow'] = mask,shadow
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    arm.animation_data_create()
    clips = library(options.operator)
    for name,clip in clips.items():
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        slot = action.slots.new(id_type='OBJECT',name=arm.name)
        arm.animation_data.action = action
        arm.animation_data.action_slot = slot
        max_error = 0.0
        for frame in range(61):
            pose = sample(clip['keys'],frame/60)
            heads,tails,errors = solve(rig,pose)
            max_error = max(max_error,max(errors.values()))
            for bone_name in ordered(rig):
                pb = arm.pose.bones[bone_name]
                rest = arm.data.bones[bone_name]
                direction = Vector(tails[bone_name])-Vector(heads[bone_name])
                original = rest.tail_local-rest.head_local
                rotation = original.rotation_difference(direction)
                matrix = rotation.to_matrix().to_4x4() @ rest.matrix_local
                matrix.translation = Vector(heads[bone_name])
                pb.matrix = matrix
                # World matrices are resolved parent-first before keying local
                # basis. Wrist twist is a deliberate local hand-axis channel.
                if bone_name.endswith('Hand'):
                    from mathutils import Quaternion
                    index = 0 if bone_name.startswith('Left') else 1
                    pb.rotation_mode = 'QUATERNION'
                    pb.rotation_quaternion = pb.rotation_quaternion @ Quaternion((0,1,0),math.radians(pose['wrist'][index]))
                pb.keyframe_insert(data_path='location',frame=frame,group=bone_name)
                pb.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=bone_name)
                pb.keyframe_insert(data_path='scale',frame=frame,group=bone_name)
        # 4.5 slotted Action API, not removed legacy action.fcurves.
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points: key.interpolation = 'LINEAR'
        action['curve_sha256'] = curve_hash(clip)
        action['max_ik_clamp_m'] = max_error
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name,0,action)
        strip.action_slot = slot
        track.mute = True
        arm.animation_data.action = None
    for pb in arm.pose.bones: pb.matrix_basis.identity()
    arm['operator_id'] = options.operator
    arm['source_sha256'] = oracle.sha256
    arm['recipe_schema'] = 1
    arm['rig_json'] = json.dumps(rig)
    master = options.root/'tools/fighting/animation/masters'/f'{options.operator}.blend'
    master.parent.mkdir(parents=True,exist_ok=True)
    scene.frame_set(0)
    bpy.ops.wm.save_as_mainfile(filepath=str(master))
    return {'status':'master_saved_unreviewed','master':str(master),'actions':len(clips),
            'bones':len(rig['heads']),'skin_batches':len(groups),'source_sha256':oracle.sha256}


def reopen_export(options,bpy):
    master = options.root/'tools/fighting/animation/masters'/f'{options.operator}.blend'
    bpy.ops.wm.open_mainfile(filepath=str(master))
    arm = next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    assert arm['operator_id']==options.operator
    clips = library(options.operator)
    actions = {t.name:t.strips[0].action for t in arm.animation_data.nla_tracks}
    assert set(actions)==set(clips), (set(actions)^set(clips))
    for name,action in actions.items():
        assert action['curve_sha256']==curve_hash(clips[name]), f'stale master: {name}'
        assert len(action.slots)==1 and len(action.layers)>0
    for bone in arm.data.bones:
        assert bone.length>.025 and all(math.isfinite(v) for row in bone.matrix_local for v in row)
    for obj in bpy.context.scene.objects:
        if obj.type=='MESH':
            assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for v in obj.data.vertices)
    if not options.roster and not options.draft_timing:
        raise ValueError('--roster required, or explicitly label --draft-timing for vertical-slice inspection')
    roster = {}
    if options.roster:
        roster = {x['id']:x for x in json.loads(options.roster.read_text())['operators']}
    manifests = {}
    for name,clip in clips.items():
        content = None
        if options.roster:
            if name in MOVES:
                content = roster[options.operator]['moves'][name]
                assert content['animation']==name, f'content animation mismatch: {name}'
            elif name.startswith('victim_'):
                pair = clip['pair']
                content = roster[pair['attacker']]['moves'][pair['move']]
        manifests[name] = {'duration':1.0,'loop':clip['loop'],'phases':clip['phases'],
            'seek_keys':timing(clip,content),'curve_sha256':curve_hash(clip),
            'max_ik_clamp_m':actions[name]['max_ik_clamp_m']}
    output = options.root/'godot/fighting/assets/operators'
    output.mkdir(parents=True,exist_ok=True)
    glb_path = output/f'{options.operator}.glb'
    bpy.ops.export_scene.gltf(filepath=str(glb_path),export_format='GLB',export_animations=True,
        export_animation_mode='ACTIONS',export_merge_animation='NONE',export_anim_single_armature=True,
        export_reset_pose_bones=True,export_force_sampling=True,export_frame_range=False,
        export_anim_slide_to_zero=True,export_skins=True,export_extras=True,export_yup=True)
    exported = GLB(glb_path)
    actual_names = {a['name'] for a in exported.doc.get('animations',[])}
    assert actual_names==set(clips), f'export clip names differ: {actual_names^set(clips)}'
    assert len(exported.doc.get('skins',[]))==1
    rig = json.loads(arm['rig_json'])
    manifest = {'version':1,'operator_id':options.operator,'status':'exported_unreviewed',
        'timing_status':'content_bound' if options.roster else 'draft',
        'sha256':exported.sha256,'source_sha256':arm['source_sha256'],
        'master_sha256':hashlib.sha256(master.read_bytes()).hexdigest(),
        'source_forward':'-Z','root_yaw_right':-math.pi/2,'clips':manifests,
        'sockets':sockets(rig),'bone_map':{name:name for name in rig['heads']},
        'root_motion':'locked','native_accepted':False}
    (output/f'{options.operator}.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return {'status':'reopened_exported_unreviewed','file':str(glb_path),'sha256':exported.sha256,'clips':len(clips)}


if __name__=='__main__':
    options = args()
    import bpy
    if bpy.app.version[:2] != (4,5): raise RuntimeError('Blender 4.5 LTS required')
    options.evidence.mkdir(parents=True,exist_ok=True)
    result = build(options,bpy) if options.mode=='build' else reopen_export(options,bpy)
    (options.evidence/f'{options.operator}-{options.mode}.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
