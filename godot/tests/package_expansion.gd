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

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): map_id = arg.trim_prefix("--map=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--expect-hash="): expected_hash = arg.trim_prefix("--expect-hash=")
	if map_id.is_empty() or mode.is_empty() or expected_hash.length() != 64:
		push_error("EXPANSION_INVALID_OPTIONS")
		quit(2)
		return
	call_deferred("inspect")

func inspect() -> void:
	var horde := mode == "horde"
	scene_path = "res://horde_maps/blackwater_demo.tscn" if horde else ("res://multiplayer_worlds/sports_demo.tscn" if mode.begins_with("puma-") else ("res://multiplayer_worlds/lattice_demo.tscn" if mode.begins_with("cocs") else "res://multiplayer_worlds/demo.tscn"))
	var art := "res://horde_maps/art/blackwater-reclamation.glb" if horde else "res://multiplayer_worlds/art/" + ("worlds/" if map_id not in ["switchyard-ward", "rainmarket-exchange"] else "") + map_id + ".glb"
	if not ResourceLoader.exists(scene_path) or not ResourceLoader.exists(art) or not load(art) is PackedScene:
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
	product = load(scene_path).instantiate()
	root.add_child(product)
	current_scene = product
	client = product.net if mode.begins_with("puma-") else product.client
	client.started.connect(func(frame: Dictionary) -> void:
		start_hash = str(frame.get("geometryHash", frame.get("hordeMapContract", {}).get("geometryHash", ""))))
	client.snapshot.connect(func(frame: Dictionary) -> void:
		last = frame
		snapshots += 1)
	client.connection_error.connect(func(message: String) -> void:
		push_error("EXPANSION_PRODUCT_ERROR " + message)
		quit(2))

func _process(delta: float) -> bool:
	age += delta
	if age > 35:
		push_error("EXPANSION_PRODUCT_TIMEOUT " + map_id + "/" + mode)
		quit(2)
		return false
	if snapshots < 3 or not is_instance_valid(product): return false
	var state: Dictionary = last.get("state", {})
	var objectives: Dictionary = state.get("objectives") if state.get("objectives") is Dictionary else {}
	var race: Dictionary = state.get("race") if state.get("race") is Dictionary else {}
	if state.is_empty() or str(state.get("mapId", "")) != map_id or start_hash != expected_hash:
		push_error("EXPANSION_PRODUCT_HASH_OR_MAP_MISMATCH " + map_id + " " + start_hash)
		quit(2)
		return false
	var horde := mode == "horde"
	var robots := []
	if horde:
		if last.get("hordeMapContract", {}).get("geometryHash") != expected_hash or state.get("blackwater", {}).get("version") != 1 or state.get("singleplayer", {}).get("wave") != 1:
			push_error("EXPANSION_BLACKWATER_CONTRACT_MISMATCH")
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
	print("EXPANSION_PRODUCT_READY ", JSON.stringify({"scene":scene_path,"map":map_id,"mode":mode,"hash":start_hash,"snapshots":snapshots,"actors":state.get("actors", []).size(),"objective":objectives.get("kind", ""),"race":race.get("phase", ""),"robots":robots,"blackwater":state.get("blackwater", {}).get("version", 0)}))
	quit(0)
	return false
