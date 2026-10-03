extends SceneTree
## Static architecture inspection; separate from the ordinary-input race.
const Builder = preload("res://multiplayer_worlds/map.gd")
var streams: Array = []
func _initialize() -> void: call_deferred("run")

func inspect_streams(node: Node) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var arrays: Array=node.mesh.surface_get_arrays(i)
			var mat: StandardMaterial3D=node.mesh.surface_get_material(i)
			var count: int=arrays[Mesh.ARRAY_VERTEX].size()
			var uv: int=arrays[Mesh.ARRAY_TEX_UV].size() if arrays[Mesh.ARRAY_TEX_UV]!=null else 0
			var tangent: int=arrays[Mesh.ARRAY_TANGENT].size() if arrays[Mesh.ARRAY_TANGENT]!=null else 0
			assert(arrays[Mesh.ARRAY_NORMAL].size()==count)
			if mat.resource_name not in ["glass","amber","ocean"]: assert(mat.albedo_texture!=null and uv==count)
			if mat.resource_name in ["asphalt","concrete","salt","brick","steel"]: assert(mat.normal_enabled and tangent==count*4)
			if mat.resource_name=="teal": assert(not mat.normal_enabled)
			streams.append({"material":mat.resource_name,"vertices":count,"uv":uv,"tangents":tangent,"normalEnabled":mat.normal_enabled})
	for child: Node in node.get_children(): inspect_streams(child)

func run() -> void:
	var out := OS.get_environment("ASSET_STAGE_EVIDENCE")
	assert(not out.is_empty())
	root.size = Vector2i(1280,800)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/stormglass-causeway.json"))
	var world := Builder.new()
	root.add_child(world)
	assert(world.build(data))
	inspect_streams(world.get_node("BlenderArtNoGameplayCollision"))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-43,-28,0)
	sun.light_color = Color("fff5e7")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	world.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("526b77")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c5cfd0")
	env.environment.ambient_light_energy = .65
	world.add_child(env)
	var camera := Camera3D.new()
	camera.far = 950
	world.add_child(camera)
	camera.make_current()
	var views: Array = [
		{"id":"overview","eye":[-350,320,-330],"target":[-35,0,5]},
		{"id":"terminal","eye":[-108,3.4,-133],"target":[-5,9,-120]},
		{"id":"freight-bore","eye":[150,3.4,22],"target":[138,7,70]},
		{"id":"quay-chicane","eye":[45,3.4,145],"target":[-45,8,133]},
		{"id":"surgeworks","eye":[-183,3.4,101],"target":[-207,13,47]},
		{"id":"return-gate","eye":[-118,3.4,11],"target":[-72,13,-28]}
	]
	if "--representative" in OS.get_cmdline_user_args(): views=views.slice(0,3)
	var rows: Array = []
	for view: Dictionary in views:
		camera.position = Vector3(view.eye[0],view.eye[1],view.eye[2])
		camera.look_at(Vector3(view.target[0],view.target[1],view.target[2]))
		camera.fov=58 if view.id=="overview" else 74
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		var path := out.path_join(str(view.id)+".png")
		assert(root.get_texture().get_image().save_png(path)==OK)
		rows.append({"view":view.id,"file":path,"eye":view.eye,"target":view.target,"capturedUsec":Time.get_ticks_usec(),"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"frameSeconds":Performance.get_monitor(Performance.TIME_PROCESS)})
	var file := FileAccess.open(out.path_join("inspection.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"accepted":false,"geometryHash":data.geometryHash,"importedStreams":streams,"renderer":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name(),"captures":rows},"  "))
	print("STORMGLASS_INSPECTION_OK ",JSON.stringify(rows))
	quit(0)
