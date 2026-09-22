extends SceneTree

# Explicitly synthetic death/results visual fixture through the actual session scene.
const SessionScene = preload("res://world/session.tscn")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output := ""
	var results := "--hud-results" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hud-capture="): output = arg.trim_prefix("--hud-capture=")
	assert(not output.is_empty())
	var session := SessionScene.instantiate()
	root.add_child(session)
	await process_frame
	session.set_process(false)
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/protocol/captured.json"))
	var snapshot: Dictionary = {}
	for record: Dictionary in capture.frames:
		if record.direction == "server" and record.client == 1 and record.frame.type == "snapshot":
			snapshot = record.frame.duplicate(true)
			break
	session.client.actor_id = 0
	session.client.started.emit({"mapId":"meridian-exchange"})
	snapshot.state.actors[0].health = 0
	snapshot.state.actors[0].dead = 2.3
	snapshot.state.actors[0].armor = 0
	snapshot.state.actors[0].deaths = 1
	session.client.snapshot.emit(snapshot)
	if results:
		snapshot.state.over = true
		session.client.results.emit(snapshot)
	var hud: CanvasLayer = session.get_node("GameHUD")
	hud.refresh_status()
	var fixture := Label.new()
	fixture.text = "SYNTHETIC LIFECYCLE FIXTURE"
	fixture.position = Vector2(20, 68)
	fixture.add_theme_font_size_override("font_size", 12)
	fixture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.root.add_child(fixture)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	assert(hud.status_panel.is_visible_in_tree())
	assert(hud.status_panel.get_global_rect().end.y < 224, "status leaves scoreboard reservation clear")
	for panel: Control in [hud.top, hud.vitals, hud.weapon_panel, hud.status_panel, hud.controls]:
		assert(root.get_visible_rect().encloses(panel.get_global_rect()))
	assert(root.get_texture().get_image().save_png(output) == OK)
	print("PORT_GAME_HUD_VISUAL_OK synthetic=true results=", results, " viewport=", root.size)
	session.queue_free()
	await process_frame
	quit(0)
