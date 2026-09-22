extends SceneTree
const Renderer = preload("res://vehicles/renderer.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var r = Renderer.new()
	root.add_child(r)
	var v := {"id":0,"kind":"puma","x":2.0,"y":3.0,"z":-4.0,"yaw":PI/2,"roll":0.0,"pitchBody":0.0,"health":300,"respawnTimer":0,"vx":2.0,"vz":0.0,"turretYaw":0.2,"driver":0}
	var s := {"vehicles":[v],"actors":[{"id":0,"team":0}],"time":1.0}
	check(r.apply_state(s, 0), "accept source shape")
	var n = r.vehicle_node(0)
	check(n.position.is_equal_approx(Vector3(2,3,-4)), "unmirrored metre translation")
	check((n.basis * Vector3(0,0,1)).is_equal_approx(Vector3(1,0,0)), "+Z nose turns +X at PI/2")
	check(n.scale == Vector3.ONE, "unit scale")
	check(is_equal_approx(n.wheels[0].position.y, 0.42), "ground anchor at tire bottom")
	check(n.get_meta("local_driver"), "actor zero driver")
	check(n.accent.albedo_color == Color("e56859"), "red team")
	check(is_equal_approx(n.turret.rotation.y, 0.2), "relative turret yaw")
	s.time = 1.05
	r.apply_state(s, 0)
	check(r.vehicle_node(0) == n, "stable reuse")
	check(n.wheels[0].rotation.x > 0, "forward roll")
	v.health = 0
	r.apply_state(s)
	check(not n.visible, "destroyed hidden")
	v.health = 300
	v.respawnTimer = 2
	r.apply_state(s)
	check(not n.visible, "respawning hidden")
	v.respawnTimer = 0
	r.apply_state(s)
	check(n.visible, "respawn visible same node")
	v.roll = 0.2
	v.pitchBody = -0.1
	r.apply_state(s)
	check(n.rotation_order == EULER_ORDER_XYZ and n.rotation.is_equal_approx(Vector3(-0.1,PI/2,0.2)), "Euler order and body tilt")
	v.x = NAN
	check(not r.apply_state(s) and n.position.x == 2, "invalid atomic rejection")
	v.x = 2
	s.vehicles.append(v.duplicate())
	check(not r.apply_state(s), "duplicate rejected")
	s.vehicles.pop_back()
	r.apply_state({"vehicles":[]})
	check(r.vehicle_node(0) == null and r.get_child_count() == 0, "disappearance detached immediately")
	r.apply_state(s)
	r.clear_round()
	check(r.nodes.is_empty() and r.stamps.is_empty(), "round reset")
	v.kind = "hornet"
	r.apply_state(s)
	check(r.nodes.is_empty(), "unsupported chassis not misrepresented")
	r.queue_free()
	await process_frame
	print("PUMA TESTS checks=", checks, " failures=", failures, " synthetic=true")
	quit(1 if failures else 0)
