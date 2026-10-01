"""Headless visual review of editable masters against their source terrain.

LP_NUM_THREADS=1 blender -b -t 1 --python tools/godot-multiplayer/urban/capture.py -- OUTPUT_DIRECTORY
Workbench only; not a Godot acceptance screenshot. Geometry from recipes is
temporary visualization and never saved into the art-only master or GLB.
"""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(sys.argv[sys.argv.index('--')+1])
OUT.mkdir(parents=True,exist_ok=True)
DATA=ROOT/'godot/multiplayer_worlds/generated'
MASTERS=ROOT/'tools/godot-multiplayer/urban'
VIEWS={
 'switchyard-ward':{
  'street':((0,-4,2.7),(-18,0,1.8)),
  'interior':((-13.6,0,1.9),(-21,0,1.5)),
  'roof':((-8,-18,6.1),(-27,-19,3.0)),
  'junction':((8,9,12),(0,-2,1.2))},
 'rainmarket-exchange':{
  'street':((14,7,2.8),(26,19,1.5)),
  'interior':((20.4,19,1.9),(31,19,1.4)),
  'roof':((-9,-10,6.1),(-27,-4,2.5)),
  'market':((-12,24,8),(9,12,1.5))}}

for map_id,views in VIEWS.items():
 bpy.ops.wm.open_mainfile(filepath=str(MASTERS/f'{map_id}.blend'))
 arena=json.loads((DATA/f'{map_id}.json').read_text())['arena']
 for surface in arena['terrain']['surfaces']:
  vertices=[(x,z,y-.006) for x,y,z in surface['vertices']]
  mesh=bpy.data.meshes.new(surface['id'])
  mesh.from_pydata(vertices,[],surface['triangles'])
  mesh.update()
  mat=bpy.data.materials.new('temporary authoritative '+surface['material'])
  colors={'asphalt':(.18,.23,.26),'wet-stone':(.24,.32,.34),'paving':(.46,.47,.45),'roof':(.35,.37,.38),'grating':(.34,.37,.31)}
  mat.diffuse_color=(*colors.get(surface['material'],(.25,.31,.3)),1)
  mesh.materials.append(mat)
  obj=bpy.data.objects.new('SOURCE TERRAIN / '+surface['id'],mesh)
  bpy.context.collection.objects.link(obj)
 scene=bpy.context.scene
 scene.render.engine='CYCLES'
 scene.cycles.device='CPU'
 scene.cycles.samples=12
 scene.render.threads_mode='FIXED'
 scene.render.threads=1
 scene.world.color=(.5,.6,.7)
 for n,loc,power,size in [('sky fill',(5,10,45),8500,32),('street fill',(-22,-28,22),3700,25)]:
  lamp=bpy.data.lights.new(n,'AREA')
  lamp.energy=power
  lamp.shape='DISK'
  lamp.size=size
  obj=bpy.data.objects.new(n,lamp)
  bpy.context.collection.objects.link(obj)
  obj.location=loc
  obj.rotation_euler=(Vector((0,0,0))-obj.location).to_track_quat('-Z','Y').to_euler()
 scene.render.resolution_x=1280
 scene.render.resolution_y=800
 scene.render.resolution_percentage=100
 scene.render.image_settings.file_format='PNG'
 camera_data=bpy.data.cameras.new('Review camera')
 camera=bpy.data.objects.new('Review camera',camera_data)
 bpy.context.collection.objects.link(camera)
 scene.camera=camera
 camera_data.lens=27
 camera_data.clip_end=300
 for label,(position,target) in views.items():
  camera.location=position
  direction=Vector(target)-camera.location
  camera.rotation_euler=direction.to_track_quat('-Z','Y').to_euler()
  path=OUT/f'{map_id}-{label}-blender.png'
  scene.render.filepath=str(path)
  bpy.ops.render.render(write_still=True)
  print('URBAN_REVIEW',path,flush=True)
