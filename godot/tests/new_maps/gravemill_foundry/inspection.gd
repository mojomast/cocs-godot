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
  ["crusher-eye",Vector3(-94,1.45,-51.16),Vector3(-49,8,-27)],
  ["crusher-maintenance",Vector3(-88,11.53,4.68),Vector3(-65,14,-8)],
  ["cooling-eye",Vector3(-82,13.45,24.52),Vector3(-46,16,29.56)],
  ["cooling-cross-aisle",Vector3(-66,13.45,26.76),Vector3(-82,17,17.52)],
  ["assay-eye",Vector3(48,13.45,42.72),Vector3(85,17,47.9)],
  ["assay-inspection",Vector3(66,13.45,45.24),Vector3(72,14.5,51)],
  ["assay-room-centered",Vector3(66,13.45,45.24),Vector3(80,19,48)],
  ["crown-eye",Vector3(-101,25.45,94.86),Vector3(55,25,116.7)],
  ["furnace-eye",Vector3(88,1.45,-25.68),Vector3(64,10,-10)],
  ["transfer-eye",Vector3(0,1.45,-64),Vector3(27,5,-58)]
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
