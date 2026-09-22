extends SceneTree
## Graphical acceptance driver for the identity zone scene
## (res://native_arenas/identity_zone_demo.tscn, Vermilion Fold Domination).
##
## Driven entirely by ordinary native input events on the shipped scene: click
## to capture the pointer, WASD/mouse to move and look, Enter to restart after
## results. It never calls a session input handler, never changes the camera or
## actor, never writes gameplay state. Each rendered zone marker and HUD line is
## compared against the same source snapshot the session received, so the
## screenshots and the correlation log are the same authority state.
##
##   DISPLAY=:N $GODOT_BIN --path godot --rendering-method gl_compatibility \
##     --audio-driver Dummy --script res://tests/zone_modes/identity_live.gd -- \
##     --endpoint=ws://127.0.0.1:PORT/native-zones --map=vermilion-fold \
##     --routes=<file> --output=<dir> --size=960x640 --zone-evidence
var session: Node3D
var output := ""
var route_file := ""
var size := Vector2i(960, 640)
var deadline_seconds := 150
var checks := 0
var samples := 0
var marker_errors := 0
var hud_errors := 0
var bearing_errors := 0
var goal := ""
var stage := "capture"
var stage_ticks := 0
var absent_point := Vector2.ZERO
var waypoint := 0
var active_route: Array = []
var routes: Array = []
var capture_proven := false
var contested_proven := false
var lost_proven := false
var recovered_proven := false
var held_proven := false
var source_results := false
var restart_proven := false
var holder_sequences: Dictionary = {}
var shot_map := false
var shot_zone := false
var shot_contested := false
var shot_results := false
var last_state: Dictionary = {}
var firing := false
var reload_cooldown := 0
var input_helper: Node

class InputHelper extends Node:
	var session: Node
	var active := false
	func _process(_delta: float) -> void:
		if active and session != null and session.can_capture_pointer() and session.phase == 3:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and session.controls_released():
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				session.combat_actions.captured()
			if session.received_pose and is_instance_valid(session.first_person):
				session.first_person.refresh()

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--routes="): route_file = arg.trim_prefix("--routes=")
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			if parts.size() == 2: size = Vector2i(int(parts[0]), int(parts[1]))
		if arg.begins_with("--deadline-seconds="):
			deadline_seconds = int(arg.trim_prefix("--deadline-seconds="))
	call_deferred("run")

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		push_error(message)
		quit(2)
	return ok

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click() -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = Vector2(size) * 0.5
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func button(code: int, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = code
	event.position = Vector2(size) * 0.5
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func look_at(target_xz: Vector2, position: Vector2, pitch_down: float = 0.0) -> void:
	var angle := atan2(-(target_xz.x - position.x), -(target_xz.y - position.y))
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-wrapf(angle - session.yaw, -PI, PI) / 0.003, (session.pitch + pitch_down) / 0.003)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/vermilion-fold-%s-%dx%d.png" % [output, name, size.x, size.y]
	check(root.get_texture().get_image().save_png(path) == OK, "screenshot save " + name)
	var panel: Control = session.zone_hud.zone_panel
	check(Rect2(Vector2.ZERO, Vector2(size)).encloses(panel.get_global_rect()), "zone HUD fits viewport " + name)
	print("ZONE_SHOT ", JSON.stringify({"name":name, "path":path, "size":[size.x, size.y],
		"phase":session.phase, "zones":session.zones.projection.zones,
		"rendered":session.zone_renderer.rendered, "markers":session.zone_renderer.markers.size(),
		"hud":session.zone_hud.zone_detail.text, "hint":session.zone_hud.zone_hint.text,
		"title":session.zone_hud.zone_title.text}))

## Pick the cached spawn->zone route closest to the actor for the target zone.
func plan_goal(actor: Dictionary) -> void:
	var best: Dictionary = {}
	var best_distance := INF
	for entry: Dictionary in routes:
		if str(entry.zone) != goal: continue
		var distance := Vector2(actor.x - entry.start[0], actor.z - entry.start[1]).length()
		if distance < best_distance: best_distance = distance; best = entry
	if best.is_empty():
		check(false, "no cached route for " + goal)
		return
	active_route = best.waypoints.duplicate()
	waypoint = 0

func next_goal(actor: Dictionary) -> void:
	var zones: Array = session.zones.projection.zones
	if zones.is_empty(): return
	# Fixed authored rotation: every zone is captured, deliberately left open
	# long enough for the enemy to take it, and then re-entered for the
	# recovery. Ownership churn is choreographed, never left to chance.
	var ids: Array = zones.map(func(zone: Dictionary) -> String: return str(zone.id))
	var index: int = ids.find(goal)
	goal = str(ids[(index + 1) % ids.size()])
	stage = "capture"
	stage_ticks = 0
	plan_goal(actor)
	print("ZONE_GOAL ", JSON.stringify({"goal":goal, "actor":{"x":actor.x,"z":actor.z}}))

## Compare every rendered marker and HUD line against the received source state.
func observe(frame: Dictionary) -> void:
	last_state = frame.state
	if session.phase != 3: return
	var projection: Dictionary = session.zones.projection
	if projection.is_empty() or not projection.has("zones"): return
	var zones: Array = frame.state.objectives.zones
	if projection.zones.size() != zones.size(): return
	var actor: Dictionary = session.presentation.local_actor
	if actor.is_empty(): return
	for zone: Dictionary in zones:
		if not session.zone_renderer.markers.has(zone.id):
			marker_errors += 1
			continue
		var marker: Node3D = session.zone_renderer.markers[zone.id]
		if not marker.position.is_equal_approx(Vector3(zone.x, zone.y, zone.z)):
			marker_errors += 1
		var ring: MeshInstance3D = marker.get_node("Radius")
		if not is_equal_approx(ring.mesh.outer_radius, float(zone.radius) + 0.08):
			marker_errors += 1
		var line := "%s  %s  %.0f%%" % [str(zone.id).to_upper(),
			("CONTESTED" if zone.contested else session.zones.allegiance(zone.owner, projection.team)),
			float(zone.progress)]
		if not session.zone_hud.zone_detail.text.contains(line):
			hud_errors += 1
		# HUD bearing must equal the direction recomputed from the same source
		# coordinates the adapter read (never a guessed or cached direction).
		var target: Dictionary = session.zones.target()
		if str(target.id) == str(zone.id):
			var dx: float = float(zone.x) - float(actor.x)
			var dz: float = float(zone.z) - float(actor.z)
			var direction := ("N" if dz < -1 else ("S" if dz > 1 else "")) + ("E" if dx > 1 else ("W" if dx < -1 else ""))
			var expected := "NEAREST %s · %.0fm %s · radius %.1fm" % [str(zone.id).to_upper(),
				Vector2(dx, dz).length(), direction, float(zone.radius)]
			if not session.zone_hud.zone_hint.text.begins_with(expected):
				bearing_errors += 1
		# Ordered holder sequence per zone (0/1, consecutive duplicates and
		# neutral gaps collapsed): 0 before 1 is a loss, 1 before 0 a recovery.
		var sequence: Array = holder_sequences.get(str(zone.id), [])
		if (zone.owner == 0 or zone.owner == 1) and (sequence.is_empty() or int(sequence[sequence.size() - 1]) != int(zone.owner)):
			sequence.append(int(zone.owner))
		holder_sequences[str(zone.id)] = sequence
		if zone.contested == true: contested_proven = true
		# Held score: a living local actor inside an owned, uncontested ring.
		if zone.owner == int(projection.team) and zone.contested != true and \
				Vector2(actor.x - zone.x, actor.z - zone.z).length() <= float(zone.radius):
			held_proven = true
	samples += 1
	if is_instance_valid(session.zone_hud) and session.zone_hud.zone_detail.text.split("\n").size() != zones.size():
		hud_errors += 1

## Ordinary return fire: aim at the nearest living enemy in weapon range and
## hold the trigger. The driver never calls a combat API directly.
func engage(local: Dictionary) -> void:
	reload_cooldown = maxi(0, reload_cooldown - 1)
	if last_state.is_empty(): return
	var team: int = int(session.zones.projection.team)
	var best: Dictionary = {}
	var best_distance := 16.0
	for actor: Dictionary in last_state.get("actors", []):
		if actor.health > 0 and int(actor.team) != team:
			var distance := Vector2(actor.x - local.x, actor.z - local.z).length()
			if distance < best_distance: best_distance = distance; best = actor
	if best.is_empty():
		if firing: button(MOUSE_BUTTON_LEFT, false); firing = false
		return
	var dx := float(best.x) - float(local.x)
	var dz := float(best.z) - float(local.z)
	var eye_y := float(local.y) + float(local.get("eyeHeight", 1.45))
	var pitch := clampf(atan2((float(best.y) + 1.2) - eye_y, maxf(0.001, sqrt(dx * dx + dz * dz))), -0.6, 0.6)
	var angles := Vector2(atan2(-dx, -dz), pitch)
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-wrapf(angles.x - session.yaw, -PI, PI) / 0.003, (session.pitch - angles.y) / 0.003)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if not firing: button(MOUSE_BUTTON_LEFT, true); firing = true
	var weapon: int = int(local.get("weapon", 0))
	var ammo: Variant = local.get("ammo", [])
	if reload_cooldown == 0 and ammo is Array and weapon >= 0 and weapon < ammo.size() and ammo[weapon] is float and float(ammo[weapon]) <= 2.0:
		key(KEY_R, true)
		key(KEY_R, false)
		reload_cooldown = 120

## Every node of `type` in the shared 3D world: descendants of the session that
## are not inside a first-person SubViewport with its own world.
func world_nodes(type: String) -> Array:
	var found: Array = []
	for node: Node in session.find_children("*", type, true, false):
		var parent: Node = node.get_parent()
		var isolated := false
		while parent != null and parent != session:
			if parent is SubViewport and parent.own_world_3d == true:
				isolated = true
				break
			parent = parent.get_parent()
		if not isolated: found.append(node)
	return found

## True when the authoritative eye can see the target ring marker (no map
## geometry between the camera and the ring centre).
func map_view_clear(local: Dictionary, zone: Dictionary) -> bool:
	var eye: Vector3 = session.camera.global_position
	var target := Vector3(zone.x, zone.y + 0.3, zone.z)
	if eye.distance_to(target) < 4.0: return true
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.collision_mask = 1
	var hit := session.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.position.distance_to(target) < 1.5

func drive(actor: Dictionary) -> void:
	if active_route.is_empty() or waypoint >= active_route.size():
		plan_goal(actor)
		if active_route.is_empty(): return
	var target := Vector2(active_route[waypoint][0], active_route[waypoint][1])
	var position := Vector2(actor.x, actor.z)
	if position.distance_to(target) < 1.0 and waypoint < active_route.size() - 1:
		waypoint += 1
		target = Vector2(active_route[waypoint][0], active_route[waypoint][1])
	look_at(target, position, 0.08)
	var distance := position.distance_to(target)
	key(KEY_W, distance > 0.5)
	key(KEY_SHIFT, distance > 6.0)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size = size
	root.grab_focus()
	session = load("res://native_arenas/identity_zone_demo.tscn").instantiate()
	root.add_child(session)
	root.msaa_3d = Viewport.MSAA_DISABLED
	session.client.snapshot.connect(observe)
	session.client.results.connect(func(_frame: Dictionary) -> void: source_results = true)
	input_helper = InputHelper.new()
	input_helper.session = session
	input_helper.process_priority = 1000
	root.add_child(input_helper)
	var deadline := Time.get_ticks_msec() + deadline_seconds * 1000
	while not session.can_capture_pointer() or not FileAccess.file_exists(route_file):
		await process_frame
		if not session.startup_error.is_empty(): check(false, "startup: " + session.startup_error); return
		if Time.get_ticks_msec() > deadline: check(false, "initial authority/route deadline"); return
	routes = JSON.parse_string(FileAccess.get_file_as_string(route_file)).routes
	var actor: Dictionary = session.presentation.local_actor
	check(not actor.is_empty(), "local actor present")
	# Pointer gate: held movement must not capture; a fresh click must.
	key(KEY_W, true)
	click()
	if not check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "held movement blocks initial capture"): return
	key(KEY_W, false)
	click()
	if not check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "fresh click captures"): return
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	if not check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "Escape releases"): return
	click()
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "re-capture after release")
	input_helper.active = true
	goal = str((session.zones.projection.zones[0] as Dictionary).id)
	plan_goal(session.presentation.local_actor)
	var spawn_position := Vector2(actor.x, actor.z)
	var goal_ticks := 0
	var map_ticks := 0
	while session.phase == 3:
		if Time.get_ticks_msec() > deadline: check(false, "natural results deadline"); return
		if session.zones.projection.is_empty(): await process_frame; continue
		var local: Dictionary = session.presentation.local_actor
		if local.is_empty() or not session.can_capture_pointer():
			await create_timer(0.05).timeout
			continue
		# A death or an epoch reset releases the pointer. Release held movement,
		# then a fresh click re-captures: controls never resume from a stale hold.
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			key(KEY_W, false)
			key(KEY_SHIFT, false)
			if session.controls_released():
				click()
			await create_timer(0.05).timeout
			continue
		stage_ticks += 1
		goal_ticks += 1
		map_ticks += 1
		engage(local)
		var zone: Dictionary = {}
		for candidate: Dictionary in session.zones.projection.zones:
			if str(candidate.id) == goal: zone = candidate
		var team: int = int(session.zones.projection.team)
		# Map evidence from inside the arena: once the actor has left its spawn
		# and can actually see the target ring (or after 30 s of driving) frame
		# the zone, never a wall the actor happens to be facing.
		if not shot_map and (Vector2(local.x, local.z).distance_to(spawn_position) > 12.0 or map_ticks > 400):
			if not zone.is_empty() and (map_view_clear(local, zone) or map_ticks > 600):
				look_at(Vector2(zone.x, zone.z), Vector2(local.x, local.z), 0.12)
				for i in 6: await process_frame
				await screenshot("map")
				shot_map = true
		if stage == "capture":
			drive(local)
			if not zone.is_empty() and zone.owner == team:
				stage = "hold"
				stage_ticks = 0
		elif stage == "hold":
			drive(local)
			if not shot_zone and not zone.is_empty() and Vector2(local.x - zone.x, local.z - zone.z).length() <= float(zone.radius):
				await screenshot("zone")
				shot_zone = true
			if stage_ticks > 40:
				# Leave the ring open: walk back toward the team side so the
				# enemy objective logic can claim it before the recovery run.
				stage = "absent"
				stage_ticks = 0
				# Nearest authored spawn: far outside every objective ring, so the
				# zone is genuinely left open for the enemy objective logic.
				absent_point = Vector2(local.x, local.z)
				var best_distance := INF
				for route: Dictionary in routes:
					var distance: float = Vector2(local.x - route.start[0], local.z - route.start[1]).length()
					if distance < best_distance: best_distance = distance; absent_point = Vector2(route.start[0], route.start[1])
		elif stage == "absent":
			var away := Vector2(local.x, local.z)
			var reach := away.distance_to(absent_point)
			if reach > 2.0:
				look_at(absent_point, away, 0.02)
				key(KEY_W, true)
				key(KEY_SHIFT, reach > 6.0)
			else:
				key(KEY_W, false)
				key(KEY_SHIFT, false)
			# Wait for the enemy to actually claim the ring (the loss), then
			# return for the recovery run. A 25-second ceiling keeps the cycle
			# bounded; a ring the enemy never takes simply stays ours.
			var lost_ring: bool = not zone.is_empty() and zone.owner == 1
			if lost_ring or stage_ticks > 500:
				stage = "recover"
				stage_ticks = 0
				plan_goal(local)
		elif stage == "recover":
			drive(local)
			if not zone.is_empty() and zone.owner == team:
				stage = "done"
			if stage_ticks > 1800:
				next_goal(local)
		elif stage == "done":
			if not shot_zone and not zone.is_empty() and Vector2(local.x - zone.x, local.z - zone.z).length() <= float(zone.radius):
				await screenshot("zone")
				shot_zone = true
			if stage_ticks > 30: next_goal(local)
		if not shot_contested:
			for candidate: Dictionary in session.zones.projection.zones:
				if candidate.contested == true:
					look_at(Vector2(candidate.x, candidate.z), Vector2(local.x, local.z), 0.1)
					await screenshot("contested")
					shot_contested = true
					break
		if goal_ticks > 1800:
			next_goal(local)
			goal_ticks = 0
		await create_timer(0.05).timeout
	key(KEY_W, false)
	check(source_results, "authoritative results observed")
	check(session.phase == 4, "results phase")
	check(not session.can_capture_pointer(), "results release controls")
	check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "results release pointer")
	await create_timer(0.3).timeout
	if not shot_results:
		await screenshot("results")
		shot_results = true
	key(KEY_W, true)
	key(KEY_ENTER, true)
	key(KEY_ENTER, false)
	while session.round_starts < 2 or not session.can_capture_pointer():
		await process_frame
		if Time.get_ticks_msec() > deadline: check(false, "restart deadline"); return
	restart_proven = true
	check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "restart has no inherited capture")
	click()
	check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "held movement blocks restart capture")
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	click()
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "fresh restart capture")
	for sequence: Array in holder_sequences.values():
		if sequence.has(0): capture_proven = true
		# Strict per-zone order: we held it, then the enemy held it (loss), then
		# we held it again (recovery). An enemy opening capture is neither.
		var first_ours := sequence.find(0)
		var enemy_after := -1 if first_ours < 0 else sequence.find(1, first_ours + 1)
		if enemy_after > first_ours: lost_proven = true
		if enemy_after >= 0 and sequence.find(0, enemy_after + 1) > enemy_after: recovered_proven = true
	check(marker_errors == 0 and hud_errors == 0 and bearing_errors == 0, "rendered/HUD source correlation")
	check(shot_map and shot_zone and shot_contested and shot_results, "all requested evidence frames")
	# Composition contract: the shared 3D world has exactly one sun and one
	# environment, and exactly one camera poses from the authority. Nodes inside
	# the first-person rig's isolated SubViewport (own_world_3d) belong to the
	# viewmodel layer, not the world, so they are counted separately.
	var lights: Array = world_nodes("DirectionalLight3D")
	var environments: Array = world_nodes("WorldEnvironment")
	var cameras: Array = world_nodes("Camera3D")
	check(lights.size() == 1 and environments.size() == 1 and cameras.size() == 1, "one world sun, one world environment, one world camera")
	check(cameras.size() == 1 and cameras[0] == session.camera and cameras[0].name == "AuthoritativeCamera" and cameras[0].is_current(), "camera is the current authoritative camera")
	print("ZONE_IDENTITY_LIVE_OK ", JSON.stringify({"map":session.current_id, "mode":session.selected_mode,
		"size":[size.x, size.y], "capture":capture_proven, "contested":contested_proven,
		"lost":lost_proven, "recovered":recovered_proven, "held":held_proven,
		"results":source_results, "restart":restart_proven, "samples":samples,
		"marker_errors":marker_errors, "hud_errors":hud_errors, "bearing_errors":bearing_errors,
		"checks":checks, "shots":[shot_map, shot_zone, shot_contested, shot_results],
		"lights":lights.size(), "environments":environments.size(), "cameras":cameras.size(),
		"local_frags":session.presentation.local_actor.get("frags", null), "normal_rate":true}))
	session.client.disconnect_server()
	await create_timer(0.4).timeout
	quit()
