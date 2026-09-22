extends SceneTree
## Real existing-playable-map baseline under the same harness.
##
## Builds one shipped native DM arena with its own builder (which owns its
## atmosphere and sun — this script adds no second environment or light) and
## samples five camera kinds that mirror the identity fixtures: spawn eye,
## landmark oblique, combat eye, objective eye, elevated worst-sector overview.
## Camera poses are derived from the generated envelope's own bounds and spawns,
## so the baseline is reproducible and is NOT a hand-tuned flattering angle.
##
## Scope: software-renderer frame cadence on this host. Not GPU acceptance.
const MAPS := {
	"cinder-array": preload("res://native_arenas/maps/cinder-array.gd"),
	"prism-foundry": preload("res://native_arenas/maps/prism-foundry.gd"),
}
var output := ""
var width := 1280
var height := 800
var ids: Array = []
var report: Dictionary = {"scope": "Existing playable native DM map baseline, same warm-up/sample harness; software renderer; camera names are locations", "maps": []}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--map="): ids = arg.trim_prefix("--map=").split(",")
		if arg.begins_with("--size="):
			var s := arg.trim_prefix("--size=").split("x")
			width = s[0].to_int()
			height = s[1].to_int()
	if output.is_empty():
		push_error("--output is required")
		quit(2)
		return
	if ids.is_empty(): ids = MAPS.keys()
	root.size = Vector2i(width,height)
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func _poses(id: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://native_arenas/generated/%s.json" % id))
	if not parsed is Dictionary: return []
	var arena: Dictionary = parsed.arena
	var bounds: Dictionary = arena.bounds
	var mid := Vector2((float(bounds.minX) + float(bounds.maxX)) * 0.5, (float(bounds.minZ) + float(bounds.maxZ)) * 0.5)
	var half := Vector2((float(bounds.maxX) - float(bounds.minX)) * 0.5, (float(bounds.maxZ) - float(bounds.minZ)) * 0.5)
	var spawns: Array = arena.spawns
	var a: Vector2 = Vector2(spawns[0][0], spawns[0][1]) if spawns.size() > 0 else mid
	var b: Vector2 = Vector2(spawns[1][0], spawns[1][1]) if spawns.size() > 1 else mid + Vector2(0, half.y * 0.5)
	return [
		{"id": "entrance", "at": [a.x, 1.7, a.y], "target": [mid.x, 4.0, mid.y]},
		{"id": "landmark", "at": [mid.x + half.x * 0.45, 7.0, mid.y + half.y * 0.45], "target": [mid.x, 6.0, mid.y]},
		{"id": "combat", "at": [mid.x - half.x * 0.5, 1.7, mid.y], "target": [mid.x + half.x * 0.5, 2.0, mid.y]},
		{"id": "objective", "at": [b.x, 2.0, b.y], "target": [mid.x, 2.0, mid.y]},
		{"id": "worst", "at": [mid.x + half.x * 1.05, half.x * 0.75, mid.y + half.y * 1.05], "target": [mid.x, 0.0, mid.y]},
	]

func _sample(entry: Dictionary, view: Dictionary, camera: Camera3D) -> void:
	camera.position = Vector3(view.at[0], view.at[1], view.at[2])
	camera.look_at(Vector3(view.target[0], view.target[1], view.target[2]))
	for i in range(12): await process_frame
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in range(40):
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now-previous)/1000.0)
		previous = now
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_width() != width or image.get_height() != height:
		push_error("Actual image dimensions differ from request: %s" % image.get_size())
		quit(4)
		return
	var filename := "%s-%s-%dx%d.png" % [str(entry.id), view.id, width, height]
	if image.save_png(output.path_join(filename)) != OK:
		push_error("Failed image save")
		quit(3)
		return
	samples.sort()
	(entry.cameras as Array).append({
		"id": view.id, "file": filename, "median_ms": samples[20], "p95_ms": samples[37],
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(width,height)
	await process_frame
	report.engine = Engine.get_version_info().string
	report.adapter = RenderingServer.get_video_adapter_name()
	report.renderer = RenderingServer.get_current_rendering_method()
	report.resolution = [width,height]
	for id: String in ids:
		if not MAPS.has(id):
			report.maps.append({"id": id, "error": "unknown baseline map"})
			continue
		var stage := Node3D.new()
		root.add_child(stage)
		var map: Node3D = (MAPS[id] as GDScript).new()
		var started := Time.get_ticks_usec()
		stage.add_child(map)
		if map.has_method("configure_dm"): map.call("configure_dm")
		await process_frame
		var build_ms := float(Time.get_ticks_usec() - started) / 1000.0
		var camera := Camera3D.new()
		camera.far = 320
		camera.fov = 72
		stage.add_child(camera)
		camera.current = true
		var entry: Dictionary = {"id": id, "build_ms": build_ms, "map_class": map.get_class(), "cameras": []}
		for view: Dictionary in _poses(id):
			await _sample(entry, view, camera)
		report.maps.append(entry)
		stage.queue_free()
		for i in range(3): await process_frame
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("IDENTITY_BASELINE ", JSON.stringify(report))
	quit(0)
