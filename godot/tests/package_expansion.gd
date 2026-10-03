extends SceneTree
## External release verifier. The script is NOT included in the PCK: it loads
## the unchanged production scene and resources from --main-pack cocs.pck.
var product: Node
var client: Node
var map_id := ""
var mode := ""
var expected_hash := ""
var scene_path := ""
var start_hash := ""
var snapshots := 0
var last: Dictionary = {}
var age := 0.0
var source_mode := false
var catalogs_ok := false
var expected_art := ""
var diagnostics := false
var wall_start := Time.get_ticks_msec()
var next_trace_ms := 0
var process_frames := 0

func observed(node: Object, names: Array) -> Dictionary:
	var result := {}
	if not is_instance_valid(node): return result
	for property: Dictionary in node.get_property_list():
		if str(property.name) in names: result[str(property.name)] = node.get(str(property.name))
	return result

func trace_phase(stage: String, extra: Dictionary = {}) -> void:
	if not diagnostics: return
	var record := {"stage":stage,"wall_ms":Time.get_ticks_msec()-wall_start,"delta_age":age,"process_frames":process_frames,"map":map_id,"mode":mode,"snapshots":snapshots,"start_hash":start_hash}
	record["product"] = observed(product,["phase","startup_error","error","current_id","selected_mode","round_starts"])
	record["client"] = observed(client,["peer_id","actor_id","last_ack"])
	if is_instance_valid(client):
		var values := observed(client,["peer"])
		if values.get("peer") is WebSocketPeer: record["socket_state"] = values.peer.get_ready_state()
	record.merge(extra)
	print("EXPANSION_PHASE ",JSON.stringify(record))

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): map_id = arg.trim_prefix("--map=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--expect-hash="): expected_hash = arg.trim_prefix("--expect-hash=")
		if arg == "--source-mode": source_mode = true
		if arg.begins_with("--expect-art="): expected_art = arg.trim_prefix("--expect-art=")
		if arg == "--expansion-diagnostics": diagnostics = true
	if map_id.is_empty() or mode.is_empty() or (not source_mode and expected_hash.length() != 64):
		push_error("EXPANSION_INVALID_OPTIONS")
		quit(2)
		return
	call_deferred("inspect")

func inspect() -> void:
	trace_phase("inspect_begin")
	var horde := mode == "horde"
	scene_path = "res://horde_maps/blackwater_demo.tscn" if horde else ("res://multiplayer_worlds/sports_demo.tscn" if mode.begins_with("puma-") else ("res://multiplayer_worlds/lattice_demo.tscn" if mode.begins_with("cocs") else "res://multiplayer_worlds/demo.tscn"))
	var art := "res://horde_maps/art/blackwater-reclamation.glb" if horde else "res://multiplayer_worlds/art/" + ("worlds/" if map_id not in ["switchyard-ward", "rainmarket-exchange"] else "") + map_id + ".glb"
	if not expected_art.is_empty() and not horde: art = expected_art
	if source_mode:
		scene_path = "res://mode_expansion/demo.tscn"
		var captions: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://experience/source_catalog.json"))
		var gameplay: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://player_gameplay/catalog.json"))
		catalogs_ok = captions is Dictionary and gameplay is Dictionary and captions.get("captions", {}).size() >= 115 and gameplay.get("operators", {}).size() == 9
		if not catalogs_ok:
			push_error("EXPANSION_PLAYER_CATALOGS_MISSING"); quit(2); return
	trace_phase("resource_check_begin",{"scene":scene_path,"art":art})
	if not ResourceLoader.exists(scene_path) or (not source_mode and (not ResourceLoader.exists(art) or not load(art) is PackedScene)):
		push_error("EXPANSION_PCK_RESOURCE_MISSING " + scene_path + " " + art)
		quit(2)
		return
	if horde:
		for robot in ["scrapper", "skirmisher", "sentinel", "mortar", "bulwark", "warden"]:
			var path := "res://campaign/art/robots/%s.glb" % robot
			if not ResourceLoader.exists(path) or not load(path) is PackedScene:
				push_error("EXPANSION_PCK_ROBOT_MISSING " + path)
				quit(2)
				return
	trace_phase("resource_check_done")
	product = load(scene_path).instantiate()
	trace_phase("product_instantiated")
	trace_phase("product_ready_begin")
	root.add_child(product)
	trace_phase("product_ready_done")
	current_scene = product
	client = product.net if mode.begins_with("puma-") else product.client
	client.started.connect(func(frame: Dictionary) -> void:
		start_hash = str(frame.get("geometryHash", frame.get("hordeMapContract", {}).get("geometryHash", "")))
		trace_phase("started"))
	client.snapshot.connect(func(frame: Dictionary) -> void:
		last = frame
		snapshots += 1
		if snapshots in [1,3]: trace_phase("snapshot",{"tick":frame.get("state",{}).get("tick",-1)}))
	client.connection_error.connect(func(message: String) -> void:
		push_error("EXPANSION_PRODUCT_ERROR " + message)
		quit(2))
	if diagnostics:
		client.lobby.connect(func(frame: Dictionary) -> void: trace_phase("lobby",{"players":frame.get("players",[]).size()}))
		client.transport_dropped.connect(func(message: String) -> void: trace_phase("transport_dropped",{"message":message}))
	trace_phase("observers_attached")

func _process(delta: float) -> bool:
	age += delta
	process_frames += 1
	if diagnostics and Time.get_ticks_msec() >= next_trace_ms:
		next_trace_ms = Time.get_ticks_msec() + 5000
		trace_phase("waiting")
	if age > 35:
		trace_phase("timeout")
		push_error("EXPANSION_PRODUCT_TIMEOUT " + map_id + "/" + mode)
		quit(2)
		return false
	if snapshots < 3 or not is_instance_valid(product): return false
	var state: Dictionary = last.get("state", {})
	var objectives: Dictionary = state.get("objectives") if state.get("objectives") is Dictionary else {}
	var race: Dictionary = state.get("race") if state.get("race") is Dictionary else {}
	if state.is_empty() or str(state.get("mapId", "")) != map_id or (not source_mode and start_hash != expected_hash):
		push_error("EXPANSION_PRODUCT_HASH_OR_MAP_MISMATCH " + map_id + " " + start_hash)
		quit(2)
		return false
	var horde := mode == "horde"
	var robots := []
	if source_mode:
		if str(state.get("config", {}).get("mode", "")) != mode or product.objective_label.text.length() < 20:
			push_error("EXPANSION_SOURCE_MODE_IDENTITY_MISMATCH"); quit(2); return false
		if mode == "arsenal":
			var actor: Dictionary = state.actors[0]
			if actor.get("ammo", []).size() != 10 or actor.ammo.any(func(value: Variant) -> bool: return value != "∞"):
				push_error("EXPANSION_ARSENAL_LOADOUT_MISSING"); quit(2); return false
		elif mode == "juggernaut" and (not objectives.has("juggernautId") or not objectives.has("points")):
			push_error("EXPANSION_CROWN_STATE_MISSING"); quit(2); return false
		elif mode == "team-elimination" and objectives.get("lives", {}).size() != 2:
			push_error("EXPANSION_TEAM_TICKETS_MISSING"); quit(2); return false
		elif mode == "vip-escort" and (not objectives.has("vipId") or objectives.get("extract", {}).is_empty()):
			push_error("EXPANSION_VIP_STATE_MISSING"); quit(2); return false
	elif horde:
		if last.get("hordeMapContract", {}).get("geometryHash") != expected_hash or state.get("blackwater", {}).get("version") != 1:
			push_error("EXPANSION_BLACKWATER_CONTRACT_MISMATCH")
			quit(2)
			return false
		# The production authority starts with a seven-second wave-zero intermission.
		# Keep the bounded deadline and wait for its ordinary wave-one transition.
		var wave := int(state.get("singleplayer", {}).get("wave", -1))
		if wave == 0: return false
		if wave != 1:
			push_error("EXPANSION_BLACKWATER_WAVE_MISMATCH")
			quit(2)
			return false
		for actor: Dictionary in state.get("actors", []):
			if actor.get("isNpc", false): robots.append(str(actor.get("npcModel", "")))
		if robots.is_empty(): return false
	elif mode == "ctf" and objectives.get("flags", []).size() != 2:
		push_error("EXPANSION_CTF_FLAGS_MISSING"); quit(2); return false
	elif mode == "payload" and float(objectives.get("payload", {}).get("total", 0)) <= 60:
		push_error("EXPANSION_PAYLOAD_ROUTE_MISSING"); quit(2); return false
	elif mode.begins_with("puma-") and str(race.get("phase", "")).is_empty():
		push_error("EXPANSION_SPORTS_STATE_MISSING"); quit(2); return false
	elif mode in ["domination", "koth", "uplink", "holdout", "assault", "combined-arms"] and objectives.get("zones", []).is_empty():
		push_error("EXPANSION_ZONES_MISSING"); quit(2); return false
	if not horde and product.get("current_id") != null and str(product.get("current_id")) != map_id:
		push_error("EXPANSION_PRODUCT_SCENE_MAP_MISMATCH"); quit(2); return false
	print("EXPANSION_PRODUCT_READY ", JSON.stringify({"scene":scene_path,"map":map_id,"mode":mode,"hash":start_hash,"snapshots":snapshots,"actors":state.get("actors", []).size(),"objective":objectives.get("kind", ""),"race":race.get("phase", ""),"robots":robots,"blackwater":state.get("blackwater", {}).get("version", 0),"source_mode":source_mode,"catalogs":catalogs_ok,"instructions":product.objective_label.text if source_mode else ""}))
	quit(0)
	return false
