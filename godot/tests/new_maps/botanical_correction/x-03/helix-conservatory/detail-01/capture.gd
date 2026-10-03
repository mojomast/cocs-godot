extends SceneTree
## Bounded native before/after WorldMap + real Binder + Weather presentation.
const Stage = preload("res://tests/new_maps/botanical_correction/x-03/helix-conservatory/staged.gd")
const Weather = preload("res://ambience/weather_service.gd")

func _initialize() -> void:
	call_deferred("run")
	create_timer(290).timeout.connect(func() -> void: push_error("Botanical capture timeout"); quit(2))

func run() -> void:
	root.size = Vector2i(1280,720)
	var id := Stage.map_id()
	var receipt := Stage.manifest(id)
	var probes := Stage.read_json(Stage.directory(id)+"detail-01/probes.json")
	var selected := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--view="): selected = arg.trim_prefix("--view=")
	var out := Stage.directory(id)+"detail-01/captures/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var records: Array = []
	for candidate: bool in [false,true]:
		var variant := "candidate-runtime-after" if candidate else "accepted-runtime-before"
		var holder := Node3D.new()
		root.add_child(holder)
		var world := Stage.make_world(holder,id,candidate)
		var originals := Stage.snapshot(world)
		var visual := Stage.visual_root(world)
		for level in [Stage.Binder.Detail.OFF,Stage.Binder.Detail.LOW,Stage.Binder.Detail.FULL]:
			Stage.Binder.set_root_detail(visual,level)
		# Accepted Binder changes architecture; compare after its Full restoration.
		Stage.restored(originals)
		for child: Node in visual.get_children():
			if child.get_meta(Stage.Binder.OWNER,false): child.set_clock_for_capture(12.0)
		var data := Stage.read_json(Stage.directory(id)+"authority.json" if candidate else receipt.source.acceptedAuthority)
		var sun := DirectionalLight3D.new()
		var environment := WorldEnvironment.new()
		holder.add_child(sun)
		holder.add_child(environment)
		Stage.presentation(id,environment,sun)
		var camera := Camera3D.new()
		camera.far = 2000
		holder.add_child(camera)
		camera.make_current()
		var weather := Weather.new()
		holder.add_child(weather)
		weather.apply_settings({"mute":true})
		weather.bind(data.arena,camera,"playing",int(data.arena.get("seed",0)))
		weather.bind_presentation(visual,environment,sun)
		assert(not weather.look.diagnostics().capped)
		weather.set_native_weather_suppressed(true)
		for view: Dictionary in probes.cameras:
			if selected != "" and view.id != selected: continue
			var eye: Array = view.eye if candidate else view.beforeEye
			camera.position = Vector3(eye[0],eye[1],eye[2])
			camera.look_at(Vector3(view.target[0],view.target[1],view.target[2]))
			camera.fov = float(view.fov)
			weather.apply_snapshot({"time":12.0})
			var start := Time.get_ticks_usec()
			for frame in range(8):
				weather.tick(.05)
				await process_frame
			await RenderingServer.frame_post_draw
			var elapsed := Time.get_ticks_usec()-start
			var path := out+str(view.id)+"-"+variant+".png"
			assert(not FileAccess.file_exists(path), "Capture exists; use a new attempt")
			assert(root.get_texture().get_image().save_png(path)==OK)
			records.append({"view":view.id,"variant":variant,"eye":eye,"target":view.target,"fov":view.fov,"comparison":view.comparison,
				"geometryHash":data.geometryHash,"glbSha256":receipt.glbSha256 if candidate else receipt.source.acceptedArtSha256,
				"path":path,"sha256":FileAccess.get_sha256(path),"weather":weather.diagnostics(),"weatherLook":weather.look.diagnostics(),
				"renderer":RenderingServer.get_video_adapter_name(),"renderingMethod":ProjectSettings.get_setting("rendering/renderer/rendering_method"),
				"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"eightFrameMicroseconds":elapsed,
				"staticViewMeanFrameMs":float(elapsed)/8000.0,"videoMemoryBytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"staticMemoryBytes":OS.get_static_memory_usage()})
		weather.look.clear()
		Stage.restored(originals)
		holder.free()
		await process_frame
	assert(records.size()==(2 if selected!="" else probes.cameras.size()*2))
	var report := {"map":id,"manifestSha256":FileAccess.get_sha256(Stage.directory(id)+"manifest.json"),"godot":Engine.get_version_info(),"captures":records,"scope":"untouched matched native presentation pairs, labelled repositioning; static backend timings, not dedicated GPU/hosted FPS; human/team-readability review pending"}
	assert(not FileAccess.file_exists(Stage.directory(id)+"detail-01/"+("capture-report.json" if selected=="" else "capture-"+selected+"-report.json")), "Receipt exists; use a new attempt")
	var file := FileAccess.open(Stage.directory(id)+"detail-01/"+("capture-report.json" if selected=="" else "capture-"+selected+"-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	print("BOTANICAL_CAPTURE_COMPLETE ",id," ",records.size())
	quit()
