extends SceneTree
## Native GL comparison harness. It does not load the shared world/session/viewer.
const Library = preload("res://moth/library.gd")
const Surfaces = preload("res://moth/surfaces.gd")
var output := "/tmp/opencode/moth-gallery.png"
var mode := "materials"
var size := Vector2i(1280, 800)
var viewports: Array[SubViewport] = []
var lut_viewports: Array[SubViewport] = []
var material_pairs: Array[ShaderMaterial] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	root.size = size
	root.content_scale_size = size
	call_deferred("build")

func label_at(parent: Node, text: String, position: Vector2, font_size: int = 16) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("d4e5ed"))
	parent.add_child(label)

func build() -> void:
	var background := ColorRect.new()
	background.color = Color("101923")
	background.size = Vector2(size)
	root.add_child(background)
	label_at(root, "MOTH / OFFLINE PIXELS + NATIVE MATERIALS", Vector2(22, 12), 23)
	if mode == "materials": build_materials()
	else: build_atlas()
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	if screenshot.get_size() != size:
		push_error("Screenshot resolution differs: %s != %s" % [screenshot.get_size(), size])
		screenshot.save_png(output)
		quit(1)
		return
	var error := screenshot.save_png(output)
	if error != OK:
		push_error("Screenshot failed: " + str(error))
		quit(1)
		return
	if mode == "materials":
		# Measured A/B with identical geometry, camera, lighting and texture, only normals toggled.
		var before: Array[Image] = []
		for viewport in viewports: before.append(viewport.get_texture().get_image())
		var lut_measurements: Array[Dictionary] = []
		for i in lut_viewports.size(): lut_measurements.append(image_delta(before[i], lut_viewports[i].get_texture().get_image(), i))
		for material in material_pairs: material.set_shader_parameter("normal_strength", 0.0)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		var measurements: Array[Dictionary] = []
		var unperturbed: Array[Image] = []
		for i in viewports.size():
			var after := viewports[i].get_texture().get_image()
			unperturbed.append(after)
			measurements.append(image_delta(before[i], after, i))
		for material in material_pairs: material.set_shader_parameter("vertex_tint", false)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		var tint_measurements: Array[Dictionary] = []
		for i in viewports.size(): tint_measurements.append(image_delta(unperturbed[i], viewports[i].get_texture().get_image(), i))
		var file := FileAccess.open(output + ".json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"size": [size.x, size.y], "normal_ab": measurements, "vertex_tint_ab": tint_measurements, "lut_ab": lut_measurements}, "\t") + "\n")
		for measure in measurements + tint_measurements + lut_measurements:
			if measure.changed_pixels < 10:
				push_error("Normal, vertex tint or LUT had no measurable rendered effect: " + str(measure))
				quit(1)
				return
	print("MOTH_GALLERY ", output)
	quit()

func image_delta(before: Image, after: Image, row: int) -> Dictionary:
	var changed := 0
	var total := 0.0
	for y in after.get_height():
		for x in after.get_width():
			var aa := before.get_pixel(x, y)
			var bb := after.get_pixel(x, y)
			var delta := absf(aa.r - bb.r) + absf(aa.g - bb.g) + absf(aa.b - bb.b)
			total += delta
			if delta > 0.005: changed += 1
	return {"row": row, "changed_pixels": changed, "mean_rgb_absolute_delta": total / (after.get_width() * after.get_height() * 3)}

func build_atlas() -> void:
	var entries: Array[Dictionary] = []
	var manifest := Library.manifest()
	if mode == "textures":
		for key in manifest.textures: entries.append({"name": key, "texture": Library.texture(key)})
		for key in manifest.normals: entries.append({"name": "normal / " + key, "texture": Library.normal(key)})
	else:
		for key in manifest.sky: entries.append({"name": "sky / " + key, "texture": Library.sky(key)})
		for key in manifest.materials:
			for part in ["r", "t"]: entries.append({"name": key + " / " + part, "texture": Library.material_lut(key)[part]})
		for key in manifest.effects:
			var effect := Library.effect(key)
			for i in effect.frames.size(): entries.append({"name": "%s / %d @%d" % [key, i, effect.fps], "texture": effect.frames[i]})
	var columns := 8
	var rows := ceili(float(entries.size()) / columns)
	var cell := Vector2((size.x - 32.0) / columns, (size.y - 76.0) / rows)
	for i in entries.size():
		var pos := Vector2(16 + (i % columns) * cell.x, 54 + (i / columns) * cell.y)
		var rect := TextureRect.new()
		rect.position = pos
		rect.size = Vector2(cell.x - 8, cell.y - 27)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.texture = entries[i].texture
		root.add_child(rect)
		label_at(root, entries[i].name, pos + Vector2(0, cell.y - 26), 10)
	label_at(root, "Raw source pixels / nearest inspection / LUT and normal previews show stored bytes", Vector2(18, size.y - 21), 12)

func build_materials() -> void:
	var keys := ["weathered_concrete", "diamond_plate", "hex_paneling", "rock"]
	var titles := ["SEMANTIC COLOR", "TRIPLANAR + NORMAL", "+ LINEAR LUT ACCENT"]
	var colors := [Color("b6c6cc"), Color("a2b1c1"), Color("a0cfc6"), Color("b2b6ae")]
	var cell := Vector2i((size.x - 40) / 3, (size.y - 116) / 4)
	for col in 3: label_at(root, titles[col], Vector2(18 + col * cell.x, 48), 15)
	for row in 4:
		for col in 3:
			var position := Vector2(18 + col * cell.x, 76 + row * cell.y)
			var container := SubViewportContainer.new()
			container.position = position
			root.add_child(container)
			var viewport := SubViewport.new()
			viewport.size = cell - Vector2i(8, 26)
			viewport.own_world_3d = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			viewport.msaa_3d = Viewport.MSAA_4X
			container.add_child(viewport)
			var environment := WorldEnvironment.new()
			environment.environment = Environment.new()
			environment.environment.background_mode = Environment.BG_COLOR
			environment.environment.background_color = Color("1b2a36")
			environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.environment.ambient_light_color = Color("bccddd")
			environment.environment.ambient_light_energy = 0.55
			viewport.add_child(environment)
			var sun := DirectionalLight3D.new()
			sun.rotation_degrees = Vector3(-38, -32, 0)
			sun.light_energy = 0.9
			viewport.add_child(sun)
			var camera := Camera3D.new()
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 3.6
			viewport.add_child(camera)
			camera.position = Vector3(4, 3, 5)
			camera.look_at(Vector3.ZERO)
			var material := Surfaces.create_surface(keys[row] if col > 0 else "", colors[row], true)
			if col == 2: Surfaces.apply_lut(material, "entanglement-arcane", 0.24, 0.8)
			if col == 1:
				viewports.append(viewport)
				material_pairs.append(material)
			if col == 2: lut_viewports.append(viewport)
			var instance := MeshInstance3D.new()
			# Erase real UVs/tangents: UV.x is reserved for semantic depth priority.
			var box := BoxMesh.new()
			box.size = Vector3(4.3, 1.5, 2.1)
			var arrays := box.get_mesh_arrays()
			arrays[Mesh.ARRAY_TANGENT] = null
			var uv := PackedVector2Array()
			var tint := PackedColorArray()
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				uv.append(Vector2(0.3, 0))
				tint.append(Color.WHITE.lerp(Color("a4b7c6"), clampf((vertex.y + 0.75) / 3.0, 0, 1)))
			arrays[Mesh.ARRAY_TEX_UV] = uv
			arrays[Mesh.ARRAY_COLOR] = tint
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			instance.mesh = mesh
			instance.material_override = material
			viewport.add_child(instance)
			label_at(root, keys[row], position + Vector2(0, cell.y - 26), 13)
	label_at(root, "Identical no-UV meshes + vertex COLOR / original pixels / world-space repeat 0.5 / normal strength 0.24", Vector2(18, size.y - 26), 12)
