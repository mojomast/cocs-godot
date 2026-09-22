extends SceneTree

# Focused integration guard: presentation must retain the map contract and must
# not add local collision. Runs against the real nine-map generated catalog.
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewer = load("res://world/viewer.gd").new()
	root.add_child(viewer)
	viewer.set_process(false)
	check(viewer.ids.size() == 9, "Locked map count changed")
	var blocks_checked := 0
	var triangles_checked := 0
	for id: String in viewer.ids:
		check(viewer.load_map(id), "Map failed: " + id)
		var map: Dictionary = viewer.catalog.resolve_map(id)
		check(viewer.current_id == id, "Selection API lost identity")
		check(viewer.world.get_node("StaticPickupMarkers").get_child_count() == map.pickups.size(), "Static marker API changed")
		check(viewer.environment.environment.background_mode == Environment.BG_SKY, "Missing native sky: " + id)
		check(viewer.world.find_children("*", "CollisionObject3D", true, false).is_empty(), "Presentation introduced collision")
		for i in range(map.blocks.size()):
			var b: Dictionary = map.blocks[i]
			var node: MeshInstance3D = viewer.world.get_child(i)
			check(node.position.is_equal_approx(Vector3(b.x, b.h / 2.0, b.z)), "Solid moved: " + id)
			check(node.mesh.size.is_equal_approx(Vector3(b.w, b.h, b.d)), "Solid resized: " + id)
			blocks_checked += 1
		var triangles: Array = map.get("terrain", {}).get("support_triangles", [])
		check(viewer.world.get_meta("semantic_triangle_count") == triangles.size(), "Triangle count changed")
		if not triangles.is_empty():
			var terrain: MeshInstance3D = viewer.world.get_node("SemanticTerrain")
			var arrays: Array = terrain.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			check(vertices.size() == triangles.size() * 3, "Support mesh topology changed")
			for i in range(triangles.size()):
				for j in range(3):
					var v: Array = triangles[i].vertices[2 - j]
					check(vertices[i * 3 + j].is_equal_approx(Vector3(v[0], v[1], v[2])), "Support vertex moved: " + id)
				triangles_checked += 1
		await process_frame
	viewer.queue_free()
	await process_frame
	print("NATIVE_WORLD_COMPATIBILITY maps=9 blocks=", blocks_checked, " triangles=", triangles_checked, " failures=", failures)
	quit(1 if failures else 0)
