extends Node3D
## Fluid visibility curve fixture: one death splatter in front of a fixed camera,
## captured at a sequence of ages, for one quality budget. Everything here is an
## arranged source fixture, not live gameplay. Reports changed pixels against a
## clean baseline at each sample age, so the rendered density of a budget is a
## measured number instead of an assumption.
##
##   godot --path godot --rendering-method gl_compatibility \
##     res://tests/blood_fx/curve.tscn -- --width=640 --height=400 --quality=High

const Controller = preload("res://blood_fx/controller.gd")

const SAMPLES := [0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.3]
const DEATH := Vector3(0.0, 1.0, 3.0)
const GROUND := 20.0

var controller := Controller.new()
var camera := Camera3D.new()
var prefix := ""
var width := 640
var height := 400
var quality := "High"
var phase := 0
var elapsed := 0.0
var busy := false
var baseline: Image
var results: Array = []
var serial := 900

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): prefix = arg.trim_prefix("--output=")
		if arg.begins_with("--width="): width = int(arg.trim_prefix("--width="))
		if arg.begins_with("--height="): height = int(arg.trim_prefix("--height="))
		if arg.begins_with("--quality="): quality = arg.trim_prefix("--quality=")
	get_window().size = Vector2i(width, height)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	Engine.max_fps = 20
	Engine.time_scale = 0.08
	_geometry()
	add_child(camera)
	camera.position = Vector3(0, 1.7, 8.0)
	camera.look_at(Vector3(0, 1.2, 0))
	camera.current = true
	add_child(controller)
	controller.configure(camera, {
		"id": "blood-fx-curve-fixture",
		"bounds": {"minX": -GROUND, "maxX": GROUND, "minZ": -GROUND, "maxZ": GROUND},
		"blocks": [],
		"terrain": {"support_triangles": [
			{"indices": [0, 1, 2], "normal": [0, 1, 0], "vertices": [[-GROUND, 0, -GROUND], [-GROUND, 0, GROUND], [GROUND, 0, GROUND]]},
			{"indices": [0, 1, 2], "normal": [0, 1, 0], "vertices": [[-GROUND, 0, -GROUND], [GROUND, 0, GROUND], [GROUND, 0, -GROUND]]},
		]},
	})
	controller.set_quality(quality)
	controller.set_active(true, false)


func _geometry() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.07, 0.1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.52, 0.55)
	environment.ambient_light_energy = 0.85
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	add_child(light)
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(GROUND * 2.0, GROUND * 2.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.25, 0.27)
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)
	var wall := BoxMesh.new()
	wall.size = Vector3(16, 5, 0.5)
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.36, 0.37, 0.4)
	wall.material = wall_material
	var wall_instance := MeshInstance3D.new()
	wall_instance.mesh = wall
	wall_instance.position = Vector3(0, 2.5, -9)
	add_child(wall_instance)
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "BLOOD FX VISIBILITY CURVE FIXTURE · arranged source fixture, not live gameplay\n%s · %dx%d" % [quality, width, height]
	label.position = Vector2(12, 10)
	label.add_theme_font_size_override("font_size", 13)
	layer.add_child(label)


func _state() -> Dictionary:
	return {"time": elapsed, "mapId": "blood-fx-curve-fixture",
		"actors": [{"id": 4, "x": DEATH.x, "y": 0.0, "z": DEATH.z, "health": 100.0, "maxHealth": 100.0}]}


func _process(delta: float) -> void:
	if busy: return
	elapsed += delta
	busy = true
	await _step()
	busy = false


func _step() -> void:
	var clean := phase % 2 == 0
	if clean:
		controller.reset()
		serial += 1
		if phase > 0:
			_baseline_sample()
	else:
		# One fresh death splatter per sample, at the sample's own age.
		controller.apply_state(_state(), -1)
		controller.set_active(true, false)
		serial += 1
		controller.apply_events([{"type": "death", "id": serial, "actor": 4,
			"pos": {"x": DEATH.x, "y": DEATH.y, "z": DEATH.z}, "killer": 2,
			"direction": {"x": 0, "y": 0, "z": -1}, "overkill": 0.0, "seed": float(serial)}], -1)
		var index := phase / 2
		var target: float = SAMPLES[index] if index < SAMPLES.size() else 0.0
		# Wait until the sample age has elapsed in simulated time.
		while elapsed - _death_time < target and target > 0.0:
			await RenderingServer.frame_post_draw
			elapsed += get_process_delta_time()
		var shot := await _capture()
		var changed := difference(baseline, shot)
		var snapshot: Dictionary = controller.snapshot()
		results.append({"age_seconds": target, "changed_pixels": changed,
			"fraction": float(changed) / float(width * height),
			"submitted_slots": snapshot.submitted_slots, "allocated_slots": snapshot.allocated_slots,
			"stains_live": snapshot.stains_live, "active_emitters": snapshot.active_emitters})
		if not prefix.is_empty(): shot.save_png("%s-age-%03d.png" % [prefix, int(target * 1000.0)])
		if index >= SAMPLES.size() - 1:
			_finish()
			return
	phase += 1


var _death_time := 0.0

func _baseline_sample() -> void:
	_death_time = elapsed
	if baseline == null:
		baseline = await _capture()
		if not prefix.is_empty(): baseline.save_png(prefix + "-baseline.png")


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func difference(a: Image, b: Image) -> int:
	var changed := 0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.02: changed += 1
	return changed


func _finish() -> void:
	var record := {"quality": quality, "viewport": [width, height], "fixture": true, "live_gameplay": false,
		"renderer": RenderingServer.get_video_adapter_name(), "rendering_method": RenderingServer.get_current_rendering_method(),
		"hardware_gpu_measured": false, "software_renderer_note": "llvmpipe software rendering; not hardware acceptance",
		"samples": results, "stain_pool": controller.snapshot().stain_pool, "budget": controller.snapshot().budget,
		"concurrent_cap": controller.snapshot().concurrent_cap, "gpu_live_readback": false}
	print("BLOOD_FX_CURVE ", JSON.stringify(record))
	if not prefix.is_empty():
		var file := FileAccess.open(prefix + ".json", FileAccess.WRITE)
		file.store_string(JSON.stringify(record, "\t") + "\n")
	get_tree().quit(0)
