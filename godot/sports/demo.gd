extends Node3D
const Network = preload("res://net/client.gd")
const World = preload("res://world/viewer.gd")
const Fleet = preload("res://vehicles/renderer.gd")
const Controls = preload("res://sports/controls.gd")
const Chase = preload("res://sports/chase.gd")
var net := Network.new()
var world := World.new()
var fleet := Fleet.new()
var controls := Controls.new()
var chase := Chase.new()
var hud := Label.new()
var ball := MeshInstance3D.new()
var map_id := ""
var endpoint := ""
var mode := ""
var phase := "connecting"
var phase_age := 0.0
var age := 999.0
var send_age := 0.0
var state: Dictionary = {}
var vehicle: Dictionary = {}
var actor: Dictionary = {}
var configured := false
var start_sent := false
var create_sent := false
var error := ""

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): map_id = arg.trim_prefix("--map=")
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
	if not map_id in ["ion-speedway", "aurora-stadium"] or endpoint.is_empty():
		push_error("Require --endpoint=ws://HOST:PORT --map=ion-speedway|aurora-stadium")
		get_tree().quit(2)
		return
	mode = "puma-race" if map_id == "ion-speedway" else "puma-soccer"
	add_child(world)
	world.set_process(false)
	world.set_process_unhandled_input(false)
	world.selector.hide()
	world.label.hide()
	if not world.load_map(map_id):
		get_tree().quit(2)
		return
	world.camera.current = true
	add_child(fleet)
	add_child(ball)
	ball.visible = false
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	ball.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.85, 0.25)
	ball.material_override = mat
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.position = Vector2(20, 20)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	add_child(net)
	net.lobby.connect(on_lobby)
	net.started.connect(on_started)
	net.snapshot.connect(on_snapshot)
	net.results.connect(func(frame: Dictionary) -> void:
		on_snapshot(frame)
		phase = "results"
		controls.release())
	net.connection_error.connect(fail)
	if net.connect_server(endpoint, world.catalog.entries, map_id) != OK: fail("Connection failed")

func checked(result: Error) -> bool:
	if result == OK: return true
	fail("Network queue failed")
	return false

func fail(message: String) -> void:
	error = message
	phase = "error"
	controls.release()
	state.clear()
	actor.clear()
	vehicle.clear()
	fleet.clear_round()
	chase.reset()
	ball.hide()
	net.disconnect_server()

func on_lobby(frame: Dictionary) -> void:
	if phase == "error": return
	if not configured:
		configured = true
		checked(net.configure_match(mode, 0))
	elif frame.get("config") != null and not start_sent:
		start_sent = true
		phase = "starting"
		phase_age = 0
		checked(net.send_frame({"type":"start"}))

func on_started(_frame: Dictionary) -> void:
	controls.release()
	fleet.clear_round()
	chase.reset()
	ball.hide()
	state.clear()
	actor.clear()
	vehicle.clear()
	age = 0
	phase = "active"
	phase_age = 0

func on_snapshot(frame: Dictionary) -> void:
	state = frame.state
	age = 0
	actor = {}
	var previous_id: Variant = vehicle.get("id")
	vehicle = {}
	if not fleet.apply_state(state, net.actor_id):
		fail("Invalid vehicle snapshot")
		return
	for a: Dictionary in state.get("actors", []):
		if a.get("id") == net.actor_id: actor = a
	for v: Dictionary in state.get("vehicles", []):
		if net.actor_id >= 0 and v.get("driver") == net.actor_id and actor.get("vehicleId") == v.id and actor.get("vehicleSeat") == "driver": vehicle = v
	if previous_id != vehicle.get("id"):
		controls.release()
		chase.reset()
	if not eligible(): controls.release()
	var race: Dictionary = state.get("race", {})
	var b: Variant = race.get("ball")
	ball.visible = b is Dictionary
	if b is Dictionary:
		ball.position = Vector3(b.x, b.y, b.z)
		ball.scale = Vector3.ONE * float(b.r)

func eligible() -> bool:
	return phase == "active" and age < 0.5 and not state.get("over", false) and not vehicle.is_empty() and vehicle.get("driver") == net.actor_id and float(vehicle.get("health", 0)) > 0 and float(vehicle.get("respawnTimer", 1)) <= 0 and float(actor.get("health", 0)) > 0 and float(actor.get("dead", 1)) <= 0 and state.get("race", {}).get("phase") in ["racing", "playing"]

func _input(event: InputEvent) -> void:
	controls.accept(event, eligible())
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F5 and phase == "results":
		controls.release()
		phase = "starting"
		phase_age = 0
		checked(net.send_frame({"type":"start"}))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: controls.focus(false)
	if what == NOTIFICATION_APPLICATION_FOCUS_IN: controls.focus(true)

func _process(delta: float) -> void:
	phase_age += delta
	age += delta
	if not eligible(): controls.release()
	if phase == "connecting" and not create_sent and net.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		create_sent = true
		checked(net.create_room())
	if phase in ["connecting", "starting"] and phase_age > 15: fail("Setup timed out")
	if phase == "active" and age > 10: fail("Authoritative snapshots timed out")
	if phase == "active":
		send_age += delta
		if send_age >= 1.0/30.0:
			send_age = 0
			checked(net.send_input(controls.packet(float(vehicle.get("yaw", 0)) - PI, eligible())))
	if not vehicle.is_empty():
		var pose: Dictionary = chase.follow(vehicle, delta)
		world.camera.position = pose.eye
		world.camera.look_at(pose.target)
	var race: Dictionary = state.get("race", {})
	var speed := Vector2(float(vehicle.get("vx", 0)), float(vehicle.get("vz", 0))).length()
	var detail := ""
	if mode == "puma-soccer": detail = "Score: %s" % str(race.get("scores", "unavailable"))
	else:
		detail = "Lap/checkpoint: unavailable"
		for row: Dictionary in race.get("standings", []):
			if row.get("actorId") == net.actor_id: detail = "Lap %s/%s · next checkpoint %s" % [row.get("lap", "?"), race.get("laps", "?"), row.get("nextGate", "?")]
	hud.text = "%s · %s %0.1f\n%0.1f m/s · %s\n%s\nEnter: engage · WASD: drive · Space: brake · Shift: boost\nEscape: release · R: race reset · F5: restart after results%s" % [map_id, race.get("phase", phase), float(race.get("countdown", 0)), speed, detail, "DRIVING" if controls.engaged else "RELEASED — fresh Enter after countdown", "\n" + error if not error.is_empty() else ""]

func _exit_tree() -> void:
	controls.release()
	net.disconnect_server()
