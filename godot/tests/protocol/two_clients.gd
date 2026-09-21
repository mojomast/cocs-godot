extends SceneTree

const Client = preload("res://net/client.gd")
const Presentation = preload("res://world/presentation.gd")
var client := Client.new()
var presentation := Presentation.new()
var join_id: String = ""
var sent: bool = false
var announced: bool = false
var configured: bool = false
var started: bool = false
var passed: bool = false
var elapsed: float = 0
var cadence: float = 0
var initial: Dictionary = {}
var humans: Array[int] = []

func _initialize() -> void:
	var endpoint: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg.begins_with("--join="): join_id = arg.trim_prefix("--join=")
	root.add_child(client)
	root.add_child(presentation)
	presentation.interpolate_remote = true
	client.connection_error.connect(func(message: String) -> void: push_error(message); quit(1))
	client.lobby.connect(on_lobby)
	client.started.connect(func(_frame: Dictionary) -> void: started = true; presentation.clear_round())
	client.snapshot.connect(on_snapshot)
	if client.connect_server(endpoint, {"meridian-exchange":{"modes":["deathmatch"]}}, "meridian-exchange") != OK: quit(1)

func on_lobby(frame: Dictionary) -> void:
	humans.clear()
	for player: Dictionary in frame.get("players", []):
		if player.get("actorId") != null: humans.append(int(player.actorId))
	if not join_id.is_empty(): return
	if not announced:
		announced = true
		print("PORT_ROOM ", client.room_id)
	if frame.get("players", []).size() == 2 and not configured:
		configured = true
		client.configure_match("deathmatch", 2)
	elif configured and frame.get("config") != null and not started:
		started = true
		client.send_frame({"type":"start"})

func on_snapshot(frame: Dictionary) -> void:
	presentation.apply_state(frame.state, client.actor_id)
	if passed or humans.size() != 2 or presentation.actors.size() != 4: return
	var moved_count: int = 0
	for id: int in humans:
		if not presentation.actors.has(id): return
		var position: Vector3 = presentation.actors[id].position
		if not initial.has(id): initial[id] = position
		if position.distance_to(initial[id]) > 0.5: moved_count += 1
	if moved_count == 2 and client.last_ack > 15 and presentation.rendered_remote_poses > 10:
		passed = true
		print("PORT_TWO_OK ", JSON.stringify({"actor_id":client.actor_id,"peer_id":client.peer_id,"humans":humans,"actors":4,"ack":client.last_ack,"both_moved":true,"remote_poses":presentation.rendered_remote_poses}))

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 20: push_error("Two-client timeout"); quit(1)
	if not sent and client.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		sent = true
		if join_id.is_empty(): client.create_room()
		else: client.join_room(join_id)
	cadence += delta
	if started and client.actor_id >= 0 and cadence >= 1.0 / 60.0:
		cadence = 0
		client.send_input({"x":0,"z":-1,"yaw":0,"pitch":0})
	return false
