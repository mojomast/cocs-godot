extends SceneTree

# Explicit synthetic render fixture. No authority, gameplay, or connection evidence.
const Scoreboard = preload("res://ui/scoreboard.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var capture_path := ""
	var results := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg == "--results": results = true
	var notice := Label.new()
	notice.position = Vector2(24, 20)
	notice.text = "SYNTHETIC SCOREBOARD RENDER FIXTURE · NOT LIVE GAMEPLAY\nTop 224 px reserved for the session HUD, restart status and errors."
	notice.add_theme_font_size_override("font_size", 16)
	notice.modulate = Color("94a8be")
	root.add_child(notice)
	var board := Scoreboard.new()
	root.add_child(board)
	await process_frame
	board.round_number = 2
	var actors: Array = []
	var names := ["Godot", "Atlas", "Nova", "Meridian Runner", "Grok", "Meta", "[b]Literal name[/b]", "Vega", "Orion", "Cassiopeia", "Echo", "Sol", "Lyra", "A very long player name that should remain clipped inside its own column"]
	for i: int in range(names.size()):
		actors.append({"id":i, "name":names[i], "frags":24 - i, "deaths":i % 6, "team":i % 2})
	board.apply_state({"mapName":"Meridian Exchange", "modeName":"Team Deathmatch", "time":213.8, "actors":actors}, 2, results)
	if not results:
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.pressed = true
		board._input(tab)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var viewport := root.get_visible_rect().size
	assert(board.panel.position.y >= 224, "HUD reservation")
	assert(board.panel.position.y + board.panel.size.y <= viewport.y - 16, "panel stays within viewport")
	assert(board.panel.size.x <= viewport.x - 48, "responsive width")
	if not capture_path.is_empty():
		var result := root.get_texture().get_image().save_png(capture_path)
		assert(result == OK, "save screenshot")
	print("PORT_SCOREBOARD_SYNTHETIC_RENDER_OK viewport=", viewport, " panel=", board.panel.get_rect(), " results=", results)
	quit(0)
