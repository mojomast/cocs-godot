extends SceneTree
## Explicit test-only paired runtime captures; no PNG processing or promotion.
const WorldMap = preload("res://multiplayer_worlds/map.gd")
const Binder = preload("res://multiplayer_worlds/dressing/binder.gd")
const Presentation = preload("res://multiplayer_worlds/abyssal_presentation.gd")
const DIR := "res://tests/new_maps/abyssal_pressureworks/corrective/"
var output := ""
var result := {"status": "started", "captures": [], "failures": [],
	"finishScope": "WorldMap + Abyssal production presentation + candidate-only preserve-PBR Binder; no WeatherService in parent snapshot; not hosted play"}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")
	create_timer(210.0).timeout.connect(func() -> void: fail("capture timeout"))

func fail(message: String) -> void:
	result.failures.append(message)
	result.status = "failed"
	finish(2)

func finish(code: int) -> void:
	if output != "":
		var file := FileAccess.open(output.path_join("capture-report.json"), FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result, "\t") + "\n")
	quit(code)

func json_at(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func run() -> void:
	if output == "" or DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("explicit writable output required")
		return
	root.size = Vector2i(1280, 720)
	var manifest := json_at(DIR + "stage-manifest.json")
	var candidate := json_at(DIR + "candidate.json")
	if candidate.get("geometryHash") != manifest.get("geometryHash") or FileAccess.get_sha256(DIR + "corrective.glb") != manifest.get("glbSha256"):
		fail("staged candidate identity changed")
		return
	var views := [
		{"id":"sw-player-wall", "eye":[-94,8.0,-86], "target":[-94,7.4,-101]},
		{"id":"sw-terrace-walk", "eye":[-103,8.0,-95], "target":[-89,7.6,-96]},
		{"id":"sw-observation-bay", "eye":[-94,8.0,-70], "target":[-94,8.5,-101]},
		{"id":"sw-exterior-detail", "eye":[-94,8.2,-110], "target":[-94,8.5,-102]},
		{"id":"se-player-wall", "eye":[91,2.0,-89], "target":[103,2.2,-90]},
		{"id":"se-terrace-walk", "eye":[84,2.0,-90], "target":[100,2.1,-91]},
		{"id":"se-exterior-detail", "eye":[112,2.2,-90], "target":[104,2.2,-90]},
		{"id":"overhead-route", "eye":[-75,15,-72], "target":[-87,8,-92]},
	]
	for variant: String in ["accepted-runtime-before", "corrective-candidate-binder"]:
		var holder := Node3D.new()
		root.add_child(holder)
		var data := candidate if variant == "corrective-candidate-binder" else json_at("res://multiplayer_worlds/generated/abyssal-pressureworks.json")
		var world := WorldMap.new()
		holder.add_child(world)
		if not world.build(data):
			fail("WorldMap build failed: " + variant)
			return
		var dressing: Dictionary = world.metrics.get("dressing", {})
		if variant == "corrective-candidate-binder":
			var old := world.get_node_or_null("BlenderArtNoGameplayCollision")
			if old != null:
				world.remove_child(old)
				old.free()
			var scene: Variant = load(DIR + "corrective.glb")
			if not scene is PackedScene:
				fail("corrective GLB not imported")
				return
			var art: Node3D = scene.instantiate()
			art.name = "BlenderArtNoGameplayCollision"
			world.add_child(art)
			dressing = Binder.apply(world, str(data.id), str(data.geometryHash))
			if dressing.get("status") != "ready":
				fail("candidate Binder did not preserve actual art PBR: " + str(dressing))
				return
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-45, -30, 0)
		sun.shadow_enabled = true
		holder.add_child(sun)
		var environment := WorldEnvironment.new()
		var settings := Environment.new()
		settings.background_mode = Environment.BG_COLOR
		settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		Presentation.configure(sun, settings)
		environment.environment = settings
		holder.add_child(environment)
		var camera := Camera3D.new()
		camera.far = 600
		camera.fov = 68
		holder.add_child(camera)
		camera.make_current()
		for view: Dictionary in views:
			camera.position = Vector3(view.eye[0], view.eye[1], view.eye[2])
			camera.look_at(Vector3(view.target[0], view.target[1], view.target[2]))
			var start := Time.get_ticks_usec()
			for frame in range(8): await process_frame
			await RenderingServer.frame_post_draw
			var cadence := Time.get_ticks_usec() - start
			var path := output.path_join(str(view.id) + "-" + variant + ".png")
			var image := root.get_texture().get_image()
			if image.get_width() != 1280 or image.get_height() != 720 or image.save_png(path) != OK:
				fail("invalid original capture: " + path)
				return
			result.captures.append({"view": view.id, "variant": variant, "eye": view.eye,
				"target": view.target, "geometryHash": data.geometryHash, "width": image.get_width(),
				"height": image.get_height(), "file": path, "sha256": FileAccess.get_sha256(path),
				"dressing": dressing, "renderer": RenderingServer.get_video_adapter_name(),
				"eightFrameMicroseconds": cadence, "staticMeanFrameMs": float(cadence) / 8000.0,
				"drawCalls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"videoMemoryBytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
				"staticMemoryBytes": OS.get_static_memory_usage(),
				"scope": "8 settled frames/static view on recorded backend; not hosted movement FPS"})
		holder.free()
		await process_frame
	result.status = "paired original PNGs captured; finish and hosted manual acceptance pending"
	finish(0)
