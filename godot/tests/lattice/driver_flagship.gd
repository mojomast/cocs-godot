extends SceneTree
## Engine-scripted ordinary recipient controls, never private Match mutation.
## Source outcomes can be natural; input is engine-generated, not OS/human.
var scene: Node
var began := 0
var last_input := 0
var last_order := 0
var orders_sent := 0
var inputs_sent := 0
var local_captures := 0
var captures := 0
var started := false
var restarting := false
var final_result: Dictionary = {}
var limit := 900
var idle := false
var capture_dir := ""
var commands_captured := false

func _initialize() -> void:
	began = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--driver-limit="): limit = int(arg.trim_prefix("--driver-limit="))
		if arg == "--driver-idle": idle = true
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	call_deferred("start_scene")

func start_scene() -> void:
	scene = load("res://lattice/world_demo.tscn").instantiate()
	root.add_child(scene)
	var client: Node = scene.get("client")
	client.events.connect(observe_events)

func observe_events(items: Array) -> void:
	var client: Node = scene.get("client")
	for raw: Variant in items:
		if not raw is Dictionary or raw.get("type") != "cocs-capture": continue
		captures += 1
		if raw.get("participants") is Array and client.get("actor_id") in raw.participants: local_captures += 1

func local_actor(client: Node) -> Dictionary:
	var snapshots: Array = client.get("snapshots")
	if snapshots.is_empty(): return {}
	var state: Dictionary = snapshots.back().get("state", {})
	for raw: Variant in state.get("actors", []):
		if raw is Dictionary and raw.get("id") == client.get("actor_id"): return raw
	return {}

func _process(_delta: float) -> bool:
	if scene == null: return false
	var elapsed := Time.get_ticks_msec() - began
	if elapsed > (limit + 160) * 1000:
		report("timeout")
		quit(1)
		return false
	if scene.get("phase") == 12 and not started:
		started = true
		call_deferred("setup_then_start")
	var client: Node = scene.get("client")
	if scene.get("phase") == 4 and not restarting:
		var observed_result: Dictionary = client.get("result_projection")
		final_result = observed_result.duplicate(true)
		restarting = true
		call_deferred("result_then_restart")
	if restarting and scene.get("phase") == 3 and client.get("revision") >= 2 and client.get("last_snapshot_seq") >= 1:
		report("result-and-restart")
		quit()
		return false
	if scene.get("phase") != 3 or idle: return false
	if not commands_captured and client.get("last_snapshot_seq") >= 3:
		commands_captured = true
		call_deferred("capture_commands")
	if elapsed - last_input >= 85:
		last_input = elapsed
		var actor := local_actor(client)
		var target: Dictionary = scene.get("lattice_hud").get("target_model")
		var node: Dictionary = {}
		var projection: Dictionary = client.get("projection")
		for candidate: Variant in projection.get("nodes", []):
			if candidate is Dictionary and candidate.get("id") == target.get("target_id"): node = candidate
		var x := 0.0
		var z := 0.0
		if not actor.is_empty() and not node.is_empty():
			var destination := Vector2(float(node.x), float(node.z))
			# Authored HQ courtyards have cardinal doorway gaps. Route through the
			# public static east/west court exit before following planar guidance.
			if actor.get("team") == 0 and float(actor.x) < -76.0: destination = Vector2(-76, 0)
			elif actor.get("team") == 1 and float(actor.x) > 76.0: destination = Vector2(76, 0)
			var dx: float = destination.x - float(actor.x)
			var dz: float = destination.y - float(actor.z)
			var distance := sqrt(dx * dx + dz * dz)
			if distance > 3.0: x = dx / distance; z = dz / distance
		var controls := {"x":x,"z":z,"yaw":0.0,"pitch":0.0,"fire":false,"jump":false,
			"reload":false,"sprint":false,"crouch":false,"interact":false,"mobility":false,
			"ads":false,"power":false,"melee":false,"grenade":false,"altFire":false}
		if client.send_input(controls) == OK: inputs_sent += 1
	if elapsed - last_order >= 2300:
		last_order = elapsed
		var selected: Dictionary = scene.get("lattice_hud").get("target_model")
		var target_id: String = str(selected.get("target_id", ""))
		if selected.get("capture_legal") == true and not target_id.is_empty() and client.action_gate("hold", target_id).is_empty():
			if client.activate("hold", target_id).is_empty(): orders_sent += 1
	return false

func save_view(name: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	var path := capture_dir.path_join(name + ".png")
	var err := root.get_texture().get_image().save_png(path)
	print("LATTICE_CAPTURE ", JSON.stringify({"name":name,"path":path,"error":err,"synthetic_input":true}))

func setup_then_start() -> void:
	await save_view("setup")
	scene.call("world_start_requested")

func capture_commands() -> void:
	if capture_dir.is_empty(): return
	var overlay: Control = scene.get("world_commands")
	overlay.show()
	overlay.call("world_refresh")
	await save_view("commands")
	overlay.hide()

func result_then_restart() -> void:
	await save_view("results")
	scene.call("world_restart_requested")

func report(status: String) -> void:
	var client: Node = scene.get("client")
	print("LATTICE_NATURAL_DRIVER ", JSON.stringify({"status":status,"engine_input":true,"human_input":false,
		"phase":scene.get("phase"),"revision":client.get("revision"),"actor":client.get("actor_id"),
		"inputs_sent":inputs_sent,"orders_sent":orders_sent,"captures":captures,"local_captures":local_captures,
		"final_result":final_result,"elapsed_ms":Time.get_ticks_msec()-began}))
