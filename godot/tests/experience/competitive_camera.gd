extends SceneTree
## Actual competitive subclass callbacks + actual spectator presenter. Detached
## composition avoids an authority/asset import; public frames are synthetic.
## This is a native ownership contract, not connected or rendered acceptance.
const Competitive = preload("res://mode_expansion/demo.gd")
const Information = preload("res://experience/player_info.gd")
var checks := 0
var failures := 0

class Visual extends Node3D:
	func apply_actor(_actor: Dictionary) -> void: pass
	func kick(_amount: float) -> void: pass

class TestInformation extends Information:
	var obstructed := false
	func blocked() -> bool: return obstructed
	func _process(_delta: float) -> void: pass # Explicit scene binding in this test.

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("COMPETITIVE_CAMERA_FAIL " + note)

func _initialize() -> void: call_deferred("run")

func frame(time: float, actors: Array) -> Dictionary:
	return {"state":{"time":time,"mapId":"meridian-exchange","config":{"mode":"arsenal"},"actors":actors,"pickups":[],"vehicles":[],"feed":[],"over":false}}

func run() -> void:
	var session := Competitive.new()
	# Keep the production session detached, exactly as other session contracts do.
	# Only actor geometry is substituted; no camera/lifecycle callback is replaced.
	session.presentation.actor_visual_factory = func(_actor: Dictionary, _id: int) -> Node3D: return Visual.new()
	session.selected_mode = "arsenal"
	session.current_id = "meridian-exchange"
	session.phase = 3
	session.evidence = true # Executes the original read-only proof assertion.
	session.client.spectating = true
	session.client.actor_id = -1
	session.client.snapshot.connect(session.on_snapshot)
	session.client.started.connect(session.on_started)
	session.client.results.connect(session.on_results)
	session.client.lobby.connect(session.on_lobby)
	session.client.transport_dropped.connect(session.on_transport_dropped)
	var info := TestInformation.new()
	root.add_child(info)
	info.bind_session(session)
	var rig: Node = info.spectator_camera
	rig.set_process(false)
	var fallback: Transform3D = session.camera.transform
	check(session.camera.position == Vector3(0, 18, 30), "constructor provides no-target fallback")
	session.client.snapshot.emit(frame(1, []))
	rig._process(0.016)
	check(session.camera.transform == fallback and rig.model.target_id == null, "actual empty snapshot keeps initialized fallback")
	check(session.fixture_spectator_checked and not session.can_capture_pointer(), "original subclass proof ran; actor capture stays denied")
	check(session.client.send_input({"fire":true}) == ERR_UNAUTHORIZED, "original read-only input boundary preserved")
	var actor := {"id":7,"name":"Public target","health":100,"x":12,"y":2,"z":-9,"yaw":0.4,"pitch":-0.1,"eyeHeight":1.45}
	session.client.snapshot.emit(frame(2, [actor]))
	rig._process(0.016)
	check(session.camera.position.is_equal_approx(Vector3(12, 3.45, -9)), "actual subclass snapshot followed by public follow pose")
	rig.action(0)
	session.camera.position = Vector3(42, 13, -21)
	session.camera.rotation = Vector3(0.2, 1.1, 0)
	var free_pose: Transform3D = session.camera.transform
	for tick: int in range(3, 8):
		actor.x += 2
		session.client.snapshot.emit(frame(tick, [actor]))
		# Assert BEFORE the helper runs: a late helper cannot mask a reset.
		check(session.camera.transform == free_pose, "actual subclass callback preserves free pose before presenter tick")
		rig._process(0.016)
		check(session.camera.transform == free_pose and not rig.captured, "unheld freecam persists over successive snapshots")
	info.obstructed = true
	rig.held[KEY_W] = true
	rig.velocity = Vector3.ONE
	session.client.snapshot.emit(frame(8, [actor]))
	rig._process(0.016)
	check(rig.model.actors.is_empty() and rig.held.is_empty() and rig.velocity == Vector3.ZERO, "modal snapshot clears camera model and motion")
	check(session.camera.transform == free_pose, "modal does not restore subclass fixed pose")
	info.obstructed = false
	session.client.snapshot.emit(frame(9, [actor]))
	rig._process(0.016)
	check(rig.model.mode == "follow" and session.camera.position.is_equal_approx(Vector3(actor.x, 3.45, -9)), "fresh snapshot resumes public follow after modal")
	rig.action(0)
	var held_pose: Transform3D = session.camera.transform
	session.snapshot_watch.advance(2)
	rig._process(0.016)
	check(rig.model.actors.is_empty() and session.camera.transform == held_pose, "stale clears attribution while holding last pose")
	session.client.snapshot.emit(frame(10, [actor]))
	rig._process(0.016)
	check(rig.model.mode == "follow" and not session.can_capture_pointer(), "stale recovery follows without granting actor controls")
	session.client.transport_dropped.emit("synthetic ownership interruption")
	rig._process(0.016)
	check(session.phase == -5 and rig.model.actors.is_empty(), "actual competitive transport callback clears spectator ownership")
	session.client.started.emit({"roundRevision":1})
	session.client.snapshot.emit(frame(11, [actor]))
	rig._process(0.016)
	check(session.phase == 3 and rig.model.target_id == 7 and rig.model.mode == "follow", "actual start/snapshot callbacks reacquire public follow after reconnect")
	rig.action(0)
	free_pose = session.camera.transform
	var results := frame(12, [actor])
	results.state.over = true
	session.client.results.emit(results)
	rig._process(0.016)
	check(session.phase == 4 and rig.model.actors.is_empty() and session.camera.transform == free_pose, "actual results callback clears target without resetting view")
	session.client.started.emit({"roundRevision":2})
	session.client.snapshot.emit(frame(0, []))
	rig._process(0.016)
	check(rig.model.target_id == null and session.camera.transform == free_pose, "empty restart holds last safe pose without inventing target")
	session.client.spectating = false
	session.client.actor_id = 7
	session.client.lobby.emit({"players":[]})
	check(not info.ready_for_events and rig.model.actors.is_empty(), "actual lobby callback and presenter clear spectator-to-player seat")
	actor.x = -15
	session.client.snapshot.emit(frame(1, [actor]))
	rig._process(0.016)
	check(session.received_pose and session.camera.position.is_equal_approx(Vector3(-15, 3.45, -9)) and rig.model.actors.is_empty(), "actual actor snapshot regains actor camera, not spectator target")
	info.unbind()
	info.free()
	# The detached constructor owns unparented composition nodes until _ready.
	for node: Node in [session.client, session.camera, session.sun, session.environment, session.label, session.selector, session.combat_label, session.pickups, session.presentation, session.combat, session.mode_markers, session.objective_label, session.connection_label, session.restart_button, session.retry_button, session.mode_panel, session.mode_card]: node.free()
	session.free()
	print("COMPETITIVE_CAMERA_CONTRACT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
