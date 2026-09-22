extends SceneTree
## Material grouping must never alter locked support geometry.
const Viewer = preload("res://world/viewer.gd")
var checks := 0
var failed := false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("GRAPHICS_TERRAIN: " + message)

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var viewer := Viewer.new()
	root.add_child(viewer)
	await process_frame
	check(viewer.ids.size() == 9, "all nine maps")
	for id: String in viewer.ids:
		check(viewer.load_map(id), "load " + id)
		var map: Dictionary = viewer.catalog.resolve_map(id)
		var triangles: Array = map.get("terrain", {}).get("support_triangles", [])
		check(viewer.world.get_meta("semantic_triangle_count") == triangles.size(), "triangle count " + id)
		if triangles.is_empty(): continue
		var terrain: MeshInstance3D = viewer.world.get_node("SemanticTerrain")
		var kinds: Array = terrain.get_meta("surface_kinds")
		check(terrain.mesh.get_surface_count() == kinds.size(), "one surface per material identity")
		var total := 0
		for index in range(kinds.size()):
			var expected := PackedVector3Array()
			for triangle: Dictionary in triangles:
				if str(triangle.get("material", "concrete")) != kinds[index]: continue
				for corner in [2,1,0]:
					var p: Array = triangle.vertices[corner]
					expected.append(Vector3(p[0],p[1],p[2]))
			var actual: PackedVector3Array = terrain.mesh.surface_get_arrays(index)[Mesh.ARRAY_VERTEX]
			check(actual.size() == expected.size(), "material group retains triangle count")
			if actual.size() != expected.size(): continue
			for vertex in range(expected.size()):
				check(actual[vertex].distance_to(expected[vertex]) < 0.00001, "exact source vertex/winding")
			total += actual.size()
			check(terrain.mesh.surface_get_material(index) != null, "material assigned")
		check(total == triangles.size()*3, "every triangle retained exactly once")
	viewer.queue_free()
	await process_frame
	print("GRAPHICS_TERRAIN_RESULT ", JSON.stringify({"passed":not failed,"checks":checks,"maps":9}))
	quit(1 if failed else 0)
