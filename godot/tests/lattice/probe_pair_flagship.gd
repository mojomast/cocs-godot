extends SceneTree
## Two independent native clients with engine-generated ordinary inputs.
## Explicit synthetic multiplayer smoke, not OS/human input or natural result.
## With --full-round the same clients keep sending ordinary inputs until the
## source publishes a terminal result, then the host issues only the ordinary
## restart request so a clean restart can be observed. It never fabricates a
## results/start event, and never claims a human or five-wave outcome.
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
var full_round := false
var probe_timeout_ms := 30000
var terminal_reported := false
var restart_reported := false
var terminal_revision := -1
var restart_requested := false

func _initialize() -> void:
	began = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--start-file="): start_file = arg.trim_prefix("--start-file=")
		elif arg.begins_with("--stop-file="): stop_file = arg.trim_prefix("--stop-file=")
		elif arg.begins_with("--pair-role="): role = arg.trim_prefix("--pair-role=")
		elif arg.begins_with("--probe-timeout-ms="): probe_timeout_ms = int(arg.trim_prefix("--probe-timeout-ms="))
		elif arg == "--full-round": full_round = true
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

## Recipient-only result facts. These come from the client's own projection;
## nothing is inferred from elapsed time or a local timer.
func result_fields(client: Node) -> Dictionary:
	var result: Dictionary = client.get("result_projection")
	if result.is_empty(): return {"result_present": false}
	var outcome: Variant = result.get("outcome")
	var progress: Variant = result.get("mode_progress")
	var waves: Variant = progress.get("waves") if progress is Dictionary else null
	var hq: Variant = progress.get("hq") if progress is Dictionary else null
	return {"result_present": true,
		"result_winner": outcome.get("winner") if outcome is Dictionary else null,
		"result_reason": outcome.get("reason") if outcome is Dictionary else null,
		"result_mode": result.get("mode"), "result_revision": result.get("revision"),
		"result_source_time": result.get("source_time"), "result_scores": result.get("scores"),
		"result_waves": waves, "result_hq": hq}

func _process(_delta: float) -> bool:
	if scene == null: return false
	var elapsed := Time.get_ticks_msec() - began
	if elapsed > probe_timeout_ms:
		report("timeout")
		quit(1)
		return false
	if role == "host" and not triggered and scene.get("phase") == 12 and not start_file.is_empty() and FileAccess.file_exists(start_file):
		triggered = true
		scene.call("world_start_requested")
	var client: Node = scene.get("client")
	if scene.get("phase") == 3 and client.get("last_snapshot_seq") >= 1:
		if reported and (not full_round or restart_reported):
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
		if input_sent >= 45 and latest != null and not reported:
			reported = true
			report("active")
	if not full_round: return false
	if scene.get("phase") == 4 and not terminal_reported:
		terminal_reported = true
		terminal_revision = int(client.get("revision"))
		report("terminal")
		# The host alone issues the ordinary restart request; the server still
		# mints the authoritative restart. The guest only observes it.
		if role == "host" and not restart_requested:
			restart_requested = true
			scene.call("world_restart_requested")
	if terminal_reported and not restart_reported and scene.get("phase") == 3 and int(client.get("revision")) > terminal_revision:
		restart_reported = true
		report("restarted")
	if restart_reported and not stop_file.is_empty() and FileAccess.file_exists(stop_file): quit()
	return false

func report(status: String) -> void:
	var client: Node = scene.get("client")
	var fields := {"status":status,"role":role,"phase":scene.get("phase"),
		"peer":client.get("peer_id"),"actor":client.get("actor_id"),"revision":client.get("revision"),
		"source_sequence":client.get("last_snapshot_seq"),"input_sent":input_sent,
		"initial":initial,"latest":latest,"engine_input":true,"human_input":false,"triggered":triggered,
		"full_round":full_round,"terminal_reported":terminal_reported,"restart_reported":restart_reported,
		"scripted_restart_requested":restart_requested}
	fields.merge(result_fields(client))
	print("LATTICE_PAIR_PROBE ", JSON.stringify(fields))
