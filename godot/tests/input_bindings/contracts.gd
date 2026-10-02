extends SceneTree
const Model = preload("res://input_bindings/model.gd")
const Actions = preload("res://world/combat_actions.gd")
const Horde = preload("res://horde/controls.gd")
const Sports = preload("res://sports/controls.gd")
const Combined = preload("res://combined_arms/controls.gd")
const Store = preload("res://input_bindings/service.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func event(code: String, pressed: bool, repeat: bool = false) -> InputEvent:
	var result := Model.virtual_event(code, pressed)
	if result is InputEventKey:
		result.location = KEY_LOCATION_RIGHT if code.ends_with("Right") and not code.begins_with("Arrow") else KEY_LOCATION_LEFT
		result.echo = repeat
	return result

func compare(actual: Dictionary, expected: Dictionary, message: String) -> void:
	for field: String in expected:
		if expected[field] is bool:
			check(bool(actual.get(field, false)) == expected[field], message + ":" + field)
		else:
			check(is_equal_approx(float(actual.get(field, 0)), float(expected[field])), message + ":" + field)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/input_bindings/source-fixtures.json"))
	for action: String in fixtures.defaults: check(Model.DEFAULTS[action] == fixtures.defaults[action], "source default " + action)
	for row: Dictionary in fixtures.normalization:
		var actual := Model.normalize(row.raw)
		for action: String in row.expected: check(actual[action] == row.expected[action], "source canonicalizer " + action)
	for row: Dictionary in fixtures.swaps:
		var actual := Model.rebind(Model.DEFAULTS, row.action, row.code)
		for action: String in row.expected: check(actual[action] == row.expected[action], "source swap " + action)
	for row: Dictionary in fixtures.samples:
		for kind: String in ["world", "horde"]:
			var sampler: Variant = Actions.new() if kind == "world" else Horde.new()
			sampler.bindings.override_bindings = Model.normalize(row.bindings)
			for step: Dictionary in row.timeline:
				if step.has("event"):
					sampler.record(event(step.event.code, step.event.pressed, step.event.repeat), true)
				else:
					var packet: Dictionary = sampler.sample(0, 0, true) if kind == "world" else sampler.sample(0, 0)
					compare(packet, step.expected, kind + " source " + row.action + " " + step.sample)
					sampler.queued()
	# Every offered physical choice must round-trip through a real InputEvent.
	for code: String in Model.editable_options():
		check(Model.physical(event(code, true)) == code, "physical code roundtrip " + code)
	for code: String in ["Escape", "F3", "F12", "KeyT", "KeyC", "Digit1", "MouseMiddle", "ControlLeft+KeyQ", "MouseWheelUp"]:
		check(not Model.valid(code), "reserved/chord rejected " + code)
	var special := InputEventKey.new()
	special.physical_keycode = KEY_F12
	check(preload("res://input_bindings/mapper.gd").new().translate(special, true) == special, "shell event identity preserved")
	for action: String in ["fire", "ads", "melee", "mobility", "forward", "crouch", "jump"]:
		for target: String in ["KeyI", "MouseX1", "ControlRight"]:
			var sampler := Actions.new()
			sampler.bindings.override_bindings = Model.rebind(Model.DEFAULTS, action, target)
			for boundary: String in ["rebind", "settings", "chat", "focus", "stale", "death", "reconnect", "spectator"]:
				sampler.record(event(target, true), true)
				sampler.clear()
				sampler.record(event(target, true), true)
				var value := sampler.sample(0, 0, true)
				check(not value.fire and not value.ads and not value.melee and not value.mobility and not value.crouch and not value.jump and value.z == 0, action + " " + target + " suppressed " + boundary)
				sampler.record(event(target, false), false)
				sampler.record(event(target, true), true)
				value = sampler.sample(0, 0, true)
				check(value.z == -1 if action == "forward" else value[action], "fresh " + action + " " + boundary)
				sampler.record(event(target, false), true)
				sampler.queued()
	# A suppressed keyboard fire cannot turn into a click-to-capture pulse.
	var fire := Actions.new()
	fire.bindings.override_bindings = Model.rebind(Model.DEFAULTS, "fire", "KeyI")
	fire.record(event("KeyI", true), false)
	fire.captured()
	check(not fire.sample(0, 0, true).fire, "no suppressed fire replay on capture")
	# Existing short X pulse is intentionally retained in the native world path.
	var mobility := Actions.new()
	mobility.bindings.override_bindings = Model.rebind(Model.DEFAULTS, "mobility", "MouseX2")
	mobility.record(event("MouseX2", true), true)
	mobility.record(event("MouseX2", false), true)
	check(mobility.sample(0, 0, true).mobility, "remapped short X survives")
	check(mobility.sample(0, 0, true).mobility, "busy queue retains short X")
	mobility.queued()
	check(not mobility.sample(0, 0, true).mobility, "short X consumed exactly once")
	var chord := Actions.new()
	chord.bindings.override_bindings = Model.rebind(Model.DEFAULTS, "crouch", "ControlRight")
	chord.record(event("ControlRight", true), true)
	chord.record(event("Space", true), true)
	check(chord.sample(0, 0, true).crouch and chord.sample(0, 0, true).jump, "Grok crouch+jump composes held actions")
	chord.queued()
	chord.record(event("Space", false), true)
	check(chord.sample(0, 0, true).crouch and not chord.sample(0, 0, true).jump, "jump release preserves held Grok charge input")
	chord.record(event("ControlRight", false), true)
	check(not chord.sample(0, 0, true).crouch, "Grok charge release")
	chord.record(event("KeyZ", true), true)
	chord.record(event("MouseMiddle", true), true)
	chord.record(event("KeyZ", false), true)
	check(chord.sample(0, 0, true).altFire, "independent fixed middle-mouse path remains held")
	chord.record(event("MouseMiddle", false), true)
	check(not chord.sample(0, 0, true).altFire, "both alt-fire paths released")
	var changed := Actions.new()
	changed.record(event("KeyW", true), true)
	changed.clear()
	changed.bindings.override_bindings = Model.rebind(Model.DEFAULTS, "forward", "KeyI")
	changed.record(event("KeyW", false), false)
	changed.record(event("KeyI", true), true)
	check(changed.sample(0, 0, true).z == -1, "keyup after rebind releases the original virtual key")
	changed.record(event("KeyI", false), true)
	check(changed.sample(0, 0, true).z == 0, "new movement binding release")
	var duplicate := Model.normalize({"fire":"MouseX1", "ads":"MouseX1"})
	check(duplicate.fire != duplicate.ads, "duplicate physical mouse mapping repaired")
	var hint_store := root.get_node_or_null("InputBindings")
	var owns_hint_store := hint_store == null
	if owns_hint_store:
		hint_store = Store.new()
		hint_store.name = "InputBindings"
		root.add_child(hint_store)
	var original: Dictionary = hint_store.values.duplicate(true)
	var hint := Label.new()
	root.add_child(hint)
	preload("res://input_bindings/hints.gd").bind(hint, "Q power · X mobility · HOLD CTRL → SPACE")
	hint_store.apply_bindings(Model.rebind(Model.DEFAULTS, "power", "KeyY"))
	check(hint.text.begins_with("Y power"), "binding change signal updates current visible hint")
	hint.text = "RESULTS: another owner now owns this label"
	hint_store.apply_bindings(Model.DEFAULTS)
	check(hint.text.begins_with("RESULTS"), "binding hints do not overwrite result/story labels")
	hint_store.apply_bindings(Model.rebind(Model.DEFAULTS, "crouch", "ControlRight"))
	var fresh := preload("res://arms_race/fresh_input.gd").new()
	fresh.observe(event("ControlRight", true))
	fresh.observe(event("ControlLeft", false))
	check(not fresh.capture_allowed(), "left modifier release cannot clear held right modifier")
	fresh.observe(event("ControlRight", false))
	check(fresh.capture_allowed(), "right modifier release permits capture")
	var panel := preload("res://input_bindings/settings_panel.gd").new()
	root.add_child(panel)
	check(panel.choices.size() == Model.LABELS.size(), "all supported gameplay actions have visible fields")
	for action: String in panel.choices:
		var choice: OptionButton = panel.choices[action]
		check(choice.focus_mode == Control.FOCUS_ALL and not choice.accessibility_name.is_empty() and not choice.accessibility_description.is_empty(), "keyboard and assistive label " + action)
	panel.free()
	hint_store.apply_bindings(original)
	hint.free()
	if owns_hint_store: hint_store.free()
	# Sports and combined arms consume the same mapped defaults exactly once.
	for kind: String in ["sports", "combined"]:
		var sampler = Sports.new() if kind == "sports" else Combined.new()
		sampler.bindings.override_bindings = Model.rebind(Model.DEFAULTS, "forward", "MouseX1")
		var enter := InputEventKey.new()
		enter.physical_keycode = KEY_ENTER
		enter.pressed = true
		sampler.accept(enter, true)
		enter.pressed = false
		sampler.accept(enter, true)
		enter.pressed = true
		sampler.accept(event("KeyW", true), true)
		check(sampler.packet(0, true).z == 0, kind + " old forward inert")
		sampler.accept(event("MouseX1", true), true)
		check(sampler.packet(0, true).z == -1, kind + " new forward mapped")
		sampler.release()
		sampler.accept(enter, true)
		sampler.accept(event("MouseX1", true), true)
		check(sampler.packet(0, true).z == 0, kind + " held input blocked after Enter")
		sampler.accept(event("MouseX1", false), false)
		sampler.accept(event("MouseX1", true), true)
		check(sampler.packet(0, true).z == -1, kind + " fresh resume")
	# Save/load/migration keep unknown fields and never change local_settings units.
	var store := Store.new()
	store.path = "user://input-bindings-contract-%d.json" % OS.get_process_id()
	store.extras = {"future_envelope":{"keep":true}}
	store.values["future_action"] = {"keep":true}
	check(store.set_binding("melee", "MouseX1"), "atomic persistence")
	var loaded := Store.new()
	loaded.load_at(store.path)
	check(loaded.values.melee == "MouseX1" and loaded.values.future_action.keep and loaded.extras.future_envelope.keep, "persist unknown fields")
	check(loaded.reset_defaults() and loaded.values.melee == "KeyF" and loaded.values.future_action.keep, "reset retains extension fields")
	var legacy := FileAccess.open(store.path, FileAccess.WRITE)
	legacy.store_string('{"future_envelope":42,"bindings":{"forward":"ArrowUp"}}')
	legacy.close()
	loaded.load_at(store.path)
	check(loaded.values.forward == "ArrowUp" and loaded.values.fire == "MouseLeft" and loaded.extras.future_envelope == 42, "partial versionless preference migration defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
	loaded.load_at(store.path)
	check(loaded.values == Model.DEFAULTS, "missing preference file restores defaults")
	store.free()
	loaded.free()
	print("INPUT_BINDINGS_CONTRACT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures == 0 else 1)
