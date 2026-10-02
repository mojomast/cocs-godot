extends SceneTree
## Native guest uses actual mouse/keyboard; source-wire owner is the Node runner.
var session: Node
var out := ""
var elapsed := 0.0
var stage := 0
var waypoint := 0
var ride_seen := false
var cable_seen := false
var models: Array = []
var end_ride := 0.0
var route := [Vector2(44, -34), Vector2(-44, -34)]
var scenario := "death"
var resumed := false
var suspended_clean := false
var resumed_live := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="): out = arg.trim_prefix("--evidence=")
		if arg.begins_with("--scenario="): scenario = arg.trim_prefix("--scenario=")
	call_deferred("begin")

func begin() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func click(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)

func aim(yaw: float, pitch: float) -> void:
	var motion := InputEventMouseMotion.new()
	var gain := 0.003 * preload("res://ui/settings_access.gd").sensitivity()
	motion.relative = Vector2((session.yaw - yaw) / gain, (session.pitch - pitch) / gain)
	Input.parse_input_event(motion)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("shared-" + label + ".png"))

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 65.0:
		push_error("shared native journey deadline stage=" + str(stage))
		quit(2)
	if is_instance_valid(session) and session.phase == -5 and scenario == "reconnect" and not resumed:
		var adapter: Node = session.get_node("PlayerGameplay")
		suspended_clean = adapter.model.is_empty() and adapter.cues.slots.is_empty() and adapter.cues.channels.is_empty()
		# Invoke the real lobby Retry handler; no transport/pose/state injection.
		session.lobby_retry_reconnect()
		resumed = true
		stage = 4
	if not is_instance_valid(session) or session.phase != 3 or not session.received_pose or not session.has_node("PlayerGameplay"): return false
	var binding: Node = session.get_node("PlayerGameplay")
	var actor: Dictionary = session.presentation.local_actor
	cable_seen = cable_seen or not binding.cues.slots.is_empty()
	if resumed and not binding.cues.slots.is_empty(): resumed_live = true
	if stage == 0:
		click(true)
		click(false)
		stage = 1
	elif stage == 1:
		if actor.get("zipRide") != null:
			ride_seen = true
			key(KEY_W, false)
			models.append(binding.model.duplicate(true))
			capture("ride")
			stage = 2
		elif waypoint < route.size():
			var direction: Vector2 = route[waypoint] - Vector2(actor.x, actor.z)
			if direction.length() < 0.4: waypoint += 1
			else:
				aim(atan2(-direction.x, -direction.y), 0)
				key(KEY_W, true)
	elif stage == 2 and actor.get("zipRide") == null:
		end_ride = elapsed
		aim(-PI / 2.0, 0)
		key(KEY_W, true)
		stage = 3
	elif stage == 3 and elapsed - end_ride > 0.5:
		key(KEY_W, false)
		stage = 4
	elif stage == 4:
		for owner: Dictionary in binding.snapshot.get("actors", []):
			if owner.id == actor.id: continue
			var done: bool = float(owner.health) <= 0.0 if scenario == "death" else owner.movement.get("anchor") == null
			if done:
				click(false)
				stage = 5
				end_ride = elapsed
				break
			if scenario != "death": continue
			var dx := float(owner.x) - float(actor.x)
			var dz := float(owner.z) - float(actor.z)
			var dy := float(owner.y) + float(owner.eyeHeight) - float(actor.y) - float(actor.eyeHeight)
			aim(atan2(-dx, -dz), atan2(dy, Vector2(dx, dz).length()))
			click(true)
			if float(actor.ammo[int(actor.weapon)]) <= 0.0:
				key(KEY_R, true)
				key(KEY_R, false)
	elif stage == 5 and elapsed - end_ride > 0.2:
		var ok: bool = ride_seen and cable_seen and binding.cues.slots.is_empty()
		if scenario == "reconnect": ok = ok and suspended_clean and resumed_live
		capture(scenario + "-cleanup")
		print("SECOND_PASS_SHARED ", JSON.stringify({"ok":ok,"scenario":scenario,"ride_seen":ride_seen,"cable_seen":cable_seen,"slots_after_cleanup":binding.cues.slots.size(),"suspended_clean":suspended_clean,"resumed_live":resumed_live,"models":models,"native_role":"guest","owner_role":"Node source-wire"}))
		stage = 6
		finish(ok)
	return false

func finish(ok: bool) -> void:
	await create_timer(0.3).timeout
	quit(0 if ok else 1)
