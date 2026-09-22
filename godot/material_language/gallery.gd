extends Node3D
## Material-language review viewer. Eight families, each on a floor slab, a wall,
## a rail, a prop and a rounded object, in one orbit scene.
##
## This is a viewer: no session, no gameplay, no collision, no world mutation.
## Every material comes from res://material_language/library.gd, so what the owner
## judges here is exactly what the applying lane binds.
##
## Controls
##   1-8 / A D      focus family / orbit
##   W S or drag    pitch
##   +/-  or wheel  zoom
##   L              cycle lighting preset
##   F              glow on/off (accent LUT emission)
##   N              normal detail on/off (A/B)
##   SPACE          pause the clock (pulse accents freeze)
##   R              reset view and clock
##
## Run: godot --path godot res://material_language/gallery.tscn

const Language = preload("res://material_language/library.gd")
const Props = preload("res://material_language/props.gd")
const SPACING := 6.2
const LIGHTING := ["KEY / AMBIENT", "RIM / LOW", "OVERCAST", "RAKING"]
const PITCH_MIN := -0.02
const PITCH_MAX := 0.72

var stations: Array[Node3D] = []
var camera: Camera3D
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var environment: Environment
var ui: Control
var title: Label
var facts: Label
var status: Label
var controls: Label
var tabs: Array[PanelContainer] = []
var selected := 0
var yaw := 0.0
var pitch := 0.34
var distance := 9.0
var dragging := false
var lighting := 3
var glow := true
var normals := true
var paused := false
var seconds := 0.0
var _hud_elapsed := 1.0

func _ready() -> void:
	_build_environment()
	for family: String in Language.families():
		var built: Dictionary = Props.build(family, self)
		stations.append(built.station)
	_layout_stations()
	_build_hud()
	_apply_lighting()
	select_family(0)
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): call_deferred("_capture", argument.trim_prefix("--capture="))
	if "--smoke" in OS.get_cmdline_user_args(): call_deferred("_smoke")

func _capture(path: String) -> void:
	# One settled frame of the viewer itself, for evidence.
	paused = true
	Language.set_clock(12.0)
	for frame in 14: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	var error := shot.save_png(path)
	print("MATERIAL_LANGUAGE_VIEWER_CAPTURE %s size=%s error=%d" % [path, str(shot.get_size()), error])
	get_tree().quit(0 if error == OK else 1)

func _smoke() -> void:
	for index in range(stations.size()):
		select_family(index)
		for frame in range(2): await get_tree().process_frame
	print("MATERIAL_LANGUAGE_GALLERY_SMOKE_OK families=%d materials=%d" % [stations.size(), Language.cache_stats().materials])
	get_tree().quit(0)

func _layout_stations() -> void:
	var count := stations.size()
	for index in range(count):
		stations[index].position = Vector3((index - (count - 1) * 0.5) * SPACING, 0, 0)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0e1620")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c3d3e0")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	fill = DirectionalLight3D.new()
	fill.shadow_enabled = false
	add_child(fill)
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.08
	camera.far = 300.0
	camera.current = true
	add_child(camera)

func _apply_lighting() -> void:
	match lighting:
		0: _set_lights(Vector3(-42, -34, 0), Color("ecf4ff"), 1.02, Vector3(-18, 148, 0), Color("9db2cc"), 0.34)
		1: _set_lights(Vector3(-14, 166, 0), Color("bcd2ec"), 0.78, Vector3(-38, -20, 0), Color("f0e0c8"), 0.42)
		2: _set_lights(Vector3(-46, -60, 0), Color("d8e4f0"), 0.28, Vector3(-20, 140, 0), Color("c8d8e6"), 0.62)
		_: _set_lights(Vector3(-14, -16, 0), Color("ffd9ac"), 1.18, Vector3(-30, 120, 0), Color("8fb0cc"), 0.24)

func _set_lights(sun_rotation: Vector3, sun_color: Color, sun_energy: float, fill_rotation: Vector3, fill_color: Color, fill_energy: float) -> void:
	sun.rotation_degrees = sun_rotation
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	fill.rotation_degrees = fill_rotation
	fill.light_color = fill_color
	fill.light_energy = fill_energy

func select_family(index: int) -> void:
	selected = clampi(index, 0, stations.size() - 1)
	yaw = 0.42
	pitch = 0.34
	distance = 9.0
	_update_camera()
	_update_hud()

func set_normals(enabled: bool) -> void:
	# The A/B only touches view state: it never edits a family record, and it uses
	# the shader's own has_normal switch so no family tuning is stomped.
	normals = enabled
	_set_view_parameter("has_normal", enabled)

func _set_view_parameter(parameter: String, value: Variant) -> void:
	for station: Node3D in stations:
		var assigned: Dictionary = station.get_meta("assigned")
		for role: String in Props.ROLES:
			var material: Material = assigned.get(role)
			if material is ShaderMaterial: material.set_shader_parameter(parameter, value)
	for family: String in Language.families():
		for variant: String in Language.variants(family):
			var options := {} if variant == "default" else {"variant": variant}
			var material := Language.material(family, options)
			if material is ShaderMaterial: material.set_shader_parameter(parameter, value)

func _update_camera() -> void:
	var target := stations[selected].position + Vector3(0, 1.05, 0)
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target)

func _process(delta: float) -> void:
	if not paused:
		seconds += delta
		Language.set_clock(seconds)
	var direction := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	if direction != 0.0:
		yaw += direction * delta * 0.6
		_update_camera()
	_hud_elapsed += delta
	if _hud_elapsed >= 0.25:
		_hud_elapsed = 0.0
		_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = clampf(distance - 0.6, 3.4, 40.0); _update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = clampf(distance + 0.6, 3.4, 40.0); _update_camera()
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.004, PITCH_MIN, PITCH_MAX)
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
				select_family(int(event.keycode - KEY_1))
			KEY_W, KEY_UP: pitch = clampf(pitch + 0.05, PITCH_MIN, PITCH_MAX); _update_camera()
			KEY_S, KEY_DOWN: pitch = clampf(pitch - 0.05, PITCH_MIN, PITCH_MAX); _update_camera()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: distance = clampf(distance - 0.5, 3.4, 40.0); _update_camera()
			KEY_MINUS, KEY_KP_SUBTRACT: distance = clampf(distance + 0.5, 3.4, 40.0); _update_camera()
			KEY_L:
				lighting = (lighting + 1) % LIGHTING.size()
				_apply_lighting()
				_update_hud()
			KEY_F:
				glow = not glow
				Language.set_glow(glow)
				_update_hud()
			KEY_N:
				set_normals(not normals)
				_update_hud()
			KEY_SPACE:
				paused = not paused
				_update_hud()
			KEY_R:
				seconds = 0.0
				Language.set_clock(0.0)
				glow = true
				Language.set_glow(true)
				set_normals(true)
				lighting = 3
				_apply_lighting()
				select_family(selected)

func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _panel_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	_label(ui, "M O T H   /   M A T E R I A L   L A N G U A G E", 13, Color("93aec2")).position = Vector2(26, 18)
	title = _label(ui, "", 26, Color.WHITE)
	title.position = Vector2(24, 40)
	var notes := PanelContainer.new()
	notes.name = "Notes"
	notes.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.075, 0.12, 0.93), Color("33485d")))
	ui.add_child(notes)
	facts = _label(notes, "", 12, Color("c6d7e6"))
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index in range(8):
		var tab := PanelContainer.new()
		tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(tab)
		tabs.append(tab)
		var label := _label(tab, "%d  %s" % [index + 1, Language.families()[index].to_upper()], 11, Color("a9c3d6"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status = _label(ui, "", 12, Color("9fd6c8"))
	controls = _label(ui, "1-8 FOCUS   A/D OR DRAG ORBIT   W/S PITCH   +/- ZOOM   L LIGHTING   F GLOW   N NORMALS   SPACE PAUSE   R RESET", 11, Color("b6cad9"))

func _layout_hud() -> void:
	if ui == null: return
	var size := get_viewport().get_visible_rect().size
	var notes := ui.get_node("Notes") as Control
	notes.position = Vector2(24, 76)
	notes.size = Vector2(430.0 if size.x >= 1100 else 360.0, 0)
	_fit_notes.call_deferred()
	var width := (size.x - 48.0) / 8.0
	for index in range(8):
		tabs[index].position = Vector2(24 + index * width, size.y - 64)
		tabs[index].size = Vector2(width - 6.0, 34)
	status.position = Vector2(24, size.y - 96)
	controls.position = Vector2(24, size.y - 26)

func _fit_notes() -> void:
	var notes := ui.get_node("Notes") as Control
	notes.size.y = notes.get_combined_minimum_size().y

func _update_hud() -> void:
	if title == null: return
	var family: String = Language.families()[selected]
	var description: Dictionary = Language.describe(family)
	title.text = "%02d / %s" % [selected + 1, String(description.label).to_upper()]
	var variant: String = stations[selected].get_meta("assigned").get("variant", "")
	var swatches := ""
	for color: Color in description.palette: swatches += "  " + color.to_html(false)
	facts.text = "\n".join([
		description.story,
		"",
		"palette " + swatches,
		"base     %s%s" % [", ".join(description.base_textures), ("   variant " + variant) if variant != "" else ""],
		"normal   %s (%s)" % [description.normal.resolved, description.normal.source],
		"accent   %s  phase %.2f  gain %.2f" % [description.emissive.lut, description.emissive.phase, description.emissive.gain],
		"density  %d px per metre · %.2f tiles per metre · triplanar" % [description.density.px_per_metre, description.density.tiles_per_metre],
		"response roughness %.2f (+%.2f derived) · metallic %.2f" % [description.response.roughness, description.response.roughness_variation, description.response.metallic],
		"budget   %d KB across %d planes" % [roundi(float(description.budget.bytes) / 1024.0), description.budget.unique_textures],
		"roles    " + ", ".join(description.roles),
	])
	status.text = "%s · LIGHT %s · GLOW %s · NORMALS %s · %s · %d shared materials / %d   %d draws" % [
		"PAUSED" if paused else "%06.2f s" % seconds, LIGHTING[lighting], "ON" if glow else "OFF",
		"ON" if normals else "OFF", RenderingServer.get_current_rendering_method(),
		Language.cache_stats().materials, Language.cache_stats().limit,
		get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
	]
	for index in range(tabs.size()):
		tabs[index].add_theme_stylebox_override("panel", _panel_style(
			Color("17293a") if index == selected else Color("0f1c2a"),
			Language.describe(Language.families()[index]).palette[0] if index == selected else Color("2c3f52")))
	_fit_notes.call_deferred()
