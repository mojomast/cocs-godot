extends SceneTree
## Static junction inspection only; locomotion evidence comes from verify.gd.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output := OS.get_cmdline_user_args()[0]
	var source := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "res://cinder_array/map.gd"
	var map: Node3D = load(source).new()
	root.add_child(map)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 65
	var views := [
		{"name": "rim-junction-approach", "eye": Vector3(-17.2, 16.0, -29.1), "target": Vector3(-24, 16.7, -28)},
		{"name": "rim-junction-side", "eye": Vector3(-15, 20.5, -19.5), "target": Vector3(-20.4, 15.5, -28.5)},
	]
	var overlays: Array[MeshInstance3D] = []
	var solids: Array[Dictionary] = []
	var connection: Dictionary = map.connections[3]
	var direction: Vector3 = connection.b - connection.a
	direction.y = 0
	var length := direction.length()
	direction /= length
	var side := Vector3(-direction.z, 0, direction.x)
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color("ff4fe7")
	ink.no_depth_test = true
	for node in map.geo.body.get_children():
		if not node.shape is ConvexPolygonShape3D: continue
		var selected := true
		var points: Array = []
		for p: Vector3 in node.shape.points:
			var local: Vector3 = p - connection.a
			if local.dot(direction) < -0.02 or local.dot(direction) > length + 0.02 or absf(local.dot(side)) > connection.width * 0.5 + 0.002 or p.y > 16.02 or p.y < 11.3:
				selected = false
			points.append([p.x, p.y, p.z])
		if not selected: continue
		solids.append({"points": points})
		var overlay := MeshInstance3D.new()
		var faces: PackedVector3Array = node.shape.get_debug_mesh().get_faces()
		var wire := ImmediateMesh.new()
		wire.surface_begin(Mesh.PRIMITIVE_LINES)
		for i in range(0, faces.size(), 3):
			for edge in range(3):
				wire.surface_add_vertex(faces[i + edge])
				wire.surface_add_vertex(faces[i + (edge + 1) % 3])
		wire.surface_end()
		overlay.mesh = wire
		overlay.material_override = ink
		overlay.visible = false
		root.add_child(overlay)
		overlays.append(overlay)
	for view: Dictionary in views:
		camera.position = view.eye
		camera.look_at(view.target)
		for collision_view in [false, true]:
			for overlay in overlays: overlay.visible = collision_view
			for i in range(8):
				await process_frame
				await RenderingServer.frame_post_draw
			var suffix := "-colliders" if collision_view else ""
			var result := root.get_texture().get_image().save_png(output.path_join(view.name + suffix + ".png"))
			if result != OK:
				quit(1)
				return
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"views": views, "godot": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "rim_profile": map.connections[3].profile, "rim_floor_solids": solids, "diagnostics": map.get_diagnostics(), "purpose": "Static geometry inspection; magenta wireframes are actual convex floor shapes, not traversal evidence"}, "\t") + "\n")
	quit(0)
