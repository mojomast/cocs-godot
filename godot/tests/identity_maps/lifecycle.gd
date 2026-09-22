extends SceneTree
## Headless map build/free lifecycle including the bounded signature effect
## pool. Three full cycles per map; asserts no node/resource/orphan growth.
const MapBuilder = preload("res://identity_maps/map.gd")
const EXPECTED_MATERIALS := 6
var assertions := 0
var failures: Array = []

func check(value: bool, label: String) -> void:
	assertions += 1
	if not value: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var counts: Array = []
	for cycle in range(3):
		for id: String in MapBuilder.IDS:
			var map := MapBuilder.new()
			root.add_child(map)
			check(map.build(id), "build " + id)
			var before := map.get_child_count()
			check(map.build(id), "idempotent build")
			check(before == map.get_child_count(), "no duplicate build")
			check(not map.build("../outside"), "reject alternate id")
			check(map.metrics.material_cells <= 120, "cell budget")
			check(map.metrics.triangles < 150000, "triangle budget")
			check(map.materials.size() == EXPECTED_MATERIALS, "material reuse")
			for child: Node in map.get_children():
				if child is MeshInstance3D:
					var arrays: Array = child.mesh.surface_get_arrays(0)
					for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: check(vertex.is_finite(), "finite vertex")
			# Effect lifecycle inside the same build/free cycle.
			map.set_fx_quality("Low")
			map.reset_fx()
			map.set_fx_quality("High")
			check(map.fx != null and map.fx.emitters.size() > 0, "fx pool")
			map.queue_free()
			for i in range(3): await process_frame
		counts.append({"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)})
	check(counts[2].nodes <= counts[1].nodes, "no node accumulation")
	check(counts[2].resources <= counts[1].resources, "no resource accumulation")
	check(counts[2].orphans <= counts[1].orphans, "no orphan accumulation")
	var result := {"assertions": assertions, "failures": failures, "cycles": counts,
		"scope": "Headless map build/free lifecycle, not gameplay restart acceptance"}
	print("IDENTITY_LIFECYCLE ", JSON.stringify(result))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			var file := FileAccess.open(arg.trim_prefix("--output="), FileAccess.WRITE)
			file.store_string(JSON.stringify(result, "\t"))
	quit(0 if failures.is_empty() else 1)
