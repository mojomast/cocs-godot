extends Node3D
const Network = preload("res://net/client.gd")
const World = preload("res://world/viewer.gd")
const Fleet = preload("res://combined_arms/fleet.gd")
const Actors = preload("res://world/presentation.gd")
const Controls = preload("res://combined_arms/controls.gd")
const CameraRig = preload("res://combined_arms/camera.gd")
const HUD = preload("res://combined_arms/hud.gd")
const Lease = preload("res://combined_arms/lease.gd")
const Motion = preload("res://world/control_math.gd")
const Graphics = preload("res://combined_arms/graphics.gd")
var net := Network.new()
var world := World.new()
var fleet := Fleet.new()
var actors := Actors.new()
var controls := Controls.new()
var chase := CameraRig.new()
var hud := HUD.new()
var graphics := Graphics.new()
var map_id := "sunscar-convoy"
var endpoint := ""
var phase := "connecting"
var phase_age := 0.0
var age := 999.0
var send_age := 0.0
var state: Dictionary = {}
var actor: Dictionary = {}
var vehicle: Dictionary = {}
var yaw := 0.0
var pitch := 0.0
var identity := ""
var configured := false
var start_sent := false
var create_sent := false
var error := ""
signal input_queued(seq: int, packet: Dictionary, result: int)

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): map_id = arg.trim_prefix("--map=")
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
	if map_id != "sunscar-convoy" or endpoint.is_empty():
		push_error("Require --map=sunscar-convoy --endpoint=ws://HOST:PORT")
		get_tree().quit(2)
		return
	add_child(world)
	world.set_process(false)
	world.set_process_unhandled_input(false)
	world.selector.hide()
	world.label.hide()
	if not world.load_map(map_id) or not chase.configure_map(map_id, world.catalog.resolve_map(map_id)):
		get_tree().quit(2)
		return
	world.camera.current = true
	add_child(fleet)
	add_child(actors)
	add_child(graphics)
	graphics.attach_to(self)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	add_child(net)
	net.lobby.connect(on_lobby)
	net.started.connect(on_started)
	net.snapshot.connect(on_snapshot)
	net.events.connect(on_events)
	net.results.connect(on_results)
	net.connection_error.connect(fail)
	checked(net.connect_server(endpoint, world.catalog.entries, map_id))

func release() -> void:
	controls.release()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	graphics.hide_infantry()

func update_graphics() -> void:
	graphics.refresh(get_window().has_focus(), Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

func on_events(items: Array) -> void:
	update_graphics()
	graphics.apply_events(items)

func clear_round() -> void:
	release()
	state = {}
	actor = {}
	vehicle = {}
	identity = ""
	fleet.clear_round()
	actors.clear_round()
	chase.reset()
	graphics.reset()
	age = 0
	send_age = 0

func checked(result: Error) -> bool:
	if result == OK: return true
	fail("Network queue failed")
	return false

func fail(message: String) -> void:
	error = message
	phase = "error"
	clear_round()
	net.disconnect_server()

func on_lobby(frame: Dictionary) -> void:
	if phase == "error": return
	if not configured:
		configured = true
		checked(net.configure_match("combined-arms", 0))
	elif frame.get("config") != null and not start_sent:
		start_sent = true
		phase = "starting"
		phase_age = 0
		checked(net.send_frame({"type":"start"}))
	update_graphics()

func on_started(_frame: Dictionary) -> void:
	clear_round()
	phase = "active"
	phase_age = 0

func on_results(frame: Dictionary) -> void:
	on_snapshot(frame)
	release()
	checked(net.send_input(controls.command(yaw, pitch, false, false)))
	if phase != "error": phase = "results"
	graphics.reset()

func on_snapshot(frame: Dictionary) -> void:
	state = frame.state
	age = 0
	if not fleet.apply_state(state, net.actor_id):
		fail("Invalid vehicle snapshot")
		return
	actors.apply_state(state, net.actor_id)
	# No standing soldiers inside vehicle hulls.
	for a: Dictionary in state.get("actors", []):
		if a.get("vehicleId") != null and actors.actors.has(int(a.id)): actors.actors[int(a.id)].hide()
	actor = Lease.actor_for(state, net.actor_id)
	vehicle = Lease.vehicle_for(state, actor)
	var next := "%s/%s/%s/%s/%s" % [net.actor_id, actor.get("vehicleId"), actor.get("vehicleSeat"), vehicle.get("id"), Lease.alive(actor)]
	if next != identity:
		release()
		chase.reset()
		yaw = float(actor.get("yaw", 0))
		pitch = float(actor.get("pitch", 0))
		identity = next
	if not eligible(): release()
	update_graphics()
	graphics.apply_state()

func eligible() -> bool:
	return phase == "active" and Lease.permitted(state, actor, vehicle, age) and actor.get("id") == net.actor_id

func _input(event: InputEvent) -> void:
	var focused := get_window().has_focus() and controls.focused
	controls.accept(event, eligible() and focused)
	if controls.engaged and focused: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and controls.engaged and eligible() and focused:
		var look := Motion.look(yaw-event.relative.x*0.003, pitch-event.relative.y*0.003)
		yaw = look.x
		pitch = look.y
	update_graphics()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		controls.focus(false)
		release()
	if what == NOTIFICATION_APPLICATION_FOCUS_IN: controls.focus(true)
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_IN]: update_graphics()

func _process(delta: float) -> void:
	age += delta
	phase_age += delta
	if not eligible() or not get_window().has_focus() or (controls.engaged and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED): release()
	if phase == "connecting" and not create_sent and net.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		create_sent = true
		checked(net.create_room())
	if phase in ["connecting", "starting"] and phase_age > 15: fail("Setup timed out")
	if phase == "active" and age > 10: fail("Authoritative snapshots timed out")
	if phase == "active":
		send_age += delta
		if send_age >= 1.0/30.0:
			send_age = 0
			var p := controls.command(yaw, pitch, eligible(), not vehicle.is_empty() and actor.get("vehicleSeat") == "driver")
			# This vertical slice accepts Puma driving. Secondary silhouettes still
			# permit safe ordinary exit; no unaccepted flight/seat controls advertised.
			if not vehicle.is_empty() and (vehicle.get("kind") != "puma" or actor.get("vehicleSeat") != "driver"):
				p.x = 0.0
				p.z = 0.0
				for field in ["fire", "jump", "sprint", "crouch", "reload"]: p[field] = false
			var result := net.send_input(p)
			input_queued.emit(net.input_seq, p, result)
			checked(result)
	if not actor.is_empty():
		var pose := chase.follow(vehicle, delta) if not vehicle.is_empty() else chase.infantry(actor, yaw, pitch)
		world.camera.position = pose.eye
		world.camera.look_at(pose.target)
	update_graphics()
	hud.update(actor, vehicle, Lease.nearby(state, actor), controls.engaged, phase, age, error)

func _exit_tree() -> void:
	release()
	net.disconnect_server()
