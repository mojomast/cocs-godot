extends CanvasLayer
## In-game, authority-confirmed single-player cheats. No launch flag required.
const Settings = preload("res://ui/settings_access.gd")
var session: Node
var state: Dictionary = {}
var launcher := Button.new()
var overlay := Control.new()
var panel := PanelContainer.new()
var status := Label.new()
var hint := Label.new()
var toggles: Dictionary = {}
var actions: Array[Button] = []
var resume := Button.new()
var pending := false
var pending_age := 0.0
var requested_revision := -1
var want_open := false

func bind_session(owner: Node) -> void:
	session = owner
	session.client.snapshot.connect(observe)
	session.client.results.connect(observe)
	session.client.started.connect(func(_frame: Dictionary) -> void:
		state.clear()
		pending = false
		want_open = false
		overlay.hide()
		refresh())
	session.client.connection_error.connect(func(_message: String) -> void:
		state.clear()
		pending = false
		want_open = false
		overlay.hide()
		refresh())
	refresh()

func _ready() -> void:
	layer = 24
	launcher.text = "Cheats · F3"
	launcher.tooltip_text = "Open single-player cheats and pause the action"
	launcher.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	launcher.offset_left = -150
	launcher.offset_right = -18
	launcher.offset_top = 48
	launcher.offset_bottom = 82
	launcher.pressed.connect(toggle_menu)
	add_child(launcher)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -360
	hint.offset_right = -18
	hint.offset_top = 86
	hint.offset_bottom = 140
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override("font_color", Color("ffd479"))
	add_child(hint)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.03, 0.87)
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142b35")
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)
	var title := Label.new()
	title.text = "Single-player cheats"
	title.add_theme_font_size_override("font_size", 24)
	stack.add_child(title)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(status)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	stack.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for entry: Array in [["invulnerable", "Invulnerability"], ["unlimitedAmmo", "Unlimited ammo"], ["flight", "Fly / noclip"]]:
		var button := CheckButton.new()
		button.text = str(entry[1])
		var key := str(entry[0])
		button.toggled.connect(func(value: bool) -> void: send_command(key, value))
		list.add_child(button)
		toggles[key] = button
	var flight_note := Label.new()
	flight_note.text = "Flight: WASD move · Space rise · Ctrl descend\nShift flies faster. Switch off to land on solid ground."
	flight_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(flight_note)
	for entry: Array in [["weapons", "Give all 10 weapons + ammo"], ["heal", "Restore health and armor"], ["clear", "Switch off all cheats"]]:
		var button := Button.new()
		button.text = str(entry[1])
		button.custom_minimum_size.y = 36
		var key := str(entry[0])
		button.pressed.connect(func() -> void: send_command(key))
		list.add_child(button)
		actions.append(button)
	resume.text = "Resume game · F3 / Esc"
	resume.custom_minimum_size.y = 40
	resume.pressed.connect(toggle_menu)
	stack.add_child(resume)
	get_viewport().size_changed.connect(resize)
	resize()
	overlay.hide()

func resize() -> void:
	var viewport := get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(460, viewport.x - 24), minf(510, viewport.y - 24))
	panel.position = (viewport - panel.size) * 0.5

func available() -> bool:
	return is_instance_valid(session) and session.phase == 3 and state.get("available") == true

func toggle_menu() -> void:
	if pending or not available() or Settings.overlay_open(): return
	want_open = not want_open
	if want_open:
		session.release_pointer()
		overlay.show()
		resume.grab_focus()
	send_command("pause", want_open)

func send_command(action: String, value: Variant = null) -> void:
	if pending or not available():
		refresh()
		return
	var frame := {"type":"solo-cheat", "v":1, "action":action, "inputEpoch":session.client.input_epoch}
	if value is bool: frame["enabled"] = value
	if session.client.send_frame(frame) != OK:
		status.text = "Command could not be sent. Reconnect to continue."
		return
	pending = true
	pending_age = 0.0
	requested_revision = int(state.get("revision", 0))
	refresh()

func observe(frame: Dictionary) -> void:
	var next: Variant = frame.get("state", {}).get("soloCheats")
	if not next is Dictionary: return
	state = next.duplicate(true)
	if pending and int(state.get("revision", 0)) > requested_revision:
		pending = false
		if not want_open and state.get("paused") == false:
			overlay.hide()
			if available() and session.application_focused and not Settings.overlay_open():
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				session.combat_actions.captured()
	refresh()

func refresh() -> void:
	launcher.disabled = not available()
	for key: String in toggles:
		toggles[key].set_pressed_no_signal(state.get(key, false) == true)
		toggles[key].disabled = pending or not available()
	for button: Button in actions: button.disabled = pending or not available()
	resume.disabled = pending or not available()
	status.text = "Applying…" if pending else ("Paused · " + str(state.get("notice", ""))).strip_edges()
	var labels: Array[String] = []
	if state.get("invulnerable", false): labels.append("INVULNERABLE")
	if state.get("unlimitedAmmo", false): labels.append("UNLIMITED AMMO")
	if state.get("flight", false): labels.append("FLY: Space ↑ / Ctrl ↓")
	hint.text = " · ".join(labels)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3 or (event.keycode == KEY_ESCAPE and overlay.visible):
			if available() and not Settings.overlay_open():
				toggle_menu()
				get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if pending:
		pending_age += delta
		if pending_age > 4.0:
			pending = false
			want_open = state.get("paused", false) == true
			refresh()
			status.text = "No confirmation yet. Check the connection and try again."
	if is_instance_valid(session) and session.phase != 3 and overlay.visible:
		overlay.hide()
		want_open = false
		pending = false
