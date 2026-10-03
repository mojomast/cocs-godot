extends SceneTree
## Native staged WorldMap + production Binder + WeatherService, not bare GLB.
const Stage = preload("res://tests/new_maps/gravemill_foundry/revision7/staged.gd")
const StageR6 = preload("res://tests/new_maps/gravemill_foundry/revision6/staged.gd")
const Weather = preload("res://ambience/weather_service.gd")
const OUT := "res://../tools/godot-multiplayer/new-maps/gravemill-foundry/revision7/evidence/native/"

func _initialize() -> void:
	call_deferred("run")
	create_timer(180).timeout.connect(func() -> void: push_error("R6 capture timeout"); quit(2))

func run() -> void:
	root.size = Vector2i(1280,720)
	var probes := Stage.read_json(Stage.DIR+"probes.json")
	var records: Array = []
	var selected := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--view="): selected = arg.trim_prefix("--view=")
	if selected != "":
		var prior := Stage.read_json(Stage.DIR+"capture-report.json")
		for row: Dictionary in prior.captures:
			if row.view != selected: records.append(row)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for variant: String in ["staged-r6-before","candidate-runtime-r7"]:
		var holder := Node3D.new()
		root.add_child(holder)
		var data: Dictionary
		var world: Node3D
		if variant == "candidate-runtime-r7":
			data = Stage.read_json(Stage.AUTHORITY)
			world = Stage.make_world(holder)
		else:
			data = Stage.read_json(StageR6.AUTHORITY)
			world = StageR6.make_world(holder)
		var original_emission := Stage.emission(world)
		for level in [Stage.Binder.Detail.OFF,Stage.Binder.Detail.LOW,Stage.Binder.Detail.FULL]:
			Stage.Binder.set_root_detail(world,level)
			assert(Stage.emission(world)==original_emission)
		for node: Node in world.get_children():
			if node.get_meta(Stage.Binder.OWNER,false): node.set_clock_for_capture(12.0)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-44,-30,0)
		sun.light_energy = 1.25
		sun.shadow_enabled = true
		holder.add_child(sun)
		var environment := WorldEnvironment.new()
		var settings := Environment.new()
		settings.background_mode = Environment.BG_COLOR
		settings.background_color = Color("627985")
		settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		settings.ambient_light_color = Color("a0adb5")
		settings.ambient_light_energy = .68
		environment.environment = settings
		holder.add_child(environment)
		var camera := Camera3D.new()
		camera.far = 1000
		camera.fov = 68
		holder.add_child(camera)
		camera.make_current()
		var weather := Weather.new()
		weather.apply_settings({"mute":true})
		holder.add_child(weather)
		weather.bind(data.arena,camera,"playing",int(data.arena.seed))
		weather.bind_presentation(world,environment,sun)
		assert(not weather.look.diagnostics().capped)
		weather.set_native_weather_suppressed(true)
		for view: Dictionary in probes.cameras:
			if selected != "" and view.id != selected: continue
			camera.position = Vector3(view.eye[0],view.eye[1],view.eye[2])
			camera.look_at(Vector3(view.target[0],view.target[1],view.target[2]))
			# Exact deterministic source-service seek; no changing lighting per view.
			weather.apply_snapshot({"time":12.0})
			var frame_start := Time.get_ticks_usec()
			for frame in range(8):
				weather.tick(.05)
				await process_frame
			await RenderingServer.frame_post_draw
			var frame_micros := Time.get_ticks_usec()-frame_start
			var emission := Stage.emission(world)
			for key: String in ["color","energy","texture","operator"]: assert(emission[key]==original_emission[key])
			var path := OUT+str(view.id)+"-"+variant+".png"
			assert(root.get_texture().get_image().save_png(path)==OK)
			records.append({"view":view.id,"variant":variant,"eye":view.eye,"target":view.target,"fov":68,"geometryHash":data.geometryHash,
				"visualRevision":7 if variant == "candidate-runtime-r7" else 6,"artHash":FileAccess.get_sha256(Stage.ART if variant == "candidate-runtime-r7" else StageR6.ART),
				"captureScriptSha256":FileAccess.get_sha256("res://tests/new_maps/gravemill_foundry/revision7/capture.gd"),
				"path":path,"sha256":FileAccess.get_sha256(path),"weather":weather.diagnostics(),"weatherLook":weather.look.diagnostics(),
				"dressing":world.get_meta("staged_dressing",{"path":"accepted production WorldMap/Binder"}),"emissionPreserved":true,
				"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"renderer":RenderingServer.get_video_adapter_name(),
				"eightFrameMicroseconds":frame_micros,"staticViewMeanFrameMs":float(frame_micros)/8000.0,
				"videoMemoryBytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"staticMemoryBytes":OS.get_static_memory_usage(),
				"performanceScope":"Eight settled static-view frames on recorded backend; not hosted movement cadence or dedicated-GPU FPS."})
			print("R7_NATIVE_CAPTURE ",path)
		weather.look.clear()
		assert(Stage.emission(world)==original_emission)
		holder.free()
		await process_frame
	var file := FileAccess.open(Stage.DIR+"capture-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"native staged runtime services, no hosted/manual approval","captures":records},"  ")+"\n")
	print("R7_CAPTURE_COMPLETE ",records.size())
	quit()
