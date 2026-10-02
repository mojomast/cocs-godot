extends SceneTree
const Map = preload("res://multiplayer_worlds/map.gd")
var out := "/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002/native-review"
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 DirAccess.make_dir_recursive_absolute(out)
 root.size=Vector2i(1280,800)
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/parallax-observatory.json"))
 var world := Map.new()
 root.add_child(world)
 assert(world.build(data))
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-44,-30,0)
 sun.light_energy=.6
 sun.shadow_enabled=true
 world.add_child(sun)
 var env := WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("46566f")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("bac7dc")
 env.environment.ambient_light_energy=.45
 world.add_child(env)
 for roof: Dictionary in data.arena.overhead:
  for j in [0]:
   var light := OmniLight3D.new()
   light.position=Vector3(roof.x+j*roof.w*.3,roof.minY-.45,roof.z)
   light.light_color=Color("ffdda3")
   light.light_energy=1.2
   light.omni_range=20
   light.shadow_enabled=false
   world.add_child(light)
 var camera := Camera3D.new()
 camera.far=600
 camera.fov=76
 world.add_child(camera)
 camera.make_current()
 var views := {}
 for shot: Dictionary in data.art.cameras:
  camera.fov=45 if shot.id=="overview" else 76
  camera.position=world._v(shot.eye)
  camera.look_at(world._v(shot.target))
  for i in range(8): await process_frame
  await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png(out.path_join(shot.id+".png"))==OK)
  views[shot.id]={"drawCalls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"objects":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
 var f := FileAccess.open(out.path_join("inspection.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"geometryHash":world.geometry_hash,"glbSha256":FileAccess.get_sha256("res://multiplayer_worlds/art/parallax-observatory/parallax-observatory.glb"),"views":views,"renderer":RenderingServer.get_video_adapter_name(),"collision":world.metrics},"  "))
 print("PARALLAX_INSPECTION ",JSON.stringify(views))
 quit()
