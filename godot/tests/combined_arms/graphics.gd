extends SceneTree
## Synthetic composition fixture: real demo callbacks, decoder and loopback socket.
## Focus/capture are injected explicitly, not claimed as desktop interaction proof.
class Demo extends "res://combined_arms/demo.gd":
	var test_focus := true
	var test_capture := true
	func _ready() -> void:
		add_child(world)
		world.set_process(false)
		world.set_process_unhandled_input(false)
		world.selector.hide()
		world.label.hide()
		add_child(fleet)
		add_child(actors)
		add_child(hud)
		add_child(graphics)
		graphics.attach_to(self)
		add_child(net)
		net.snapshot.connect(on_snapshot)
		net.events.connect(on_events)
		net.started.connect(on_started)
		net.results.connect(on_results)
		net.connection_error.connect(fail)
		set_process(false)
		net.set_process(false)
	func update_graphics() -> void:
		graphics.refresh(test_focus, test_capture)

var failures: Array[String] = []
var checks := 0
var seq := 0
var demo: Demo
var server := TCPServer.new()
var remote := WebSocketPeer.new()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func frame(value: Dictionary) -> void:
	check(demo.net.decode_text(JSON.stringify(value)), "decoder accepts " + str(value.type))

func snapshot(state: Dictionary) -> void:
	seq += 1
	frame({"type":"snapshot", "seq":seq, "state":state})

func events(items: Array) -> void:
	frame({"type":"events", "items":items})

func engage() -> void:
	demo.controls.engaged = true
	demo.update_graphics()

func shot(id: int) -> Dictionary:
	return {"type":"shot", "id":id, "time":float(id), "actor":0, "weapon":0,
		"from":{"x":0,"y":1,"z":0}, "to":{"x":0,"y":1,"z":-5}}

func cleared(message: String) -> void:
	var g = demo.graphics
	check(not g.rig.showing and g.rig.recoil == 0 and g.rig.flash_remaining == 0, message + " rig hidden/motion cleared")
	check(g.feedback.tracers.is_empty() and g.feedback.blasts.is_empty() and g.feedback.projectiles.markers.is_empty() and g.feedback.moth_effects.active_count() == 0 and g.feedback.audio_feedback._last_play_usec.is_empty(), message + " public feedback cleared")

func _initialize() -> void: call_deferred("run")

func capture(label: String) -> void:
	if "--graphics-probe" not in OS.get_cmdline_user_args(): return
	demo.graphics.rig.advance(0.016)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../port/native-combined-arms-graphics/evidence/synthetic-%s.png" % label)
	check(root.get_texture().get_image().save_png(path) == OK, "synthetic rendered capture " + label)

func run() -> void:
	demo = Demo.new()
	root.add_child(demo)
	check(server.listen(0, "127.0.0.1") == OK, "private loopback listener")
	check(demo.net.peer.connect_to_url("ws://127.0.0.1:%d" % server.get_local_port()) == OK, "loopback connect")
	for attempt in 200:
		demo.net.peer.poll()
		if server.is_connection_available(): check(remote.accept_stream(server.take_connection()) == OK, "loopback accept")
		remote.poll()
		if demo.net.peer.get_ready_state() == WebSocketPeer.STATE_OPEN: break
		await create_timer(0.005).timeout
	check(demo.net.peer.get_ready_state() == WebSocketPeer.STATE_OPEN, "real socket is open")
	# Freeze automatic animation and camera/input loops; all subsequent steps explicit.
	demo.process_mode = Node.PROCESS_MODE_DISABLED
	demo.net.requested_map = "sunscar-convoy"
	demo.net.allowlist = {"sunscar-convoy": {"modes":["combined-arms"]}}
	demo.net.actor_id = 0
	frame({"type":"start", "mapId":"sunscar-convoy"})
	var state := {"mapId":"sunscar-convoy", "config":{"mode":"combined-arms"}, "over":false,
		"actors":[{"id":0,"team":0,"health":100,"dead":0,"weapon":0,"x":0,"y":0,"z":0,"yaw":0,"pitch":0,"vehicleId":null,"vehicleSeat":null}],
		"vehicles":[{"id":"p","kind":"puma","driver":null,"gunner":null,"passengers":[],"health":300,"respawnTimer":0,"x":1,"y":0,"z":0,"vx":0,"vz":0,"yaw":0,"pitchBody":0,"roll":0,"turretYaw":0}],
		"rockets":[{"id":8,"owner":0,"weapon":1,"pos":{"x":0,"y":2,"z":-2},"dir":{"x":0,"y":0,"z":-1}}]}
	snapshot(state)
	check(not demo.graphics.rig.showing, "initial identity requires existing engagement latch")
	engage()
	var g = demo.graphics
	check(g.rig.showing and g.rig.source_camera == demo.world.camera, "infantry rig attached to composition camera")
	await capture("infantry")
	check(g.feedback.projectiles.markers.has(8), "snapshot rocket reaches shared public feedback")
	events([shot(1), {"type":"explosion","id":2,"pos":{"x":0,"y":1,"z":-3}}, {"type":"damage","id":3,"actor":0,"source":1,"amount":5}])
	check(g.rig.recoil_count == 1 and g.feedback.shots == 1 and g.feedback.explosions == 1 and g.feedback.hurts == 1, "source events reach rig and shared combat feedback")
	check(is_instance_valid(g.feedback.weapon_effects) and is_instance_valid(g.feedback.world_particles) and is_instance_valid(g.feedback.shields) and g.feedback.moth_effects.active_count() == 0, "production composition uses integrated effects instead of legacy Moth cues")
	check(not g.feedback.audio_feedback._last_play_usec.is_empty(), "shared source audio dispatch")
	events([shot(1), {"type":"explosion","id":2,"pos":{"x":0,"y":1,"z":-3}}])
	check(g.rig.recoil_count == 1 and g.feedback.shots == 1 and g.feedback.explosions == 1 and g.feedback.event_ids.size() == 3, "decoder duplicate IDs are not re-queued as fresh effects")
	var source_before := JSON.stringify(demo.state)
	var aim_before := Vector2(demo.yaw, demo.pitch)
	var camera_before := demo.world.camera.transform
	var input_before := demo.net.input_seq
	var control = demo.Controls.new()
	for gate in [demo.controls, control]:
		gate.engaged = true
		gate.keys[KEY_W] = true
		gate.fire = true
		gate.interact_pending = true
	for repeat in 20:
		demo.update_graphics()
		g.apply_state()
	check(demo.controls.interact_pending and demo.controls.fire and demo.controls.engaged, "graphics never consumes input latches")
	check(demo.controls.command(demo.yaw, demo.pitch, true, false) == control.command(demo.yaw, demo.pitch, true, false), "identical infantry command with graphics")
	check(JSON.stringify(demo.state) == source_before and Vector2(demo.yaw, demo.pitch) == aim_before and demo.world.camera.transform == camera_before and demo.net.input_seq == input_before, "refresh leaves snapshot aim camera and network input untouched")
	check(g.rig.recoil_count == 1 and g.feedback.shots == 1, "snapshot/refresh does not replay effects")
	state.actors[0].vehicleId = "p"
	state.actors[0].vehicleSeat = "driver"
	state.vehicles[0].driver = 0
	snapshot(state)
	check(not g.rig.showing and g.rig.recoil == 0 and not demo.controls.engaged and not demo.vehicle.is_empty(), "boarding Puma hides and clears infantry immediately")
	engage()
	events([shot(4)])
	check(not g.rig.showing and g.rig.recoil_count == 1 and g.feedback.shots == 2, "Puma keeps public feedback without infantry recoil")
	await capture("mounted")
	state.vehicles[0].driver = 9
	snapshot(state)
	check(demo.vehicle.is_empty() and not g.rig.showing, "broken mounted lease never falls back to infantry")
	state.actors[0].vehicleId = null
	state.actors[0].vehicleSeat = null
	state.vehicles[0].driver = null
	snapshot(state)
	check(not g.rig.showing and not demo.controls.engaged, "dismount respects release latch")
	engage()
	events([shot(4)])
	check(g.rig.showing and g.rig.recoil_count == 1, "dismount cannot replay mounted shot")
	await capture("dismounted")
	demo.age = 0.5
	demo.update_graphics()
	cleared("stale")
	events([shot(5)])
	snapshot(state)
	engage()
	events([shot(5)])
	check(g.rig.recoil_count == 1 and g.feedback.shots == 0, "stale event consumed without recovery replay")
	demo.test_focus = false
	demo.update_graphics()
	cleared("unfocused")
	demo.test_focus = true
	demo.test_capture = false
	demo.update_graphics()
	check(not g.rig.showing, "actual capture predicate required independently of engagement")
	demo.test_capture = true
	demo.controls.focus(false)
	demo.update_graphics()
	check(not g.rig.showing, "controls focus also required")
	demo.controls.focus(true)
	engage()
	state.actors[0].health = 0
	state.actors[0].dead = 1
	snapshot(state)
	cleared("death")
	state.actors[0].health = 100
	state.actors[0].dead = 0
	snapshot(state)
	engage()
	for foreign_id in [-1, 1]:
		demo.net.actor_id = foreign_id
		demo.update_graphics()
		check(not g.rig.showing, "unassigned/foreign identity hidden")
	demo.net.actor_id = 0
	demo.net.spectating = true
	demo.update_graphics()
	check(not g.rig.showing, "connection spectator hidden")
	demo.net.spectating = false
	state.actors[0].spectating = true
	snapshot(state)
	check(not g.rig.showing, "actor spectator hidden")
	state.actors[0].spectating = false
	snapshot(state)
	engage()
	events([shot(6)])
	state.over = true
	frame({"type":"results", "state":state})
	cleared("results")
	check(demo.phase == "results" and g.rig.seen.is_empty() and g.feedback.public_actors.is_empty(), "results resets rig history and source feedback actors")
	events([shot(7)])
	check(g.feedback.shots == 0 and g.rig.recoil_count == 0, "post-results events ignored")
	frame({"type":"start", "mapId":"sunscar-convoy"})
	state.over = false
	snapshot(state)
	engage()
	events([shot(1)])
	check(g.rig.recoil_count == 1 and g.feedback.shots == 1, "new round accepts reused source IDs once")
	demo.net.peer.close()
	demo.update_graphics()
	cleared("closed socket")
	demo.fail("synthetic failure")
	cleared("error")
	check(demo.phase == "error" and g.rig.seen.is_empty() and demo.state.is_empty(), "error clears round")
	remote.close()
	server.stop()
	demo.free()
	# Let the audio server retire stopped synthetic voices before process teardown.
	await create_timer(0.15).timeout
	print("COMBINED_ARMS_GRAPHICS ", JSON.stringify({"checks":checks,"failures":failures,"synthetic":true}))
	quit(0 if failures.is_empty() else 1)
