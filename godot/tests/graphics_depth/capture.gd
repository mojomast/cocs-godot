extends SceneTree
## Real Compatibility raster regression: run graphically, never with --headless.

const SURFACE = preload("res://moth/surface.gdshader")
const LOW := Color(0.9, 0.08, 0.04)
const HIGH := Color(0.04, 0.85, 0.12)
const MODES := ["low-only", "high-only", "low-high", "high-low", "equal-low-high", "equal-high-low"]
var cells: Array = []
var references: Dictionary = {}

func _initialize() -> void:
	call_deferred("capture")

func make_mesh(distance: float, slope: float, mode: String) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var material := ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter("vertex_tint", true)
	var layers: Array = [false, true]
	if mode.ends_with("high-low"): layers.reverse()
	if mode == "low-only": layers = [false]
	if mode == "high-only": layers = [true]
	var extent := distance * 0.38
	var gradient := tan(deg_to_rad(slope))
	var vertices := [Vector3(-extent, -extent * gradient, -extent), Vector3(extent, extent * gradient, -extent), Vector3(extent, extent * gradient, extent), Vector3(-extent, -extent * gradient, extent)]
	var normal := Vector3(-gradient, 1, 0).normalized()
	for high: bool in layers:
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Same semantic packing and source-to-Godot winding as world/viewer.gd.
		for triangle: Array in [[0, 2, 1], [0, 3, 2]]:
			for index in [2, 1, 0]:
				builder.set_normal(normal)
				builder.set_color(HIGH if high else LOW)
				builder.set_uv(Vector2(2.0 if high and not mode.begins_with("equal-") else 1.0, 0))
				builder.add_vertex(vertices[triangle[index]])
		builder.set_material(material)
		builder.commit(mesh)
	return mesh

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or DisplayServer.get_name() == "headless":
		push_error("Usage: graphical Godot --script res://tests/graphics_depth/capture.gd -- OUTPUT LABEL")
		quit(2)
		return
	var output := args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var size := root.size
	var heading := Label.new()
	heading.position = Vector2(12, 8)
	heading.add_theme_font_size_override("font_size", 19)
	root.add_child(heading)
	var cell_size := Vector2i((size.x - 32) / 3, (size.y - 100) / 2)
	for slope: float in [0.0, 35.0]:
		for distance: float in [4.0, 40.0, 160.0]:
			var index := cells.size()
			var position := Vector2(8 + (index % 3) * (cell_size.x + 8), 72 + (index / 3) * (cell_size.y + 8))
			var container := SubViewportContainer.new()
			container.position = position
			root.add_child(container)
			var viewport := SubViewport.new()
			viewport.size = cell_size - Vector2i(0, 24)
			viewport.own_world_3d = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			container.add_child(viewport)
			var environment := WorldEnvironment.new()
			environment.environment = Environment.new()
			environment.environment.background_mode = Environment.BG_COLOR
			environment.environment.background_color = Color("172333")
			environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.environment.ambient_light_color = Color.WHITE
			environment.environment.ambient_light_energy = 1.0
			viewport.add_child(environment)
			var camera := Camera3D.new()
			camera.fov = 60
			camera.near = 0.05
			camera.far = 500
			viewport.add_child(camera)
			camera.position = Vector3(0, 0.65, 0.76).normalized() * distance
			camera.look_at(Vector3.ZERO)
			var instance := MeshInstance3D.new()
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			viewport.add_child(instance)
			var label := Label.new()
			label.position = position + Vector2(0, cell_size.y - 24)
			label.text = "distance %.0f | slope %.0f deg" % [distance, slope]
			root.add_child(label)
			cells.append({"viewport": viewport, "instance": instance, "distance": distance, "slope": slope})
	var results: Array = []
	var failures := 0
	var control_winners: Dictionary = {}
	for mode: String in MODES:
		heading.text = "%s | %s | %dx%d\nGREEN = authored priority 2; RED = base priority 1" % [args[1], mode, size.x, size.y]
		for cell: Dictionary in cells:
			cell.instance.mesh = make_mesh(cell.distance, cell.slope, mode)
		for frame in range(5):
			await process_frame
			await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		if screenshot.save_png(output.path_join(mode + ".png")) != OK:
			quit(2)
			return
		for index in range(cells.size()):
			var cell: Dictionary = cells[index]
			var image: Image = cell.viewport.get_texture().get_image()
			var samples: Array = []
			for y in range(-4, 5):
				for x in range(-4, 5):
					samples.append(image.get_pixel(image.get_width() / 2 + x * 3, image.get_height() / 2 + y * 3))
			if mode.ends_with("only"):
				references[str(index) + mode] = samples
				continue
			var high_count := 0
			var low_count := 0
			for i in range(samples.size()):
				var pixel: Color = samples[i]
				var high: Color = references[str(index) + "high-only"][i]
				var low: Color = references[str(index) + "low-only"][i]
				if pixel.g > pixel.r * 2.0 and pixel_distance(pixel, high) < 0.02: high_count += 1
				if pixel.r > pixel.g * 2.0 and pixel_distance(pixel, low) < 0.02: low_count += 1
			var center: Color = samples[40]
			var row := {"mode": mode, "distance": cell.distance, "slope_degrees": cell.slope, "high_pixels": high_count, "low_pixels": low_count, "samples": samples.size(), "center_rgb8": [roundi(center.r * 255), roundi(center.g * 255), roundi(center.b * 255)]}
			results.append(row)
			print("DEPTH_PIXELS ", JSON.stringify(row))
			if mode.begins_with("equal-"):
				control_winners[str(index) + mode] = "high" if high_count == 81 else ("low" if low_count == 81 else "mixed")
			elif high_count != 81:
				failures += 1
	var order_controls_pass := true
	for index in range(cells.size()):
		var a: String = control_winners[str(index) + "equal-low-high"]
		var b: String = control_winners[str(index) + "equal-high-low"]
		if a == b or a == "mixed" or b == "mixed": order_controls_pass = false
	if not order_controls_pass: failures += 1
	var report := {"label": args[1], "engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "width": size.x, "height": size.y, "shader_sha256": FileAccess.get_sha256("res://moth/surface.gdshader"), "order_controls_pass": order_controls_pass, "failures": failures, "results": results}
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("DEPTH_GRAPHICAL failures=", failures, " order_controls_pass=", order_controls_pass)
	quit(0 if failures == 0 else 1)

func pixel_distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
