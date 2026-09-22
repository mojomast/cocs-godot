extends RefCounted
## Layout builder for the material-language review captures. Produces SubViewport
## panels (so each family is rendered on its own camera/world) and the measured
## A/B passes. Viewer only: no gameplay, no collision, no world mutation.

const Language = preload("res://material_language/library.gd")
const Props = preload("res://material_language/props.gd")

const LIGHTING := {
	"raking": [Vector3(-14, -16, 0), Color("ffd9ac"), 1.18, Vector3(-30, 120, 0), Color("8fb0cc"), 0.24],
	"key": [Vector3(-42, -34, 0), Color("ecf4ff"), 1.02, Vector3(-18, 148, 0), Color("9db2cc"), 0.34],
	"overcast": [Vector3(-46, -60, 0), Color("d8e4f0"), 0.28, Vector3(-20, 140, 0), Color("c8d8e6"), 0.62],
}

var materials: Array[ShaderMaterial] = []
var tiles: Array[Dictionary] = []
var control: Dictionary = {}

func _panel(parent: Node, origin: Vector2, pixel_size: Vector2i, world: String, lighting: String = "raking", shadows: bool = false) -> Dictionary:
	var container := SubViewportContainer.new()
	container.position = origin
	container.size = pixel_size
	container.stretch = true
	parent.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = pixel_size
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Software rasteriser: no MSAA in the review captures. The three-light setup
	# and the close family panels are what make the surface readable.
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	container.add_child(viewport)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("141d26")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c3d3e0")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	viewport.add_child(environment)
	var setup: Array = LIGHTING[lighting]
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = setup[0]
	sun.light_color = setup[1]
	sun.light_energy = setup[2]
	sun.shadow_enabled = shadows
	viewport.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = setup[3]
	fill.light_color = setup[4]
	fill.light_energy = setup[5]
	viewport.add_child(fill)
	var camera := Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.06
	camera.far = 220.0
	camera.name = "Camera"
	viewport.add_child(camera)
	return {"viewport": viewport, "camera": camera, "world": world}

func _frame(camera: Camera3D, target: Vector3, yaw: float, pitch: float, distance: float) -> void:
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target)

func variant_name_for(family: String) -> String:
	var variants: PackedStringArray = Language.variants(family)
	return variants[1] if variants.size() > 1 else "default"

func _register(nodes: Array) -> void:
	for node: Node in nodes:
		if node is MeshInstance3D and node.material_override is ShaderMaterial and not materials.has(node.material_override):
			materials.append(node.material_override)

func _label(parent: Node, text: String, position: Vector2, font_size: int = 12, color: Color = Color("cfe0ec"), width: float = 0.0) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if width > 0.0:
		# Clipped to the tile: at 960x640 a long detail line must never bleed into
		# the neighbouring family's label.
		label.size = Vector2(width, 0.0)
		label.clip_text = true
	parent.add_child(label)

func _header(parent: Node, size: Vector2i, subtitle: String) -> void:
	_label(parent, "M O T H   /   M A T E R I A L   L A N G U A G E", Vector2(18, 10), 15, Color("9db8cc"))
	_label(parent, subtitle, Vector2(18, 32), 12, Color("7e94a8"))
	_label(parent, "world-space triplanar · shared materials · GL Compatibility · no gameplay", Vector2(size.x - 470, 14), 11, Color("6e8498"))

## Eight families, each on the same five props.
func sheet(parent: Node, size: Vector2i) -> Dictionary:
	_header(parent, size, "eight families · floor slab / wall / rail / prop / rounded object · raking key light")
	var columns := 4
	var rows := 2
	var margin := 14.0
	var gap := 10.0
	var label_height := 46.0
	var cell := Vector2((size.x - margin * 2.0 - gap * (columns - 1)) / columns, (size.y - 66.0 - label_height * rows - gap * (rows - 1)) / rows)
	var ids: PackedStringArray = Language.families()
	for index in range(ids.size()):
		var family: String = ids[index]
		var column := index % columns
		var row := index / columns
		var origin := Vector2(margin + column * (cell.x + gap), 56.0 + row * (cell.y + label_height + gap))
		var panel := _panel(parent, origin, Vector2i(cell), family)
		var built: Dictionary = Props.build(family, panel.viewport)
		_frame(panel.camera, Vector3(0.1, 1.0, 0.0), 0.55, 0.42, 6.6)
		_register(built.nodes)
		var description: Dictionary = Language.describe(family)
		tiles.append({"family": family, "viewport": panel.viewport})
		var label_origin := origin + Vector2(0, cell.y + 5)
		_label(parent, "%s · %s" % [String(description.label).to_upper(), description.base_textures[0]], label_origin, 11, Color(description.palette[0]), cell.x)
		_label(parent, "normal %s" % description.normal.resolved.trim_prefix("baked:"), label_origin + Vector2(0, 15), 9, Color("93aec2"), cell.x)
		_label(parent, "accent %s @%.2f · %d px/m · rail %s" % [description.emissive.lut, description.emissive.phase, description.density.px_per_metre, variant_name_for(family)], label_origin + Vector2(0, 27), 9, Color("7e94a8"), cell.x)
	_measure_control(parent)
	return {"metrics": tile_metrics()}

## A 64x64 offscreen copy of the same station with one plain StandardMaterial3D:
## the draw-call control for "a material swap adds no draws".
func _measure_control(parent: Node) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(viewport)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("141d26")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c3d3e0")
	env.ambient_light_energy = 0.3
	environment.environment = env
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-14, -16, 0)
	sun.light_energy = 1.18
	sun.shadow_enabled = false
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.06
	viewport.add_child(camera)
	_frame(camera, Vector3(0.1, 1.0, 0.0), 0.55, 0.42, 6.6)
	var plain := StandardMaterial3D.new()
	plain.albedo_color = Color("cfc9ba")
	plain.roughness = 0.34
	var built: Dictionary = Props.build("pearl-ceramic", viewport)
	for node: Node in built.nodes: node.material_override = plain
	control = {"viewport": viewport, "reason": "same station, one plain StandardMaterial3D"}

## One family, close and wide, with a distance strip behind it for the fade check.
func family_panel(parent: Node, size: Vector2i, family: String) -> Dictionary:
	var description: Dictionary = Language.describe(family)
	_header(parent, size, "%s · close and wide · raking key light" % String(description.label).to_upper())
	var cell := Vector2((size.x - 42.0) / 2.0, size.y - 96.0)
	var close_panel := _panel(parent, Vector2(14, 54), Vector2i(cell), family, "raking", true)
	var close_built: Dictionary = Props.build(family, close_panel.viewport)
	_frame(close_panel.camera, Vector3(0.1, 0.9, 0.0), 0.62, 0.30, 3.9)
	_register(close_built.nodes)
	tiles.append({"family": family, "viewport": close_panel.viewport})
	var wide_panel := _panel(parent, Vector2(28 + cell.x, 54), Vector2i(cell), family, "raking", true)
	var wide_built: Dictionary = Props.build(family, wide_panel.viewport)
	Props.distance_strip(family, wide_panel.viewport, 60.0)
	_register(wide_built.nodes)
	for child: Node in wide_panel.viewport.get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial and not materials.has(child.material_override):
			materials.append(child.material_override)
	_frame(wide_panel.camera, Vector3(0.0, 0.6, -6.0), 0.0, 0.20, 13.0)
	tiles.append({"family": family, "viewport": wide_panel.viewport, "kind": "distance"})
	_label(parent, "close · %.1f m" % 3.9, Vector2(16, 36), 11, Color("8aa2b6"), cell.x)
	_label(parent, "wide · 60 m distance strip for the detail-fade check", Vector2(30 + cell.x, 36), 11, Color("8aa2b6"), cell.x)
	_label(parent, "normal %s · accent %s phase %.2f gain %.2f · %d px/m" % [description.normal.resolved, description.emissive.lut, description.emissive.phase, description.emissive.gain, description.density.px_per_metre], Vector2(14, size.y - 38), 11, Color("9fd6c8"), size.x - 28.0)
	return {"metrics": tile_metrics()}

## Grazing floors: the flicker/shimmer case for a 64 px tile.
func distance_panel(parent: Node, size: Vector2i) -> Dictionary:
	_header(parent, size, "grazing floors · regolith / polar-ice / hazard-industrial · near to 60 m")
	var families := PackedStringArray(["regolith", "polar-ice", "hazard-industrial"])
	var cell := Vector2((size.x - 42.0) / 3.0, size.y - 96.0)
	for index in range(families.size()):
		var family: String = families[index]
		var panel := _panel(parent, Vector2(14 + index * (cell.x + 7), 54), Vector2i(cell), family)
		var strip := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(7.0, 0.24, 70.0)
		strip.mesh = mesh
		strip.position = Vector3(0, -0.12, -32.0)
		strip.material_override = Language.material(family, {})
		panel.viewport.add_child(strip)
		if strip.material_override is ShaderMaterial: materials.append(strip.material_override)
		# A couple of rails give the distance read a vertical reference.
		for side: float in [-2.4, 2.4]:
			var rail := MeshInstance3D.new()
			var rail_mesh := BoxMesh.new()
			rail_mesh.size = Vector3(0.14, 0.9, 70.0)
			rail.mesh = rail_mesh
			rail.position = Vector3(side, 0.34, -32.0)
			rail.material_override = Language.material(family, {"variant": "" if Language.variants(family).size() < 2 else Language.variants(family)[1]})
			panel.viewport.add_child(rail)
			if rail.material_override is ShaderMaterial: materials.append(rail.material_override)
		_frame(panel.camera, Vector3(0, 0.85, -14.0), 0.0, 0.115, 1.6)
		tiles.append({"family": family, "viewport": panel.viewport})
		_label(parent, "%s · raking light along the surface" % family, Vector2(16 + index * (cell.x + 7), size.y - 38), 11, Color("9fd6c8"), cell.x)
	return {"metrics": tile_metrics()}

## Draw calls and primitives per tile, read after the frame has settled.
func tile_metrics() -> Dictionary:
	var rows: Array[Dictionary] = []
	for tile: Dictionary in tiles:
		var viewport: SubViewport = tile.viewport
		rows.append({
			"family": tile.family,
			"kind": tile.get("kind", "station"),
			"draws": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"primitives": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		})
	var control_viewport: SubViewport = control.get("viewport")
	if control_viewport != null:
		rows.append({
			"family": "control", "kind": "plain-standard-material",
			"draws": control_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"primitives": control_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		})
	return {"tiles": rows, "materials": Language.cache_stats().materials, "ab_materials": materials.size(), "budget": Language.budget()}

## Toggles the two judgement switches on exactly the materials in this capture
## and measures what actually changed on screen.
func measure_ab(root: Window, size: Vector2i, targets: Array = materials, save_prefix: String = "", enabled: bool = true) -> Dictionary:
	var panels: Array[ShaderMaterial] = []
	for entry: Variant in targets:
		if entry is ShaderMaterial and not panels.has(entry): panels.append(entry)
	if not enabled:
		return {"skipped": true, "materials": panels.size()}
	print("MATERIAL_LANGUAGE_AB_START materials=%d" % panels.size())
	await _settle()
	var base := root.get_texture().get_image()
	_assign_parameter(panels, "has_normal", false)
	await _settle()
	var without_normals := root.get_texture().get_image()
	_assign_parameter(panels, "has_normal", true)
	_assign_parameter(panels, "glow", 0.0)
	await _settle()
	var without_glow := root.get_texture().get_image()
	_assign_parameter(panels, "glow", 1.0)
	await _settle()
	if save_prefix != "":
		without_normals.save_png(save_prefix + "-normals-off.png")
		without_glow.save_png(save_prefix + "-glow-off.png")
	return {
		"materials": panels.size(),
		"sampling": "every third pixel in x and y",
		"normal_off": _delta(base, without_normals),
		"glow_off": _delta(base, without_glow),
	}

func _assign_parameter(panels: Array[ShaderMaterial], parameter: String, value: Variant) -> void:
	for material: ShaderMaterial in panels:
		material.set_shader_parameter(parameter, value)

func _settle() -> void:
	# One settled frame is enough: nothing else is mutating the scene.
	await RenderingServer.frame_post_draw

func _delta(before: Image, after: Image) -> Dictionary:
	var changed := 0
	var total := 0.0
	var sampled := 0
	for y in range(0, after.get_height(), 3):
		for x in range(0, after.get_width(), 3):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			var delta := absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			total += delta
			sampled += 1
			if delta > 0.01: changed += 1
	return {"changed_pixels": changed, "sampled_pixels": sampled, "mean_rgb_delta": total / maxf(1.0, sampled * 3.0)}
