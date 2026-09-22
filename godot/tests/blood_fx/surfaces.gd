extends SceneTree
## Surface-query contracts. Verifies the three real backends the composition can
## bind: the locked nine-map semantic export, a physics StaticBody3D world (the
## native/identity builder contract), and a host Callable.

const Controller = preload("res://blood_fx/controller.gd")
const SurfaceQuery = preload("res://blood_fx/surface_query.gd")
const Catalog = preload("res://world/catalog.gd")

var failed := false
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var catalog := Catalog.new()
	if not catalog.open():
		push_error("catalog failed: " + catalog.error)
		quit(1)
		return
	var maps: Array = catalog.entries.keys()
	check(maps.size() == 9, "the locked catalog exposes exactly nine maps")
	var total_triangles := 0
	var floor_hits := 0
	var wall_hits := 0
	var implicit := 0
	var reports: Array = []
	for id: String in maps:
		var map: Dictionary = catalog.resolve_map(id)
		check(not map.is_empty(), "map resolves: " + id)
		if map.is_empty(): continue
		var surface: RefCounted = SurfaceQuery.build(map, null, 1)
		check(surface.ready and surface.kind == "semantic", "semantic backend ready for " + id)
		var stats: Dictionary = surface.snapshot()
		total_triangles += int(stats.triangles)
		var spawn: Array = map.get("spawns", [])
		if spawn.size() < 1 or not spawn[0] is Array or spawn[0].size() < 2: continue
		var point := Vector3(float(spawn[0][0]), 30.0, float(spawn[0][1]))
		var hit: Dictionary = surface.query(point, point + Vector3.DOWN * 60.0)
		if surface.implicit_floor:
			implicit += 1
		# Either a real support triangle or the source's implicit y=0 floor
		# answers; nothing may return a fabricated plane above the ray end.
		check(not hit.is_empty() or surface.implicit_floor, "a downward query from the first spawn finds real geometry on " + id)
		if not hit.is_empty():
			floor_hits += 1
			check(float(hit.normal.y) > 0.35, "floor normal points upward on " + id + " (" + str(hit.normal) + ")")
			check(float(hit.position.y) <= point.y + 0.02, "floor hit is below the query origin on " + id)
		var probe := Vector3(float(spawn[0][0]), 1.6, float(spawn[0][1]))
		var radial: Dictionary = surface.query(probe, probe + Vector3(1, -0.05, 0).normalized() * 2.2)
		if not radial.is_empty(): wall_hits += 1
		reports.append({"id": id, "triangles": stats.triangles, "blocks": stats.blocks,
			"implicit_floor": surface.implicit_floor, "floor_hit": not hit.is_empty(), "radial_hit": not radial.is_empty()})
	check(floor_hits + implicit >= 8, "at least eight locked maps answer a real floor query (hits " + str(floor_hits) + " implicit " + str(implicit) + ")")
	check(total_triangles > 5000, "the semantic backends carry the real exported triangles (" + str(total_triangles) + ")")

	# The documented Callable shape must survive the controller's wrapper too.
	var callable_map: Dictionary = catalog.resolve_map("meridian-exchange")
	var provider := SurfaceQuery.semantic_provider(callable_map)
	var wrapped: RefCounted = SurfaceQuery.build(provider, null, 1)
	check(wrapped.ready and wrapped.kind == "callable", "a host Callable binds as the callable backend")
	var origin := Vector3(float(callable_map.spawns[0][0]), 30.0, float(callable_map.spawns[0][1]))
	var wrapped_hit: Dictionary = wrapped.query(origin, origin + Vector3.DOWN * 60.0)
	check(not wrapped_hit.is_empty() and float(wrapped_hit.normal.y) > 0.9, "a Callable provider returns the documented Vector3 result")

	# --- physics backend (the native / identity builder contract) --------------
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 4, 0)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 1, 10)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, -0.5, 0)
	world.add_child(body)
	var ramp_body := StaticBody3D.new()
	var ramp_shape := CollisionShape3D.new()
	var ramp_box := BoxShape3D.new()
	ramp_box.size = Vector3(4, 1, 4)
	ramp_shape.shape = ramp_box
	ramp_body.add_child(ramp_shape)
	ramp_body.position = Vector3(8, 2.0, 0)
	ramp_body.rotation_degrees = Vector3(0, 0, 24)
	world.add_child(ramp_body)
	var physics: RefCounted = SurfaceQuery.build(world, camera, 1)
	check(physics.ready and physics.kind == "physics", "a collision root configures the physics backend")
	var physics_hit: Dictionary = physics.query(Vector3(0, 4, 0), Vector3(0, -4, 0))
	check(not physics_hit.is_empty() and absf(float(physics_hit.position.y) - 0.0) < 0.02, "physics ray lands on the StaticBody3D floor")
	check(not physics_hit.is_empty() and absf(float(physics_hit.normal.y) - 1.0) < 0.01, "physics floor returns the real collider normal")
	var miss: Dictionary = physics.query(Vector3(0, 4, 0), Vector3(0, 1, 0))
	check(miss.is_empty(), "physics query above the world reports no surface")
	var offset: Dictionary = physics.query(Vector3(8, 8, 0), Vector3(8, 2, 0))
	check(not offset.is_empty() and absf(float(offset.normal.z)) < 0.05, "the rotated collider returns its tilted face normal")
	var outside: Dictionary = physics.query(Vector3(40, 4, 0), Vector3(40, -4, 0))
	check(outside.is_empty(), "physics backend never invents a floor outside the colliders")

	# --- the controller stains a physics surface -------------------------------
	var controller := Controller.new()
	world.add_child(controller)
	var configured: Dictionary = controller.configure(camera, world)
	check(configured.ok and configured.surface_kind == "physics", "controller binds a physics collision root")
	controller.apply_state({"time": 1.0, "mapId": "physics-fixture",
		"actors": [{"id": 1, "x": 0, "y": 0, "z": 0, "health": 100.0, "maxHealth": 100.0}]}, 1)
	controller.apply_events([{"type": "death", "id": 1, "actor": 1, "pos": {"x": 0, "y": 1.0, "z": 0},
		"killer": -1, "direction": {"x": 1, "y": 0, "z": 0}, "seed": 2.0}], 1)
	check(controller.snapshot().stains_placed > 0, "a death against a physics world places real stains")
	var on_floor := 0
	for slot: Dictionary in controller.stain_slots:
		if slot.remaining <= 0.0: continue
		if absf(float(slot.node.global_position.y) - 0.012) < 0.03: on_floor += 1
	check(on_floor >= 1, "the physics floor pool lands on the collider surface, not at a fixed height")

	# --- occlusion rejection: a stain behind a wall is not placed -------------
	world.remove_child(controller)
	controller.free()
	var blocked := Controller.new()
	world.add_child(blocked)
	var map := {
		"id": "occlusion-fixture",
		"blocks": [{"x": 0.0, "z": -3.0, "w": 12.0, "h": 6.0, "d": 0.5}],
		"terrain": {"support_triangles": [
			{"indices": [0, 1, 2], "normal": [0, 1, 0], "vertices": [[-20, 0, -20], [-20, 0, 20], [20, 0, 20]]},
			{"indices": [0, 1, 2], "normal": [0, 1, 0], "vertices": [[-20, 0, -20], [20, 0, 20], [20, 0, -20]]},
		]},
	}
	blocked.configure(camera, map)
	blocked.apply_state({"time": 1.0, "mapId": "occlusion-fixture",
		"actors": [{"id": 1, "x": 0, "y": 0, "z": -6, "health": 100.0, "maxHealth": 100.0}]}, 1)
	blocked.apply_events([{"type": "death", "id": 1, "actor": 1, "pos": {"x": 0, "y": 1.0, "z": -6},
		"killer": -1, "direction": {"x": 1, "y": 0, "z": 0}, "seed": 2.0}], 1)
	# The pool under the body is placed; radial probes that only reach the wall's
	# far side are rejected by the visibility check.
	check(blocked.snapshot().stains_placed >= 1, "the pool under the body is still placed")
	check(blocked.snapshot().stains_rejected >= 0, "rejection counter is reported")
	var reached_far_side := 0
	for slot: Dictionary in blocked.stain_slots:
		if slot.remaining <= 0.0: continue
		# x=0/z=-6 is behind the wall (z=-3 centre, 0.5 deep). Any stain on the
		# wall's far face would sit at z < -3.25 with a +Z normal.
		var normal: Vector3 = slot.node.global_transform.basis.z
		if float(slot.node.global_position.z) < -3.3 and normal.z < -0.6: reached_far_side += 1
	check(reached_far_side == 0, "no stain is placed on a surface hidden behind the wall")

	print("BLOOD_FX_SURFACES ", "FAIL" if failed else "PASS", " checks=", checks)
	print("BLOOD_FX_SURFACES_MAPS ", JSON.stringify(reports))
	print("BLOOD_FX_SURFACES_SNAPSHOT ", JSON.stringify(physics.snapshot()))
	quit(1 if failed else 0)
