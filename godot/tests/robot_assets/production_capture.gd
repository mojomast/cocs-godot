extends SceneTree
var out := ""
var source := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--robot-replay="): source = arg.trim_prefix("--robot-replay=")
		if arg.begins_with("--robot-output="): out = arg.trim_prefix("--robot-output=")
	call_deferred("run")

func run() -> void:
	create_timer(140).timeout.connect(func(): quit(2))
	var replay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	root.size = Vector2i(1280,800)
	root.get_node("LocalSettings").set_value("ui_scale",100,false)
	root.get_node("LocalSettings").set_process(false); root.get_node("LocalSettings").hint.hide()
	var session: Node = load("res://tests/campaign/trailer_session.gd").new()
	root.add_child(session); current_scene = session
	session.client.actor_id = 0; session.client.set_process(false)
	session.presentation.interpolate_remote = false
	session.on_started({"mapId":"emberline-ascent","geometryHash":replay.header.geometryHash,"inputEpoch":1})
	session.campaign_hud.hide_brief(); session.campaign_hud.set_process(false)
	for i in range(4): await process_frame
	var report := {"frames":[],"skins":[],"workshop":session.world.get_node("SwitchyardWorkshop").installed,"renderer":RenderingServer.get_video_adapter_name()}
	var overlay := Label.new(); overlay.position = Vector2(18,20); overlay.add_theme_font_size_override("font_size",22)
	root.add_child(overlay)
	for index in replay.records.size():
		var record: Dictionary = replay.records[index]
		session.client.last_ack = int(record.acks["0"])
		session.on_snapshot({"state":record.state})
		session.ground_tells.apply_events(record.events); session.combat.apply_events(record.events,0)
		assert(session.phase == 3)
		session.combat.overlay.modulate.a = 0; session.campaign_hud.hide(); session.story_widgets.hide()
		if is_instance_valid(session.first_person): session.first_person.rig.apply_actor({},false); session.first_person.set_process(false)
		for visual: Node3D in session.presentation.actors.values():
			if visual.has_meta("switchyard_skin"):
				var entry := {"role":visual.model_id,"skin":visual.get_meta("switchyard_skin")}
				if entry not in report.skins: report.skins.append(entry)
				visual.automatic_animation = false; visual.automatic_lod = false
				visual.advance(1.0/12)
		var focus := Vector3(replay.header.focus.x,replay.header.focus.y,replay.header.focus.z)
		var angle := atan2(float(replay.header.vantage.x)-focus.x,float(replay.header.vantage.z)-focus.z)
		var eye := focus+Vector3(sin(angle)*9,3.0,cos(angle)*9)
		eye.y = maxf(eye.y,session.world.height_at(eye.x,eye.z)+1.5)
		session.camera.position = eye; session.camera.look_at(focus+Vector3(0,.9,0))
		overlay.text = "EMBERLINE / %s / production source events\nControlled authority replay · native skins + six workshop mounts" % replay.header.shot.id
		await process_frame; await RenderingServer.frame_post_draw
		var path := out.path_join("frame-%03d.png" % index)
		assert(root.get_texture().get_image().save_png(path) == OK)
		report.frames.append({"frame":index,"sourceTime":float(index)/12,"ticksUsec":Time.get_ticks_usec(),"path":path,"ack":session.client.last_ack})
	var file := FileAccess.open(out.path_join("native.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	session.client.disconnect_server(); current_scene = null; session.queue_free(); overlay.queue_free()
	await process_frame; await process_frame
	print("SWITCHYARD_PRODUCTION_NATIVE_OK skins=",report.skins)
	quit()
