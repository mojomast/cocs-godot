extends SceneTree
const Controls = preload("res://horde/controls.gd")
const CODES := {"KeyW":KEY_W,"KeyD":KEY_D,"KeyR":KEY_R,"KeyE":KEY_E,"KeyQ":KEY_Q,"KeyF":KEY_F,"KeyG":KEY_G,"KeyX":KEY_X,"KeyZ":KEY_Z,"KeyC":KEY_C,"Space":KEY_SPACE,"ShiftLeft":KEY_SHIFT,"Digit2":KEY_2}

func _initialize() -> void:
	var path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--vectors="): path = arg.trim_prefix("--vectors=")
	var vectors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var model := Controls.new()
	var count := 0
	for case: Dictionary in vectors.cases:
		if case.cancel: model.clear()
		for raw: Dictionary in case.events:
			var event: InputEvent
			if raw.kind == "key":
				event = InputEventKey.new()
				event.physical_keycode = CODES[raw.code]
				event.keycode = CODES[raw.code]
				event.echo = raw.echo
			else:
				event = InputEventMouseButton.new()
				event.button_index = int(raw.button)
			event.pressed = raw.pressed
			model.record(event, true, {"weapon":0,"ammo":vectors.ammo})
		var actual := model.sample(0.7, 0.2)
		for field: String in case.expected:
			var expected: Variant = case.expected[field]
			var value: Variant = actual.get(field, false)
			var ok: bool = absf(float(value)-float(expected)) < 0.00001 if expected is float else value == expected
			if not ok:
				push_error("%s: %s expected %s, got %s" % [case.name,field,str(expected),str(value)])
				quit(1)
				return
		count += 1
		model.queued()
	for case: Dictionary in vectors.lookCases:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = case.ads
		model.record(event, true)
		var actual := model.look(case.yaw, case.pitch, Vector2(case.x, case.y))
		if not actual.is_equal_approx(Vector2(case.expected[0], case.expected[1])):
			push_error("Source default ADS look gain differs")
			quit(1)
			return
	# Shared combat composition gates its effect stack on `controls.focused`
	# (godot/world/combat_feedback.gd `_allowed`); a focus transition must also
	# drop held controls rather than resuming them silently.
	var focus_model := Controls.new()
	if not focus_model.focused:
		push_error("Horde controls must start focused")
		quit(1)
		return
	focus_model.keys[KEY_W] = true
	focus_model.mouse[MOUSE_BUTTON_LEFT] = true
	focus_model.focus(false)
	if focus_model.focused or not focus_model.keys.is_empty() or not focus_model.mouse.is_empty():
		push_error("Focus transition must clear held controls")
		quit(1)
		return
	focus_model.focus(true)
	if not focus_model.focused:
		push_error("Focus transition did not restore focus")
		quit(1)
		return
	print("HORDE_FOCUS_OK samples=1 focused=", focus_model.focused)
	print("HORDE_SOURCE_INPUT_OK samples=", count)
	print("HORDE_SOURCE_LOOK_OK samples=", vectors.lookCases.size())
	quit()
