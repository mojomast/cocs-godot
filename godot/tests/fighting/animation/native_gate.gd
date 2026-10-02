extends SceneTree
## Prepared native gate. Requires an explicit parent heavy-tool grant to execute.

const Visual = preload("res://fighting/visuals/fighter_visual.gd")
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var output := "user://fighting-animation-native.json"
	var selected: Array[String] = Visual.OPERATORS.duplicate()
	for index: int in range(arguments.size() - 1):
		if arguments[index] == "--output":
			output = arguments[index + 1]
		if arguments[index] == "--operators":
			selected.assign(arguments[index + 1].split(","))
	var visuals: Dictionary = {}
	for operator: String in selected:
		var visual := Visual.new()
		root.add_child(visual)
		_check(visual.configure(operator), operator + ": " + visual.unavailable_reason)
		if not visual.available:
			visual.free()
			continue
		visuals[operator] = visual
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Visual.ASSET_ROOT + operator + ".json"))
		for clip: String in manifest["clips"]:
			var data: Dictionary = manifest["clips"][clip]
			var end_frame := int(data["seek_keys"][-1][0])
			for frame: int in range(end_frame + 1):
				visual.present({"animation": clip, "animation_frame": frame, "x": 1000, "y": 0, "facing": 1}, 0.9)
				_check(visual.position == Vector3(1, 0, 0), operator + ": root moved " + clip)
				for socket: String in ["Chest", "GripR", "FootL", "FootR"]:
					_check(visual.socket_world(socket).is_finite(), operator + ": nonfinite " + clip + ":" + socket)
			visual.present({"animation": clip, "animation_frame": 7, "x": 1000, "facing": 1}, 0.0)
			var before: Vector3 = visual.socket_world("KnuckleR")
			visual.present({"animation": clip, "animation_frame": end_frame, "x": 1000, "facing": 1}, 1.0)
			visual.present({"animation": clip, "animation_frame": 7, "x": 1000, "facing": 1}, 0.8)
			_check(before.distance_to(visual.socket_world("KnuckleR")) < 0.00001, operator + ": rewind " + clip)
			await process_frame
			await process_frame
			_check(before.distance_to(visual.socket_world("KnuckleR")) < 0.00001, operator + ": autonomous clock " + clip)
			visual.present({"animation": clip, "animation_frame": 7, "x": 1000, "facing": -1}, 0.0)
			var mirrored: Vector3 = visual.socket_world("KnuckleR")
			_check(absf(before.x + mirrored.x - 2.0) < 0.0001 and absf(before.y - mirrored.y) < 0.0001, operator + ": facing " + clip)
		visual.reset()
	# Binary manifest pair contracts are exported on each victim clip. Compare
	# native sockets over every actual hold frame, for every selected body pairing.
	var roster: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/roster.json"))
	for operator: Dictionary in roster["operators"]:
		var attacker_id := str(operator["id"])
		if not visuals.has(attacker_id):
			continue
		for move_name: String in operator["moves"]:
			var move: Dictionary = operator["moves"][move_name]
			var pair: Dictionary = move.get("throw", move.get("counter", {}))
			if pair.is_empty():
				continue
			var contact := int(pair.get("from", move["startup"]))
			var release := int(pair["release_frame"])
			for victim_id: String in visuals:
				# Mirror matches need distinct nodes, too.
				var victim := Visual.new()
				root.add_child(victim)
				_check(victim.configure(victim_id), "paired victim configure")
				for frame: int in range(contact, release + 1):
					visuals[attacker_id].present({"animation": move_name, "animation_frame": frame, "facing": 1}, 0.0)
					victim.present({"animation": "victim_" + attacker_id + "_" + move_name, "animation_frame": frame,
						"x": int(pair.get("victim_x", 600)), "y": int(pair.get("victim_y", 0)), "facing": -1}, 0.0)
					var distance: float = visuals[attacker_id].socket_world("GripR").distance_to(victim.socket_world("Chest"))
					_check(distance <= 0.06, "%s/%s/%s frame %d contact %.6f" % [attacker_id, victim_id, move_name, frame, distance])
				victim.free()
	var result := {"status": "passed" if failures.is_empty() else "failed", "checks": checks,
		"failures": failures, "operators": selected, "art_accepted": false}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t") + "\n")
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
