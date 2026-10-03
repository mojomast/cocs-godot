extends SceneTree
## Staged native art inspection, separate from ordinary-input hosted evidence.
const WorldMap = preload("res://multiplayer_worlds/map.gd")
var rows: Array = []
var streams: Array = []
func inspect_streams(node: Node) -> void:
 if node is MeshInstance3D:
  for index in range(node.mesh.get_surface_count()):
   var arrays: Array = node.mesh.surface_get_arrays(index)
   var material: StandardMaterial3D = node.mesh.surface_get_material(index)
   var preserved: bool = material.resource_name in ["glass","water","letter"]
   var vertices: int = arrays[Mesh.ARRAY_VERTEX].size()
   var uv: int = arrays[Mesh.ARRAY_TEX_UV].size() if arrays[Mesh.ARRAY_TEX_UV] != null else 0
   var tangent: int = arrays[Mesh.ARRAY_TANGENT].size() if arrays[Mesh.ARRAY_TANGENT] != null else 0
   assert(arrays[Mesh.ARRAY_NORMAL].size()==vertices)
   if not preserved:
    assert(uv==vertices and tangent==vertices*4)
    assert(material.albedo_texture != null and material.normal_enabled and material.normal_texture != null)
   streams.append({"material":material.resource_name,"vertices":vertices,"uv":uv,"tangents":tangent,"normalEnabled":material.normal_enabled,"normalScale":material.normal_scale,"albedo":str(material.albedo_texture.resource_path) if material.albedo_texture != null else "preserved","normal":str(material.normal_texture.resource_path) if material.normal_texture != null else "preserved"})
 for child: Node in node.get_children(): inspect_streams(child)
func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var out := OS.get_environment("ASSET_STAGE_EVIDENCE")
 assert(not out.is_empty())
 root.size = Vector2i(1280,800)
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/vesper-viaduct.json"))
 var world := WorldMap.new()
 root.add_child(world)
 assert(world.build(data))
 assert(world.get_node_or_null("BlenderArtNoGameplayCollision") != null)
 inspect_streams(world.get_node("BlenderArtNoGameplayCollision"))
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-44,-30,0)
 sun.light_energy = 1.25
 sun.shadow_enabled = true
 world.add_child(sun)
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_COLOR
 environment.environment.background_color = Color("8393a3")
 environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color = Color("ddd9d1")
 environment.environment.ambient_light_energy = .65
 world.add_child(environment)
 var camera := Camera3D.new()
 camera.far = 650
 camera.fov = 74
 world.add_child(camera)
 camera.make_current()
 var views: Array = data.arena.art.inspectionViews.duplicate(true)
 if "--representative" in OS.get_cmdline_user_args():
  views = views.filter(func(view: Dictionary) -> bool: return view.id in ["overview","civic","concourse"])
 else:
  for hall: Dictionary in data.arena.structures:
   var y := 24.0 if hall.z > 65 else 0.0 if hall.z < -65 else 12.0
   # Look into each purpose-built side room; the separate concourse view already
   # records the long through-route. Repeating that axis hid all counters/windows.
   views.append({"id":hall.id+"-interior","eye":[hall.x,y+1.65,hall.z-2],"target":[hall.x+hall.w*.14,y+2.8,hall.z+hall.d/2]})
  views.append({"id":"civic-stair","eye":[32,13.65,22],"target":[32,25,70]})
  views.append({"id":"canal-bridge","eye":[-100,1.65,-117],"target":[-100,12,-60]})
  views.append({"id":"row-street","eye":[-100,19,44],"target":[-45,23,44]})
  views.append({"id":"arcade-front","eye":[-100,24.15,60],"target":[-48,31,66]})
  views.append({"id":"warehouse-sign","eye":[-66,1.65,-103],"target":[-66,5.4,-98]})
 for view: Dictionary in views:
  camera.position = Vector3(view.eye[0],view.eye[1],view.eye[2])
  camera.look_at(Vector3(view.target[0],view.target[1],view.target[2]))
  camera.fov = 58 if view.id == "overview" else 74
  for frame in range(8): await process_frame
  await RenderingServer.frame_post_draw
  var path := out.path_join(str(view.id)+".png")
  assert(root.get_texture().get_image().save_png(path) == OK)
  rows.append({"view":view.id,"file":path,"eye":view.eye,"target":view.target,"capturedUsec":Time.get_ticks_usec(),"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"frameSeconds":Performance.get_monitor(Performance.TIME_PROCESS)})
  var file := FileAccess.open(out.path_join("inspection.json"),FileAccess.WRITE)
  file.store_string(JSON.stringify({"geometryHash":data.geometryHash,"collision":world.metrics,"importedStreams":streams,"renderer":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name(),"captures":rows},"  "))
 print("VESPER_INSPECTION_OK ",JSON.stringify(rows))
 quit(0)
