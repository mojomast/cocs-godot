extends SceneTree
## Static art inspection, separate from input-driven hosted gameplay.
const Builder = preload("res://multiplayer_worlds/map.gd")
var rows: Array = []
var streams: Array = []
func _initialize() -> void: call_deferred("run")

func inspect_streams(node: Node) -> void:
 if node is MeshInstance3D:
  for i in range(node.mesh.get_surface_count()):
   var arrays: Array = node.mesh.surface_get_arrays(i)
   var mat: StandardMaterial3D = node.mesh.surface_get_material(i)
   var count: int = arrays[Mesh.ARRAY_VERTEX].size()
   var uv: int = arrays[Mesh.ARRAY_TEX_UV].size() if arrays[Mesh.ARRAY_TEX_UV] != null else 0
   var tangent: int = arrays[Mesh.ARRAY_TANGENT].size() if arrays[Mesh.ARRAY_TANGENT] != null else 0
   var preserved: bool = mat.resource_name in ["glass","cyan","amber"]
   assert(arrays[Mesh.ARRAY_NORMAL].size()==count)
   if not preserved: assert(mat.albedo_texture != null and uv==count)
   if mat.resource_name == "copper": assert(mat.normal_enabled and mat.normal_texture != null and tangent==count*4)
   if mat.resource_name in ["navy","coral","ivory"]: assert(not mat.normal_enabled)
   streams.append({"material":mat.resource_name,"vertices":count,"uv":uv,"tangents":tangent,"normalEnabled":mat.normal_enabled,"albedo":str(mat.albedo_texture.resource_path) if mat.albedo_texture != null else "preserved"})
 for child: Node in node.get_children(): inspect_streams(child)

func run() -> void:
 var out := OS.get_environment("ASSET_STAGE_EVIDENCE")
 assert(not out.is_empty())
 root.size = Vector2i(1280,800)
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/abyssal-pressureworks.json"))
 var world := Builder.new()
 root.add_child(world)
 assert(world.build(data))
 assert(world.get_node_or_null("BlenderArtNoGameplayCollision") != null)
 inspect_streams(world.get_node("BlenderArtNoGameplayCollision"))
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-44,-30,0)
 sun.light_energy = 1.25
 sun.shadow_enabled = true
 world.add_child(sun)
 var env := WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_COLOR
 env.environment.background_color = Color("081b30")
 env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color = Color("c5d1d6")
 env.environment.ambient_light_energy = .65
 world.add_child(env)
 preload("res://multiplayer_worlds/abyssal_presentation.gd").configure(sun,env.environment)
 var camera := Camera3D.new()
 camera.far = 650
 world.add_child(camera)
 camera.make_current()
 var views: Array = [
  {"id":"overview","eye":[-178,174,182],"target":[0,10,0]},
  {"id":"equalizer","eye":[31,11.65,-7],"target":[44,24,8]},
  {"id":"reef-window","eye":[-94,7.65,-70],"target":[-94,9,-101]},
  {"id":"pump-spine","eye":[-82,11.65,0],"target":[-22,14,0]},
  {"id":"operations-gallery","eye":[-90,21.65,68],"target":[-37,23,78]},
  {"id":"maintenance-bypass","eye":[-83,7.65,-68],"target":[-34,6,-78]},
  {"id":"reactor-overlook","eye":[30,17.5,36],"target":[40,13,8]}
 ]
 if "--representative" in OS.get_cmdline_user_args(): views = views.slice(0,3)
 else:
  for room: Dictionary in data.arena.structures:
   if not room.has("silhouette"): continue
   views.append({"id":str(room.id)+"-interior","eye":[room.x-5,room.y+1.65,room.z-3],"target":[room.x+8,room.y+3,room.z+12]})
 for view: Dictionary in views:
  camera.position = Vector3(view.eye[0],view.eye[1],view.eye[2])
  camera.look_at(Vector3(view.target[0],view.target[1],view.target[2]))
  camera.fov = 58 if view.id=="overview" else 74
  for frame in range(6): await process_frame
  await RenderingServer.frame_post_draw
  var path := out.path_join(str(view.id)+".png")
  assert(root.get_texture().get_image().save_png(path)==OK)
  rows.append({"view":view.id,"file":path,"eye":view.eye,"target":view.target,"capturedUsec":Time.get_ticks_usec(),"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"frameSeconds":Performance.get_monitor(Performance.TIME_PROCESS)})
  var file := FileAccess.open(out.path_join("inspection.json"),FileAccess.WRITE)
  file.store_string(JSON.stringify({"geometryHash":data.geometryHash,"collision":world.metrics,"importedStreams":streams,"renderer":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name(),"captures":rows},"  "))
 print("ABYSSAL_INSPECTION_OK ",JSON.stringify(rows))
 quit(0)
