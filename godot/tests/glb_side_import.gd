extends SceneTree

# Structural regression on the exported assets; no material/camera overrides.
func _initialize() -> void:
	var ids: Array = JSON.parse_string(FileAccess.get_file_as_string("res://content/generated/manifest.json")).maps
	# CI generates the Meridian probe; the dedicated exporter suite covers all nine.
	var selected := ""
	for arg: String in OS.get_cmdline_user_args():
		assert(arg.begins_with("--map=") and selected.is_empty())
		selected = arg.trim_prefix("--map=")
		assert(not selected.is_empty())
	if not selected.is_empty():
		ids = ids.filter(func(entry: Dictionary) -> bool: return entry.id == selected)
		assert(ids.size() == 1)
	for entry: Dictionary in ids:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file("res://content/probes/" + entry.id + "/world.glb", state) == OK)
		var scene := document.generate_scene(state)
		assert(scene != null)
		var skies := 0
		for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			var bounds := mesh.get_aabb()
			if not bounds.position.is_equal_approx(Vector3(-185, -185, -185)) or not bounds.size.is_equal_approx(Vector3(370, 370, 370)):
				continue
			skies += 1
			assert(mesh.mesh.get_surface_count() == 1)
			var material := mesh.get_active_material(0) as BaseMaterial3D
			assert(material != null and material.cull_mode == BaseMaterial3D.CULL_BACK)
			var arrays := mesh.mesh.surface_get_arrays(0)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			assert(indices.size() == 2976 * 3)
			for i in positions.size():
				assert(positions[i].dot(normals[i]) < 0.0)
			# Godot's glTF importer reverses CCW to CW: cross product points
			# outward for inward-facing CW triangles, normals still point in.
			for i in range(0, indices.size(), 3):
				var a := positions[indices[i]]
				var b := positions[indices[i + 1]]
				var c := positions[indices[i + 2]]
				assert((b - a).cross(c - a).dot(a) > 0.0)
		assert(skies == 1)
		print("GLB_SIDE_IMPORT_OK id=", entry.id, " inward_sky_triangles=2976 cull=BACK meshes=", state.get_meshes().size())
		scene.free()
	quit(0)
