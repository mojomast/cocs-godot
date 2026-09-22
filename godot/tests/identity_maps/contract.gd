extends SceneTree
## Contract gate: material vocabulary, texture budget, collision ownership and
## bounded signature effects for the three identity maps. Headless; no pixels.
const MapBuilder = preload("res://identity_maps/map.gd")
const Style = preload("res://identity_maps/style.gd")
const MAX_TEXTURE_BYTES := 32 * 1024 * 1024
const EXPECTED_MATERIALS := 6
var assertions := 0
var failures: Array = []

func check(value: bool, label: String) -> void:
	assertions += 1
	if not value: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var report: Array = []
	for id: String in MapBuilder.IDS:
		var wall_count := map_wall_count(id)
		var map := MapBuilder.new()
		root.add_child(map)
		check(map.build(id), "build " + id)
		var metrics := map.metrics_snapshot()
		# Materials: one shared material per semantic key, no per-surface copy.
		check(map.materials.size() == EXPECTED_MATERIALS, "%s material count %d" % [id, map.materials.size()])
		check(int(metrics.texture_bytes) <= MAX_TEXTURE_BYTES, id + " texture budget")
		for key: String in map.materials:
			var material: Material = map.materials[key]
			check(material is ShaderMaterial, "%s material %s is shader-backed" % [id, key])
			check(material.get_rid().is_valid(), "%s material %s has a resource" % [id, key])
		# Collision ownership: every block, floor and polygon wall has a body.
		var bodies := 0
		var shapes := 0
		for child: Node in map.get_children():
			if child is StaticBody3D:
				bodies += 1
				if child.get_child_count() > 0 and child.get_child(0) is CollisionShape3D:
					shapes += 1
			if child is MeshInstance3D or child is MultiMeshInstance3D:
				# Render-only nodes must never own a collider.
				for grandchild: Node in child.get_children():
					check(not (grandchild is CollisionShape3D), "%s render node owns collision" % id)
		var fence_count := int(metrics.movement_fences if metrics.has("movement_fences") else 0)
		check(shapes == body_count(map), "%s collision shapes %d/%d" % [id, shapes, body_count(map)])
		check(int(metrics.walls) == wall_count, id + " wall entries match recipe")
		check(bodies >= shapes, id + " body/shape pairing")
		# Detail is render-only and bounded.
		check(int(metrics.detail_instances) > 0, id + " has trim detail")
		check(int(metrics.detail_instances) < 4000, id + " detail budget")
		check(int(metrics.detail_batches) <= 4, id + " detail draw batches")
		# Signature effect: one bounded pool, Low/High switch, reset works.
		check(map.fx != null, id + " signature fx present")
		var high: Dictionary = map.fx.snapshot()
		check(int(high.allocated) <= 32768, id + " High particle budget")
		check(int(high.emitters) >= 2 and int(high.emitters) <= 12, id + " emitter pool bound")
		check(high.gameplay_authority == false, id + " fx has no gameplay authority")
		check(map.set_fx_quality("Low"), id + " set Low")
		var low: Dictionary = map.fx.snapshot()
		check(int(low.allocated) <= 8192, id + " Low particle budget")
		check(int(low.allocated) < int(high.allocated), id + " Low is smaller than High")
		check(map.set_fx_quality("High"), id + " set High")
		check(not map.set_fx_quality("Extreme"), id + " rejects unknown quality")
		map.reset_fx()
		map.fx.set_paused(true)
		check(bool(map.fx.snapshot().suspended), id + " pause suspends fx")
		map.fx.set_paused(false)
		# Graybox rebuild keeps the same collision answer and drops decoration.
		map.queue_free()
		await process_frame
		var gray := MapBuilder.new()
		root.add_child(gray)
		check(gray.build(id, true), "graybox build " + id)
		check(int(gray.metrics.walls) == wall_count, id + " graybox keeps wall count")
		check(gray.fx == null and gray.detail == null, id + " graybox skips decoration")
		check(gray.materials.size() == EXPECTED_MATERIALS, id + " graybox materials")
		gray.queue_free()
		await process_frame
		report.append({"id": id, "materials": EXPECTED_MATERIALS, "texture_bytes": int(metrics.texture_bytes),
			"bodies": bodies, "shapes": shapes, "movement_fences": fence_count,
			"detail_instances": int(metrics.detail_instances), "detail_batches": int(metrics.detail_batches),
			"fx_high": int(high.allocated), "fx_low": int(low.allocated), "fx_emitters": int(high.emitters),
			"walls": int(metrics.walls), "triangles": int(metrics.triangles)})
	var result := {"assertions": assertions, "failures": failures, "maps": report,
		"scope": "Identity map material/collision/effect contract, headless; not visual or GPU acceptance"}
	print("IDENTITY_CONTRACT ", JSON.stringify(result))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			var file := FileAccess.open(arg.trim_prefix("--output="), FileAccess.WRITE)
			file.store_string(JSON.stringify(result, "\t"))
	quit(0 if failures.is_empty() else 1)

func body_count(map: Node) -> int:
	return int(map.metrics.blocks) + int(map.metrics.surfaces) + polygon_walls(map)

func map_wall_count(id: String) -> int:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://identity_maps/generated/" + id + ".json"))
	if not parsed is Dictionary: return -1
	return (parsed.arena.terrain.walls as Array).size()

func polygon_walls(map: Node) -> int:
	if not map.recipe.has("arena"): return -1
	var count := 0
	for wall: Dictionary in map.recipe.arena.terrain.walls:
		if not wall.has("a") and not wall.has("b"): count += 1
	return count
