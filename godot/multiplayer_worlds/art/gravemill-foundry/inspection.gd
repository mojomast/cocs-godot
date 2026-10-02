extends SceneTree
const WorldMap = preload("res://multiplayer_worlds/map.gd")

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var destination := "/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002/native-views"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--out="): destination = arg.trim_prefix("--out=")
 DirAccess.make_dir_recursive_absolute(destination)
 var before := Time.get_ticks_msec()
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/gravemill-foundry.json"))
 var world := WorldMap.new()
 root.add_child(world)
 if not world.build(data): quit(2); return
 var sun := DirectionalLight3D.new()
 world.add_child(sun)
 sun.rotation_degrees = Vector3(-44,-30,0)
 sun.light_energy = 1.25
 sun.shadow_enabled = true
 var environment := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color("627985")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("a0adb5")
 env.ambient_light_energy = .68
 environment.environment = env
 world.add_child(environment)
 var camera := Camera3D.new()
 world.add_child(camera)
 camera.far = 1000
 camera.fov = 74
 camera.make_current()
 var views := [
  ["overview",Vector3(275,230,-290),Vector3(0,12,0)],
  ["reverse",Vector3(-270,160,220),Vector3(0,12,0)],
  ["crusher-eye",Vector3(-117,1.65,-60),Vector3(-59,14,-10)],
  ["cooling-eye",Vector3(-95,13.65,22.7),Vector3(-45,17,29.7)],
  ["assay-eye",Vector3(37,13.65,41.18),Vector3(86,17,48.04)],
  ["crown-eye",Vector3(-101,25.65,94.86),Vector3(55,25,116.7)],
  ["furnace-eye",Vector3(113,1.65,-22.18),Vector3(65,20,1.1)]
 ]
 for view: Array in views:
  camera.fov = 45 if view[0] in ["overview", "reverse"] else 74
  camera.global_position = view[1]
  camera.look_at(view[2])
  for i in range(4): await process_frame
  await RenderingServer.frame_post_draw
  var error := root.get_texture().get_image().save_png(destination.path_join(str(view[0])+".png"))
  if error != OK: push_error("capture failed"); quit(2); return
  print("FOUNDRY_NATIVE_VIEW ", JSON.stringify({"view":view[0],"hash":world.geometry_hash,"elapsedMs":Time.get_ticks_msec()-before,"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"renderObjects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"renderPrimitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"nodes":get_node_count(),"metrics":world.metrics}))
 quit()
