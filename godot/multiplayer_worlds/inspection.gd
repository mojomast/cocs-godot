extends Node3D
const Catalog = preload("res://multiplayer_worlds/catalog.gd")
const WorldMap = preload("res://multiplayer_worlds/map.gd")

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
 var camera := Camera3D.new()
 camera.fov = 76
 camera.far = 300
 add_child(camera)
 camera.make_current()
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-48,-22,0)
 sun.light_energy = 1.9
 add_child(sun)
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color("5d7689")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("b6c4c4")
 env.ambient_light_energy = 0.8
 var world_env := WorldEnvironment.new()
 world_env.environment = env
 add_child(world_env)
 var positions := {
  "switchyard-ward":{
   "street":[Vector3(0,2.1,9),Vector3(0,1,-17)],
   "interior":[Vector3(-17,1.8,0),Vector3(-8,1,0)],
   "roof":[Vector3(-27,5.3,-19),Vector3(-8,1,-19)],
   "objective":[Vector3(15,10,18),Vector3(0,0,0)]},
  "rainmarket-exchange":{
   "street":[Vector3(0,2.1,23),Vector3(0,1,-17)],
   "interior":[Vector3(26,1.8,19),Vector3(18,1,19)],
   "roof":[Vector3(-26,4.8,-4),Vector3(-8,1,-4)],
   "objective":[Vector3(16,12,28),Vector3(0,0,-7)]}}
 if not positions.has(id):
  var arena: Dictionary = catalog.recipes[id].arena
  var bounds: Dictionary = arena.bounds
  var width := float(bounds.maxX) - float(bounds.minX)
  var depth := float(bounds.maxZ) - float(bounds.minZ)
  var center := Vector3((float(bounds.minX)+float(bounds.maxX))/2,0,(float(bounds.minZ)+float(bounds.maxZ))/2)
  positions[id] = {"overview":[center+Vector3(width*.37,maxf(35,width*.21),depth*.37),center],
   "ground":[center+Vector3(-width*.23,2.2,depth*.23),center+Vector3(0,1,0)]}
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
