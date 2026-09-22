extends SceneTree
## Blood/spatter evidence through the REAL shared composition (not the blood lane's
## standalone controller). Arranged authority events on real map geometry: a remote
## operator is damaged and killed in view, and the frames are captured at both sizes.
## This is a labelled fixture with arranged events — not live gameplay.

const Feedback = preload("res://world/combat_feedback.gd")
const Catalog = preload("res://world/catalog.gd")
const OperatorVisual = preload("res://source_operators/operator_visual.gd")

var output := ""
var size := Vector2i(1280, 800)
var feedback: Node3D
var camera: Camera3D
var failed := 0
var checks := 0

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument.begins_with("--size="):
			var parts := argument.trim_prefix("--size=").split("x")
			if parts.size() == 2: size = Vector2i(int(parts[0]), int(parts[1]))
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error("BLOOD_CAPTURE: " + message)

func build_map(parent: Node3D, catalog: Variant, id: String) -> void:
	var map: Dictionary = catalog.resolve_map(id)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("5a6774")
	metal.roughness = 0.85
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color("8d8477")
	ground.roughness = 1.0
	for block: Dictionary in map.get("blocks", []):
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(block.w, block.h, block.d)
		mesh.mesh = box
		mesh.material_override = metal
		mesh.position = Vector3(block.x, block.h * 0.5, block.z)
		parent.add_child(mesh)
	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(160, 0.4, 160)
	slab.mesh = slab_mesh
	slab.material_override = ground
	slab.position = Vector3(0, -0.2, 0)
	parent.add_child(slab)

func difference(a: Image, b: Image, rect: Rect2i) -> int:
	var changed := 0
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO, a.get_size()))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			if a.get_pixel(x, y) != b.get_pixel(x, y): changed += 1
	return changed

func capture(name: String) -> Image:
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(output.path_join(name + ".png"))
	return image

func run() -> void:
	if output.is_empty():
		push_error("BLOOD_CAPTURE requires --output")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var world := Node3D.new()
	root.add_child(world)
	var catalog := Catalog.new()
	check(catalog.open(), "authoritative nine-map catalog opens")
	build_map(world, catalog, "meridian-exchange")
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	world.add_child(sun)
	camera = Camera3D.new()
	camera.position = Vector3(25.4, 1.75, -30.6)
	world.add_child(camera)
	camera.look_at(Vector3(28.0, 0.9, -34.0))
	camera.current = true
	camera.make_current()
	feedback = Feedback.new()
	world.add_child(feedback)
	feedback.configure_effects(camera, null)

	var label := Label.new()
	label.position = Vector2(28, 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	var layer := CanvasLayer.new()
	layer.layer = 4
	layer.add_child(label)
	root.add_child(layer)

	var local := {"id": 0, "x": 25.4, "y": 0.85, "z": -30.6, "health": 100, "maxHealth": 100, "dead": 0, "protection": 0, "yaw": 0, "pitch": 0, "weapon": 0, "grounded": true}
	var remote := {"id": 1, "x": 28.0, "y": 0.0, "z": -34.0, "health": 100, "maxHealth": 100, "dead": 0, "character": "meta", "team": 1, "weapon": 3, "yaw": 0.6, "bodyYaw": 0.6}
	# Real imported operator body so the fixture shows a genuine actor being hit.
	var remote_visual: Node3D = OperatorVisual.new()
	world.add_child(remote_visual)
	remote_visual.position = Vector3(remote.x, remote.y + 0.9, remote.z)
	remote_visual.rotation.y = remote.bodyYaw
	remote_visual.apply_actor(remote)
	for step in range(30): remote_visual.advance(1.0 / 60.0)
	var state := {"mapId": "meridian-exchange", "time": 1.0, "over": false, "actors": [local, remote]}
	feedback.apply_state(state)
	feedback._process(0.016)
	label.text = "BLOOD FIXTURE - arranged authority events on real map geometry, not live gameplay\nclean baseline %dx%d" % [size.x, size.y]
	var clean := await capture("clean")

	# Remote hit: 45 health damage. Arterial pulse plus a directional jet.
	remote.health = 55
	state.time = 1.4
	feedback.apply_state(state)
	feedback.apply_events([{"type": "damage", "id": 11, "actor": 1, "source": 0, "amount": 45, "shield": 0}], 0)
	feedback.flush_effects()
	feedback._process(0.05)
	label.text = "BLOOD FIXTURE - remote hit for 45 health damage\npooled jet + arterial pulse, real surfaces %dx%d" % [size.x, size.y]
	var spurt := await capture("spurt")
	feedback._process(0.25)
	var spurt_late := await capture("spurt-late")

	# Remote death: burst, growing pool, radial stains on the real floor.
	remote.health = 0
	remote.dead = 1
	state.time = 2.1
	feedback.apply_state(state)
	feedback.apply_events([{"type": "damage", "id": 12, "actor": 1, "source": 0, "amount": 60, "shield": 0},
		{"type": "death", "id": 13, "actor": 1, "killer": 0}], 0)
	feedback.flush_effects()
	feedback._process(0.06)
	label.text = "BLOOD FIXTURE - remote death splatter\nburst + floor pool + surface staining %dx%d" % [size.x, size.y]
	var death := await capture("death")
	feedback._process(0.9)
	var death_late := await capture("death-late")

	var rect := Rect2i(0, 0, size.x, size.y)
	var spurt_pixels := difference(clean, spurt, rect)
	var late_pixels := difference(clean, spurt_late, rect)
	var death_pixels := difference(clean, death, rect)
	var stain_pixels := difference(spurt, death_late, rect)
	check(spurt_pixels > 200, "remote hit renders visible fluid")
	check(late_pixels > 200, "spurt remains visible while it ages")
	check(death_pixels > 800, "death splatter renders visibly")
	check(stain_pixels > 40, "death adds staining beyond the earlier spurt")
	print("BLOOD_CAPTURE_OK ", JSON.stringify({"size": "%dx%d" % [size.x, size.y], "checks": checks,
		"failures": failed, "spurt_changed_pixels": spurt_pixels, "spurt_late_changed_pixels": late_pixels,
		"death_changed_pixels": death_pixels, "stain_delta_pixels": stain_pixels,
		"scope": "arranged authority events on the real composition; not live gameplay"}))
	feedback.free()
	world.free()
	quit(1 if failed else 0)
