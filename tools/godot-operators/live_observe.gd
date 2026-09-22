extends SceneTree
## Normal-rate production observer for the source operator presentation lane.
## Joins the shipped combat scene to a private authority as a guest, records what
## the real client renders while a real remote peer and two bots walk, fire and
## reload, drives the round results/restart boundary and unloads cleanly.
## The only local write is camera aim, so remote actors are actually framed.
var session: Node
var output: String = OS.get_environment("SOURCE_OPERATOR_LIVE_OUTPUT")
var started_usec: int = 0
var last_write_usec: int = 0
var snapshot_count: int = 0
var remote_state: Dictionary = {}
var remote_ids: Dictionary = {}
var remote_walking: Dictionary = {}
var remote_firing: Dictionary = {}
var remote_reloading: Dictionary = {}
var remote_weapons: Dictionary = {}
var last_positions: Dictionary = {}
var last_shots: Dictionary = {}
var max_shots: int = 0
var visual_scripts: Dictionary = {}
var visual_world_weapons: Dictionary = {}
var visual_pulse_hidden: Dictionary = {}
var visual_weapon_matches: Dictionary = {}
var visual_lods: Dictionary = {}
var grip_max_error: float = 0.0
var grip_clamp_max: float = 0.0
var grip_excess_max: float = 0.0
var rendered_remote_poses_max: int = 0
var applied_max: int = 0
var results: Dictionary = {}
var restarts: Dictionary = {}
var restart_pose_base: int = 0
var restart_capture_pending: bool = false
var captures: Array = []
var pending: Array = []
var capture_busy: bool = false
var finishing: bool = false
var move_held: bool = false
var sprint_held: bool = false
var errors: Array[String] = []
var outcome: String = "running"

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	started_usec = Time.get_ticks_usec()
	if output.is_empty():
		push_error("SOURCE_OPERATOR_LIVE_OUTPUT is unset")
		quit(1)
		return
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	session.client.snapshot.connect(_on_snapshot)
	session.client.results.connect(_on_results)
	session.client.started.connect(_on_started)
	session.client.connection_error.connect(func(message: String) -> void: errors.append(message))
	print("SOURCE_OPERATOR_LIVE_READY scene=res://world/session.tscn")

func _on_snapshot(frame: Dictionary) -> void:
	snapshot_count += 1
	var state: Variant = frame.get("state")
	if not state is Dictionary: return
	var local_id: int = int(session.client.actor_id)
	for actor: Dictionary in state.get("actors", []):
		var id: int = int(actor.get("id", -2))
		if id == local_id or id < 0: continue
		remote_state[id] = actor.duplicate(true)
		remote_ids[id] = true
		var shots: int = int(actor.get("shots", 0))
		if last_shots.has(id) and shots > int(last_shots[id]): remote_firing[id] = true
		max_shots = maxi(max_shots, shots)
		last_shots[id] = shots
		if actor.get("reloading", false) == true: remote_reloading[id] = true
		var position := Vector3(float(actor.get("x", 0)), float(actor.get("y", 0)), float(actor.get("z", 0)))
		if last_positions.has(id) and position.distance_to(last_positions[id]) > 0.04: remote_walking[id] = true
		last_positions[id] = position
		var weapon: int = int(actor.get("weapon", -1))
		if weapon >= 0: remote_weapons[weapon] = true

func _on_results(frame: Dictionary) -> void:
	var state: Variant = frame.get("state")
	results = {"count": int(results.get("count", 0)) + 1, "over": state is Dictionary and state.get("over", false) == true, "phase": session.phase, "actors": session.presentation.actors.size(), "lifecycle": session.presentation.lifecycle.status}
	write_report()

func _on_started(_frame: Dictionary) -> void:
	if not results.is_empty() and restarts.is_empty():
		restarts = {"count": 1, "phase": session.phase, "actors": session.presentation.actors.size()}
		restart_pose_base = rendered_remote_poses_max
		restart_capture_pending = true
	write_report()

func _process(_delta: float) -> bool:
	var elapsed: float = (Time.get_ticks_usec() - started_usec) / 1000000.0
	if elapsed > 150.0:
		outcome = "watchdog"
		write_report()
		quit(1)
		return true
	if session == null: return false
	# Presentation-side checks against the authoritative remote snapshots.
	for id: int in remote_state:
		if not session.presentation.actors.has(id): continue
		var node: Variant = session.presentation.actors[id]
		if not node is Node3D: continue
		var weapon: int = int(remote_state[id].get("weapon", -1))
		visual_scripts[id] = node.get_script().resource_path if node.get_script() != null else ""
		visual_world_weapons[id] = is_instance_valid(node.world_weapon)
		var pulse_hidden: bool = true
		if node.nodes.has("weapon"): pulse_hidden = node.nodes.weapon.visible == false
		visual_pulse_hidden[id] = pulse_hidden
		visual_weapon_matches[id] = node.weapon_type == weapon
		visual_lods[id] = node.lod_level
		for side: String in node.grip_error:
			var error: float = float(node.grip_error[side])
			var clamp: float = float(node.grip_clamp.get("clamped"+side,0.0))
			grip_max_error = maxf(grip_max_error,error)
			grip_clamp_max = maxf(grip_clamp_max,clamp)
			grip_excess_max = maxf(grip_excess_max,error-clamp)
	rendered_remote_poses_max = maxi(rendered_remote_poses_max, session.presentation.rendered_remote_poses)
	applied_max = maxi(applied_max, session.presentation.applied)
	if session.phase == 3: aim_at_remote()
	# Walk the local player into close range through the shipped input path so
	# the captures show the articulated operator instead of a 30 m silhouette.
	var distance: float = nearest_remote_distance()
	if session.phase == 3 and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if session.phase != 3 or session.presentation.lifecycle.can_control() == false:
		set_move(false)
	else:
		set_move(not capture_busy and captures.size() < 2 and distance > 14.0 and elapsed < 52.0)
	if not capture_busy and pending.is_empty() and not finishing:
		if captures.is_empty() and session.phase == 3 and remote_ids.size() >= 2 and rendered_remote_poses_max > 30 and (distance < 18.0 or elapsed > 42.0):
			pending.append({"name": "actors-960x640", "size": Vector2i(960, 640), "ids": remote_ids.keys()})
			pending.append({"name": "actors-1280x800", "size": Vector2i(1280, 800), "ids": remote_ids.keys()})
		elif captures.size() == 2 and restart_capture_pending and session.phase == 3 and session.presentation.rendered_remote_poses > 20:
			restart_capture_pending = false
			set_move(false)
			pending.append({"name": "restart-1280x800", "size": Vector2i(1280, 800), "ids": remote_ids.keys()})
	if not capture_busy and not pending.is_empty():
		capture_busy = true
		capture_next.call_deferred()
	if captures.size() == 3 and not finishing:
		finish_run.call_deferred()
	if (Time.get_ticks_usec() - last_write_usec) / 1000000.0 > 0.5:
		write_report()
	return false

func nearest_remote() -> Dictionary:
	if not is_instance_valid(session) or not is_instance_valid(session.camera): return {}
	var best: Dictionary = {}
	var best_distance: float = INF
	for id: int in remote_state:
		var actor: Dictionary = remote_state[id]
		if float(actor.get("health", 0)) <= 0: continue
		var target := Vector3(float(actor.get("x", 0)), float(actor.get("y", 0)) + 1.15, float(actor.get("z", 0)))
		var distance: float = session.camera.global_position.distance_to(target)
		if distance < best_distance:
			best_distance = distance
			best = actor
	return best

func nearest_remote_distance() -> float:
	if not is_instance_valid(session) or not is_instance_valid(session.camera): return INF
	var actor: Dictionary = nearest_remote()
	if actor.is_empty(): return INF
	return session.camera.global_position.distance_to(Vector3(float(actor.get("x", 0)), float(actor.get("y", 0)) + 1.15, float(actor.get("z", 0))))

func set_move(pressed: bool) -> void:
	if pressed == move_held: return
	move_held = pressed
	var walk := InputEventKey.new()
	walk.physical_keycode = KEY_W
	walk.pressed = pressed
	Input.parse_input_event(walk)
	if not pressed:
		var stop := InputEventKey.new()
		stop.physical_keycode = KEY_SHIFT
		stop.pressed = false
		Input.parse_input_event(stop)
		sprint_held = false
	elif not sprint_held:
		sprint_held = true
		var sprint := InputEventKey.new()
		sprint.physical_keycode = KEY_SHIFT
		sprint.pressed = true
		Input.parse_input_event(sprint)

func aim_at_remote() -> void:
	var camera: Camera3D = session.camera
	if not is_instance_valid(camera): return
	var best: Dictionary = nearest_remote()
	if best.is_empty(): return
	var target := Vector3(float(best.get("x", 0)), float(best.get("y", 0)) + 1.15, float(best.get("z", 0)))
	if camera.global_position.distance_to(target) < 0.5: return
	camera.look_at(target, Vector3.UP)
	session.yaw = camera.rotation.y
	session.pitch = camera.rotation.x

func capture_next() -> void:
	var item: Dictionary = pending.pop_front()
	root.size = item.size
	await process_frame
	await process_frame
	if session != null and session.phase == 3: aim_at_remote()
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var name: String = str(item.name)
	if image != null:
		image.save_png(output.path_join(name + ".png"))
		captures.append({"name": name, "size": [image.get_width(), image.get_height()], "viewport": [root.size.x, root.size.y], "remote": item.ids, "distance": nearest_remote_distance(), "camera": [session.camera.global_position.x, session.camera.global_position.y, session.camera.global_position.z], "camera_yaw": session.yaw})
	else:
		errors.append("capture failed: " + name)
	capture_busy = false
	write_report()

func finish_run() -> void:
	finishing = true
	outcome = "complete"
	set_move(false)
	if is_instance_valid(session) and is_instance_valid(session.client): session.client.disconnect_server()
	write_report()
	print("SOURCE_OPERATOR_LIVE_DONE snapshots=", snapshot_count, " remotes=", remote_ids.size(), " walking=", remote_walking.size(), " firing=", remote_firing.size(), " reloading=", remote_reloading.size(), " results=", results.get("count", 0), " restarts=", restarts.get("count", 0), " rendered_remote_poses=", rendered_remote_poses_max)
	if is_instance_valid(session):
		session.queue_free()
		await process_frame
	quit(0)

func write_report() -> void:
	last_write_usec = Time.get_ticks_usec()
	var report: Dictionary = {
		"outcome": outcome,
		"elapsed": (Time.get_ticks_usec() - started_usec) / 1000000.0,
		"snapshots": snapshot_count,
		"phase": session.phase if session != null else -99,
		"actor_count": session.presentation.actors.size() if session != null else 0,
		"remote_ids": remote_ids.keys(),
		"remote_walking": remote_walking.keys(),
		"remote_firing": remote_firing.keys(),
		"remote_reloading": remote_reloading.keys(),
		"remote_weapons": remote_weapons.keys(),
		"remote_max_shots": max_shots,
		"rendered_remote_poses": rendered_remote_poses_max,
		"applied": applied_max,
		"hud_text": session.presentation.hud_text if session != null else "",
		"label_text": session.label.text if session != null and is_instance_valid(session.label) else "",
		"spectating": session.client.spectating if session != null and is_instance_valid(session.client) else false,
		"visual_script": visual_scripts.values().min() if not visual_scripts.is_empty() else "",
		"visual_scripts_all_match": visual_scripts.values().all(func(value: String) -> bool: return value == "res://source_operators/operator_visual.gd"),
		"visual_world_weapons_all_match": visual_world_weapons.values().all(func(value: bool) -> bool: return value),
		"visual_pulse_hidden_all_match": visual_pulse_hidden.values().all(func(value: bool) -> bool: return value),
		"visual_weapon_matches_all_match": visual_weapon_matches.values().all(func(value: bool) -> bool: return value),
		"visual_lods": visual_lods.values(),
		"grip_max_error": grip_max_error,
		"grip_clamp_max": grip_clamp_max,
		"grip_excess_max": grip_excess_max,
		"captures": captures,
		"results": results,
		"restarts": restarts,
		"errors": errors,
	}
	var file: FileAccess = FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
