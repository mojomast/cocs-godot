extends SceneTree
## Test-only architectural capture; excluded from production asset closure.
const WorldMap = preload("res://multiplayer_worlds/map.gd")
var out := ""
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--helix-out="): out = arg.trim_prefix("--helix-out=")
 call_deferred("run")
func run() -> void:
 root.size = Vector2i(1440,900)
 var world := WorldMap.new()
 root.add_child(world)
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/helix-conservatory.json"))
 assert(world.build(data))
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-48,-35,0)
 sun.light_energy = 1.3
 sun.shadow_enabled = true
 world.add_child(sun)
 var env := WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_COLOR
 env.environment.background_color = Color("789fae")
 env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color = Color("cfdfdf")
 env.environment.ambient_light_energy = .65
 world.add_child(env)
 var camera := Camera3D.new()
 camera.far = 600
 camera.fov = 76
 world.add_child(camera)
 camera.make_current()
 var shots := {
  "overview":[Vector3(125,145,135),Vector3(0,12,0)],
  "lightwell-eye":[Vector3(0,1.7,-12),Vector3(0,14,0)],
  "archive-eye":[Vector3(-52,9.7,-7),Vector3(-52,10,9)],
  "archive-portal-eye":[Vector3(-52,9.7,-18),Vector3(-52,12,-8)],
  "irrigation-eye":[Vector3(57,9.7,-9),Vector3(70,18,0)],
  "pavilion-eye":[Vector3(25,17.7,79),Vector3(0,24,86)],
  "canopy-eye":[Vector3(0,17.7,86),Vector3(-35,15,25)],
  "crown-eye":[Vector3(0,25.7,-116),Vector3(35,27,0)]}
 var metrics := {}
 for id: String in shots:
  camera.position = shots[id][0]
  camera.look_at(shots[id][1])
  for frame in range(12): await process_frame
  await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png(out.path_join(id+".png")) == OK)
  metrics[id] = {"drawCalls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"visibleObjects":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
 var file := FileAccess.open(out.path_join("inspection.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"geometryHash":world.geometry_hash,"collision":world.metrics,"views":metrics,"renderer":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name()},"  "))
 print("HELIX_INSPECTION_OK ",JSON.stringify(metrics))
 quit()
