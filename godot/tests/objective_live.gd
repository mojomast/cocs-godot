extends SceneTree
## Normal-rate Room-wire observer. Does not alter the source match or actor poses.
var map_id := ""
var mode := ""
var seen := 0
var geometry := 0
var vehicle_frames := 0
var results := false
var winner: Variant = null
var reason := ""
var session: Node
var deadline := 0
var failed := false
var controlled := false

func check(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		push_error("OBJECTIVE_LIVE_FAIL " + mode + "/" + map_id + " " + message)
		quit(1)
	return ok

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): map_id = arg.trim_prefix("--map=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg == "--controlled-completion": controlled = true
	call_deferred("run")

func observe(frame: Dictionary) -> void:
	if failed or session.phase != 3 or not frame.get("state") is Dictionary: return
	var source: Dictionary = frame.state
	if not check(source.mapId == map_id and source.config.mode == mode, "source identity"): return
	if mode == "assault":
		if not check(not session.assault.objective.is_empty(), "source objective projection"): return
		var expected := ["puma", "scout"] if map_id == "tidal-citadel" else ["puma", "scout", "titan", "transport", "hornet"]
		var kinds: Array = source.vehicles.map(func(vehicle: Dictionary) -> String: return str(vehicle.kind))
		if not check(expected.all(func(kind: String) -> bool: return kind in kinds), "authored source vehicle roster"): return
		if not check(is_instance_valid(session.vehicle_fleet), "shared source vehicle renderer"): return
		for vehicle: Dictionary in source.vehicles:
			if not check(is_instance_valid(session.vehicle_fleet.vehicle_node(vehicle.id)), "source chassis rendered by shared bridge"): return
		vehicle_frames += 1
		var sector: Dictionary = session.assault.active_sector()
		if not sector.is_empty() and is_instance_valid(session.sectors.marker):
			if check(session.sectors.marker.position.distance_to(Vector3(sector.x,sector.y+0.08,sector.z)) < 0.01, "active sector geometry"): geometry += 1
		if not check(session.objective_label.text.contains("ASSAULT"), "visible objective guidance"): return
	else:
		if not check(not session.zones.projection.is_empty(), "source objective projection"): return
		for zone: Dictionary in source.objectives.zones:
			if session.zone_renderer.markers.has(zone.id):
				if check(session.zone_renderer.markers[zone.id].position.distance_to(Vector3(zone.x,zone.y,zone.z)) < 0.01, "source zone geometry"): geometry += 1
		if not source.over and not check(session.zones.text().title.contains(mode.to_upper()), "variant HUD mode identity"): return
	seen += 1

func completed(frame: Dictionary) -> void:
	if failed: return
	results = true
	winner = frame.state.get("winner")
	reason = str(frame.state.get("overReason"))
	check(frame.state.get("over") == true and frame.state.config.mode == mode, "authoritative results")

func run() -> void:
	deadline = Time.get_ticks_msec() + 110000
	session = load("res://assault/demo.tscn" if mode == "assault" else "res://zone_modes/demo.tscn").instantiate()
	root.add_child(session)
	session.client.snapshot.connect(observe)
	session.client.results.connect(completed)
	while session.phase != 4 and not failed:
		await process_frame
		if Time.get_ticks_msec() > deadline or session.phase == -1:
			check(false,"source results timeout or session error: " + session.label.text)
			return
	if not check(results and seen > 10 and geometry > 0 and (mode != "assault" or vehicle_frames > 10), "live source snapshots and marker/vehicle geometry"): return
	if not check(session.scoreboard.finished and session.scoreboard.entries.size() > 0, "source objective scoreboard results"): return
	if mode == "assault":
		if not check(winner == (0 if controlled else 1) and session.objective_label.text.contains("Attackers win" if controlled else "Defenders win"), "source assault result"): return
	else:
		if not check(session.zones.projection.winner == winner and session.zones.projection.over, "source timeout winner projection"): return
	if not check(session._request_restart(), "source rematch queued"): return
	while session.round_starts < 2 and not failed:
		await process_frame
		if Time.get_ticks_msec() > deadline:
			check(false,"rematch start timeout")
			return
	if not check(session.phase == 3 and session.scoreboard.finished == false, "new authoritative round clears results"): return
	print("OBJECTIVE_LIVE_OK ", JSON.stringify({"mode":mode,"map":map_id,"snapshots":seen,"geometry":geometry,"vehicle_frames":vehicle_frames,"winner":winner,"reason":reason,"rounds":session.round_starts,"normal_rate":true,"controlled_fixture_placement":controlled}))
	session.client.disconnect_server()
	quit(0)
