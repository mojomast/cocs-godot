extends SceneTree
## Automated native input journey. No actor/state/controls dictionary writes.
var session: Node
var elapsed := 0.0
var age := 0.0
var stage := 0
var out := ""
var operator := ""
var observed := {}
var max_cables := 0
var ride_seen := false
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="): out = arg.trim_prefix("--evidence=")
		if arg.begins_with("--operator="): operator = arg.trim_prefix("--operator=")
	call_deferred("begin")
func begin() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	session.client.events.connect(func(items: Array) -> void:
		for event: Dictionary in items:
			if event.get("actor") == session.client.actor_id: observed[event.type] = true
		print("JOURNEY_EVENTS ", JSON.stringify(items)))
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
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(operator + "-" + label + ".png"))
func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 25.0:
		push_error("journey deadline stage=" + str(stage))
		quit(2)
		return false
	if not is_instance_valid(session) or session.phase != 3 or not session.received_pose: return false
	age += delta
	if session.has_node("PlayerGameplay"):
		max_cables = maxi(max_cables, session.get_node("PlayerGameplay").cues.slots.size())
	ride_seen = ride_seen or session.presentation.local_actor.get("zipRide") != null
	if stage == 0 and age > 0.5:
		click(true)
		click(false)
		stage = 1
		age = 0
	elif stage == 1 and age > 0.25:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(0, (session.pitch + 0.35) / 0.003)
		Input.parse_input_event(motion)
		capture("before")
		stage = 2
		age = 0
	elif stage == 2 and age > 0.4:
		key(KEY_Q, true)
		key(KEY_Q, false)
		# Both events in one engine frame: the old adapter loses this X tap.
		key(KEY_X, true)
		key(KEY_X, false)
		stage = 3
		age = 0
	elif stage == 3 and age > 0.45:
		capture("accepted")
		print("JOURNEY_MODEL ", JSON.stringify(session.get_node("PlayerGameplay").model))
		print("JOURNEY_ACTOR ", JSON.stringify(session.presentation.local_actor))
		stage = 4
		age = 0
	elif stage == 4 and age > 1.5:
		key(KEY_Q, true)
		key(KEY_Q, false)
		if operator == "qwen":
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(PI / 0.003, 0.3 / 0.003)
			Input.parse_input_event(motion)
		capture("cooldown")
		stage = 5
		age = 0
	elif stage == 5 and age > 1.0:
		key(KEY_ESCAPE, true)
		key(KEY_ESCAPE, false)
		print("JOURNEY_RESULT ", JSON.stringify({"operator":operator,"events":observed,"model":session.get_node("PlayerGameplay").model,"cables":session.get_node("PlayerGameplay").cues.slots.size(),"max_cables":max_cables,"ride_seen":ride_seen}))
		quit(0 if observed.has("power") and (observed.has("rope-place") or observed.has("windup-start") or observed.has("grapple-hook")) else 1)
	return false
