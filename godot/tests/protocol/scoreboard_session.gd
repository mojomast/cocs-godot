extends SceneTree

# Actual session scene + stored server state, with synthetic signal delivery.
# Requires the existing generated map content; no server connection is opened.
const SessionScene = preload("res://world/session.tscn")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session := SessionScene.instantiate()
	root.add_child(session)
	await process_frame
	var board: CanvasLayer = session.get_node("Scoreboard")
	assert(board.client == session.client, "scene child binds after parent setup")
	assert(session.phase == -1 and not board.panel.visible, "missing endpoint error keeps panel hidden")
	assert(session.label.text == "A local launcher endpoint is required", "error label preserved")
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/protocol/captured.json"))
	var first_snapshot: Dictionary = {}
	var result: Dictionary = {}
	for record: Dictionary in capture.frames:
		if record.direction != "server" or record.client != 1: continue
		if record.frame.type == "snapshot" and first_snapshot.is_empty(): first_snapshot = record.frame
		if record.frame.type == "results": result = record.frame
	session.client.actor_id = 0
	session.client.started.emit({"mapId":"meridian-exchange"})
	session.client.snapshot.emit(first_snapshot)
	assert(session.round_starts == 1 and board.round_number == 1, "parent start handler precedes scoreboard")
	assert(board.entries.size() == session.presentation.actors.size(), "scene and panel receive same authoritative roster")
	session.client.results.emit(result)
	await process_frame
	assert(board.finished and board.panel.visible and session.phase == 4, "actual results integration")
	assert("Enter: restart" in session.label.text and "Enter:" in board.footer.text, "existing restart prompt retained")
	session.on_error("Synthetic integration connection error")
	await process_frame
	assert(not board.panel.visible and session.label.text == "Synthetic integration connection error", "local errors have visual priority")
	print("PORT_SCOREBOARD_SESSION_OK actual_scene=true synthetic_signal_delivery=true captured_state=true")
	session.queue_free()
	await process_frame
	quit(0)
