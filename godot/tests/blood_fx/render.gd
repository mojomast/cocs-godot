extends Node3D
## Rendered blood-FX fixture. EVERYTHING in this scene is an arranged source
## fixture: a flat-floor/ramp/wall/crate arrangement that is not live gameplay,
## driven by authoritative-shaped damage and death dictionaries. The same
## description builds the rendered meshes and the semantic surface query, so a
## stain that lands on a visible surface is a real query result.
##
## Run:
##   godot --path godot --rendering-method gl_compatibility \
##     res://tests/blood_fx/render.tscn -- --width=960 --height=640 \
##     --output=/path/prefix --quality=High
##
## Emits one JSON record and PNGs, including the rendered stain occlusion
## controls (behind opaque cover = zero changed pixels).

const Controller = preload("res://blood_fx/controller.gd")
const SurfaceQuery = preload("res://blood_fx/surface_query.gd")

const GROUND := 30.0
const WALL := {"x": 0.0, "z": -6.0, "w": 10.0, "h": 6.0, "d": 1.0}
const CRATE := {"x": 6.5, "z": 0.0, "w": 3.0, "h": 1.5, "d": 3.0}
const RAMP := [Vector3(-6, 0, 4), Vector3(-2, 0, 4), Vector3(-2, 3, 8), Vector3(-6, 3, 8)]
const RAMP_NORMAL := Vector3(0, 0.8, -0.6)

var controller := Controller.new()
var camera := Camera3D.new()
var label := Label.new()
var prefix := ""
var width := 960
var height := 640
var quality := "High"
var frame := 0
var finishing := false
var serial := 500
var baseline: Image
var behind: Image
var front: Image
var local_shot: Image
var remote_shot: Image
var hero: Image
var record: Dictionary = {}
var stains_behind := 0
var stains_front := 0
var stains_local := 0
var stains_remote := 0
var phase := 0
var elapsed := 0.0
var mean_delta := 0.0
var busy := false
var frame_count := 0
# Phase thresholds in simulated seconds. The fixture is driven by elapsed time,
# not frame numbers, so a slow software-rendered frame cannot collapse a phase:
# a capture always happens at the intended age of the fluid.
var schedule := [0.12, 0.18, 0.24, 0.32, 0.42, 0.52, 0.62, 1.05, 1.15, 1.55, 1.65, 2.35, 2.45, 2.75, 2.85, 3.15]


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): prefix = arg.trim_prefix("--output=")
		if arg.begins_with("--width="): width = int(arg.trim_prefix("--width="))
		if arg.begins_with("--height="): height = int(arg.trim_prefix("--height="))
		if arg.begins_with("--quality="): quality = arg.trim_prefix("--quality=")
	get_window().size = Vector2i(width, height)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# 20 fps ceiling: software rendering frames are long and the fixture slows
	# simulated time, so the two multiplied give a deterministic capture cadence.
	# The scaled delta keeps the fixture schedule and the GPU particle age on the
	# same clock: a 2 s software frame advances 0.16 s of fluid, not two seconds.
	Engine.max_fps = 20
	# Software rendering (llvmpipe) frames are far longer than a real frame, so
	# the fixture slows simulated time to keep both the phase schedule and the
	# GPU particle age on the same clock. This is a capture-harness setting, not
	# gameplay: a live session runs at normal time.
	Engine.time_scale = 0.12
	_build_environment()
	_build_geometry()
	add_child(camera)
	camera.position = Vector3(0, 4.2, 15.0)
	camera.look_at(Vector3(0, 1.4, 0))
	camera.fov = 70.0
	camera.current = true
	add_child(controller)
	var configured: Dictionary = controller.configure(camera, _fixture_map())
	controller.set_quality(quality)
	if not configured.ok:
		push_error("fixture configure failed: " + str(configured))
		get_tree().quit(1)
		return
	_build_hud()
	print("BLOOD_FX_FIXTURE " + JSON.stringify({"configured": configured, "map_id": "blood-fx-fixture",
		"fixture": true, "live_gameplay": false}))


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.07, 0.1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.47, 0.55)
	environment.ambient_light_energy = 0.75
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -35, 0)
	light.light_energy = 1.15
	add_child(light)


func _fixture_map() -> Dictionary:
	return {
		"id": "blood-fx-fixture",
		"bounds": {"minX": -GROUND, "maxX": GROUND, "minZ": -GROUND, "maxZ": GROUND},
		"blocks": [WALL, CRATE],
		"terrain": {
			"support_triangles": [
				{"indices": [0, 1, 2], "normal": [0, 1, 0], "vertices": [[-GROUND, 0, -GROUND], [-GROUND, 0, GROUND], [GROUND, 0, GROUND]]},
				{"indices": [0, 1, 2], "normal": [0, 1, 0], "vertices": [[-GROUND, 0, -GROUND], [GROUND, 0, GROUND], [GROUND, 0, -GROUND]]},
				{"indices": [0, 1, 2], "normal": [0, 0.8, -0.6], "vertices": [[-6, 0, 4], [-2, 0, 4], [-2, 3, 8]]},
				{"indices": [0, 1, 2], "normal": [0, 0.8, -0.6], "vertices": [[-6, 0, 4], [-2, 3, 8], [-6, 3, 8]]},
			],
			"wall_triangles": [],
			"surfaces": [],
		},
	}


func _box(block: Dictionary, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(block.w, block.h, block.d)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = Vector3(block.x, block.h * 0.5, block.z)
	add_child(instance)


func _build_geometry() -> void:
	var ground := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-GROUND, 0, -GROUND), Vector3(-GROUND, 0, GROUND), Vector3(GROUND, 0, GROUND),
		Vector3(-GROUND, 0, -GROUND), Vector3(GROUND, 0, GROUND), Vector3(GROUND, 0, -GROUND)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	ground.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.22, 0.23, 0.26)
	ground_material.roughness = 0.95
	ground.surface_set_material(0, ground_material)
	var ground_instance := MeshInstance3D.new()
	ground_instance.mesh = ground
	ground_instance.name = "FixtureFloor"
	add_child(ground_instance)
	_box(WALL, Color(0.34, 0.35, 0.38))
	_box(CRATE, Color(0.43, 0.34, 0.2))
	# The ramp renders exactly the triangles the surface query answers with.
	var ramp := ArrayMesh.new()
	var faces: Array = []
	faces.resize(Mesh.ARRAY_MAX)
	faces[Mesh.ARRAY_VERTEX] = PackedVector3Array([RAMP[0], RAMP[1], RAMP[2], RAMP[0], RAMP[2], RAMP[3]])
	faces[Mesh.ARRAY_NORMAL] = PackedVector3Array([RAMP_NORMAL, RAMP_NORMAL, RAMP_NORMAL, RAMP_NORMAL, RAMP_NORMAL, RAMP_NORMAL])
	ramp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, faces)
	var ramp_material := StandardMaterial3D.new()
	ramp_material.albedo_color = Color(0.3, 0.32, 0.3)
	ramp_material.roughness = 0.9
	ramp_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ramp.surface_set_material(0, ramp_material)
	var ramp_instance := MeshInstance3D.new()
	ramp_instance.mesh = ramp
	ramp_instance.name = "FixtureRamp"
	add_child(ramp_instance)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	label.position = Vector2(14, 12)
	label.add_theme_font_size_override("font_size", 15 if width <= 960 else 18)
	label.add_theme_color_override("font_color", Color("d8e6f2"))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	# Static on purpose: every pixel comparison below is a rendered control, so
	# the HUD must not change between captures. Live counters go to the console
	# and the JSON record instead.
	label.text = "BLOOD FX FIXTURE · arranged source fixtures, not live gameplay\n%s · %dx%d\nPooled fluid emitters + surface stains, no Decal nodes" % [quality, width, height]
	layer.add_child(label)


func _point(p: Vector3) -> Dictionary:
	return {"x": p.x, "y": p.y, "z": p.z}


## Arranged fixture actors: y is the standing surface height (source convention).
func _actors() -> Array:
	return [
		{"id": 11, "x": 2.0, "y": 0.0, "z": 6.0, "health": 100.0, "maxHealth": 100.0},
		{"id": 12, "x": -3.0, "y": 0.0, "z": 4.0, "health": 100.0, "maxHealth": 100.0},
		{"id": 13, "x": -4.0, "y": 1.5, "z": 6.0, "health": 100.0, "maxHealth": 100.0},
		{"id": 14, "x": 3.5, "y": 5.0, "z": 8.0, "health": 100.0, "maxHealth": 100.0},
		{"id": 15, "x": 0.0, "y": 0.0, "z": -12.0, "health": 100.0, "maxHealth": 100.0},
	]


func _state() -> Dictionary:
	return {"time": float(frame) / 60.0, "mapId": "blood-fx-fixture", "actors": _actors()}


## The fixture is an arranged capture scene, so it runs the controller without
## the live public-state watchdog (the stale drain is verified headlessly in
## tests/blood_fx/contracts.gd).
func _apply(value: Dictionary, local: int) -> void:
	controller.apply_state(value, local)
	controller.set_active(true, false)


func _damage(victim: int, source: int, amount: float) -> Dictionary:
	serial += 1
	return {"type": "damage", "id": serial, "actor": victim, "source": source, "amount": amount, "shield": 0.0}


func _death(victim: int, position: Vector3, killer: int, direction: Vector3, overkill: float = 0.0) -> Dictionary:
	serial += 1
	return {"type": "death", "id": serial, "actor": victim, "pos": _point(position), "killer": killer,
		"direction": _point(direction), "overkill": overkill, "seed": float(serial)}


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func difference(a: Image, b: Image) -> int:
	var changed := 0
	for y in range(0, a.get_height(), 1):
		for x in range(0, a.get_width(), 1):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.02: changed += 1
	return changed


func _process(delta: float) -> void:
	if finishing or busy: return
	elapsed += delta
	mean_delta = elapsed / maxf(1.0, float(frame_count))
	frame_count += 1
	if phase >= schedule.size(): return
	if elapsed < float(schedule[phase]): return
	busy = true
	var current := phase
	phase += 1
	await _step(current)
	busy = false


func _step(current: int) -> void:
	match current:
		0:
			baseline = await _capture()
			if not prefix.is_empty(): baseline.save_png(prefix + "-baseline.png")
		1:
			_apply(_state(), 11)
			controller.apply_events([
				_damage(11, 12, 6.0), _damage(12, 11, 24.0), _damage(13, 12, 52.0),
			], 11)
		2:
			controller.apply_events([
				_damage(11, 12, 34.0), _damage(12, 11, 48.0), _damage(13, 12, 90.0),
			], 11)
		3:
			# Flat-ground death.
			controller.apply_events([_death(14, Vector3(1.5, 1.0, 3.0), 11, Vector3(0.4, 0, 0.9), 12.0)], 11)
		4:
			# Ramp death: the pool must land on the tilted surface.
			controller.apply_events([_death(13, Vector3(-4.0, 2.5, 6.0), 12, Vector3(0.7, 0, 0.7), 40.0)], 11)
		5:
			# Mid-air death over the floor.
			controller.apply_events([_death(14, Vector3(3.5, 6.0, 8.0), 11, Vector3(-0.5, 0, 0.8), 5.0)], 11)
		6:
			controller.apply_events([
				_damage(11, 12, 12.0), _damage(12, 11, 8.0), _damage(13, 12, 62.0), _damage(11, 15, 40.0),
			], 11)
		7:
			hero = await _capture()
			if not prefix.is_empty(): hero.save_png(prefix + "-action.png")
		8:
			# Occlusion control, isolated: stains only (fluid alpha gain zero, so
			# measured pixels can only come from stain quads).
			controller.reset()
			_apply(_state(), -1)
			controller.settings.density = 0.0
			controller.apply_events([_death(15, Vector3(0.0, 2.5, -12.0), 11, Vector3(0, 0, 1), 0.0)], -1)
			stains_behind = controller.snapshot().stains_placed
		9:
			behind = await _capture()
			if not prefix.is_empty(): behind.save_png(prefix + "-behind-wall.png")
		10:
			# Front control: the same isolated stains, in full view.
			controller.reset()
			_apply(_state(), -1)
			for spot: Vector3 in [Vector3(0.0, 1.0, 6.0), Vector3(2.5, 1.0, 4.0), Vector3(-2.5, 1.0, 5.0)]:
				controller.apply_events([_death(12, spot, 11, Vector3(0.5, 0, 0.8), 0.0)], -1)
			stains_front = controller.snapshot().stains_placed
		11:
			front = await _capture()
			if not prefix.is_empty(): front.save_png(prefix + "-front-control.png")
		12:
			# Local-actor death: the eye is inside the splatter.
			controller.reset()
			controller.settings.density = 1.0
			var eye := camera.global_position
			var actors := _actors()
			actors.append({"id": 42, "x": eye.x, "y": eye.y - 0.9, "z": eye.z, "health": 100.0, "maxHealth": 100.0})
			_apply({"time": 2.0, "mapId": "blood-fx-fixture", "actors": actors}, 42)
			controller.apply_events([_death(42, Vector3(eye.x, eye.y, eye.z), 11, Vector3(0, 0, -1), 0.0)], 42)
			stains_local = controller.snapshot().stains_placed
		13:
			local_shot = await _capture()
			if not prefix.is_empty(): local_shot.save_png(prefix + "-local-death.png")
		14:
			# Remote control: the same burst on a body just ahead of the eye, so
			# the coverage cap is measured against a real nearby splatter.
			controller.reset()
			_apply(_state(), -1)
			var ahead := camera.global_position - camera.global_transform.basis.z * 1.6 - Vector3.UP * 1.1
			controller.apply_events([_death(14, ahead, 11, Vector3(0, 0, -1), 0.0)], -1)
			stains_remote = controller.snapshot().stains_placed
		15:
			remote_shot = await _capture()
			if not prefix.is_empty(): remote_shot.save_png(prefix + "-remote-control.png")
			_finish()


func _finish() -> void:
	finishing = true
	var snapshot: Dictionary = controller.snapshot()
	var behind_changed := difference(baseline, behind)
	var front_changed := difference(baseline, front)
	var local_changed := difference(baseline, local_shot)
	var remote_changed := difference(baseline, remote_shot)
	var pixels := width * height
	record = snapshot.duplicate(true)
	record.merge({
		"frames": frame, "mean_delta": mean_delta, "time_scale": Engine.time_scale,
		"max_fps_ceiling": Engine.max_fps,
		"fixture": "arranged source fixture: flat floor + ramp + wall + crate, not live gameplay",
		"live_gameplay": false, "requested_viewport": [width, height],
		"viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"godot": Engine.get_version_info().string, "renderer": RenderingServer.get_video_adapter_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(), "hardware_gpu_measured": false,
		"software_renderer_note": "llvmpipe software rendering; not hardware acceptance",
		"behind_wall_stains_placed": stains_behind, "behind_wall_changed_pixels": behind_changed,
		"front_control_stains_placed": stains_front, "front_control_changed_pixels": front_changed,
		"local_death_stains_placed": stains_local, "remote_control_stains_placed": stains_remote,
		"local_vs_remote_changed_pixels": local_changed, "remote_control_changed_pixels": remote_changed,
		"local_changed_fraction": float(local_changed) / float(pixels),
		"remote_changed_fraction": float(remote_changed) / float(pixels),
		"occlusion_negative_zero_pixels": behind_changed == 0,
		"screenshots": [prefix + "-action.png", prefix + "-behind-wall.png", prefix + "-front-control.png",
			prefix + "-local-death.png", prefix + "-remote-control.png"],
	}, true)
	var local_fraction := float(record.get("local_changed_fraction", 1.0))
	var remote_fraction := float(record.get("remote_changed_fraction", 0.0))
	var emitters := []
	for slot: Dictionary in controller.fluid_slots:
		if slot.remaining <= 0.0: continue
		emitters.append({"profile": slot.profile, "ratio": slot.ratio, "remaining": slot.remaining,
			"amount": slot.node.amount, "amount_ratio": slot.node.amount_ratio, "visible": slot.node.visible,
			"emitting": slot.node.emitting, "speed_scale": slot.node.speed_scale,
			"origin": [slot.position.x, slot.position.y, slot.position.z],
			"life": slot.material.get_shader_parameter("life"), "speed_max": slot.material.get_shader_parameter("speed_max"),
			"density_gain": slot.material.get_shader_parameter("density_gain"),
			"size_scale": slot.draw.get_shader_parameter("size_scale")})
	record["live_emitters"] = emitters
	record["stains_at_finish"] = controller.snapshot().stains_live
	var ok := behind_changed == 0 and front_changed > 200 and stains_behind > 0 and stains_front > 0 \
		and remote_fraction > 0.01 and local_fraction < 0.5 * remote_fraction and local_fraction <= 0.02
	print("BLOOD_FX_RENDER ", "PASS" if ok else "FAIL", " ", JSON.stringify(record))
	if not prefix.is_empty():
		var file := FileAccess.open(prefix + ".json", FileAccess.WRITE)
		file.store_string(JSON.stringify(record, "\t") + "\n")
	get_tree().quit(0 if ok else 1)
