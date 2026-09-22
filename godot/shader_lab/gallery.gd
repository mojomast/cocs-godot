extends Node3D
## Standalone native material studies. No session/gameplay dependencies.
const Factory = preload("res://shader_lab/factory.gd")
const Surfaces = preload("res://moth/surfaces.gd")
const KEYS := ["shield", "conduit", "phase"]
const TITLES := ["INTERFERENCE", "FLUX / REACTOR", "PHASE / MATTER"]
const ACCENTS := [Color("68deee"), Color("ffd08a"), Color("e3a4fc")]
const DESCRIPTIONS := [
	"A light membrane around a solid core.\n\nFresnel rim / moving scan bands\nMoth grid + shield RGB motif\nLinear flow field / R + T LUT\n\nAlpha mixed · depth tested\nNo transparent depth writes",
	"Directed energy on a machined vessel.\n\nEight flowing emissive channels\nMoth brushed metal + full normals\nLinear flow field / R + T LUT\n\nOpaque · depth writes\nEmission without bloom",
	"A static cargo module in transition.\n\nMacro-organic threshold field\nMoth riveted armor + full normals\nHot cut edge / time-driven shimmer\n\nOpaque cutout · depth writes\n[ / ] adjust transition",
]
var factory := Factory.new()
var materials: Array[ShaderMaterial] = []
var exhibits: Array[Node3D] = []
var camera: Camera3D
var stage: Node3D
var ui: Control
var title: Label
var details: Label
var status: Label
var stats: Label
var phase_label: Label
var tabs: Array[PanelContainer] = []
var selected := 0
var seconds := 0.0
var intensity := 1.0
var paused := false
var phase_amount := 0.43
var yaw := 0.4
var pitch := 0.23
var dragging := false
var capture_mode := false
var _hud_elapsed := 0.0
var _fixture_label := "PRESENTATION FIXTURE / NO GAMEPLAY CLAIM"

func _ready() -> void:
	_build_environment()
	_build_stage()
	_build_exhibits()
	_build_hud()
	select_effect(0)
	_update_camera()
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()
	if "--smoke" in OS.get_cmdline_user_args(): call_deferred("_smoke")

func _smoke() -> void:
	for index in range(KEYS.size()):
		select_effect(index)
		factory.update_time(1.0)
		for frame in range(3): await get_tree().process_frame
		if materials[index] == null or materials[index].shader == null:
			push_error("Shader lab material failed to load")
			get_tree().quit(1)
			return
	print("SHADER_LAB_SMOKE_OK effects=3 authority=false graphical=false")
	get_tree().quit(0)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101a29")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d4dfeb")
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = environment
	add_child(world)
	for setup: Array in [[Vector3(-38, -30, 0), Color("ecf4ff"), 0.95], [Vector3(-15, 145, 0), Color("a2b6d2"), 0.35]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = setup[0]
		light.light_color = setup[1]
		light.light_energy = setup[2]
		light.shadow_enabled = setup[2] > 0.5
		add_child(light)
	camera = Camera3D.new()
	camera.fov = 35.0
	camera.near = 0.1
	camera.far = 60.0
	camera.h_offset = 1.15
	camera.current = true
	add_child(camera)

func _plain(color: Color, emission := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

func _mesh(parent: Node3D, shape: Mesh, position_: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.position = position_
	node.material_override = material
	parent.add_child(node)
	return node

func _cylinder(radius: float, height: float, segments := 64) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh

func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _ring(parent: Node3D, radius: float, thickness: float, height: float, material: Material) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 64
	mesh.ring_segments = 8
	_mesh(parent, mesh, Vector3(0, height, 0), material)

func _build_stage() -> void:
	stage = Node3D.new()
	add_child(stage)
	var floor_material := _plain(Color("151e28"))
	_mesh(stage, _box(Vector3(80, 0.12, 80)), Vector3(0, -0.27, 0), floor_material)
	var base := Surfaces.create_surface("brushed_metal", Color("607488"))
	_mesh(stage, _cylinder(2.1, 0.28), Vector3(0, -0.07, 0), base)
	_mesh(stage, _cylinder(1.96, 0.07), Vector3(0, 0.105, 0), _plain(Color("26384b")))
	_ring(stage, 1.91, 0.013, 0.15, _plain(Color("7eb5cb"), 0.4))
	_ring(stage, 2.1, 0.022, -0.1, _plain(Color("487589"), 0.3))
	# Static instancing keeps calibration ticks to one draw call, no per-frame vertices.
	var ticks := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _box(Vector3(0.018, 0.008, 0.1))
	multi.instance_count = 60
	for index in range(60):
		var angle := TAU * index / 60.0
		multi.set_instance_transform(index, Transform3D(Basis(Vector3.UP, angle), Vector3(sin(angle) * 1.77, 0.148, cos(angle) * 1.77)))
	ticks.multimesh = multi
	ticks.material_override = _plain(Color("728d9f"), 0.12)
	stage.add_child(ticks)

func _build_exhibits() -> void:
	for effect: String in KEYS:
		materials.append(factory.create_material(effect))
		var node := Node3D.new()
		exhibits.append(node)
		add_child(node)
	var metal := Surfaces.create_surface("brushed_metal", Color("9eb5c5"))
	var dark := Surfaces.create_surface("hex_paneling", Color("607688"))
	var cyan := _plain(Color("a2e3f0"), 0.35)
	var crystal := _cylinder(0.53, 1.7, 6)
	crystal.top_radius = 0.24
	_mesh(exhibits[0], crystal, Vector3(0, 1.95, 0), metal)
	_mesh(exhibits[0], _cylinder(0.76, 0.15, 12), Vector3(0, 0.65, 0), dark)
	_mesh(exhibits[0], _cylinder(0.4, 0.38, 12), Vector3(0, 0.4, 0), metal)
	for height: float in [1.0, 2.7]: _ring(exhibits[0], 0.7, 0.035, height, cyan)
	for index in range(3):
		var angle := TAU * index / 3.0
		_mesh(exhibits[0], _box(Vector3(0.07, 1.65, 0.07)), Vector3(sin(angle) * 0.69, 1.84, cos(angle) * 0.69), metal)
	var sphere := SphereMesh.new()
	sphere.radius = 1.47
	sphere.height = 2.94
	sphere.radial_segments = 64
	sphere.rings = 32
	var shell := _mesh(exhibits[0], sphere, Vector3(0, 1.88, 0), materials[0])
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh(exhibits[1], _cylinder(0.85, 2.65), Vector3(0, 1.78, 0), materials[1])
	for height: float in [0.43, 3.13]:
		_mesh(exhibits[1], _cylinder(1.01, 0.18, 16), Vector3(0, height, 0), metal)
		_ring(exhibits[1], 0.96, 0.026, height + 0.105, cyan)
	for index in range(8):
		var angle := TAU * (float(index) + 0.5) / 8.0
		var rail := _mesh(exhibits[1], _box(Vector3(0.055, 2.6, 0.085)), Vector3(sin(angle) * 0.91, 1.78, cos(angle) * 0.91), dark)
		rail.rotation.y = angle
	_mesh(exhibits[1], _cylinder(0.56, 0.2, 8), Vector3(0, 3.31, 0), dark)
	# Single static combined mesh: every rib/face shares one local dissolve field.
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.append_from(_box(Vector3(1.82, 2.25, 1.5)), 0, Transform3D.IDENTITY)
	for x: float in [-0.89, 0.89]:
		for z: float in [-0.74, 0.74]:
			builder.append_from(_box(Vector3(0.19, 2.42, 0.18)), 0, Transform3D(Basis.IDENTITY, Vector3(x, 0, z)))
	for y: float in [-1.13, 0.72, 1.13]:
		builder.append_from(_box(Vector3(1.97, 0.14, 1.68)), 0, Transform3D(Basis.IDENTITY, Vector3(0, y, 0)))
	for x: float in [-0.48, -0.24, 0, 0.24, 0.48]:
		builder.append_from(_box(Vector3(0.09, 0.66, 1.58)), 0, Transform3D(Basis.IDENTITY, Vector3(x, 0.18, 0)))
	var cargo := _mesh(exhibits[2], builder.commit(), Vector3(0, 1.68, 0), materials[2])
	cargo.rotation.y = -0.25
	_mesh(exhibits[2], _cylinder(1.36, 0.19, 8), Vector3(0, 0.31, 0), dark)
	_ring(exhibits[2], 1.32, 0.02, 0.42, _plain(Color("b690d4"), 0.3))

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
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	var footer := Panel.new()
	footer.name = "Footer"
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_stylebox_override("panel", _panel_style(Color("0e1927"), Color("25374b")))
	ui.add_child(footer)
	var eyebrow := _label(ui, "M O T H   /   N A T I V E   M A T E R I A L   S T U D I E S", 13, Color("9ab1c4"))
	eyebrow.position = Vector2(30, 21)
	title = _label(ui, "", 29, Color.WHITE)
	title.position = Vector2(28, 44)
	var subtitle := _label(ui, _fixture_label, 11, Color("8198ae"))
	subtitle.position = Vector2(30, 84)
	var sidebar := PanelContainer.new()
	sidebar.name = "Sidebar"
	sidebar.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.075, 0.12, 0.94), Color("33485d")))
	ui.add_child(sidebar)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	sidebar.add_child(column)
	_label(column, "SURFACE NOTES", 12, Color("7c9eb7"))
	details = _label(column, "", 13, Color("c6d7e6"))
	phase_label = _label(column, "", 13, Color("dda5ee"))
	status = _label(column, "", 13, Color("91dbe8"))
	stats = _label(column, "", 11, Color("90a9bd"))
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index in range(3):
		var tab := PanelContainer.new()
		tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(tab)
		tabs.append(tab)
		var label := _label(tab, "%d   %s" % [index + 1, ["INTERFERENCE", "REACTOR FLOW", "PHASE PROP"][index]], 14, ACCENTS[index])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var controls := _label(ui, "1–3  SELECT     SPACE  PAUSE     A/D or DRAG  ORBIT     +/−  INTENSITY     R  RESET", 12, Color("bed1df"))
	controls.name = "Controls"
	var footnote := _label(ui, "GL COMPATIBILITY   /   OBJECT-SPACE EFFECTS   /   FIXED GEOMETRY", 10, Color("7892a8"))
	footnote.name = "Footnote"

func _layout_hud() -> void:
	if ui == null: return
	var size := get_viewport().get_visible_rect().size
	var width := 288.0 if size.x >= 1100 else 256.0
	var sidebar := ui.get_node("Sidebar") as Control
	sidebar.position = Vector2(size.x - width - 28, 118)
	sidebar.size = Vector2(width, 0)
	_fit_sidebar.call_deferred()
	ui.get_node("Footer").position = Vector2(-5, size.y - 122)
	ui.get_node("Footer").size = Vector2(size.x + 10, 130)
	for index in range(3):
		tabs[index].position = Vector2(28 + index * (size.x - 68) / 3.0, size.y - 108)
		tabs[index].size = Vector2((size.x - 92) / 3.0, 42)
	ui.get_node("Controls").position = Vector2(30, size.y - 52)
	ui.get_node("Footnote").position = Vector2(30, size.y - 30)
	# Keep the object clear of the notes at both audited resolutions.
	camera.h_offset = 1.25 if size.x < 1100 else 1.15

func _fit_sidebar() -> void:
	var sidebar := ui.get_node("Sidebar") as Control
	sidebar.size.y = sidebar.get_combined_minimum_size().y

func select_effect(index: int) -> void:
	selected = clampi(index, 0, 2)
	for item in range(exhibits.size()): exhibits[item].visible = item == selected
	if title != null:
		title.text = "%02d / %s" % [selected + 1, TITLES[selected]]
		details.text = DESCRIPTIONS[selected]
		for item in range(tabs.size()):
			tabs[item].add_theme_stylebox_override("panel", _panel_style(Color("152b3c") if item == selected else Color("101e2e"), ACCENTS[item] if item == selected else Color("31465b")))
		_update_hud()

func set_time(value: float) -> void:
	if factory.update_time(value): seconds = float(factory.state().time)

func set_intensity(value: float) -> void:
	if not is_finite(value): return
	intensity = clampf(value, 0.0, 2.5)
	for material: ShaderMaterial in materials: factory.configure(material, {"intensity": intensity})
	_update_hud()

func reset_gallery() -> void:
	factory.reset()
	seconds = 0.0
	intensity = 1.0
	phase_amount = 0.43
	paused = false
	yaw = 0.4
	pitch = 0.23
	_update_camera()
	_update_hud()

func _update_camera() -> void:
	var target := Vector3(0, 1.65, 0)
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 9.5
	camera.look_at(target)

func _update_hud() -> void:
	if status == null: return
	status.text = "%s   %06.2f s\nINTENSITY  %.2f / 2.50" % ["PAUSED" if paused else "RUNNING", seconds, intensity]
	phase_label.text = "TRANSITION  %02d%%   [ / ]" % roundi(phase_amount * 100) if selected == 2 else ""
	phase_label.visible = selected == 2
	var gpu := RenderingServer.get_video_adapter_name()
	var timing := "STILL CAPTURE / timing in evidence" if capture_mode else "%d FPS · CPU process %.2f ms" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0]
	stats.text = "%s\n%s\n%s\n%d draws · %s primitives\nGPU timing: unavailable\n%d shared shaders / %d instances" % [RenderingServer.get_current_rendering_method(), gpu, timing, get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME), str(get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)), factory.state().shared_shaders, factory.state().materials]
	_fit_sidebar.call_deferred()

func _process(delta: float) -> void:
	if not paused: set_time(seconds + delta)
	var direction := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	if direction != 0.0:
		yaw += direction * delta * 0.65
		_update_camera()
	_hud_elapsed += delta
	if _hud_elapsed >= 0.25:
		_hud_elapsed = 0.0
		_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.004, -0.05, 0.65)
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3: select_effect(int(event.keycode - KEY_1))
			KEY_SPACE:
				paused = not paused
				_update_hud()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: set_intensity(intensity + 0.1)
			KEY_MINUS, KEY_KP_SUBTRACT: set_intensity(intensity - 0.1)
			KEY_R: reset_gallery()
			KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
				phase_amount = clampf(phase_amount + (0.05 if event.keycode == KEY_BRACKETRIGHT else -0.05), 0.0, 1.0)
				factory.configure(materials[2], {"dissolve": phase_amount})
				_update_hud()

func _exit_tree() -> void:
	factory.clear()
