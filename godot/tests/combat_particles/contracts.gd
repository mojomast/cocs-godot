extends SceneTree
const Manager = preload("res://combat_particles/manager.gd")
var failed := false
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func event(id: int, pos := Vector3(0, 3, 0)) -> Dictionary:
	return {"type": "explosion", "id": id, "weapon": 1, "pos": {"x": pos.x, "y": pos.y, "z": pos.z}}
func rocket(id: int, owner: int) -> Dictionary:
	return {"id": id, "owner": owner, "weapon": 1, "pos": {"x": id % 6, "y": 3, "z": 0}, "dir": {"x": 1, "y": 0, "z": 0}}
func run() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	parent.position = Vector3(800, 100, 200)
	var manager := Manager.new()
	parent.add_child(manager)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 3, 12)
	check(manager.configure(camera, {"id": "test", "bounds": AABB(Vector3(-10, -2, -10), Vector3(20, 20, 20)), "blocks": [{"x": 5, "z": 0, "w": 1, "h": 6, "d": 8}]}).ok, "valid world configuration")
	check(manager.occupancy.solid(Vector3(5, 3, 0)) and not manager.occupancy.solid(Vector3(0, 3, 0)), "wall occupancy and free space")
	var gpu_ids := []
	for slot: Dictionary in manager.slots:
		gpu_ids.append(slot.node.get_instance_id())
		check(slot.node is GPUParticles3D and not slot.node.local_coords and slot.node.global_position == Vector3.ZERO, "world-space independent of translated parent")
	manager.apply_state({"time": 1, "rockets": []}, 7)
	manager.consume([event(11), event(11), event(10), {"id": 12, "type": "shot", "end": {"x": 1, "y": 3, "z": 0}}, event(13, Vector3(NAN, 0, 0))], 7)
	check(manager.snapshot().burst_emitters == 2 and manager.duplicates == 1 and manager.rejected == 1, "public event dedup, out-of-order, tiny-hit ownership and malformed rejection")
	check(manager.last_event_position == Vector3(0, 3, 0), "event position is exact authoritative source position")
	var events := []
	for i in range(100, 2000): events.append(event(i))
	manager.consume(events)
	check(manager.snapshot().burst_emitters == 20 and manager.slots.size() == 32, "bounded scan and emitter recycling")
	check(manager.last_event_id == 611, "512 event scan cap")
	manager.consume([event(9000), event(11)])
	check(manager.last_event_id == 9000, "history floor prevents old replay")
	var rockets := []
	for i in range(12): rockets.append(rocket(i, 2))
	rockets.append(rocket(100, 7))
	manager.apply_state({"time": 2, "rockets": rockets}, 7)
	check(not manager._find_trail(100).is_empty() and manager.snapshot().trail_emitters == 8, "late local projectile gets first refusal")
	var before: int = manager.spawned
	manager.apply_state({"time": 3, "rockets": []}, 7)
	check(manager.spawned == before and manager._find_trail(100).material.get_shader_parameter("source_alive") == false, "missing projectile retires trail without invented explosion")
	for level: String in ["Extreme", "Low", "High", "Extreme"]:
		check(manager.set_quality(level), "quality accepted")
		check(manager.snapshot().allocated_slots == manager.budget and manager.budget <= 1000000, "shared total capacity exactly bounded")
		for i in range(32): check(gpu_ids[i] == manager.slots[i].node.get_instance_id(), "quality reuses emitter pool")
	check(not manager.set_quality("Ultra") and manager.quality == "Extreme", "invalid quality transactional")
	manager.set_paused(true)
	var clock: float = manager.clock
	manager._process(0.2)
	check(manager.clock == clock and manager.snapshot().draw_slots == 0, "pause freezes CPU clock and hides GPU draws")
	manager.set_paused(false)
	manager._process(NAN)
	manager._process(-0.5)
	check(manager.clock == clock, "invalid delta rejected")
	manager.hide()
	manager._process(0.2)
	check(manager.clock == clock and manager.slots[0].node.speed_scale == 0, "hidden node freezes GPU simulation")
	manager.show()
	manager._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	manager._process(0.2)
	check(manager.clock == clock, "focus loss freezes")
	manager._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	paused = true
	manager._process(0.2)
	check(manager.clock == clock, "SceneTree pause freezes even always-process manager")
	paused = false
	manager.last_state_usec = Time.get_ticks_usec() - 1000000
	manager._process(0.2)
	check(not manager.active and manager.snapshot().draw_slots == 0, "stale public state resets")
	manager.apply_state({"time": 4, "rockets": [rocket(4, 7)]}, 7)
	manager.consume([event(11)], 7)
	check(manager.last_event_id == 11, "reset allows authoritative round ID reuse")
	manager.apply_state({"over": true}, 7)
	manager.consume([event(12)], 7)
	check(not manager.active and manager.last_event_id == -1 and manager.snapshot().draw_slots == 0, "results drains all effects and rejects late events")
	check(not manager.configure(camera, "invalid-map").ok, "unknown map rejected")
	print("COMBAT_PARTICLES_CONTRACTS ", "FAIL" if failed else "PASS", " ", JSON.stringify(manager.snapshot()))
	parent.free()
	camera.free()
	quit(1 if failed else 0)
