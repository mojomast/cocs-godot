extends SceneTree

const Presentation = preload("res://world/presentation.gd")
const Client = preload("res://net/client.gd")
const Catalog = preload("res://world/catalog.gd")

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var catalog := Catalog.new()
	check(catalog.open(), "catalog")
	var client := Client.new()
	var view := Presentation.new()
	root.add_child(view)
	client.allowlist = catalog.entries
	client.requested_map = "meridian-exchange"
	client.started.connect(func(_f: Dictionary) -> void: view.clear_round())
	client.snapshot.connect(func(f: Dictionary) -> void: view.apply_state(f.state, client.actor_id))
	client.results.connect(func(f: Dictionary) -> void: view.apply_state(f.state, client.actor_id))
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/protocol/captured.json"))
	var count: int = 0
	var results_count: int = 0
	var last_state: Dictionary = {}
	for record: Dictionary in capture.frames:
		if record.direction != "server" or record.client != 1: continue
		check(client.decode_text(JSON.stringify(record.frame)), "decode")
		if record.frame.type not in ["snapshot", "results"]: continue
		var state: Dictionary = record.frame.state
		last_state = state
		check(view.actors.size() == state.actors.size(), "actor count")
		for actor: Dictionary in state.actors:
			var node: Node3D = view.actors[int(actor.id)]
			check(node.position.is_equal_approx(Vector3(actor.x, actor.y + 0.9, actor.z)), "source coordinates")
			check(node.visible == (int(actor.id) != client.actor_id and float(actor.dead) <= 0), "death/local visibility")
			if int(actor.id) == client.actor_id:
				check(view.eye_position().is_equal_approx(Vector3(actor.x, actor.y + actor.eyeHeight, actor.z)), "camera eye")
		check("HP" in view.hud_text, "HUD health")
		if record.frame.type == "results":
			results_count += 1
			check("RESULTS" in view.hud_text, "results HUD")
		count += 1
	check(count > 1 and results_count > 0, "real snapshots/results present")
	# Explicit synthetic lifecycle mutation, not claimed as captured server output.
	var removed: Dictionary = last_state.duplicate(true)
	removed.actors = []
	view.apply_state(removed, client.actor_id)
	check(view.actors.is_empty() and view.get_child_count() == 0, "despawn cleanup")
	check(view.local_actor.is_empty(), "stale local actor removed")
	view.apply_state(last_state, client.actor_id)
	view.clear_round()
	check(view.actors.is_empty() and view.get_child_count() == 0 and view.applied == 0, "restart cleanup")
	print("PORT_PRESENTATION_REPLAY_OK states=", count, " results=", results_count, " coordinates=source camera=eye death_visibility=true cleanup=true")
	view.free()
	client.free()
	quit(0)
