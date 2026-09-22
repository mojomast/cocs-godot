extends SceneTree
## Native collision/locomotion acceptance; does not teleport between route waypoints.

const Map = preload("res://cinder_array/map.gd")
class Walker extends "res://exploration/walker.gd":
	var wish_direction := Vector3.ZERO
	var speed := 6.0
	func _physics_process(delta: float) -> void:
		var local_direction := basis.inverse() * wish_direction
		step(delta, Vector2(local_direction.x, -local_direction.z), speed > WALK_SPEED)
var failures: Array[String] = []
var assertions := 0
var map: Node3D
var walker: CharacterBody3D
var report: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		push_error("CINDER_CHECK: " + message)

func finite(value: Variant) -> bool:
	if value is float: return is_finite(value)
	if value is Color: return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
	if value is Vector2 or value is Vector3 or value is Transform3D or value is Basis: return value.is_finite()
	if value is Array or value is PackedVector3Array:
		for entry: Variant in value:
			if not finite(entry): return false
	if value is Dictionary:
		for entry: Variant in value.values():
			if not finite(entry): return false
	return true

func ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [walker.get_rid()])
	return map.get_world_3d().direct_space_state.intersect_ray(query)

func run() -> void:
	map = Map.new()
	root.add_child(map)
	walker = Walker.new()
	root.add_child(walker)
	var spawn: Dictionary = map.get_spawn()
	walker.set_spawn(spawn.position, spawn.yaw, spawn.pitch)
	for i in range(8): await physics_frame
	var initial: Dictionary = map.get_diagnostics()
	check(initial.built and initial.areas == 6, "six authored areas built")
	check(walker.is_on_floor(), "spawn settles onto a native collider")
	check(absf(walker.position.y - 7.0) < 0.05, "spawn feet on transfer deck")
	map.build()
	check(initial.nodes == map.get_diagnostics().nodes, "build is idempotent")
	check(initial.embers == 48 and initial.steam == 16, "small fixed particle budget")
	check(not map.environment.glow_enabled and not map.environment.volumetric_fog_enabled, "Compatibility feature contract")
	check(finite(spawn) and finite(map.get_route_points()), "finite authored spawn and route")
	var route: Array[Vector3] = map.get_route_points()
	check(route[0] == route[-1], "route closes a loop")
	var route_copy: Array[Vector3] = map.get_route_points()
	route_copy[0] = Vector3.ZERO
	check(map.get_route_points()[0] != Vector3.ZERO, "route accessor is caller-owned")
	var max_slope := 0.0
	for surface: Dictionary in map.walk_surfaces:
		max_slope = maxf(max_slope, surface.slope)
		check(surface.slope < 30.0, "ramp slope <30 degrees: " + surface.name)
		check(finite(surface), "finite walk geometry: " + surface.name)
	for material: Material in map.materials.values():
		if material is ShaderMaterial:
			for uniform: Dictionary in material.shader.get_shader_uniform_list():
				check(finite(material.get_shader_parameter(uniform.name)), "finite shader uniform " + uniform.name)
		elif material is StandardMaterial3D:
			check(finite(material.albedo_color), "finite standard material")
	# Probe every ramp centre/edge strip, independently of its authored polygon mesh.
	var floor_probes := 0
	for connection: Dictionary in map.connections:
		var a: Vector3 = connection.a
		var b: Vector3 = connection.b
		var side := Vector3(-(b - a).z, 0, (b - a).x).normalized()
		for i in range(1, 20):
			for offset in [-0.72, 0.0, 0.72]:
				var p: Vector3 = map.connection_point(connection, float(i) / 20) + side * connection.width * 0.5 * offset
				var hit := ray(p + Vector3.UP * 0.32, p - Vector3.UP * 0.35)
				check(not hit.is_empty(), "continuous floor " + connection.name + " sample " + str(i) + " / " + str(offset) + " point=" + str(p) + " profile=" + str(connection.profile))
				if not hit.is_empty():
					check(absf(hit.position.y - p.y) < 0.055, "floor follows visual ramp " + connection.name)
					check(hit.normal.dot(Vector3.UP) > cos(deg_to_rad(30)), "walkable native floor normal " + connection.name)
				floor_probes += 1
	# Full loop, then reverse it. The capsule only advances via move_and_slide.
	var traversals: Array[Dictionary] = []
	traversals.append(await traverse(route, "forward", 6.0))
	route.reverse()
	traversals.append(await traverse(route, "reverse-sprint", 10.0))
	# Mid-span rails resist deliberate outward motion from both sides.
	var bridge: Dictionary = map.connections[0]
	var middle: Vector3 = map.connection_point(bridge, 0.5)
	var side := Vector3(-(bridge.b - bridge.a).z, 0, (bridge.b - bridge.a).x).normalized()
	var rail_probes: Array[Dictionary] = []
	for sign_value in [-1.0, 1.0]:
		walker.position = middle + Vector3.UP * 0.08
		walker.velocity = Vector3.ZERO
		walker.wish_direction = side * sign_value
		walker.speed = 10
		for i in range(70): await physics_frame
		var across: float = absf((walker.position - middle).dot(side))
		check(across < bridge.width * 0.5 - 0.20, "bridge continuous rail arrests sprint " + str(sign_value))
		check(walker.position.y > middle.y - 0.15, "bridge rail keeps feet on span " + str(sign_value))
		rail_probes.append({"side": sign_value, "outward_sprint_frames": 70, "across_m": across, "limit_m": bridge.width * 0.5 - 0.20, "feet": walker.position, "on_floor": walker.is_on_floor()})
	walker.wish_direction = Vector3.ZERO
	# Low ceiling rays and actual loop traversal together detect sealed tunnel ends.
	var tunnel_probes: Array[Dictionary] = []
	for x in [-5, 0, 7, 14, 19]:
		var clear := ray(Vector3(x, 13.8, -31), Vector3(x, 16.7, -31)).is_empty()
		var ceiling := ray(Vector3(x, 16.8, -31), Vector3(x, 18, -31))
		check(clear, "bore eye/head clearance " + str(x))
		check(not ceiling.is_empty(), "bore has native ceiling " + str(x))
		tunnel_probes.append({"x": x, "head_clear": clear, "ceiling_hit": not ceiling.is_empty(), "ceiling_position": ceiling.get("position", Vector3.ZERO)})
	var boundary_cases := [Vector3(0, -4, 0), Vector3(97, 12, 0), Vector3(0, 15, -89), Vector3(0, 90, 0)]
	var boundary_probes: Array[Dictionary] = []
	for p in boundary_cases:
		walker.position = p
		walker.velocity = Vector3(3, -12, 8)
		check(map.enforce_boundary(walker), "boundary triggers native reset " + str(p))
		check(walker.position.is_equal_approx(spawn.position) and walker.velocity == Vector3.ZERO, "reset restores spawn and clears velocity")
		boundary_probes.append({"outside": p, "reset_position": walker.position, "reset_velocity": walker.velocity})
	check(map.needs_respawn(Vector3(NAN, 0, 0)), "nonfinite boundary rejected")
	check(not map.enforce_boundary(walker), "safe spawn does not reset repeatedly")
	for i in range(240): await physics_frame
	check(initial.nodes == map.get_diagnostics().nodes, "node count stable after traversal, particles and resets")
	check(initial.collision_shapes == map.get_diagnostics().collision_shapes, "collider count stable")
	var capsule: CapsuleShape3D = walker.get_child(0).shape
	report = {"assertions": assertions, "failures": failures, "diagnostics": map.get_diagnostics(), "max_ramp_degrees": max_slope, "floor_probes": floor_probes, "traversals": traversals, "boundary_cases": boundary_cases.size(), "godot": Engine.get_version_info().string,
		"controller": {"script": "res://exploration/walker.gd", "entry_point": "step", "input_adapter": "world wish direction to local axes; inherited production physics and capsule", "capsule_radius": capsule.radius, "capsule_height": capsule.height, "safe_margin": walker.safe_margin, "floor_snap_length": walker.floor_snap_length, "floor_constant_speed": walker.floor_constant_speed}, "connections": map.connections,
		"rail_probes": rail_probes, "tunnel_probes": tunnel_probes, "boundary_probes": boundary_probes}
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("CINDER_VERIFY ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func traverse(route: Array[Vector3], label: String, speed: float) -> Dictionary:
	walker.speed = speed
	var frames := 0
	var worst_height_error := 0.0
	var reached := 0
	var off_floor_frames := 0
	var stalled_contacts: Dictionary = {}
	var reset_count: int = walker.reset_count
	var arrivals: Array[Dictionary] = []
	for target in route:
		var arrived := false
		for i in range(1200):
			var delta: Vector3 = target - walker.position
			var horizontal := Vector3(delta.x, 0, delta.z)
			if horizontal.length() < 0.38:
				arrived = true
				worst_height_error = maxf(worst_height_error, absf(delta.y))
				check(absf(delta.y) < 0.22, label + " waypoint height matches surface " + str(target))
				arrivals.append({"target": target, "actual": walker.position, "physics_frame": frames, "on_floor": walker.is_on_floor()})
				break
			walker.wish_direction = horizontal.normalized()
			await physics_frame
			frames += 1
			if not walker.is_on_floor(): off_floor_frames += 1
			if map.needs_respawn(walker.position): break
		check(arrived, label + " physically reached " + str(target) + " actual=" + str(walker.position))
		if not arrived:
			stalled_contacts = contact_snapshot()
			break
		reached += 1
	walker.wish_direction = Vector3.ZERO
	check(reached == route.size(), label + " entire connected loop traversed")
	check(off_floor_frames == 0, label + " remains floor-supported across seams")
	check(walker.reset_count == reset_count, label + " traverses without controller resets")
	return {"direction": label, "speed_m_s": speed, "reached": reached, "waypoints": route.size(), "physics_frames": frames, "off_floor_frames": off_floor_frames, "worst_waypoint_height_error": worst_height_error, "controller_resets": walker.reset_count - reset_count, "stalled_contacts": stalled_contacts, "arrivals": arrivals}

func contact_snapshot() -> Dictionary:
	var contacts: Array[Dictionary] = []
	for i in walker.get_slide_collision_count():
		var hit: KinematicCollision3D = walker.get_slide_collision(i)
		var body: CollisionObject3D = hit.get_collider()
		var shape_node: CollisionShape3D = hit.get_collider_shape()
		var contact := {"position": hit.get_position(), "normal": hit.get_normal(), "depth": hit.get_depth(), "collider": str(body.get_path()), "shape_index": hit.get_collider_shape_index(), "shape_transform": shape_node.transform}
		if shape_node.shape is ConvexPolygonShape3D: contact["shape_points"] = shape_node.shape.points
		contacts.append(contact)
	return {"feet": walker.position, "velocity": walker.velocity, "floor_normal": walker.get_floor_normal(), "last_motion": walker.get_last_motion(), "contacts": contacts}
