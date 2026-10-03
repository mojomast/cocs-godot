extends SceneTree
## Graphical shader-contract test for weapon_effects/flash.gdshader use_sheet.
##
## Part 1 renders an explicitly synthetic opaque-black Moth-format frame (a cyan
## disk on black) and asserts the card is discarded.
##
## Part 2 loads the REAL baked Moth frames that world/combat_feedback.gd binds
## (pulse -> spark-impact, plasma/shock -> arc-burst), decodes their actual PNG
## pixels, and asserts the background-free extraction: source corner
## (26,8,6)/(10,4,30), fully opaque alpha, uniform corners, a strong diagonal
## authored symmetry, background alpha < 0.02, the analytic core retained, the
## off-centre authored bright core retained, and no unexpected hue shift.
##
## It does not consume or alter any reserved external pulse preview, writes no
## asset or .import file, and makes no performance claim.
const ShaderFX = preload("res://weapon_effects/flash.gdshader")
const SIZE := 128
var output := ""
var failures := 0
## kind/tint mirror weapon_effects/profiles.gd modes 0 (Pulse) and 4 (Plasma).
var real_frames := [
	{"name":"spark-impact", "path":"res://moth/generated/effects/spark-impact-0.png",
		"kind":0, "tint":Color("70ffe6"), "background":Color8(26,8,6,255)},
	{"name":"arc-burst", "path":"res://moth/generated/effects/arc-burst-0.png",
		"kind":4, "tint":Color("72cfff"), "background":Color8(10,4,30,255)},
]
## UV points that are source background but sit inside the card, off the centre.
var off_core_uv := [Vector2(0.75,0.75), Vector2(0.75,0.25), Vector2(0.25,0.25), Vector2(0.20,0.80)]

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-out="): output = arg.trim_prefix("--evidence-out=")
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("WEAPON_EFFECTS_MOTH_COVERAGE " + message)

static func _signal(image: Image, background: Color, x: int, y: int) -> float:
	var c := image.get_pixel(x, y)
	return maxf(c.r-background.r, maxf(c.g-background.g, c.b-background.b))

static func _chroma(c: Color) -> Vector3:
	var m := maxf(c.r, maxf(c.g, c.b))
	return Vector3.ZERO if m <= 0.0001 else Vector3(c.r, c.g, c.b)/m

static func _hue_distance(a: Color, b: Color) -> float:
	return _chroma(a).distance_to(_chroma(b))

## Render one opaque quad filling the viewport with the flash shader. `sheet`
## binds the frame texture; otherwise the analytic profile renders alone.
func render(texture: Texture2D, kind: int, tint: Color, sheet: bool) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	viewport.add_child(camera)
	camera.current = true
	var node := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2, 2)
	node.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = ShaderFX
	material.set_shader_parameter("use_sheet", sheet)
	material.set_shader_parameter("frame_texture", texture if sheet else null)
	material.set_shader_parameter("kind", kind)
	material.set_shader_parameter("tint", tint)
	node.material_override = material
	node.position.z = -1
	viewport.add_child(node)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	viewport.queue_free()
	return rendered

func run() -> void:
	if not output.is_empty():
		if DirAccess.make_dir_recursive_absolute(output) != OK:
			push_error("Cannot create muzzle evidence directory: "+output)
			quit(1)
			return
	# ---------------------------------------------------------- synthetic ---
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	for y: int in 64:
		for x: int in 64:
			if Vector2(x-31.5, y-31.5).length()/32.0 < 0.4:
				image.set_pixel(x, y, Color(0.4, 0.9, 1.0, 1.0))
	var rendered := await render(ImageTexture.create_from_image(image), 0, Color("70ffe6"), true)
	var corner_alpha := rendered.get_pixel(2, 2).a
	var black_edge_alpha := rendered.get_pixel(10, 64).a
	var center_alpha := rendered.get_pixel(64, 64).a
	check(corner_alpha < 0.01, "synthetic black corner is transparent")
	check(black_edge_alpha < 0.02, "synthetic black off-core card is transparent")
	check(center_alpha > 0.4, "synthetic luminous core is retained")
	var result := {
		"fixture":"synthetic opaque black frame; GL Compatibility shader output",
		"input_black_alpha":image.get_pixel(0, 0).a,
		"corner_alpha":corner_alpha, "black_edge_alpha":black_edge_alpha, "center_alpha":center_alpha,
	}
	if not output.is_empty():
		check(rendered.save_png(output.path_join("moth-opaque-coverage.png"))==OK,"synthetic PNG saved")
	# ------------------------------------------------------------- real ---
	var real: Array = []
	for entry: Dictionary in real_frames:
		var name: String = entry.name
		var background: Color = entry.background
		var source := Image.load_from_file(entry.path)
		if source == null:
			var imported := load(entry.path) as Texture2D
			if imported != null: source = imported.get_image()
		check(source != null, name + ": real source PNG decodes")
		if source == null: continue
		check(source.get_pixel(0, 0).is_equal_approx(background), name + ": source corner matches authored background")
		check(source.get_pixel(source.get_width()-1, 0).is_equal_approx(background)
			and source.get_pixel(0, source.get_height()-1).is_equal_approx(background)
			and source.get_pixel(source.get_width()-1, source.get_height()-1).is_equal_approx(background),
			name + ": source corners are uniform")
		check(is_equal_approx(source.get_pixel(0, 0).a, 1.0), name + ": source alpha is fully opaque")
		# Brightest authored impulse, which sits off the quad centre.
		var peak_x := 0
		var peak_y := 0
		var peak_signal := -1.0
		for y: int in source.get_height():
			for x: int in source.get_width():
				var s := _signal(source, background, x, y)
				if s > peak_signal:
					peak_signal = s
					peak_x = x
					peak_y = y
		var uv := Vector2((peak_x+0.5)/source.get_width(), (peak_y+0.5)/source.get_height())
		var sheet_image := await render(ImageTexture.create_from_image(source), entry.kind, entry.tint, true)
		var analytic_image := await render(null, entry.kind, entry.tint, false)
		check(peak_signal > 0.5, name + ": authored bright impulse exists off the quad centre")
		check(sheet_image.get_pixel(2, 2).a < 0.02, name + ": background corner alpha < 0.02")
		var off_core_max := 0.0
		for sample_uv: Vector2 in off_core_uv:
			var p := Vector2i(clampi(int(sample_uv.x*SIZE), 0, SIZE-1), clampi(int(sample_uv.y*SIZE), 0, SIZE-1))
			off_core_max = maxf(off_core_max, sheet_image.get_pixelv(p).a)
		check(off_core_max < 0.03, name + ": source background off the analytic core stays transparent")
		check(sheet_image.get_pixel(64, 64).a > 0.4, name + ": analytic core is retained")
		# Both UV orientations are accepted; require a retained bright sample that
		# follows the weapon tint rather than the baked background hue.
		var base := Vector2i(clampi(int(uv.x*SIZE), 0, SIZE-1), clampi(int(uv.y*SIZE), 0, SIZE-1))
		var flip := Vector2i(base.x, SIZE-1-base.y)
		var a0 := sheet_image.get_pixelv(base)
		var a1 := sheet_image.get_pixelv(flip)
		check(maxf(a0.a, a1.a) > 0.5, name + ": authored bright core is retained (alpha > 0.5)")
		var to_tint := minf(_hue_distance(a0, entry.tint), _hue_distance(a1, entry.tint))
		var to_background := minf(_hue_distance(a0, background), _hue_distance(a1, background))
		check(to_tint < 0.6 and to_tint < to_background, name + ": no unexpected hue shift away from the weapon tint")
		# Where the frame is background (the analytic centre) the card must add
		# nothing, so sheet-on vs analytic-only colour stays identical.
		var centre_sheet := sheet_image.get_pixel(64, 64)
		var centre_analytic := analytic_image.get_pixel(64, 64)
		var centre_shift := absf(centre_sheet.r-centre_analytic.r) + absf(centre_sheet.g-centre_analytic.g) + absf(centre_sheet.b-centre_analytic.b)
		check(centre_shift < 0.05, name + ": analytic centre colour is not re-tinted by the card")
		real.append({"name":name, "size":[source.get_width(), source.get_height()],
			"background_rgba8":[roundi(background.r*255), roundi(background.g*255), roundi(background.b*255), 255],
			"peak_xy":[peak_x, peak_y], "peak_signal":snappedf(peak_signal, 0.001),
			"corner_alpha":sheet_image.get_pixel(2, 2).a, "off_core_max_alpha":off_core_max,
			"center_alpha":sheet_image.get_pixel(64, 64).a, "retained_core_alpha":maxf(a0.a, a1.a),
			"hue_to_tint":snappedf(to_tint, 0.001), "hue_to_background":snappedf(to_background, 0.001),
			"center_shift":snappedf(centre_shift, 0.0001)})
		if not output.is_empty():
			check(sheet_image.save_png(output.path_join("moth-%s-coverage.png" % name))==OK,name+": real PNG saved")
	result["real_frames"] = real
	result["passed"] = failures == 0
	if not output.is_empty():
		FileAccess.open(output.path_join("moth-coverage.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t")+"\n")
	print("WEAPON_EFFECTS_MOTH_COVERAGE ", JSON.stringify(result))
	quit(0 if failures == 0 else 1)
