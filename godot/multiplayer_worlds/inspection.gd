extends Node3D
const Catalog = preload("res://multiplayer_worlds/catalog.gd")
const WorldMap = preload("res://multiplayer_worlds/map.gd")
const UrbanLighting = preload("res://multiplayer_worlds/urban_lighting.gd")

func _ready() -> void:
 var catalog := Catalog.new()
 if not catalog.open():
  push_error(catalog.error)
  get_tree().quit(1)
  return
 var id := "switchyard-ward"
 var output := ""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--map="): id=arg.trim_prefix("--map=")
  if arg.begins_with("--capture-directory="): output=arg.trim_prefix("--capture-directory=")
 if not catalog.entries.has(id) or output.is_empty():
  push_error("Inspection needs a registered world and --capture-directory")
  get_tree().quit(1)
  return
 var world := WorldMap.new()
 add_child(world)
 if not world.build(catalog.recipes[id]):
  push_error("World build failed")
  get_tree().quit(1)
  return
 if id in ["switchyard-ward","rainmarket-exchange"]:
  var room_lights := UrbanLighting.new()
  room_lights.name = "AuthoredInteriorLighting"
  world.add_child(room_lights)
  room_lights.build(catalog.recipes[id].arena,id == "rainmarket-exchange")
 var camera := Camera3D.new()
 camera.fov = 76
 camera.far = 300
 add_child(camera)
 camera.make_current()
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-44,-30,0)
 sun.light_energy = 1.25
 sun.shadow_enabled = true
 add_child(sun)
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color("627985")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("a0adb5")
 env.ambient_light_energy = 0.68
 var world_env := WorldEnvironment.new()
 world_env.environment = env
 add_child(world_env)
 var positions := {
  "switchyard-ward":{
   "street":[Vector3(0,2.7,-4),Vector3(-18,1.8,0)],
   "interior":[Vector3(-13.6,1.9,0),Vector3(-21,1.5,0)],
   "roof":[Vector3(-8,6.1,-18),Vector3(-27,3,-19)],
   "objective":[Vector3(15,10,18),Vector3(0,0,0)]},
  "rainmarket-exchange":{
   "street":[Vector3(14,2.8,7),Vector3(26,1.5,19)],
   "interior":[Vector3(20.4,1.9,19),Vector3(31,1.4,19)],
   "roof":[Vector3(-9,6.1,-10),Vector3(-27,2.5,-4)],
   "objective":[Vector3(16,12,28),Vector3(0,0,-7)]}}
 if not positions.has(id):
  var arena: Dictionary = catalog.recipes[id].arena
  var bounds: Dictionary = arena.bounds
  var width := float(bounds.maxX) - float(bounds.minX)
  var depth := float(bounds.maxZ) - float(bounds.minZ)
  var center := Vector3((float(bounds.minX)+float(bounds.maxX))/2,0,(float(bounds.minZ)+float(bounds.maxZ))/2)
  positions[id] = {"overview":[center+Vector3(width*.37,maxf(35,width*.21),depth*.37),center],
   "ground":[center+Vector3(-width*.23,2.2,depth*.23),center+Vector3(0,1,0)]}
 if id in ["switchyard-ward","rainmarket-exchange"]:
  for slab: Dictionary in catalog.recipes[id].arena.overhead:
   var label: String = str(slab.id).trim_suffix("-ceiling")
   var door_direction := Vector3(-1,0,0) if label in ["east-service","east-kiosk","east-warehouse"] else Vector3(1,0,0)
   if label in ["north-ticket","north-station"]: door_direction = Vector3(0,0,-1)
   if label == "south-depot": door_direction = Vector3(0,0,1)
   var center := Vector3(float(slab.x),1.8,float(slab.z))
   var length: float = float(slab.w) if absf(door_direction.x)>0 else float(slab.d)
   positions[id]["interior-"+label] = [center+door_direction*(length*.25),center-door_direction*(length*.2)]
 for key: String in positions[id]:
  camera.position = positions[id][key][0]
  camera.look_at(positions[id][key][1])
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  await RenderingServer.frame_post_draw
  var path := output.path_join(id + "-" + key + ".png")
  if get_viewport().get_texture().get_image().save_png(path) != OK:
   push_error("Capture failed " + path)
   get_tree().quit(1)
   return
  print("WORLD_CAPTURE ",path," ",world.metrics)
 get_tree().quit(0)
