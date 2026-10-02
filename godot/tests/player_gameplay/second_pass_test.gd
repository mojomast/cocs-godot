extends SceneTree
const Status = preload("res://player_gameplay/status.gd")
const Cues = preload("res://player_gameplay/world_cues.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/player_gameplay/second_pass_oracle.json"))
	var status := Status.new()
	for result: Dictionary in oracle.results:
		for actor: Dictionary in result.samples:
			var model := status.project(actor)
			check(not model.is_empty(), result.operator + " source sample projects")
			if result.operator == "grok":
				check(model.mobility.input.contains("RELEASE") and not model.mobility.input.contains("SPACE"), "Grok actual release control")
				if actor.movement.phase == "charging" and float(actor.movement.windup) >= 0.45:
					check(model.mobility.state == "RELEASE CTRL TO LAUNCH", "source full charge is actionable")
			if result.operator == "chatgpt": check(model.mobility.input.contains("HOLD X"), "grapple must be held to mantle")
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/player_gameplay/fixtures.json"))
	var guest := {"id":1,"x":0,"y":0,"z":0,"grounded":true,"health":100}
	check(Status.rope_hint(guest, fixtures.rope).contains("WALK INTO"), "another operator can discover shared boarding")
	guest.zipRide = {"id":"rope-1"}
	check(Status.rope_hint(guest, fixtures.rope).is_empty(), "rider does not see boarding prompt")
	var cues := Cues.new()
	root.add_child(cues)
	cues.apply_state(fixtures.rope)
	check(cues.slots.size() == 1, "valid rope exists before invalid replacement")
	var invalid: Dictionary = fixtures.rope.duplicate(true)
	invalid.actors[0].movement.anchor.x = 999.0
	cues.apply_state(invalid)
	check(cues.slots.is_empty(), "invalid replacement cannot retain old cable")
	for boundary in ["expired", "death", "missing", "over"]:
		cues.apply_state(fixtures.rope)
		var frame: Dictionary = fixtures.rope.duplicate(true)
		match boundary:
			"expired": frame.actors[0].movement.anchor.life = 0
			"death": frame.actors[0].health = 0
			"missing": frame.actors = []
			"over": frame.over = true
		cues.apply_state(frame)
		check(cues.slots.is_empty(), boundary + " drains source cable")
	# Structural stress fixture only: source semantic fixtures above are separate.
	var actors: Array = []
	for i in range(80): actors.append({"id":i,"x":i,"y":0,"z":0,"health":100,"verbState":{"active":true,"verb":"deep-compute","charge":0.5}})
	cues.reduced_motion = true
	cues.set_quality(0)
	cues.apply_state({"actors":actors})
	check(cues.channels.size() == 8, "Low bounded channel budget")
	var positions: Array = []
	for node: Node3D in cues.channels.values(): positions.append(node.transform)
	cues.advance(0.5)
	var index := 0
	for node: Node3D in cues.channels.values():
		check(node.transform == positions[index], "reduced-motion channel remains static")
		index += 1
	cues.apply_state({"actors":[]})
	check(cues.channels.is_empty(), "absent passive owners drain")
	cues.clear_round()
	cues.free()
	var binding := preload("res://player_gameplay/session_binding.gd").new()
	var notices: Array = []
	binding.status_changed.connect(func(model: Dictionary) -> void: notices.append(model))
	binding.model = {"stale":true}
	binding.clear_round()
	check(notices.size() == 1 and notices[0].is_empty(), "disconnect publishes empty model immediately")
	check(not binding.panel.visible, "disconnect hides fallback immediately")
	binding.refresh()
	check(binding.model.is_empty(), "no snapshot cannot resurrect stale model")
	binding.cues.free()
	binding.panel.free()
	binding.free()
	print("SECOND_PASS_GAMEPLAY_TEST failures=", failures)
	quit(0 if failures == 0 else 1)
