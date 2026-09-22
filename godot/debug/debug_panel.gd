extends CanvasLayer
## Port-owned debug panel. OFF by default: it only exists when the operator
## asked for it (COCS_DEBUG=1 in the environment or --debug-panel on the command
## line) AND the route is a local single-human authority. session.gd creates it,
## so every local route gets the same panel without per-scene edits.
##
## Honesty rules baked in here:
##   * knobs marked LIVE are applied by the authority to the running source
##     match; knobs marked RESTART are queued for the next round.
##   * the port-only reconciliation (god mode, incoming scale, unlock-all) is
##     labelled debug-only in the UI; nothing here ever targets a bot seat.
##   * it sends nothing until the local authority echoed its debug channel, and
##     it refuses to exist in the multi-human lobby/guest routes at all.
const DAMAGE_PRESETS: Array[float] = [0.5, 1.0, 1.5, 2.0]
const INCOMING_PRESETS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0]
const DIFFICULTY_IDS: Array[String] = ["easy", "normal", "hard", "nightmare"]
const MUTATOR_TOGGLES: Array[Dictionary] = [
	{"key":"speedBoost", "label":"Speed 1.25x", "patch":{"speed":1.25}, "off":{"speed":1.0}},
	{"key":"lowGravity", "label":"Gravity 0.4x", "patch":{"gravity":0.4}, "off":{"gravity":1.0}},
	{"key":"oneShot", "label":"One shot", "patch":{"oneShot":true}, "off":{"oneShot":false}},
	{"key":"instagib", "label":"Instagib", "patch":{"instagib":true}, "off":{"instagib":false}},
	{"key":"noRecoil", "label":"No recoil", "patch":{"noRecoil":true}, "off":{"noRecoil":false}},
	{"key":"bigHead", "label":"Big head", "patch":{"bigHead":true}, "off":{"bigHead":false}},
	{"key":"berserk", "label":"Berserk", "patch":{"berserk":true}, "off":{"berserk":false}},
	{"key":"bounty", "label":"Bounty", "patch":{"bounty":true}, "off":{"bounty":false}},
	{"key":"lifeSteal", "label":"Life steal", "patch":{"lifeSteal":true}, "off":{"lifeSteal":false}},
	{"key":"suddenDeath", "label":"Sudden death", "patch":{"suddenDeath":true}, "off":{"suddenDeath":false}},
	{"key":"fastPowers", "label":"Fast powers", "patch":{"fastPowers":true}, "off":{"fastPowers":false}},
	{"key":"mirrorLoadout", "label":"Mirror loadout", "patch":{"mirrorLoadout":true}, "off":{"mirrorLoadout":false}},
	{"key":"randomLoadout", "label":"Random loadout", "patch":{"randomLoadout":true}, "off":{"randomLoadout":false}},
]

var session: Node = null
var enabled := false
var authority_ready := false
var badge: Label
var panel: PanelContainer
var status: Label
var god_toggle: CheckButton
var damage_option: OptionButton
var incoming_option: OptionButton
var unlock_toggle: CheckButton
var difficulty_option: OptionButton
var bot_spin: SpinBox
var respawn_spin: SpinBox
var restart_button: Button
var mutator_buttons: Dictionary = {}
var applied: Dictionary = {}
var restart_note := ""
var capture_path := ""
var capture_delay := 1.2
var capture_applied := false
var capture_started := false
var round_epoch := 0

func bind_session(owner: Node) -> void:
	session = owner
	enabled = true
	badge.show()
	_refresh_badge()

func acknowledge(echo: Dictionary) -> void:
	if echo.get("enabled") != true or echo.get("version") != 1: return
	authority_ready = true
	applied = echo.get("live", {}).duplicate(true)
	applied["_queued"] = echo.get("queued", {}).duplicate(true)
	applied["_constructed"] = echo.get("constructed", {}).duplicate(true)
	var restart: Dictionary = echo.get("restart", {})
	if is_instance_valid(bot_spin):
		if restart.has("botCount"):
			# Route bounds come from the authority, never from a hard-coded guess.
			bot_spin.min_value = restart.botCount[0]
			bot_spin.max_value = restart.botCount[1]
			bot_spin.editable = true
			restart_button.disabled = false
		else:
			bot_spin.editable = false
			restart_button.disabled = true
			restart_note = "this route advertises no construction-time knobs"
		var constructed: Variant = applied["_constructed"].get("botCount", null)
		if constructed != null:
			bot_spin.set_value_no_signal(float(constructed))
	_refresh_controls()
	_refresh_status()

func observe_config(config: Dictionary) -> void:
	if config.is_empty(): return
	for key: String in ["damage", "difficulty", "speed", "gravity", "respawn", "botCount"]:
		if config.has(key): applied[key] = config[key]
	var mutators: Variant = config.get("mutators", [])
	if mutators is Array:
		applied["_mutators"] = mutators.duplicate()
	_refresh_badge()
	_refresh_status()

func round_started() -> void:
	round_epoch += 1
	# The authority clears god mode at every round boundary; mirror that here
	# instead of pretending the toggle is still authoritative.
	if is_instance_valid(god_toggle): god_toggle.set_pressed_no_signal(false)
	print("DEBUG_PANEL_ROUND ", JSON.stringify({"epoch":round_epoch, "phase":session.get("phase")}))
	var queued: Dictionary = applied.get("_queued", {})
	applied["_constructed"] = queued.duplicate()
	restart_note = ""
	if is_instance_valid(bot_spin) and queued.has("botCount"):
		bot_spin.set_value_no_signal(float(queued.botCount))
	_refresh_status()

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--debug-capture="): capture_path = arg.trim_prefix("--debug-capture=")
		if arg.begins_with("--debug-capture-delay="): capture_delay = maxf(0.2, arg.trim_prefix("--debug-capture-delay=").to_float())
	_build()
	set_process(not capture_path.is_empty())
	if not capture_path.is_empty():
		panel.show()
		status.text = "capture mode: waiting for the live round…"

func _build() -> void:
	badge = Label.new()
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.offset_left = -420
	badge.offset_right = -18
	badge.offset_top = 10
	badge.offset_bottom = 34
	badge.add_theme_color_override("font_color", Color("ffb347"))
	badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .8))
	badge.add_theme_constant_override("shadow_offset_x", 1)
	badge.add_theme_constant_override("shadow_offset_y", 1)
	add_child(badge)
	_refresh_badge()

	panel = PanelContainer.new()
	panel.position = Vector2(18, 84)
	panel.custom_minimum_size = Vector2(430, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.text = "DEBUG · local authority only · never in rooms"
	title.add_theme_color_override("font_color", Color("ffd479"))
	box.add_child(title)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(410, 0)
	box.add_child(status)

	god_toggle = CheckButton.new()
	god_toggle.text = "God mode — LIVE, human seat only (debug reconciliation)"
	god_toggle.toggled.connect(func(on: bool) -> void:
		_send({"godMode":on}, "god %s" % ("ON" if on else "off")))
	box.add_child(god_toggle)

	damage_option = _option_row(box, "Damage × — LIVE (source mutator)", DAMAGE_PRESETS.map(func(value: float) -> String: return str(value)),
		DAMAGE_PRESETS.find(float(applied.get("damage", 1.0))),
		func(index: int) -> void: _send({"damage":DAMAGE_PRESETS[index]}, "damage %s×" % DAMAGE_PRESETS[index]))
	var damage_note := Label.new()
	damage_note.text = "source note: below 1× the locked source only lowers vehicle damage"
	damage_note.add_theme_font_size_override("font_size", 11)
	damage_note.modulate = Color(1, 1, 1, .65)
	box.add_child(damage_note)

	incoming_option = _option_row(box, "Incoming × on me — LIVE, debug-only", INCOMING_PRESETS.map(func(value: float) -> String: return str(value)),
		INCOMING_PRESETS.find(1.0),
		func(index: int) -> void: _send({"playerIncomingScale":INCOMING_PRESETS[index]}, "incoming %s×" % INCOMING_PRESETS[index]))
	var incoming_note := Label.new()
	incoming_note.text = "debug-only port reconciliation; the global source multiplier above stays honest"
	incoming_note.add_theme_font_size_override("font_size", 11)
	incoming_note.modulate = Color(1, 1, 1, .65)
	box.add_child(incoming_note)

	unlock_toggle = CheckButton.new()
	unlock_toggle.text = "Unlock all weapons — LIVE (∞ ammo for all 10, human seat)"
	unlock_toggle.toggled.connect(func(on: bool) -> void:
		_send({"unlockAllWeapons":on}, "unlock all weapons %s" % ("ON" if on else "off")))
	box.add_child(unlock_toggle)

	difficulty_option = _option_row(box, "Bot intelligence — LIVE", DIFFICULTY_IDS,
		DIFFICULTY_IDS.find(str(applied.get("difficulty", "easy"))),
		func(index: int) -> void: _send({"difficulty":DIFFICULTY_IDS[index]}, "difficulty %s" % DIFFICULTY_IDS[index]))
	var pacify_note := Label.new()
	pacify_note.text = "no pacify toggle: the locked source has no reviewed live bot-policy swap\n(botPolicy is a harness-only construction seam, so this panel refuses to fake one)"
	pacify_note.add_theme_font_size_override("font_size", 11)
	pacify_note.modulate = Color(1, 1, 1, .65)
	box.add_child(pacify_note)

	_restart_row(box)

	var mutator_label := Label.new()
	mutator_label.text = "Source mutators — LIVE (spawn-time ones apply on respawn)"
	box.add_child(mutator_label)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for entry: Dictionary in MUTATOR_TOGGLES:
		var toggle := CheckButton.new()
		toggle.text = entry.label + " (live)"
		toggle.toggled.connect(func(on: bool) -> void:
			var patch: Dictionary = (entry.patch if on else entry.off).duplicate()
			_send(patch, "%s %s" % [entry.label, "ON" if on else "off"]))
		grid.add_child(toggle)
		mutator_buttons[entry.key] = toggle
	var respawn_row := HBoxContainer.new()
	var respawn_label := Label.new()
	respawn_label.text = "Respawn seconds — LIVE"
	respawn_row.add_child(respawn_label)
	respawn_spin = SpinBox.new()
	respawn_spin.min_value = 1
	respawn_spin.max_value = 5
	respawn_spin.step = 1
	respawn_spin.value = float(applied.get("respawn", 2))
	respawn_spin.custom_minimum_size = Vector2(90, 0)
	respawn_spin.value_changed.connect(func(value: float) -> void:
		_send({"respawn":value}, "respawn %s s" % value))
	respawn_row.add_child(respawn_spin)
	grid.add_child(respawn_row)

	var actions := HBoxContainer.new()
	var test_button := Button.new()
	test_button.text = "Test hit (40)"
	test_button.tooltip_text = "Debug-only self-damage through the source damage path, to see the multiplier/god mode live."
	test_button.pressed.connect(func() -> void: _send({"testDamage":40}, "test hit 40"))
	actions.add_child(test_button)
	var clear_button := Button.new()
	clear_button.text = "Clear debug"
	clear_button.pressed.connect(func() -> void:
		_send({"clear":true}, "cleared")
		_capture_controls_off())
	actions.add_child(clear_button)
	var close_button := Button.new()
	close_button.text = "Close (F3)"
	close_button.pressed.connect(_toggle_panel)
	actions.add_child(close_button)
	box.add_child(actions)

	var keys := Label.new()
	keys.text = "Keys: F3 panel · F4 god · F5 weapons · F6 difficulty\nEsc releases the mouse so the panel can be clicked."
	keys.add_theme_font_size_override("font_size", 11)
	keys.modulate = Color(1, 1, 1, .7)
	box.add_child(keys)
	panel.hide()
	_refresh_status()

func _option_row(box: VBoxContainer, label_text: String, values: Array, selected: int, on_selected: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(250, 0)
	row.add_child(label)
	var option := OptionButton.new()
	for value: Variant in values: option.add_item(str(value))
	option.selected = maxi(0, selected)
	option.item_selected.connect(on_selected)
	row.add_child(option)
	box.add_child(row)
	return option

func _restart_row(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Bots — RESTART to apply"
	label.custom_minimum_size = Vector2(250, 0)
	row.add_child(label)
	bot_spin = SpinBox.new()
	bot_spin.min_value = 1
	bot_spin.max_value = 7
	bot_spin.step = 1
	bot_spin.value = float(applied.get("botCount", 2))
	bot_spin.custom_minimum_size = Vector2(90, 0)
	bot_spin.value_changed.connect(func(value: float) -> void:
		restart_note = "queued bots=%d — restart to apply" % int(value)
		_send({"botCount":int(value)}, "bots %d queued" % int(value)))
	row.add_child(bot_spin)
	restart_button = Button.new()
	restart_button.text = "Restart to apply"
	restart_button.tooltip_text = "Uses the existing authoritative restart (available at the results screen, or Enter)."
	restart_button.pressed.connect(func() -> void:
		if session != null and session.has_method("debug_restart") and session.debug_restart():
			restart_note = "restart requested — queued knobs apply to the new round"
		else:
			restart_note = "restart is only available at results (finish the round, then press Enter)"
		_refresh_status())
	row.add_child(restart_button)
	box.add_child(row)

func _toggle_panel() -> void:
	panel.visible = not panel.visible
	if panel.visible and session != null and session.has_method("release_pointer"):
		session.release_pointer()
	_refresh_status()

func _capture_controls_off() -> void:
	god_toggle.set_pressed_no_signal(false)
	unlock_toggle.set_pressed_no_signal(false)

func _send(patch: Dictionary, note: String) -> void:
	if not enabled: return
	if not authority_ready:
		status.text = "No debug channel on this authority — nothing was sent."
		return
	if session == null or not session.has_method("debug_send"):
		status.text = "No session binding — nothing was sent."
		return
	var frame := {"type":"debug", "v":1}
	frame.merge(patch, true)
	var result: int = session.debug_send(frame)
	if result != OK:
		status.text = "debug frame not sent (error %d)" % result
		return
	applied["_last"] = note
	_refresh_status()

func _refresh_controls() -> void:
	if is_instance_valid(god_toggle):
		god_toggle.set_pressed_no_signal(bool(applied.get("godMode", false)))
	if is_instance_valid(unlock_toggle):
		unlock_toggle.set_pressed_no_signal(bool(applied.get("unlockAllWeapons", false)))
	if is_instance_valid(damage_option) and applied.has("damage"):
		var index: int = DAMAGE_PRESETS.find(float(applied.damage))
		if index >= 0: damage_option.selected = index
	if is_instance_valid(difficulty_option) and applied.has("difficulty"):
		var difficulty_index: int = DIFFICULTY_IDS.find(str(applied.difficulty))
		if difficulty_index >= 0: difficulty_option.selected = difficulty_index
	if is_instance_valid(respawn_spin) and applied.has("respawn"):
		respawn_spin.set_value_no_signal(float(applied.respawn))
	for entry: Dictionary in MUTATOR_TOGGLES:
		var toggle: CheckButton = mutator_buttons.get(entry.key)
		if toggle == null: continue
		var on := false
		for key: String in entry.patch.keys():
			on = applied.get(key) == entry.patch[key]
		toggle.set_pressed_no_signal(on)

func _refresh_badge() -> void:
	if not is_instance_valid(badge): return
	var mutators: Variant = applied.get("_mutators", [])
	badge.text = "DEBUG" + (" · %d mutators" % mutators.size() if mutators is Array and not mutators.is_empty() else "")

func _refresh_status() -> void:
	if not is_instance_valid(status): return
	if not enabled:
		status.text = "disabled"
		return
	if not authority_ready:
		status.text = "waiting for the local authority's debug echo…\nThis route has no debug channel; knobs are inert."
		return
	var lines: Array[String] = []
	lines.append("authority: damage %s× · difficulty %s · respawn %s s · mutators %s" % [
		applied.get("damage", "?"), applied.get("difficulty", "?"), applied.get("respawn", "?"),
		str(applied.get("_mutators", []))])
	var queued: Dictionary = applied.get("_queued", {})
	var constructed: Dictionary = applied.get("_constructed", {})
	if not queued.is_empty():
		lines.append("queued for next restart: %s" % JSON.stringify(queued))
	if not constructed.is_empty():
		lines.append("this round was constructed with: %s" % JSON.stringify(constructed))
	if not restart_note.is_empty(): lines.append(restart_note)
	if applied.has("_last"): lines.append("last sent: %s" % applied["_last"])
	lines.append("god mode: %s (authority clears it every round)" % ("ON" if god_toggle.button_pressed else "off"))
	status.text = "\n".join(lines)

func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey and event.pressed and not event.echo): return
	match event.physical_keycode:
		KEY_F3:
			_toggle_panel()
			get_viewport().set_input_as_handled()
		KEY_F4:
			god_toggle.button_pressed = not god_toggle.button_pressed
			get_viewport().set_input_as_handled()
		KEY_F5:
			unlock_toggle.button_pressed = not unlock_toggle.button_pressed
			get_viewport().set_input_as_handled()
		KEY_F6:
			var next: int = (difficulty_option.selected + 1) % DIFFICULTY_IDS.size()
			difficulty_option.select(next)
			_send({"difficulty":DIFFICULTY_IDS[next]}, "difficulty %s" % DIFFICULTY_IDS[next])
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if capture_path.is_empty() or capture_applied: return
	if session == null or not authority_ready: return
	# Only after the authoritative round is live: a stimulus sent during the
	# handshake would be cleared by the round boundary (correctly).
	if session.get("phase") != 3: return
	if not capture_started:
		capture_started = true
		# Scripted capture stimulus: drive the panel's own controls so the image
		# shows the live knobs, and let their signals send the debug frames.
		print("DEBUG_PANEL_STIMULUS ", JSON.stringify({"phase":session.get("phase"), "round":round_epoch}))
		god_toggle.button_pressed = true
		damage_option.select(3)
		damage_option.item_selected.emit(3)
		difficulty_option.select(2)
		difficulty_option.item_selected.emit(2)
		return
	# The scripted frame is applied by the authority on its next step; wait a
	# moment so the capture shows the live panel reading back the config.
	capture_applied = true
	await get_tree().create_timer(capture_delay).timeout
	# Re-assert the demonstration right before the shutter so a round boundary
	# that landed during the delay cannot blank the evidence image.
	if not god_toggle.button_pressed: god_toggle.button_pressed = true
	if damage_option.selected != 3:
		damage_option.select(3)
		damage_option.item_selected.emit(3)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var result: int = image.save_png(capture_path)
	print("DEBUG_PANEL_CAPTURE ", JSON.stringify({"path":capture_path, "result":result,
		"size":[image.get_width(), image.get_height()], "god":god_toggle.button_pressed,
		"damage":applied.get("damage", null), "phase":session.get("phase")}))
	get_tree().quit(0 if result == OK else 1)
