extends "res://multiplayer_worlds/sports_demo.gd"
## Private candidate bootstrap; production chase, HUD, fleet and callbacks inherited.
var controls_path := ""
var capture_root := ""
var role := "host"
var capture_busy := false
var capture_age := 0.0
var frames := 0
var shutting_down := false
var restart_sent := false
var starts := 0
var pending_captures := 0

func _ready() -> void:
	controls = preload("res://tests/new_maps/stormglass_causeway/fixture_controls.gd").new()
	world.catalog = preload("res://tests/asset_production/candidate_catalog.gd").new()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): map_id=arg.trim_prefix("--map=")
		if arg.begins_with("--endpoint="): endpoint=arg.trim_prefix("--endpoint=")
		if arg.begins_with("--join-room="): join_room_id=arg.trim_prefix("--join-room=")
		if arg.begins_with("--foundry-controls="): controls_path=arg.trim_prefix("--foundry-controls=")
		if arg.begins_with("--foundry-capture="): capture_root=arg.trim_prefix("--foundry-capture=")
		if arg.begins_with("--foundry-role="): role=arg.trim_prefix("--foundry-role=")
	assert(map_id=="stormglass-causeway" and not endpoint.is_empty())
	mode="puma-race"
	world_bots=0
	time_limit=900
	round_target=1
	add_child(world)
	world.set_process(false)
	world.set_process_unhandled_input(false)
	world.selector.hide()
	world.label.hide()
	assert(world.load_map(map_id))
	expected_hash=str(world.catalog.entries[map_id].geometryHash)
	audiovisual.configure(self,world.camera,world.catalog.resolve_map(map_id),mode,endpoint)
	world.camera.current=true
	initial_camera=world.camera.transform
	assert(chase.configure_map(map_id,world.catalog.resolve_map(map_id)))
	add_child(fleet)
	add_child(ball)
	ball.visible=false
	var layer:=CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	if "--foundry-compact" in OS.get_cmdline_user_args():
		# Test-only responsive candidate profile; inherited fixed 680px panel clips at UI150.
		hud.result_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hud.result_panel.offset_left=16
		hud.result_panel.offset_right=-16
		hud.result_panel.offset_top=80
		hud.result_panel.offset_bottom=-80
		hud.result_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		hud.result_label.add_theme_font_size_override("font_size",16)
		hud.title.add_theme_font_size_override("font_size",16)
		hud.phase_label.add_theme_font_size_override("font_size",14)
		hud.detail.add_theme_font_size_override("font_size",18)
		hud.speed_label.add_theme_font_size_override("font_size",18)
	add_child(net)
	net.lobby.connect(on_lobby)
	net.started.connect(on_started)
	net.snapshot.connect(on_snapshot)
	net.results.connect(on_results)
	net.events.connect(func(items: Array) -> void:
		if phase=="active":
			progression.events(items,net.actor_id)
			audiovisual.events(items))
	net.connection_error.connect(fail)
	var settings:=SettingsAccess.service()
	if settings!=null: settings.set_value("ui_scale",150 if "--foundry-compact" in OS.get_cmdline_user_args() else 100,false)
	if not capture_root.is_empty(): DirAccess.make_dir_recursive_absolute(capture_root)
	assert(net.connect_server(endpoint,world.catalog.entries,map_id)==OK)

func on_lobby(frame: Dictionary) -> void:
	if configured and not start_sent and frame.get("players",[]).size()<2: return
	super.on_lobby(frame)

func on_started(frame: Dictionary) -> void:
	super.on_started(frame)
	starts+=1
	print("STORMGLASS_STARTED ",JSON.stringify({"starts":starts,"role":role,"hash":expected_hash}))
	if starts>1: capture_after_layout("restart")

func _process(delta: float) -> void:
	if shutting_down: return
	var command: Variant=JSON.parse_string(FileAccess.get_file_as_string(controls_path)) if FileAccess.file_exists(controls_path) else {}
	if command is Dictionary:
		controls.set("command",command)
		if command.get("restart",false) and not restart_sent:
			restart_sent=true
			var event:=InputEventKey.new()
			event.physical_keycode=KEY_F5
			event.pressed=true
			Input.parse_input_event(event)
		if command.get("quit",false):
			shutting_down=true
			shutdown.call_deferred()
			return
	super._process(delta)
	# Candidate label only: stock sports HUD currently hardcodes Ion Speedway.
	hud.title.text="Stormglass · Puma Race" if "--foundry-compact" in OS.get_cmdline_user_args() else "Stormglass Causeway · Puma Race"
	capture_age+=delta
	if command is Dictionary and command.get("clip",false) and capture_age>=.1 and not capture_busy:
		capture_age=0
		capture("frame-%06d"%frames)
		frames+=1

func capture(label_name: String) -> void:
	if capture_root.is_empty() or capture_busy: return
	capture_busy=true
	await RenderingServer.frame_post_draw
	var result:=get_viewport().get_texture().get_image().save_png(capture_root.path_join(label_name+".png"))
	print("STORMGLASS_NATIVE_CAPTURE ",JSON.stringify({"label":label_name,"error":result,"ticksMs":Time.get_ticks_msec(),"vehicle":vehicle,"camera":str(world.camera.global_position),"viewport":str(get_viewport().get_visible_rect().size),"renderer":RenderingServer.get_video_adapter_name(),"engineFrames":Engine.get_frames_drawn()}))
	capture_busy=false

func on_results(frame: Dictionary) -> void:
	super.on_results(frame)
	await capture_after_layout("results")
	print("CANDIDATE_RESULTS ",JSON.stringify({"role":role,"hash":expected_hash,"mode":mode,"sent":controls.get("sent"),"ack":net.last_ack,"state":frame.state}))

func capture_after_layout(label_name: String) -> void:
	pending_captures+=1
	for i in range(3): await get_tree().process_frame
	await capture(label_name)
	pending_captures-=1

func shutdown() -> void:
	while capture_busy or pending_captures>0: await get_tree().process_frame
	net.disconnect_server()
	audiovisual.dropped()
	stop_fixture_audio(self)
	preload("res://audio/playback_cleanup.gd").drain()
	print("CANDIDATE_TEARDOWN_READY ",JSON.stringify({"role":role,"phase":phase,"hash":expected_hash}))
	if role=="host":
		var settings:=SettingsAccess.service()
		settings.open_panel()
		print("STORMGLASS_LEAVE_HOME ",JSON.stringify({"overlay":settings.overlay_open(),"behavior":"canonical Leave match returns to launcher by quitting native process"}))
		settings.rows.leave.pressed.emit()
		return
	get_tree().quit(0)

func stop_fixture_audio(node: Node) -> void:
	# Immediate post-restart shutdown is a fixture lifecycle, not a sound-rule change.
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.call("stop")
		node.set("stream",null)
	for child: Node in node.get_children(): stop_fixture_audio(child)
