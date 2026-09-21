extends SceneTree

const Pickups = preload("res://world/pickups.gd")
var checks: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var view := Pickups.new()
	root.add_child(view)
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/protocol/captured.json"))
	var states: int = 0
	var sample: Dictionary = {}
	for record: Dictionary in capture.frames:
		if record.direction != "server" or record.client != 1: continue
		if record.frame.type not in ["snapshot", "results"]: continue
		var state: Dictionary = record.frame.state
		view.apply_state(state)
		check(view.markers.size() == state.pickups.size(), "recorded pickup count")
		for pickup: Dictionary in state.pickups:
			var node: Node3D = view.markers[int(pickup.id)]
			check(node.position.is_equal_approx(Vector3(pickup.x, pickup.y + 1, pickup.z)), "authoritative support position")
			check(node.visible == (float(pickup.wait) <= 0), "recorded availability")
			check(node.get_meta("kind") == str(pickup.kind), "pickup kind")
		sample = state.duplicate(true)
		states += 1
	check(states > 1 and not sample.pickups.is_empty(), "actual pickup records present")
	# Explicit synthetic lifecycle cases; not claimed as live collection evidence.
	var pickup: Dictionary = sample.pickups[0]
	var id: int = int(pickup.id)
	var instance: int = view.markers[id].get_instance_id()
	pickup.wait = 12.0
	view.apply_state(sample)
	check(not view.markers[id].visible, "collected pickup hidden")
	await process_frame
	check(not view.markers[id].visible, "no client-side respawn")
	pickup.wait = 0.0
	sample.pickups.reverse()
	view.apply_state(sample)
	check(view.markers[id].visible, "authoritative respawn shown")
	check(view.markers[id].get_instance_id() == instance, "reorder/respawn retain identity")
	view.apply_state({"pickups": [pickup]})
	check(view.markers.size() == 1 and view.get_child_count() == 1, "despawn removes stale nodes")
	view.apply_state({})
	check(view.markers.is_empty() and view.get_child_count() == 0, "missing pickup list clears stale state")
	view.apply_state(sample)
	view.clear_round()
	check(view.markers.is_empty() and view.get_child_count() == 0, "round reset")
	print("PORT_PICKUPS_OK recorded_states=", states, " checks=", checks, " synthetic_lifecycle=true")
	view.free()
	quit(0)
