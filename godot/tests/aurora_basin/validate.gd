extends SceneTree
const Basin = preload("res://aurora_basin/map.gd")
const Walker = preload("res://tests/aurora_basin/test_walker.gd")
var output := "/tmp/opencode/aurora-validation.json"
var failures: Array[String] = []
var checks := 0
var map: Node3D
var walker: CharacterBody3D
var walks: Array[Dictionary] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("AURORA_CHECK " + message)

func run() -> void:
	map = Basin.new()
	root.add_child(map)
	map.build()
	var before: Dictionary = map.resource_report()
	map.build()
	check(map.resource_report().nodes == before.nodes, "build() must be idempotent")
	check(before.invalid_transforms == 0, "all object and MultiMesh transforms must be finite")
	check(before.nodes < 850, "node budget <850")
	check(before.mesh_triangles + before.multimesh_triangles < 90000, "expanded static triangle budget <90000")
	check(before.multimesh_instances <= 500, "instanced prop budget <=500")
	check(before.lights <= 3 and before.shadow_lights == 1, "three lights, one shadow light maximum")
	check(before.particle_emitters == 3 and before.particle_capacity == 384, "bounded local snow capacity")
	check(before.moth_cache.textures <= 16, "bounded inherited texture budget")
	var pending: Array[Node] = [map]
	var mesh_vertices := 0
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		for child in node.get_children(): pending.append(child)
		if node is MeshInstance3D:
			for surface in node.mesh.get_surface_count():
				var vertices: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				mesh_vertices += vertices.size()
				for p in vertices:
					if not p.is_finite(): check(false, "nonfinite mesh vertex in " + node.name)
	check(mesh_vertices > 20000, "procedural mesh geometry is present")
	for i in 5: await physics_frame
	var route_reports: Array[Dictionary] = []
	for entry in [{"name": "lake_loop", "points": map.route_points}, {"name": "landing_ramp", "points": map.landing_points}, {"name": "crown_skywalk", "points": map.skywalk_points}]:
		var points: PackedVector3Array = entry.points
		var max_slope := 0.0
		var max_height_error := 0.0
		var hits := 0
		for i in points.size():
			var query := PhysicsRayQueryParameters3D.create(points[i] + Vector3.UP * 1.8, points[i] - Vector3.UP * 0.6)
			var hit := map.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty(), "%s support ray %d" % [entry.name, i])
			if not hit.is_empty():
				hits += 1
				var error: float = absf(hit.position.y - points[i].y)
				max_height_error = maxf(max_height_error, error)
				# Overlapping access aprons can sit above the lake loop; motion probes
				# below independently prove that these junctions remain passable.
				check(hit.normal.y >= 0.70, "%s support slope %d" % [entry.name, i])
			if i > 0:
				var delta := points[i] - points[i - 1]
				var slope := rad_to_deg(atan2(absf(delta.y), Vector2(delta.x, delta.z).length()))
				max_slope = maxf(max_slope, slope)
		check(max_slope < 25.0, "%s authored slope <25 degrees" % entry.name)
		check(max_height_error < 0.15, "%s ray support matches authored surface height" % entry.name)
		route_reports.append({"name": entry.name, "support_rays": hits, "max_slope_degrees": max_slope, "max_height_error_m": max_height_error})
	# Traverse with an actual 1.8m capsule, 0.35m radius, 1.6m eye, speed 6,
	# gravity and move_and_slide(). No navigation teleport between waypoints.
	Engine.physics_ticks_per_second = 120
	Engine.time_scale = 3.0
	walker = Walker.new()
	walker.test_driving = true
	root.add_child(walker)
	walks.append(await walk_route("landing_to_lake", map.landing_points))
	walks.append(await walk_route("lake_circuit", map.route_points))
	walks.append(await walk_route("sealed_lake_crossing", PackedVector3Array([Vector3(0, 0.08, 27), Vector3(0, 0.04, 20), Vector3(15, 0.04, 12), Vector3(17, 0.04, 0), Vector3(17, 0.04, -15), Vector3(20, 0.08, -18)])))
	walks.append(await walk_route("crown_east_to_west", map.skywalk_points))
	var reverse: PackedVector3Array = map.skywalk_points.duplicate()
	reverse.reverse()
	walks.append(await walk_route("crown_west_to_east", reverse))
	walks.append(await walk_route("vista_walk_in", PackedVector3Array([Vector3(16, 9, -31), Vector3(16, 9, -34), Vector3(16, 9, -36)])))
	# Both ends of the skywalk overlap the lake circuit. Exercise the junctions.
	for entry in [Vector3(25, 0.08, 12), Vector3(-25, 0.08, -11)]:
		var radial := Vector3(entry.x, 0, entry.z).normalized()
		var junction := PackedVector3Array([radial * 25.5 + Vector3.UP * 0.08, entry, radial * 29.0 + Vector3.UP * 0.08])
		walks.append(await walk_route("lake_skywalk_junction", junction, 0.6))
	walker.set_spawn(map.get_spawn(), Basin.SPAWN_YAW, Basin.SPAWN_PITCH)
	walker.test_direction = Vector3.ZERO
	for i in 20: await physics_frame
	check(walker.is_on_floor(), "spawn capsule is grounded")
	check(absf(walker.position.y - 0.08) < 0.08, "spawn is on landing platform")
	check(absf(walker.camera.global_position.y - walker.global_position.y - 1.6) < 0.001, "native eye height is 1.6m")
	check(map.resource_report().nodes == before.nodes, "no map node creation during traversal")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "resources": before, "mesh_vertices_checked": mesh_vertices, "routes": route_reports, "walks": walks, "engine": Engine.get_version_info(), "controller": "private baseline-compatible capsule probe"}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("AURORA_VALIDATION ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func walk_route(label: String, points: PackedVector3Array, height_tolerance := 0.45) -> Dictionary:
	walker.set_spawn(points[0] + Vector3.UP * 0.05)
	walker.test_direction = Vector3.ZERO
	for i in 14: await physics_frame
	var index := 1
	var frames := 0
	var grounded := 0
	var max_height_error := 0.0
	var began: float = walker.travelled
	var last_progress := 0
	while index < points.size() and frames < 5000:
		var target := points[index]
		var delta := Vector3(target.x - walker.position.x, 0, target.z - walker.position.z)
		if delta.length() < 0.23:
			max_height_error = maxf(max_height_error, absf(walker.position.y - target.y))
			index += 1
			last_progress = frames
			continue
		walker.test_direction = delta.normalized()
		await physics_frame
		frames += 1
		if walker.is_on_floor(): grounded += 1
		if frames - last_progress > 160: break
	walker.test_direction = Vector3.ZERO
	check(index == points.size(), "%s actual capsule traversal stopped at %d/%d (%s)" % [label, index, points.size(), walker.position])
	check(max_height_error < height_tolerance, "%s actual capsule support height error %.3fm" % [label, max_height_error])
	var contacts: Array[Dictionary] = []
	if index < points.size():
		for i in walker.get_slide_collision_count():
			var collision := walker.get_slide_collision(i)
			contacts.append({"collider": str(collision.get_collider().get_path()), "normal": str(collision.get_normal()), "position": str(collision.get_position())})
	var report := {"name": label, "completed": index == points.size(), "waypoints_reached": index, "waypoints_total": points.size(), "physics_frames": frames, "grounded_frames": grounded, "distance_m": walker.travelled - began, "max_height_error_m": max_height_error, "end_position": [walker.position.x, walker.position.y, walker.position.z], "blocked_contacts": contacts}
	print("AURORA_WALK ", JSON.stringify(report))
	return report
