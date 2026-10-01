"""Blender-only placement diagnostic; never substitute for Godot acceptance.

blender -b -t 1 tools/godot-multiplayer/worlds/masters/<id>.blend \
  --python tools/godot-multiplayer/worlds/offline_preview.py -- <id> <view>
"""
import math
import pathlib
import sys

import bpy
from mathutils import Vector

id,view=sys.argv[sys.argv.index('--')+1:sys.argv.index('--')+3]
views={
    'breakwater-exchange':{'ground':((-78,1.7,-13),(-25,1.5,18)),'quay':((-77,1.7,-46),(-25,8,-56)),'overview':((86,74,96),(0,1,0))},
    'thermal-divide':{'ground':((-78,1.7,-12),(-49,1,0)),'plant':((-67,1.7,4),(-49,12,15)),'overview':((89,69,85),(0,1,0))},
    'sirocco-circuit':{'ground':((-58,1.7,-66),(25,1.5,-66)),'overview':((152,105,130),(0,1,0))},
    'copper-bowl':{'goal':((40,3,0),(52,1,0)),'sideline':((-15,3,-21),(47,2,0)),'overview':((73,55,78),(0,1,0))},
    'tern-archipelago':{'causeway':((-64,1.7,-55),(0,1.5,-55)),'overview':((103,90,120),(0,1,0))},
}
def zup(p):return Vector((p[0],-p[2],p[1]))
for c in bpy.data.collections:
    if c.name.startswith('SOURCE -'):c.hide_render=True
    if c.name.startswith('EXPORT -'):c.hide_render=False
camera_data=bpy.data.cameras.new('Offline camera / review composition')
camera=bpy.data.objects.new('Offline camera / review composition',camera_data)
bpy.context.scene.collection.objects.link(camera)
eye,target=views[id][view]
camera.location=zup(eye)
camera.rotation_euler=(zup(target)-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='PERSP'
# Godot's Camera3D.fov=72 is vertical at 1280×800. Blender's angle is
# horizontal at its default sensor fit, so convert instead of narrowing view.
camera_data.angle=2*math.atan(math.tan(math.radians(72)/2)*1280/800)
camera_data.clip_end=650
scene=bpy.context.scene
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.device='CPU'
scene.cycles.samples=8
scene.cycles.use_denoising=False
scene.world.color=(.3,.38,.42)
light_data=bpy.data.lights.new('Diagnostic sun','SUN')
light_data.energy=2
sun=bpy.data.objects.new('Diagnostic sun',light_data)
scene.collection.objects.link(sun)
sun.rotation_euler=(math.radians(42),0,math.radians(-30))
scene.render.resolution_x=1280
scene.render.resolution_y=800
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
root=pathlib.Path('/home/mojo/.tmp-on-disk/cocs-multiplayer-evidence-20261001/worlds')
scene.render.filepath=str(root/(id+'-'+view+'-BLENDER-DIAGNOSTIC.png'))
bpy.ops.render.render(write_still=True)
print('OFFLINE_BLENDER_DIAGNOSTIC',scene.render.filepath)
