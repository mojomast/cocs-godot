extends SceneTree
## Captures the integrated, live Node-authoritative DM session, not a photo camera.
var session: Node3D
var frames := 0
var captured := false
var output := "/tmp/opencode/native-dm-captures"
var software_low_shadows := false
var click_tail: Node

class CaptureClickTail extends Node:
	var session: Node
	var active := false
	func _process(_delta: float) -> void:
		if active and session.can_capture_pointer():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			session.combat_actions.captured()
			session.first_person.refresh()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-root="): output = arg.trim_prefix("--capture-root=")
		if arg == "--capture-low-shadows": software_low_shadows = true
	DirAccess.make_dir_recursive_absolute(output)
	session = load("res://native_arenas/demo.tscn").instantiate()
	root.add_child(session)
	click_tail = CaptureClickTail.new()
	click_tail.session = session
	click_tail.process_priority = 1000
	root.add_child(click_tail)
	# Xvfb uses llvmpipe. Keep actual full-size rendering but disable MSAA so
	# renderer stalls do not trigger the authority's stale-input cancellation.
	root.msaa_3d = Viewport.MSAA_DISABLED
	if software_low_shadows:
		for light in session.world.find_children("*", "Light3D", true, false): light.shadow_enabled = false
	root.size = Vector2i(1280, 720)
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not session.startup_error.is_empty():
			push_error("Capture startup: " + session.startup_error)
			quit(1)
			return
		if session.phase != 3 or not session.received_pose: continue
		if session.presentation.applied < 5: continue
		if not is_instance_valid(session.first_person): continue
		break
	if session.phase != 3 or not session.received_pose:
		push_error("Integrated DM session did not receive authoritative pose")
		quit(1)
		return
	# Human-equivalent look input only; camera translation remains authoritative.
	var target := Vector3(0, 3.5, 0)
	if session.current_id == "aurora-basin": target = Vector3(3, 8, -9)
	if session.current_id == "cinder-array": target = Vector3(22, 17, -6)
	var delta: Vector3 = target - session.camera.position
	session.yaw = atan2(-delta.x, -delta.z)
	session.pitch = atan2(delta.y, Vector2(delta.x, delta.z).length())
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		root.grab_focus()
		click_tail.active = true
		var stable_frames := 0
		for i in 120:
			await process_frame
			if not root.has_focus(): root.grab_focus()
			await RenderingServer.frame_post_draw
			if session.first_person.rig.showing and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				stable_frames += 1
			else: stable_frames = 0
			if stable_frames >= 2: break
		if not session.first_person.rig.showing:
			push_error("Capture requires a visible live first-person rig: " + JSON.stringify({"phase":session.phase,"focus":session.application_focused,"window_focus":root.has_focus(),"pointer":Input.mouse_mode,"stale":session.snapshot_watch.stale(),"lifecycle":session.presentation.lifecycle.status}))
			quit(1)
			return
		var path: String = output + "/" + session.current_id + "-%dx%d.png" % [size.x, size.y]
		root.get_texture().get_image().save_png(path)
		print("NATIVE_DM_GRAPHICAL_CAPTURE ", JSON.stringify({"map":session.current_id,"size":[size.x,size.y],"path":path,"authoritative_eye": [session.camera.position.x,session.camera.position.y,session.camera.position.z],"snapshots":session.presentation.applied,"actors":session.presentation.actors.size(),"geometryHash":session.world.get_meta("native_geometry_hash"),"first_person":session.first_person.rig.showing,"msaa":"disabled","software_low_shadows":software_low_shadows}))
	session.client.disconnect_server()
	quit()
