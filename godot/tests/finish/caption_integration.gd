extends SceneTree
const Captions = preload("res://experience/caption_model.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var vectors: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/finish/caption-eligibility.json"))
	for row: Dictionary in vectors:
		check(Captions.event_allowed(row.event, int(row.actor), row.team) == row.expected, JSON.stringify(row))
	var captions := Captions.new()
	var event := {"type":"cocs-command", "action":"set-route", "value":"front-1", "team":0}
	captions.consume([event], 1.0, 0, true, 0)
	check(captions.line(1.0) == "Route set · FRONT 1", "dynamic formatter reachable for current own team")
	captions.clear()
	captions.consume([event], 2.0, 1, true, 1)
	check(captions.line(2.0).is_empty(), "foreign team cannot format private intent")
	captions.consume([event], 3.0, -1, true)
	check(captions.line(3.0).is_empty(), "spectator cannot inherit command text")
	captions.consume([event], 4.0, 0, false, 0)
	check(captions.line(4.0).is_empty(), "disabled captions stay cleared")
	print("FINISH_CAPTION_INTEGRATION ", checks, " checks / ", failures, " failures")
	quit(1 if failures else 0)
