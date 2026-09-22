extends Control
## Standalone native scene. Input never reads/writes the game's input/session API.
const Field = preload("res://particle_lab/field.gd")
const Metrics = preload("res://particle_lab/frame_metrics.gd")
const TITLES := ["STORM VORTEX", "SPIRAL GALAXY", "ION BURST", "PLASMA FOUNTAIN"]
const DESCRIPTIONS := ["Differential rotation / rising filaments", "Five arms / warm core / inclined halo", "Four expanding shells / spring advection", "Ballistic crown / twisted plasma nozzle"]
const SCALES := [1.0, 0.75, 0.5]
const CYAN := Color("73e3ef")
const MUTED := Color("91a7bf")

var field: Field
var viewport: SubViewport
var camera: Camera3D
var metrics := Metrics.new()
var hud: Control
var count_label: Label
var telemetry: Label
var backend_label: Label
var status_label: Label
var renderer_label: Label
var description: Label
var scale_button: Button
var pause_button: Button
var backend_button: Button
var camera_button: Button
var appearance_label: Label
var energy_button: Button
var _count_buttons: Array[Button] = []
var _preset_buttons: Array[Button] = []
var _count_index := 1
var _preset_index := 0
var _scale_index := 0
var _stats_timer := 0.0
var _yaw := 0.55
var _pitch := 0.38
var _distance := 108.0
var _freefly := false
var _orbit := true
var _dragging := false
var _smoke := false
var _cli_error := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	DisplayServer.window_set_title("COCS · Native Particle Observatory")
	_build_world()
	_build_ui()
	get_viewport().size_changed.connect(_resize)
	_resize()
	var requested := 32768
	var selected_preset := "vortex"
	var selected_backend := "gpu"
	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke": _smoke = true
		elif arg.begins_with("--particles="):
			var value := arg.get_slice("=", 1)
			if value.is_valid_int(): requested = int(value)
			else: _cli_error = "Malformed --particles value"
		elif arg.begins_with("--preset="): selected_preset = arg.get_slice("=", 1)
		elif arg.begins_with("--particle-backend="): selected_backend = arg.get_slice("=", 1)
		elif arg == "--render-scale=0.5": _scale_index = 2
		elif arg == "--render-scale=0.75": _scale_index = 1
	var result: Dictionary = field.configure(requested, selected_preset, selected_backend)
	if not result.ok:
		_cli_error = result.error
		field.configure(32768, "vortex", "gpu")
	_preset_index = Field.PRESETS.find(field.preset)
	_count_index = Field.COUNTS.find(field.count)
	RenderingServer.frame_post_draw.connect(_on_render_frame)
	_place_orbit()
	_resize()
	_refresh_ui()
	if not _cli_error.is_empty(): status_label.text = _cli_error + " · using safe default"
	if _smoke: _run_smoke.call_deferred()

func _build_world() -> void:
	viewport = SubViewport.new()
	viewport.name = "ParticleRenderTarget"
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(viewport)
	var output := TextureRect.new()
	output.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	output.stretch_mode = TextureRect.STRETCH_SCALE
	output.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	output.texture = viewport.get_texture()
	output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(output)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("030813")
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment.glow_enabled = false
	world.add_child(environment)
	var stage := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	var material := ShaderMaterial.new()
	material.shader = preload("res://particle_lab/stage.gdshader")
	plane.material = material
	stage.mesh = plane
	stage.position.y = -24.0
	stage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(stage)
	field = Field.new()
	field.name = "ReusableParticleField"
	world.add_child(field)
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.1
	camera.far = 800.0
	world.add_child(camera)
	camera.current = true

func _panel(parent: Node, rect: Rect2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.019, 0.038, 0.069, 0.94)
	style.border_color = Color(0.18, 0.32, 0.43, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(text: String, font_size: int = 14, color: Color = MUTED) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("line_spacing", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 32
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color("c5d7e9"))
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("17303e") if state != "normal" else Color("101d2e")
		style.border_color = Color("457a86") if state != "normal" else Color("294255")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.content_margin_left = 11
		style.content_margin_right = 11
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	return button

func _build_ui() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	var eyebrow := _label("COCS  /  NATIVE RENDER LAB     ·     EXPERIMENT 01", 12, CYAN)
	eyebrow.position = Vector2(22, 15)
	hud.add_child(eyebrow)
	var title := _label("Particle Observatory", 30, Color("edf5ff"))
	title.position = Vector2(20, 33)
	hud.add_child(title)
	renderer_label = _label("", 12)
	renderer_label.position = Vector2(-335, 18)
	renderer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	renderer_label.size.x = 312
	renderer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(renderer_label)
	var presets := HBoxContainer.new()
	presets.position = Vector2(22, 83)
	presets.add_theme_constant_override("separation", 8)
	hud.add_child(presets)
	for i in TITLES.size():
		var button := _button("%d  %s" % [i + 1, TITLES[i]], select_preset.bind(i))
		presets.add_child(button)
		_preset_buttons.append(button)
	description = _label("", 13, CYAN)
	description.position = Vector2(24, 123)
	hud.add_child(description)
	var card := _panel(hud, Rect2(22, 160, 236, 286))
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 4)
	card.add_child(stats)
	stats.add_child(_label("LIVE PARTICLE SLOTS", 11, CYAN))
	count_label = _label("32,768", 32, Color.WHITE)
	stats.add_child(count_label)
	backend_label = _label("", 12)
	stats.add_child(backend_label)
	stats.add_child(HSeparator.new())
	telemetry = _label("", 13, Color("c5d7e9"))
	stats.add_child(telemetry)
	var note := _label("Slots ≠ on-screen pixel count\nNo adaptive count / no hidden LOD", 11)
	stats.add_child(note)
	var settings := _panel(hud, Rect2(-226, 160, 204, 262))
	settings.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 7)
	settings.add_child(controls)
	controls.add_child(_label("FIELD CONTROLS", 11, CYAN))
	backend_button = _button("B  GPU simulation", toggle_backend)
	controls.add_child(backend_button)
	scale_button = _button("V  Render 100%", cycle_scale)
	controls.add_child(scale_button)
	pause_button = _button("Space  Pause", toggle_pause)
	controls.add_child(pause_button)
	controls.add_child(_button("R  Reset field", reset_field))
	camera_button = _button("F  Freeflight", toggle_camera)
	controls.add_child(camera_button)
	energy_button = _button("L  Low-energy view", toggle_energy)
	controls.add_child(energy_button)
	appearance_label = _label("", 11)
	controls.add_child(appearance_label)
	var footer := _panel(hud, Rect2(22, -144, 800, 122))
	footer.name = "Footer"
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 22
	footer.offset_right = -22
	footer.offset_top = -144
	footer.offset_bottom = -20
	var footer_rows := VBoxContainer.new()
	footer_rows.add_theme_constant_override("separation", 7)
	footer.add_child(footer_rows)
	var budget_row := HBoxContainer.new()
	budget_row.add_theme_constant_override("separation", 8)
	footer_rows.add_child(budget_row)
	budget_row.add_child(_label("PARTICLE BUDGET   − / +", 12, CYAN))
	for i in Field.COUNTS.size():
		var short_name: String = ["8K", "32K", "128K", "512K", "1M"][i]
		var button := _button(short_name, select_count.bind(i))
		button.custom_minimum_size.x = 63
		budget_row.add_child(button)
		_count_buttons.append(button)
	status_label = _label("", 12, Color("d2e4f2"))
	footer_rows.add_child(status_label)
	footer_rows.add_child(_label("Drag / wheel: orbit + zoom   O: auto orbit   F: flight · WASD/QE/Shift · RMB: look   Esc: release", 12))
	footer_rows.add_child(_label("1–4: presets   B: backend   V: resolution   Space: pause   R: reset   [ ]: size   , . / L: energy   H: HUD", 12))

func _resize() -> void:
	if not viewport: return
	var window_size := get_viewport_rect().size
	viewport.size = Vector2i(maxi(1, int(window_size.x * SCALES[_scale_index])), maxi(1, int(window_size.y * SCALES[_scale_index])))
	if scale_button:
		scale_button.text = "V  Render %d%%" % int(SCALES[_scale_index] * 100.0)
	metrics.reset()

func _process(delta: float) -> void:
	if _freefly and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var direction := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W): direction -= camera.transform.basis.z
		if Input.is_physical_key_pressed(KEY_S): direction += camera.transform.basis.z
		if Input.is_physical_key_pressed(KEY_A): direction -= camera.transform.basis.x
		if Input.is_physical_key_pressed(KEY_D): direction += camera.transform.basis.x
		if Input.is_physical_key_pressed(KEY_Q): direction.y -= 1.0
		if Input.is_physical_key_pressed(KEY_E): direction.y += 1.0
		camera.position += direction.normalized() * delta * (55.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 22.0)
	elif not _freefly and _orbit and not _dragging:
		_yaw += delta * 0.06
		_place_orbit()
	_stats_timer += delta
	if _stats_timer >= 0.25:
		_stats_timer = 0.0
		_refresh_ui()

func _input(event: InputEvent) -> void:
	# Handle release before GUI dispatch. Never wait for a popup or synchronous
	# benchmark. At slow GPU rates input is limited by the next native frame.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_dragging = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed:
		_dragging = false
		if event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4: select_preset(event.keycode - KEY_1)
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: select_count(mini(_count_index + 1, Field.COUNTS.size() - 1))
			KEY_MINUS, KEY_KP_SUBTRACT: select_count(maxi(_count_index - 1, 0))
			KEY_SPACE: toggle_pause()
			KEY_R: reset_field()
			KEY_B: toggle_backend()
			KEY_V: cycle_scale()
			KEY_F: toggle_camera()
			KEY_O: _orbit = not _orbit
			KEY_H: hud.visible = not hud.visible
			KEY_L: toggle_energy()
			KEY_BRACKETLEFT: field.set_appearance(field.particle_size / 1.2, field.intensity)
			KEY_BRACKETRIGHT: field.set_appearance(field.particle_size * 1.2, field.intensity)
			KEY_COMMA: field.set_appearance(field.particle_size, field.intensity / 1.2)
			KEY_PERIOD: field.set_appearance(field.particle_size, field.intensity * 1.2)
		_refresh_ui()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(35.0, _distance * 0.9)
			if not _freefly: _place_orbit()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(240.0, _distance * 1.1)
			if not _freefly: _place_orbit()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if _freefly and event.button_index == MOUSE_BUTTON_RIGHT:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif not _freefly: _dragging = true
	elif event is InputEventMouseMotion:
		if _freefly and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			camera.rotation.y -= event.relative.x * 0.003
			camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.5, 1.5)
		elif _dragging:
			_yaw -= event.relative.x * 0.006
			_pitch = clampf(_pitch + event.relative.y * 0.006, -0.15, 1.3)
			_place_orbit()

func _place_orbit() -> void:
	camera.position = Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	camera.look_at(Vector3.ZERO)

func select_count(index: int) -> void:
	_count_index = clampi(index, 0, Field.COUNTS.size() - 1)
	field.configure(Field.COUNTS[_count_index], field.preset, field.backend)
	metrics.reset()
	_refresh_ui()

func select_preset(index: int) -> void:
	_preset_index = clampi(index, 0, Field.PRESETS.size() - 1)
	field.configure(field.count, Field.PRESETS[_preset_index], field.backend)
	metrics.reset()
	_refresh_ui()

func toggle_backend() -> void:
	field.configure(field.count, field.preset, "analytic" if field.backend == "gpu" else "gpu")
	metrics.reset()
	_refresh_ui()

func toggle_pause() -> void:
	field.set_paused(not field.paused)
	_refresh_ui()

func reset_field() -> void:
	field.reset()
	metrics.reset()
	_refresh_ui()

func cycle_scale() -> void:
	_scale_index = (_scale_index + 1) % SCALES.size()
	_resize()
	_refresh_ui()

func toggle_camera() -> void:
	_freefly = not _freefly
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_dragging = false
	if not _freefly: _place_orbit()
	_refresh_ui()

func toggle_energy() -> void:
	# Explicit display-energy control, independent of count/backend. Never an
	# automatic response to density or frame time. Every particle still draws.
	field.set_appearance(field.particle_size, 0.06 if field.intensity >= 0.3 else 0.85)
	metrics.reset()
	_refresh_ui()

func _on_render_frame() -> void:
	metrics.record_render_frame()

static func format_count(value: int) -> String:
	var source := str(value)
	var result := ""
	for i in source.length():
		if i > 0 and (source.length() - i) % 3 == 0: result += ","
		result += source[i]
	return result

func _refresh_ui() -> void:
	if not field or not field.draw_material: return
	var state: Dictionary = field.snapshot()
	var timing: Dictionary = metrics.snapshot()
	count_label.text = format_count(state.draw_slots)
	if field.backend == "gpu":
		backend_label.text = "GPUParticles3D · stateful GPU\n%s\namount %s · ratio %.2f" % ["OpenGL transform feedback" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else "RenderingDevice simulation", format_count(state.emitter_amount), state.amount_ratio]
	else:
		backend_label.text = "MultiMesh · GPU analytic motion\ninstance_count %s\nvisible_instance_count %s" % [format_count(state.instance_count), format_count(state.visible_instance_count)]
	var buffer_bytes := int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED))
	var buffer_text := "%.1f MiB" % (buffer_bytes / 1048576.0) if buffer_bytes > 0 else "unavailable"
	telemetry.text = "Median   %7.2f ms\np95          %7.2f ms\nCadence  %7.1f fps · n=%d\nBuffer payload  %.1f MiB*\nEngine buffers  %s\nRender target  %d × %d\nSim clock  %.2f s · %s" % [timing.median_ms, timing.p95_ms, timing.fps_from_median, timing.samples, state.buffer_payload_estimate_bytes / 1048576.0, buffer_text, viewport.size.x, viewport.size.y, field.clock, "PAUSED" if field.paused else "RUNNING"]
	backend_button.text = "B  " + ("GPU simulation" if field.backend == "gpu" else "GPU analytic")
	pause_button.text = "Space  " + ("Resume" if field.paused else "Pause")
	camera_button.text = "F  " + ("Return to orbit" if _freefly else "Freeflight")
	energy_button.text = "L  " + ("Low-energy view" if field.intensity >= 0.3 else "Standard energy")
	appearance_label.text = "Quad %.3f m · energy %.2f\n*Payload estimate, excludes copies" % [field.particle_size, field.intensity]
	description.text = DESCRIPTIONS[_preset_index]
	renderer_label.text = "GODOT 4.5.2  /  " + RenderingServer.get_current_rendering_method().to_upper() + "\n" + RenderingServer.get_video_adapter_name().left(49)
	status_label.text = "%s  ·  %s  ·  Explicit %d%% resolution  ·  Draws %d / primitives %s" % ["FLIGHT: hold RMB to move/look" if _freefly else "ORBIT CAMERA", "PAUSED" if field.paused else "LIVE", int(SCALES[_scale_index] * 100), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), format_count(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))]
	for i in _count_buttons.size():
		_count_buttons[i].add_theme_color_override("font_color", CYAN if i == _count_index else MUTED)
	for i in _preset_buttons.size():
		_preset_buttons[i].add_theme_color_override("font_color", CYAN if i == _preset_index else MUTED)

func statistics() -> Dictionary:
	var state: Dictionary = field.snapshot()
	state["timing"] = metrics.snapshot()
	state["renderer"] = RenderingServer.get_current_rendering_method()
	state["adapter"] = RenderingServer.get_video_adapter_name()
	state["adapter_vendor"] = RenderingServer.get_video_adapter_vendor()
	state["window_size"] = [int(get_viewport_rect().size.x), int(get_viewport_rect().size.y)]
	state["render_target"] = [viewport.size.x, viewport.size.y]
	state["resolution_scale"] = SCALES[_scale_index]
	state["engine_frames_drawn"] = Engine.get_frames_drawn()
	state["draw_calls"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	state["primitives"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	state["render_buffer_bytes"] = int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED))
	state["render_video_bytes"] = int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	state["static_memory_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	state["object_count"] = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	state["resource_count"] = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	return state

func _run_smoke() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var ok: bool = _cli_error.is_empty() and field.snapshot().moth_resources_ready
	print("PARTICLE_LAB_SMOKE " + JSON.stringify({"ok": ok, "gpu_performance_test": false, "field": field.snapshot(), "error": _cli_error}))
	get_tree().quit(0 if ok else 1)

func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_on_render_frame):
		RenderingServer.frame_post_draw.disconnect(_on_render_frame)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(field): field.dispose()
