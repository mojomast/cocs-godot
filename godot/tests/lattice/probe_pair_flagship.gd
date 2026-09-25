extends SceneTree
## Two independent native clients with engine-generated ordinary inputs.
## Explicit synthetic multiplayer smoke, not OS/human input or natural result.
var scene: Node
var began := 0
var last_input := 0
var input_sent := 0
var initial: Variant = null
var latest: Variant = null
var triggered := false
var reported := false
var start_file := ""
var stop_file := ""
var role := ""

func _initialize() -> void:
	began = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--start-file="): start_file = arg.trim_prefix("--start-file=")
		elif arg.begins_with("--stop-file="): stop_file = arg.trim_prefix("--stop-file=")
		elif arg.begins_with("--pair-role="): role = arg.trim_prefix("--pair-role=")
	call_deferred("start_scene")

func start_scene() -> void:
	scene = load("res://lattice/world_demo.tscn").instantiate()
	root.add_child(scene)

func pose(client: Node) -> Variant:
	var snapshots: Array = client.get("snapshots")
	if snapshots.is_empty(): return null
	var state: Dictionary = snapshots.back().get("state", {})
	for actor: Variant in state.get("actors", []):
		if actor is Dictionary and actor.get("id") == client.get("actor_id"):
			return {"x":actor.get("x"),"z":actor.get("z")}
	return null

func _process(_delta: float) -> bool:
	if scene == null: return false
	var elapsed := Time.get_ticks_msec() - began
	if elapsed > 30000:
		report("timeout")
		quit(1)
		return false
	if role == "host" and not triggered and scene.get("phase") == 12 and not start_file.is_empty() and FileAccess.file_exists(start_file):
		triggered = true
		scene.call("world_start_requested")
	var client: Node = scene.get("client")
	if scene.get("phase") == 3 and client.get("last_snapshot_seq") >= 1:
		if reported:
			if not stop_file.is_empty() and FileAccess.file_exists(stop_file): quit()
			return false
		if initial == null: initial = pose(client)
		latest = pose(client)
		if elapsed - last_input >= 85:
			last_input = elapsed
			var controls := {"x":1.0 if role == "host" else -1.0,"z":0.0,"yaw":0.0,"pitch":0.0,
				"fire":false,"jump":false,"reload":false,"sprint":false,"crouch":false,"interact":false,
				"mobility":false,"ads":false,"power":false,"melee":false,"grenade":false,"altFire":false}
			if client.send_input(controls) == OK: input_sent += 1
		if input_sent >= 45 and latest != null:
			reported = true
			report("active")
	return false

func report(status: String) -> void:
	var client: Node = scene.get("client")
	print("LATTICE_PAIR_PROBE ", JSON.stringify({"status":status,"role":role,"phase":scene.get("phase"),
		"peer":client.get("peer_id"),"actor":client.get("actor_id"),"revision":client.get("revision"),
		"source_sequence":client.get("last_snapshot_seq"),"input_sent":input_sent,
		"initial":initial,"latest":latest,"engine_input":true,"human_input":false,"triggered":triggered}))
