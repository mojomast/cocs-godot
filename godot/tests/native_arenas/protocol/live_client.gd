extends SceneTree
## Live protocol/ADS test. The Node runner labels synthetic vs generated maps.
const NativeClient = preload("res://native_arenas/client.gd")
const OrdinaryClient = preload("res://net/client.gd")
var client: Node
var map_id := "prism-foundry"
var elapsed := 0.0
var stage := 0
var ordinary := false
var event_ids: Dictionary = {}
var first_epoch := 0
var snapshot_count := 0

func _initialize() -> void:
	var endpoint := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg.begins_with("--map="): map_id = arg.trim_prefix("--map=")
		if arg == "--ordinary": ordinary = true
	client = OrdinaryClient.new() if ordinary else NativeClient.new()
	root.add_child(client)
	client.connection_error.connect(func(message: String) -> void: push_error(message); quit(1))
	client.lobby.connect(on_lobby)
	client.snapshot.connect(on_snapshot)
	client.events.connect(func(items: Array) -> void:
		for event: Dictionary in items:
			if event_ids.has(str(event.id)): push_error("Duplicate public event"); quit(1)
			event_ids[str(event.id)] = true)
	if client.connect_server(endpoint, {map_id:{"modes":["deathmatch"]}}, map_id) != OK: quit(1)

func on_lobby(frame: Dictionary) -> void:
	if stage == 1 and frame.get("config") == null:
		stage = 2
		client.configure_match("deathmatch", 2)
	elif stage == 2 and frame.get("config") != null:
		stage = 3
		client.send_frame({"type":"start"})

func on_snapshot(frame: Dictionary) -> void:
	snapshot_count += 1
	if frame.state.mapId != map_id or frame.state.config.mode != "deathmatch" or frame.state.actors.size() != 3:
		push_error("Native identity/roster mismatch"); quit(1); return
	var actor: Dictionary = frame.state.actors[0]
	if stage == 3:
		first_epoch = int(frame.inputEpoch)
		stage = 4
		client.send_input({"ads":true})
	elif stage == 4 and client.last_ack >= 1:
		if actor.ads != true: push_error("Source ADS press missing"); quit(1); return
		stage = 5
		client.send_input({"ads":false})
	elif stage == 5 and client.last_ack >= 2:
		if actor.ads != false: push_error("Source ADS release missing"); quit(1); return
		stage = 6
		client.send_input({"ads":true})
	elif stage == 6 and int(frame.inputEpoch) > first_epoch:
		if actor.ads != false: push_error("Stale ADS survived cancellation"); quit(1); return
		if event_ids.size() < 3: push_error("Construction spawn events missing"); quit(1); return
		print("NATIVE_ARENA_LIVE_PROTOCOL ", JSON.stringify({"ok":true,"mapId":map_id,"ordinary":ordinary,
			"snapshots":snapshot_count,"eventIds":event_ids.size(),"ack":client.last_ack,"epoch":frame.inputEpoch,
			"adsPressReleaseStale":true}))
		client.disconnect_server()
		quit(0)

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 20:
		push_error("Native protocol timeout at stage %d" % stage); quit(1)
	if stage == 0 and client.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		stage = 1
		client.create_room()
	return false
