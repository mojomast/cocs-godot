extends Node3D
const Catalog = preload("res://multiplayer_worlds/catalog.gd")
const WorldMap = preload("res://multiplayer_worlds/map.gd")
var camera := Camera3D.new()
var world := WorldMap.new()

func _ready() -> void:
 var id := "breakwater-exchange"
 var directory := ""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--map="): id=arg.trim_prefix("--map=")
  if arg.begins_with("--capture-directory="): directory=arg.trim_prefix("--capture-directory=")
 var catalog := Catalog.new()
 if directory.is_empty() or not catalog.open() or not catalog.recipes.has(id):
  push_error("Unknown world inspection or missing capture directory: " + id)
  get_tree().quit(2)
  return
 add_child(world)
 if not world.build(catalog.recipes[id]):
  get_tree().quit(2)
  return
 var sunlight := DirectionalLight3D.new()
 sunlight.rotation_degrees=Vector3(-46,-31,0)
 sunlight.light_energy=1.05
 sunlight.shadow_enabled=true
 add_child(sunlight)
 var environment := Environment.new()
 environment.background_mode=Environment.BG_COLOR
 environment.background_color=Color("6b8796")
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color=Color("a7b6bb")
 environment.ambient_light_energy=.43
 var sky := WorldEnvironment.new()
 sky.environment=environment
 add_child(sky)
 camera.fov=72
 camera.far=600
 add_child(camera)
 camera.make_current()
 var views := {
  "breakwater-exchange":{"overview":[Vector3(86,74,96),Vector3(0,1,0)],"ground":[Vector3(-78,1.7,-13),Vector3(-25,1.5,18)],"interior":[Vector3(-31,1.7,41),Vector3(-15,1.7,41)],"gantry":[Vector3(-31,2,-56),Vector3(-10,11,-56)],"objective":[Vector3(0,18,12),Vector3(0,0,19)]},
  "thermal-divide":{"overview":[Vector3(89,69,85),Vector3(0,1,0)],"ground":[Vector3(-78,1.7,-12),Vector3(-49,1,0)],"interior":[Vector3(-49,1.7,15),Vector3(-30,1.7,15)],"bridge":[Vector3(-24,5.7,39),Vector3(15,4,39)],"objective":[Vector3(0,18,-35),Vector3(0,0,-35)]},
  "sirocco-circuit":{"overview":[Vector3(152,105,130),Vector3(0,1,0)],"ground":[Vector3(-58,1.7,-66),Vector3(25,1.5,-66)],"hairpin":[Vector3(65,18,55),Vector3(43,0,35)],"pits":[Vector3(-20,4,-93),Vector3(-20,0,-66)],"objective":[Vector3(100,24,0),Vector3(0,0,0)]},
  "copper-bowl":{"overview":[Vector3(73,55,78),Vector3(0,1,0)],"ground":[Vector3(-34,1.7,-10),Vector3(0,1.1,0)],"goal":[Vector3(40,3,0),Vector3(52,1,0)],"stands":[Vector3(0,12,52),Vector3(0,0,0)],"objective":[Vector3(0,25,40),Vector3(0,0,0)]},
  "tern-archipelago":{"overview":[Vector3(103,90,120),Vector3(0,1,0)],"ground":[Vector3(-104,1.7,0),Vector3(-54,1,0)],"interior":[Vector3(-104,1.7,0),Vector3(-80,1.7,0)],"causeway":[Vector3(-64,1.7,-55),Vector3(0,1.5,-55)],"objective":[Vector3(0,22,50),Vector3(0,0,0)]},
 }
 if not views.has(id):
  get_tree().quit(2)
  return
 for label: String in views[id]:
  camera.position=views[id][label][0]
  camera.look_at(views[id][label][1])
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  await RenderingServer.frame_post_draw
  var image: Image=get_viewport().get_texture().get_image()
  var path: String=directory.path_join(id+"-"+label+".png")
  if image.save_png(path)!=OK:
   push_error("Could not save " + path)
   get_tree().quit(2)
   return
  print("WORLD_WORLD_CAPTURE ",path," ",JSON.stringify(world.metrics))
 get_tree().quit()
