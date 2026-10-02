extends CanvasLayer
## Presentation-only camera owner. There is deliberately no network send path.
const Model = preload("res://experience/spectator_model.gd")
const Motion = preload("res://ui/mouse_motion.gd")
const FreeMotion = preload("res://experience/free_camera_math.gd")
var model := Model.new()
var information: Node
var camera: Camera3D
var panel := ScrollContainer.new()
var heading := Label.new()
var captured := false
var held: Dictionary = {}
var active := false
var velocity := Vector3.ZERO
var help := Label.new()
var buttons := HFlowContainer.new()

func _ready() -> void:
	layer = 7
	process_priority = 100
	add_child(panel)
	panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.focus_mode = Control.FOCUS_ALL
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.04, 0.065, 0.94)
	panel.add_theme_stylebox_override("panel", background)
	preload("res://experience/scroll_keys.gd").bind(panel)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(rows)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(heading)
	rows.add_child(buttons)
	for spec: Array in [["Previous [", -1], ["Next ]", 1], ["Follow / Free V", 0]]:
		var button := Button.new()
		button.text = spec[0]
		var step: int = spec[1]
		button.pressed.connect(func(): action(step))
		buttons.add_child(button)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = "[ / ] or buttons: target · V: camera mode\nFree: Enter/click world captures mouse · Esc releases\nWASD move · Space/Ctrl up/down · Shift boost"
	rows.add_child(help)
	panel.hide()

func release() -> void:
	held.clear()
	velocity = Vector3.ZERO
	if captured: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	captured = false

func clear() -> void:
	release()
	model.clear()
	active = false
	heading.text = ""
	panel.hide()
	camera = null

func available() -> bool:
	return is_instance_valid(information) and information.spectator() and information.ready_for_events and information.live() and information.current_role() == information.role_key and not information.stale() and not information.blocked()

func snapshot(state: Dictionary) -> void:
	if not available():
		clear()
		return
	model.snapshot(state)

func action(step: int) -> void:
	if not available(): return
	release()
	if step == 0: model.mode = "free" if model.mode == "follow" else "follow"
	else: model.cycle(step)

func _unhandled_input(event: InputEvent) -> void:
	if not available(): return
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		if not event.pressed:
			held.erase(key)
			return
		if event.echo: return
		if key == KEY_BRACKETLEFT: action(-1)
		elif key == KEY_BRACKETRIGHT: action(1)
		elif key == KEY_V: action(0)
		elif key == KEY_ESCAPE: release()
		elif key == KEY_ENTER and model.mode == "free": capture()
		elif captured and key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_CTRL, KEY_SHIFT]: held[key] = true
		else: return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and model.mode == "free":
		capture()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and captured and is_instance_valid(camera):
		var motion := Motion.raw_delta(event)
		camera.rotation.y -= motion.x * 0.002
		camera.rotation.x = clampf(camera.rotation.x - motion.y * 0.002, -1.5, 1.5)
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# GUI focus may consume key-up before _unhandled_input.
	if event is InputEventKey and not event.pressed:
		held.erase(event.physical_keycode if event.physical_keycode else event.keycode)

func capture() -> void:
	release()
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null: focused.release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	captured = true

func _process(delta: float) -> void:
	var view := get_viewport().get_visible_rect().size
	panel.position = Vector2(16, view.y * 0.65)
	panel.size = Vector2(minf(520, view.x - 32), view.y * 0.35 - 16)
	if not available():
		clear()
		if is_instance_valid(information) and is_instance_valid(information.session) and information.spectator() and not information.blocked():
			heading.text = "SPECTATOR · READ ONLY\nCamera paused · Waiting for fresh live snapshot / host restart"
			buttons.hide()
			help.hide()
			panel.show()
		return
	var session: Node = information.session
	camera = session.get("camera") if "camera" in session else (session.world.camera if "world" in session else null)
	if not is_instance_valid(camera): return
	active = true
	if captured and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: release()
	panel.show()
	buttons.show()
	help.show()
	heading.text = model.heading() + (" · MOUSE CAPTURED" if captured else " · CURSOR FREE")
	if model.mode == "follow":
		var actor := model.target()
		if actor.has("x") and actor.has("y") and actor.has("z"):
			camera.position = Vector3(actor.x, actor.y + (float(actor.get("eyeHeight", 1.45)) if float(actor.get("health", 0)) > 0 else 0.65), actor.z)
			camera.rotation = Vector3(float(actor.get("pitch", 0)), float(actor.get("yaw", 0)), 0)
	elif captured:
		var move := Vector3(float(held.has(KEY_W)) - float(held.has(KEY_S)), float(held.has(KEY_D)) - float(held.has(KEY_A)), float(held.has(KEY_SPACE)) - float(held.has(KEY_CTRL)))
		var pose := FreeMotion.integrate(camera.position, velocity, camera.rotation.y, camera.rotation.x, move, held.has(KEY_SHIFT), delta)
		camera.position = pose.position
		velocity = pose.velocity

func _exit_tree() -> void: release()
