extends SceneTree
## Test-only offline production renderer. Never opens a gameplay connection.
var source := ""
var output := ""
var session: Node
var ledger: FileAccess
var replay: FileAccess
var capture_token := ""
var asset_proof := ""

func _initialize() -> void:
	seed(421002)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--trailer-source="): source = arg.trim_prefix("--trailer-source=")
		if arg.begins_with("--trailer-output="): output = arg.trim_prefix("--trailer-output=")
		if arg.begins_with("--capture-token="): capture_token = arg.trim_prefix("--capture-token=")
		if arg.begins_with("--asset-proof="): asset_proof = arg.trim_prefix("--asset-proof=")
	call_deferred("run")

func finish(code: int) -> void:
	if replay != null: replay.close()
	if ledger != null: ledger.close()
	if is_instance_valid(session):
		session.queue_free()
		await process_frame
		await process_frame
	quit(code)

func run() -> void:
	replay = FileAccess.open(source, FileAccess.READ)
	if replay == null or output.is_empty() or capture_token.length() != 64 or asset_proof.is_empty():
		push_error("CINEMATIC_V3 missing replay/output")
		await finish(1)
		return
	var header: Dictionary = JSON.parse_string(replay.get_line())
	var shot: Dictionary = header.shot
	var asset_inputs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(asset_proof))
	for path: String in asset_inputs.files:
		if not path.begins_with("godot/"): continue
		var resource_path := "res://" + path.trim_prefix("godot/")
		if FileAccess.get_sha256(resource_path) != str(asset_inputs.files[path]) or (path.ends_with(".glb") and not ResourceLoader.exists(resource_path)):
			push_error("CINEMATIC_V3 required asset missing/stale: " + path)
			await finish(1)
			return
	root.size = Vector2i(1280, 720)
	root.get_node("LocalSettings").set_process(false)
	root.get_node("LocalSettings").hint.hide()
	Engine.max_fps = 24
	session = load("res://tests/campaign/trailer_session.gd").new()
	root.add_child(session)
	current_scene = session
	session.client.actor_id = 0
	session.client.set_process(false)
	session.presentation.interpolate_remote = false
	session.on_started({"mapId":shot.map,"geometryHash":header.geometryHash,"inputEpoch":1})
	session.campaign_hud.hide_brief()
	session.campaign_hud.set_process(false)
	for i: int in range(4): await process_frame
	var scenery: Node = session.world.get_node_or_null("BiomeExpansionFour")
	if scenery == null or scenery.loaded_assets.size() != 3:
		push_error("CINEMATIC_V3 final chapter scenery not installed; fallback refused")
		await finish(1)
		return
	ledger = FileAccess.open(output.get_base_dir().path_join("cadence.jsonl"), FileAccess.WRITE)
	if ledger == null:
		push_error("CINEMATIC_V3 cannot open cadence ledger")
		await finish(1)
		return
	var index := 0
	var previous_process := Engine.get_process_frames()
	while not replay.eof_reached():
		var line := replay.get_line()
		if line.is_empty(): continue
		var record: Dictionary = JSON.parse_string(line)
		if int(record.frame) != index:
			push_error("CINEMATIC_V3 noncontiguous source")
			await finish(1)
			return
		session.client.last_ack = int(record.acks["0"])
		session.on_snapshot({"state":record.state})
		session.ground_tells.apply_events(record.events)
		session.combat.apply_events(record.events, 0)
		session.av_events(record.events)
		for visual: Node in session.presentation.actors.values():
			var model: Variant = visual.get("model_id")
			if model != null and asset_inputs.requiredNativeSkins.has(str(model)) and visual.get_meta("switchyard_skin", "") != asset_inputs.requiredNativeSkins[str(model)]:
				push_error("CINEMATIC_V3 required production skin fell back: " + str(model))
				await finish(1)
				return
		if session.phase != 3:
			push_error("CINEMATIC_V3 production session rejected snapshot")
			await finish(1)
			return
		var fp: bool = shot.camera == "fp"
		session.combat.overlay.modulate.a = 1.0 if fp else 0.0
		session.campaign_hud.visible = bool(shot.hud)
		# Keep mission/ammo/health/comms in ordinary-input shots. No edited victory UI.
		session.story_widgets.visible = shot.kind in ["npc", "pet"] or fp
		if is_instance_valid(session.first_person):
			session.first_person.set_process(false)
			session.first_person.rig.apply_actor(session.presentation.local_actor, fp)
			session.first_person.rig.apply_events(record.events, 0)
		var t := float(index) / maxf(1.0, float(shot.seconds * 24 - 1))
		var focus := Vector3(header.focus.x, header.focus.y, header.focus.z)
		session.camera.fov = 65
		if fp:
			var actor: Dictionary = record.state.actors[0]
			session.camera.position = Vector3(actor.x, actor.y + float(actor.get("eyeHeight", 1.45)), actor.z)
			session.camera.rotation = Vector3(float(actor.pitch), float(actor.yaw), 0)
		elif shot.get("path") is Dictionary:
			var path: Dictionary = shot.path
			var points: Array = path.controls
			var u := 1.0 - t
			session.camera.position = vec(points[0]) * u * u * u + vec(points[1]) * 3 * u * u * t + vec(points[2]) * 3 * u * t * t + vec(points[3]) * t * t * t
			var glance := sin(t * PI) * 0.65
			session.camera.look_at(vec(path.target) + vec(path.glance) * glance)
			session.camera.fov = float(path.fov)
		else:
			var distance := 3.4 if shot.kind in ["pet", "npc"] else 8.0
			var height := 1.4 if shot.kind in ["pet", "npc"] else 2.8
			var angle := lerpf(-0.28, 0.28, t) + (PI if shot.kind in ["pet", "npc"] else 0.0)
			if shot.kind == "artillery":
				distance = 14.0
				height = 9.0
			if shot.kind in ["combat", "warden"] and header.has("vantage"):
				angle += atan2(float(header.vantage.x) - focus.x, float(header.vantage.z) - focus.z)
			var eye := focus + Vector3(sin(angle) * distance, height, cos(angle) * distance)
			eye.y = maxf(eye.y, float(session.world.height_at(eye.x, eye.z)) + 1.2)
			session.camera.position = eye
			session.camera.look_at(focus + Vector3.UP * (0.5 if shot.kind == "pet" else 1.1))
		# The rendering-only session skips live input/staleness processing. Advance
		# its production audiovisual/weather service exactly once on the source clock.
		session.av_tick(1.0 / 24.0)
		root.get_node("LocalSettings").hint.hide()
		await RenderingServer.frame_post_draw
		var rendered_at := Time.get_ticks_usec()
		var image := root.get_texture().get_image()
		var error := image.save_png(output.path_join("%06d.png" % index))
		var cast := []
		for id: String in session.story_director.actors:
			var actor: Node3D = session.story_director.actors[id]
			var screen: Vector2 = session.camera.unproject_position(actor.global_position + Vector3.UP * 0.5)
			cast.append({"id":id,"screen":[screen.x,screen.y],"potentiallyVisible":actor.is_visible_in_tree() and not session.camera.is_position_behind(actor.global_position) and Rect2(0,0,1280,720).has_point(screen)})
		var engine_frame := Engine.get_process_frames()
		ledger.store_line(JSON.stringify({"frame":index,"sourceFrame":record.frame,"sourceTime":record.state.time,
			"captureToken":capture_token,"sourceRecordSHA256":line.sha256_text(),"pngSHA256":FileAccess.get_sha256(output.path_join("%06d.png" % index)),
			"wallUsec":rendered_at,"saveFinishedUsec":Time.get_ticks_usec(),"saveError":error,
			"engineProcessFrames":engine_frame - previous_process,"requestedVisualDelta":1.0 / 24.0,
			"camera":[session.camera.position.x,session.camera.position.y,session.camera.position.z],
			"cast":cast,"eventCount":record.events.size(),"width":image.get_width(),"height":image.get_height()}))
		ledger.flush()
		previous_process = engine_frame
		if error != OK or image.get_width() != 1280 or image.get_height() != 720:
			push_error("CINEMATIC_V3 failed full-viewport frame")
			await finish(1)
			return
		index += 1
		await process_frame
	print("CINEMATIC_V3_OK ", shot.id, " frames=", index)
	await finish(0)

func vec(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
