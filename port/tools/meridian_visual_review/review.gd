extends SceneTree

# Private causal experiment, never wired into the shipped viewer/session.
# run.py first enforces the historical GLB SHA; the shape check below identifies
# its source addSky sphere (glTF node 56), not arbitrary large scene geometry.
var output: String
var experiment: String

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--review-output="): output = arg.trim_prefix("--review-output=")
		if arg.begins_with("--review-case="): experiment = arg.trim_prefix("--review-case=")
	run.call_deferred()

func vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func bounds(value: AABB) -> Dictionary:
	return {"position": vec(value.position), "size": vec(value.size)}

func material_info(mat: BaseMaterial3D) -> Dictionary:
	return {"cull_mode": mat.cull_mode, "depth_draw_mode": mat.depth_draw_mode,
		"shading_mode": mat.shading_mode, "transparency": mat.transparency,
		"vertex_color_use_as_albedo": mat.vertex_color_use_as_albedo,
		"albedo": [mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b, mat.albedo_color.a]}

func run() -> void:
	if output.is_empty() or experiment not in ["baseline", "source-cull-only", "camera-inside"]:
		push_error("Invalid review arguments")
		quit(1)
		return
	var viewer = load("res://main.tscn").instantiate()
	root.add_child(viewer)
	viewer.set_process(false)
	var meshes: Array[Node] = viewer.world.find_children("*", "MeshInstance3D", true, false)
	var inventory: Array = []
	var sky: MeshInstance3D
	for node: MeshInstance3D in meshes:
		var local := node.get_aabb()
		var surfaces: Array = []
		for index in node.mesh.get_surface_count():
			var mat := node.get_active_material(index) as BaseMaterial3D
			surfaces.append(material_info(mat) if mat else {})
		inventory.append({"path": str(viewer.world.get_path_to(node)), "local_bounds": bounds(local),
			"world_bounds": bounds(node.global_transform * local), "position": vec(node.global_position),
			"basis": [vec(node.global_basis.x), vec(node.global_basis.y), vec(node.global_basis.z)],
			"visible": node.is_visible_in_tree(), "surfaces": surfaces})
		if local.position.is_equal_approx(Vector3(-185, -185, -185)) and local.size.is_equal_approx(Vector3(370, 370, 370)):
			if sky != null:
				push_error("Ambiguous sky")
				quit(1)
				return
			sky = node
	if sky == null or sky.mesh.get_surface_count() != 1:
		push_error("Historical sky missing")
		quit(1)
		return
	var report := {"case": experiment, "native_version": Engine.get_version_info(),
		"camera_before": vec(viewer.camera.position), "target": [0, 0, 0],
		"camera_distance": viewer.camera.position.length(), "near": viewer.camera.near,
		"far": viewer.camera.far, "fov": viewer.camera.fov, "mesh_count": meshes.size(),
		"sky_path": str(viewer.world.get_path_to(sky)), "imported_inventory": inventory,
		"sky_material_before": material_info(sky.get_active_material(0))}
	if experiment == "source-cull-only":
		# Preserve original geometry/vertex colors. Restore precisely the source
		# BackSide rasterization; no hiding, recoloring, rescaling or relighting.
		var mat := sky.get_active_material(0).duplicate() as BaseMaterial3D
		mat.cull_mode = BaseMaterial3D.CULL_FRONT
		sky.set_surface_override_material(0, mat)
	elif experiment == "camera-inside":
		viewer.camera.position *= 0.5
		viewer.camera.look_at(Vector3.ZERO)
	report["camera_after"] = vec(viewer.camera.position)
	report["sky_material_after"] = material_info(sky.get_active_material(0))
	# This label makes modified experiments visibly distinct from acceptance.
	if experiment != "baseline":
		viewer.label.text += "\nCAUSAL EXPERIMENT: " + experiment + " (NOT a production fix)"
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(output + "/" + experiment + ".png")
	var file := FileAccess.open(output + "/" + experiment + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("MERIDIAN_REVIEW case=", experiment, " meshes=", meshes.size(), " sky=", report.sky_path, " png_error=", error)
	quit(error)
