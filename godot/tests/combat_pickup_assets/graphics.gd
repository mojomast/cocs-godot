extends SceneTree
const Pickups = preload("res://world/pickups.gd")
const Legacy = preload("res://world/pickup_visual.gd")
var output := ""
var size := Vector2i(960, 640)
var failed := false
var rig: Node3D
var camera: Camera3D
var view: Node3D
var measurements := {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--size="):
			var dimensions := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	create_timer(120.0).timeout.connect(func() -> void: push_error("pickup render watchdog"); quit(1))
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func box(pos: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	node.material_override = material
	node.position = pos
	rig.add_child(node)
	return node

func freeze() -> void:
	for node: Node3D in view.markers.values():
		node.set_process(false)
		node.reset_presentation()

func capture(title: String) -> Image:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not title.is_empty(): check(image.save_png(output.path_join(title + ".png")) == OK, "save " + title)
	return image

func difference(a: Image, b: Image) -> Dictionary:
	var count := 0
	var maximum := 0.0
	for y in range(size.y):
		for x in range(size.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var delta := maxf(absf(ca.r-cb.r), maxf(absf(ca.g-cb.g), absf(ca.b-cb.b)))
			maximum = maxf(maximum, delta)
			if delta > 0.025: count += 1
	return {"changed_pixels": count, "max_delta": maximum}

func run() -> void:
	check(not output.is_empty(), "output path required")
	if failed: quit(1); return
	root.size = size
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/combat_pickup_assets/source.json"))
	var initial: Dictionary = fixture.frames[0].state
	rig = Node3D.new()
	root.add_child(rig)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101a27")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bdccdd")
	environment.environment.ambient_light_energy = 0.7
	rig.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -32, 0)
	light.light_energy = 1.6
	rig.add_child(light)
	box(Vector3(0, -0.1, -3), Vector3(16, 0.2, 22), Color("24384a"))
	box(Vector3(0, 1.5, -9), Vector3(16, 3, 0.3), Color("30485b"))
	for x in range(-4, 5): box(Vector3(x * 1.3, 0.005, -3), Vector3(0.012, 0.01, 16), Color("476172"))
	for z in range(-8, 4): box(Vector3(0, 0.006, z * 1.0), Vector3(12, 0.01, 0.012), Color("476172"))
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.6, 5)
	camera.fov = 75
	camera.current = true
	rig.add_child(camera)
	camera.look_at(Vector3(0, 1.0, -2))
	var caption := Label.new()
	caption.text = "NATIVE SUPPLIES / arranged source snapshot fixture / eye 1.6 m"
	caption.position = Vector2(22, 18)
	caption.add_theme_font_size_override("font_size", 16)
	root.add_child(caption)
	view = Pickups.new()
	rig.add_child(view)
	var baseline := await capture("empty-baseline")
	var old := Node3D.new()
	rig.add_child(old)
	for pickup: Dictionary in initial.pickups:
		var marker := Legacy.new()
		old.add_child(marker)
		marker.apply_kind(pickup.kind)
		marker.position = Vector3(pickup.x, pickup.y + 1.0, pickup.z)
	await capture("before-legacy")
	old.free()
	view.apply_state(initial)
	freeze()
	var available := await capture("after-native")
	measurements.visible = difference(baseline, available)
	check(measurements.visible.changed_pixels > 1800, "native models visibly contribute")
	var same := await capture("")
	check(difference(available, same).max_delta == 0.0, "paused deterministic render")
	for i in range(10):
		for node: Node3D in view.markers.values(): node._process(0.1)
	var animated := await capture("energy-bands-active")
	measurements.animation = difference(available, animated)
	check(measurements.animation.changed_pixels > 150, "bounded native motion and Moth energy bands animate")
	freeze()
	view.apply_state(fixture.frames[1].state)
	freeze()
	var collected := await capture("health-source-collected")
	measurements.collection = difference(available, collected)
	check(measurements.collection.changed_pixels > 150, "real source health collection removes model")
	view.apply_state(fixture.frames[2].state)
	freeze()
	var unavailable := await capture("all-source-unavailable")
	measurements.unavailable = difference(baseline, unavailable)
	check(measurements.unavailable.max_delta == 0.0, "wait-positive pickups render zero pixels including rings")
	view.apply_state(fixture.frames[3].state)
	freeze()
	var respawn := await capture("source-respawn")
	check(difference(available, respawn).max_delta == 0.0, "actual source respawn restores identical presentation")
	view.clear_round()
	var cleared := await capture("after-clear")
	measurements.clear = difference(baseline, cleared)
	check(measurements.clear.max_delta == 0.0 and view.get_child_count() == 0, "clear leaves zero models/rings/labels")
	# Full-image occlusion test of one real source pickup behind opaque geometry.
	var block := box(Vector3(-2.262, 1.078, 0.65), Vector3(1.25, 2.05, 0.25), Color("a07c56"))
	var blocked_baseline := await capture("occlusion-empty")
	view.apply_state({"pickups": [initial.pickups[0]]})
	freeze()
	var occluded := await capture("occlusion-native")
	measurements.occlusion = difference(blocked_baseline, occluded)
	check(measurements.occlusion.max_delta == 0.0, "opaque cover fully occludes model and Moth ring")
	block.free()
	view.apply_state(initial)
	freeze()
	# Close source-coordinate rows: all 20 authored kinds, at playable eye height.
	for row in range(4):
		# Inspect one source row at a time to avoid the preceding row intersecting
		# the close camera. Positions/kinds remain byte-for-byte source values.
		view.apply_state({"pickups": initial.pickups.slice(row * 5, row * 5 + 5)})
		freeze()
		camera.position = Vector3(0, 1.6, 3.0 - row * 2.0)
		camera.look_at(Vector3(0, 0.95, -row * 2.0))
		await capture("detail-row-%d" % row)
	measurements["budget"] = {"pickups": initial.pickups.size(), "draws": initial.pickups.size() * 4, "render_nodes": initial.pickups.size() * 4, "particles": 0, "labels": 0, "eye_height": 1.6, "size": [size.x, size.y]}
	var file := FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements, "\t") + "\n")
	file.close()
	print("PICKUP_RENDER_OK ", JSON.stringify(measurements))
	rig.free()
	caption.free()
	quit(1 if failed else 0)
