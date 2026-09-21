extends SceneTree

const Client = preload("res://net/client.gd")
const Catalog = preload("res://world/catalog.gd")
var client := Client.new()
var phase: int = 0
var elapsed: float = 0
var endpoint: String = ""
var frames: int = 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
	var catalog := Catalog.new()
	if endpoint.is_empty() or not catalog.open():
		quit(1)
		return
	root.add_child.call_deferred(client)
	client.connection_error.connect(func(message: String) -> void: push_error(message); quit(1))
	client.lobby.connect(on_lobby)
	client.started.connect(func(_frame: Dictionary) -> void: phase = 3; client.send_input({"forward":1,"yaw":0,"pitch":0}))
	client.snapshot.connect(on_snapshot)
	if client.connect_server(endpoint, catalog.entries, "meridian-exchange") != OK: quit(1)

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 15:
		push_error("Live smoke timeout")
		quit(1)
	if phase == 0 and client.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		phase = 1
		client.create_room()
	return false

func on_lobby(frame: Dictionary) -> void:
	if phase == 1:
		phase = 2
		client.configure_match("deathmatch", 2)
	elif phase == 2 and frame.get("config") != null:
		phase = 20
		client.send_frame({"type":"start"})

func on_snapshot(frame: Dictionary) -> void:
	frames += 1
	if client.last_ack < 1: return
	if frame.state.actors.size() != 3 or client.actor_id < 0 or client.actor_id == client.peer_id:
		push_error("Live identity/actor-count failure")
		quit(1)
		return
	print("PORT_NATIVE_LIVE_OK actors=3 map=", frame.state.mapId, " ack=", client.last_ack, " snapshots=", frames)
	client.disconnect_server()
	quit(0)
