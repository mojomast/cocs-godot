extends CanvasLayer
## Device-local preferences. The supervisor still owns the authority process;
## leaving this Godot child returns control to its existing menu loop.
const VERSION := 1
const MAX_BYTES := 4096
const MENU_SCENE := "res://ui/main_menu.tscn"
const DEFAULTS := {"master_volume": 100, "mute": false, "window_mode": "windowed", "mouse_sensitivity": 100, "ui_scale": 100}
var path := "user://local_settings.json"
var values: Dictionary = DEFAULTS.duplicate()
var panel: Control
var return_focus: Control
var rows: Dictionary = {}
var status: Label
var hint: Label
var career_button: Button
var startup_display_override := false

static func explicit_display_flag(args: PackedStringArray, user_args: PackedStringArray = PackedStringArray()) -> bool:
	# Godot includes args after `--` in both lists. Only engine-side flags
	# override stored preferences; a route's user argument is not a display flag.
	var engine_count := args.size()
	if user_args.size() <= args.size() and args.slice(args.size() - user_args.size()) == user_args:
		engine_count -= user_args.size()
	for i in engine_count:
		if args[i] in ["--fullscreen", "-f", "--windowed", "-w"]: return true
	return false

func _ready() -> void:
	# CLI/headless contracts and captures remain deterministic and do not touch
	# a real user's preferences. Tests can explicitly load_at an injected path.
	if DisplayServer.get_name() != "headless":
		startup_display_override = explicit_display_flag(OS.get_cmdline_args(), OS.get_cmdline_user_args())
		var configured := OS.get_environment("COCS_SETTINGS_PATH")
		if configured.is_absolute_path():
			path = configured
		load_at(path)
	build_panel()
	apply()

static func normalize(raw: Variant) -> Dictionary:
	var result := DEFAULTS.duplicate()
	if not raw is Dictionary: return result
	for key: String in ["master_volume", "mouse_sensitivity", "ui_scale"]:
		var value: Variant = raw.get(key)
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT: continue
		if value is float and not is_finite(value): continue
		var low := 0 if key == "master_volume" else (25 if key == "mouse_sensitivity" else 75)
		var high := 100 if key == "master_volume" else (250 if key == "mouse_sensitivity" else 150)
		result[key] = clampi(roundi(clampf(float(value), low, high)), low, high)
	if raw.get("mute") is bool: result.mute = raw.mute
	if raw.get("window_mode") in ["windowed", "fullscreen"]: result.window_mode = raw.window_mode
	return result

func load_at(file_path: String) -> void:
	path = file_path
	values = DEFAULTS.duplicate()
	if not FileAccess.file_exists(path):
		apply()
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return
	if file.get_length() > MAX_BYTES:
		file.close()
		apply()
		return
	var parser := JSON.new()
	var parsed := parser.parse(file.get_as_text())
	file.close()
	if parsed == OK and parser.data is Dictionary and typeof(parser.data.get("version")) == TYPE_FLOAT and parser.data.version == VERSION:
		values = normalize(parser.data.get("settings"))
	apply()

func save() -> bool:
	var text := JSON.stringify({"version": VERSION, "settings": normalize(values)})
	if text.to_utf8_buffer().size() > MAX_BYTES: return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) != OK: return false
	var temp := path + ".%d.tmp" % OS.get_process_id()
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if ok: ok = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path)) == OK
	if not ok: DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	return ok

func set_value(key: String, value: Variant, persist: bool = true) -> bool:
	if not DEFAULTS.has(key): return false
	if key == "mute" and not value is bool: return false
	if key == "window_mode" and value not in ["windowed", "fullscreen"]: return false
	if key in ["master_volume", "mouse_sensitivity", "ui_scale"]:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]: return false
		if value is float and not is_finite(value): return false
	var candidate := values.duplicate()
	candidate[key] = value
	var clean := normalize(candidate)
	values = clean
	if key == "window_mode": startup_display_override = false
	apply()
	if persist and not save():
		if status != null: status.text = "Settings could not be saved."
		return false
	return true

func sensitivity() -> float:
	return float(values.mouse_sensitivity) / 100.0

func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_linear(bus, float(values.master_volume) / 100.0)
		AudioServer.set_bus_mute(bus, values.mute)
	if DisplayServer.get_name() != "headless":
		if not startup_display_override:
			var desired := Window.MODE_FULLSCREEN if values.window_mode == "fullscreen" else Window.MODE_WINDOWED
			if get_window().mode != desired: get_window().mode = desired
	# Canvas-items stretch scales *existing* explicit HUD/deck font overrides and
	# Home labels live. Do not also multiply font sizes, which would double-scale.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	# Use the actual window as the layout basis, not the project's fixed 1280x800
	# design resolution; resizing must reflow controls instead of shrinking text.
	get_window().content_scale_size = Vector2i.ZERO
	get_window().content_scale_factor = float(values.ui_scale) / 100.0

func overlay_open() -> bool:
	return panel != null and panel.visible

func build_panel() -> void:
	layer = 100
	panel = Control.new()
	panel.name = "LocalSettingsPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.04, 0.06, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 280
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	var title := Label.new()
	title.text = "SETTINGS"
	column.add_child(title)
	for entry: Dictionary in [
		{"key":"master_volume", "label":"Master volume", "low":0, "high":100},
		{"key":"mouse_sensitivity", "label":"Mouse sensitivity", "low":25, "high":250},
		{"key":"ui_scale", "label":"Interface scale", "low":75, "high":150}]:
		var key: String = entry.key
		var caption := Label.new()
		caption.text = entry.label
		column.add_child(caption)
		var slider := HSlider.new()
		slider.min_value = entry.low
		slider.max_value = entry.high
		slider.step = 5
		slider.custom_minimum_size.y = 32
		var line := HBoxContainer.new()
		line.add_child(slider)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var number := Label.new()
		number.custom_minimum_size.x = 62
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(number)
		column.add_child(line)
		rows[key] = slider
		rows[key + "_value"] = number
		slider.value_changed.connect(func(value: float) -> void:
			set_value(key, roundi(value))
			number.text = "%d%%" % values[key])
	var mute := CheckButton.new()
	mute.text = "Mute all audio"
	column.add_child(mute)
	rows.mute = mute
	mute.toggled.connect(func(on: bool) -> void: set_value("mute", on))
	var mode := CheckButton.new()
	mode.text = "Fullscreen"
	column.add_child(mode)
	rows.window_mode = mode
	mode.toggled.connect(func(on: bool) -> void: set_value("window_mode", "fullscreen" if on else "windowed"))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var back := Button.new()
	back.name = "SettingsBack"
	back.text = "Back to game (Esc)"
	column.add_child(back)
	rows.back = back
	back.pressed.connect(close_panel)
	career_button = Button.new()
	career_button.name = "SettingsCareer"
	career_button.text = "Career / Arsenal"
	career_button.custom_minimum_size.y = 44
	career_button.pressed.connect(open_career)
	column.add_child(career_button)
	var leave := Button.new()
	leave.name = "LeaveMatch"
	leave.text = "Leave match · Return Home"
	column.add_child(leave)
	rows.leave = leave
	leave.pressed.connect(leave_match)
	panel.hide()
	hint = Label.new()
	hint.name = "SettingsHint"
	hint.text = "F12 · Settings / Leave"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override("font_color", Color(0.68, 0.76, 0.82, 0.8))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -210
	hint.offset_top = -27
	hint.offset_right = -12
	hint.offset_bottom = -6
	add_child(hint)
	hint.hide()

func _process(_delta: float) -> void:
	if hint == null: return
	var scene := get_tree().current_scene
	var career := get_tree().root.get_node_or_null("Career")
	hint.visible = DisplayServer.get_name() != "headless" and scene != null and scene.scene_file_path != MENU_SCENE and not overlay_open() and (career == null or not career.active())
	# LATTICE integrates the shortcut into its own control ribbon. Its modal
	# deck/setup surfaces must not acquire another overlapping footer overlay.
	if hint.visible and "tactical_hud" in scene:
		hint.hide()

func open_panel(from_menu: bool = false, previous_focus: Control = null) -> void:
	if panel == null or overlay_open(): return
	return_focus = previous_focus
	release_controls()
	status.text = "The match continues while Settings is open. After Back, use the mode's click/Enter controls to resume input."
	for key: String in ["master_volume", "mouse_sensitivity", "ui_scale"]: rows[key].set_value_no_signal(values[key])
	for key: String in ["master_volume", "mouse_sensitivity", "ui_scale"]: rows[key + "_value"].text = "%d%%" % values[key]
	rows.mute.set_pressed_no_signal(values.mute)
	rows.window_mode.set_pressed_no_signal(values.window_mode == "fullscreen")
	rows.leave.visible = not from_menu
	rows.back.text = "Back to Home (Esc)" if from_menu else "Back to game (Esc)"
	panel.show()
	rows.back.grab_focus()

func release_controls() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path != MENU_SCENE:
		if scene.has_method("world_neutral"): scene.world_neutral()
		elif scene.has_method("release_pointer"): scene.release_pointer()
		elif scene.has_method("release"): scene.release()
		if "local_motion" in scene and scene.local_motion != null: scene.local_motion.reset()
		if "controls" in scene and scene.controls != null:
			if scene.controls.has_method("release"): scene.controls.release()
			elif scene.controls.has_method("clear"): scene.controls.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func open_career() -> void:
	if not overlay_open(): return
	var from_menu: bool = not bool(rows.leave.visible)
	var original_focus := return_focus
	close_panel()
	var career := get_tree().root.get_node_or_null("Career")
	if career != null: career.open_panel(original_focus, true, from_menu)

func close_panel() -> void:
	if not overlay_open(): return
	panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(return_focus): return_focus.grab_focus()
	return_focus = null

func leave_match() -> void:
	if not overlay_open() or not rows.leave.visible: return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_deferred("quit", 0)

func _input(event: InputEvent) -> void:
	if DisplayServer.get_name() == "headless" or panel == null: return
	if overlay_open():
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode in [KEY_ESCAPE, KEY_F12] or event.physical_keycode in [KEY_ESCAPE, KEY_F12]):
			close_panel()
			get_viewport().set_input_as_handled()
		# Other events must reach GUI to operate sliders and buttons. Gameplay
		# adapters gate their _input on overlay_open; the full-screen Control
		# intercepts _unhandled_input and pointer capture.
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_F12 or event.physical_keycode == KEY_F12):
		var career := get_tree().root.get_node_or_null("Career")
		if career != null and career.active(): return
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path != MENU_SCENE:
			open_panel()
			get_viewport().set_input_as_handled()
