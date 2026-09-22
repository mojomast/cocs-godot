extends Node3D
## Rendered combat fixture in the ordinary semantic arena renderer, with a POV
## dummy HUD. No particle-lab scene, analytic particles, or fabricated live server.
const Viewer = preload("res://world/viewer.gd")
const Manager = preload("res://combat_particles/manager.gd")
var viewer := Viewer.new()
var manager := Manager.new()
var label := Label.new()
var frame := 0
var previous_usec := 0
var samples := PackedFloat64Array()
var points: Array[Vector3] = []
var serial := 1000
var replay_time := 0.0
var prefix := ""
var quality := "Extreme"
var map_id := "meridian-exchange"
var width := 1280
var height := 800
var sample_count := 72
var peak_draw_slots := 0
var baseline := false
var startup_usec := 0
var configured_ms := 0.0
var finishing := false

func _ready() -> void:
	startup_usec = Time.get_ticks_usec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): prefix = arg.trim_prefix("--output=")
		if arg.begins_with("--quality="): quality = arg.trim_prefix("--quality=")
		if arg.begins_with("--map="): map_id = arg.trim_prefix("--map=")
		if arg.begins_with("--samples="): sample_count = int(arg.trim_prefix("--samples="))
		if arg == "--small": width = 800; height = 600
		if arg == "--baseline": baseline = true
	get_window().size = Vector2i(width, height)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	add_child(viewer)
	if not viewer.load_map(map_id): get_tree().quit(1); return
	viewer.set_process(false)
	viewer.selector.hide()
	viewer.label.hide()
	add_child(manager)
	var configured: Dictionary = manager.configure(viewer.camera, map_id)
	if not configured.ok: push_error(str(configured)); get_tree().quit(1); return
	manager.set_quality(quality)
	manager.set_active(true, false)
	var map: Dictionary = viewer.catalog.resolve_map(map_id)
	var spawn: Array = map.spawns[0]
	viewer.camera.position = Vector3(spawn[0], viewer.support_height(map, spawn[0], spawn[1]) + 2.0, spawn[1])
	viewer.camera.look_at(Vector3(0, 2, 0))
	viewer.camera.current = true
	# Deterministic, bounded authored replay sites in real map coordinates. Sites
	# include the near-wall/free-space boundary, not a separate laboratory stage.
	for z in range(-30, 35, 4):
		for x in range(-40, 40, 4):
			var p := Vector3(x, viewer.support_height(map, x, z) + 2.0, z)
			var distance := viewer.camera.position.distance_to(p)
			if distance > 6 and distance < 35 and not manager.occupancy.solid(p): points.append(p)
	if points.size() < 28: push_error("Insufficient free replay sites"); get_tree().quit(1); return
	var ui := CanvasLayer.new()
	add_child(ui)
	label.position = Vector2(16, 16)
	label.add_theme_font_size_override("font_size", 17 if width == 800 else 20)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	ui.add_child(label)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.position = Vector2(width / 2.0 - 5, height / 2.0 - 10)
	ui.add_child(crosshair)
	var status := Label.new()
	status.position = Vector2(20, height - 70)
	status.add_theme_font_size_override("font_size", 21)
	status.text = "100 HEALTH     75 ARMOR                         ROCKET / PLASMA\nPOV dummy HUD · authoritative-shape combat replay"
	ui.add_child(status)
	configured_ms = (Time.get_ticks_usec() - startup_usec) / 1000.0
	if baseline: manager.reset()
	else: _bursts(20)
	previous_usec = Time.get_ticks_usec()

func _point(p: Vector3) -> Dictionary:
	return {"x": p.x, "y": p.y, "z": p.z}

func _bursts(count: int) -> void:
	var events := []
	for i in range(count):
		var p: Vector3 = points[(serial * 7) % points.size()]
		events.append({"type": "explosion", "id": serial, "weapon": 4 if serial % 5 == 0 else 1, "pos": _point(p)})
		serial += 1
	manager.consume(events, 7)

func _process(_delta: float) -> void:
	if points.is_empty() or finishing: return
	var now := Time.get_ticks_usec()
	var ms := (now - previous_usec) / 1000.0
	previous_usec = now
	frame += 1
	replay_time += 1.0 / 30.0
	if not baseline:
		var rockets := []
		for i in range(8):
			var p: Vector3 = points[(i * 11) % points.size()] + Vector3(0, sin(replay_time + i) * 0.45, 0)
			rockets.append({"id": i + 1, "owner": 7 if i < 2 else 2, "weapon": 4 if i % 2 else 1, "pos": _point(p), "dir": _point(Vector3.RIGHT)})
		manager.apply_state({"time": replay_time, "rockets": rockets}, 7)
		if frame % 6 == 0: _bursts(4)
	var snap: Dictionary = manager.snapshot()
	peak_draw_slots = maxi(peak_draw_slots, snap.draw_slots)
	label.text = "%s · IN-WORLD COMBAT REPLAY\n%s  |  %s  |  %s\n%,d shared allocated / %,d submitted draw slots\n%d bursts · %d persistent trails · 4 weather fields\nFrame %.1f ms · geometry depth + voxel collision".replace("%,d", "%d") % [map_id.to_upper(), quality, "GPUParticles3D", "BASELINE" if baseline else "STATEFUL GPU", snap.allocated_slots, snap.draw_slots, snap.burst_emitters, snap.trail_emitters, ms]
	if frame > 16: samples.append(ms)
	if frame == 25 and not prefix.is_empty(): _capture(prefix + ".png")
	if samples.size() >= sample_count: _finish()

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != Vector2i(width, height):
		push_error("Actual capture resolution mismatch: %s expected %s" % [image.get_size(), Vector2i(width, height)])
		get_tree().quit(1)
		return
	var error := image.save_png(path)
	if error != OK: push_error("Capture failed: " + str(error))

func _finish() -> void:
	finishing = true
	var ordered := samples.duplicate()
	ordered.sort()
	var record := manager.snapshot()
	record.merge({"fixture": "normal world/viewer.gd semantic arena + POV dummy HUD", "baseline": baseline,
		"viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y], "requested_viewport": [width, height], "renderer": RenderingServer.get_video_adapter_name(), "adapter_vendor": RenderingServer.get_video_adapter_vendor(),
		"rendering_method": RenderingServer.get_current_rendering_method(), "godot": Engine.get_version_info().string,
		"hardware_gpu_measured": false, "sample_count": samples.size(), "warmup_frames": 16,
		"median_ms": ordered[ordered.size() / 2], "p95_ms": ordered[mini(ordered.size() - 1, ceili(ordered.size() * 0.95) - 1)],
		"max_ms": ordered[-1], "frame_ms": Array(samples), "configure_ms": configured_ms,
		"wall_seconds": (Time.get_ticks_usec() - startup_usec) / 1000000.0, "peak_submitted_draw_slots": peak_draw_slots,
		"scene_draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"scene_primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"scene_objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"geometry_blocks": viewer.world.get_meta("semantic_block_count"), "geometry_triangles": viewer.world.get_meta("semantic_triangle_count"),
		"screenshot": prefix + ".png", "source_event_ids_generated": serial - 1000}, true)
	print("COMBAT_PARTICLES_RENDERED ", JSON.stringify(record))
	if not prefix.is_empty():
		var file := FileAccess.open(prefix + ".json", FileAccess.WRITE)
		file.store_string(JSON.stringify(record, "\t") + "\n")
	manager.reset()
	get_tree().quit(0 if baseline or peak_draw_slots == manager.budget else 1)
