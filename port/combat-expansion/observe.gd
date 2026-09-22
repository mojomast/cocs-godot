extends SceneTree
## Observation only: production scene, networking, controls and cameras stay intact.
var session: Node
var output := ""
var rows: Array = []
var events: Array = []
var transitions: Array = []
var busy := false
var elapsed := 0.0
var started_usec := 0
var sample_age := 0.0

func _initialize() -> void:
	output = OS.get_environment("COMBAT_REVIEW_OUTPUT")
	call_deferred("start")

func start() -> void:
	var path := OS.get_environment("COMBAT_REVIEW_SCENE")
	if path.is_empty(): path = "res://world/session.tscn"
	if output.is_empty() or not ResourceLoader.exists(path):
		push_error("Combat review requires an output directory and a production scene")
		quit(1)
		return
	session = load(path).instantiate()
	root.add_child(session)
	started_usec = Time.get_ticks_usec()
	session.client.snapshot.connect(func(frame: Dictionary) -> void:
		rows.append({"snapshot":frame,"view":sample()}))
	session.client.events.connect(func(items: Array) -> void: events.append_array(items))
	for signal_name in ["started", "results"]:
		session.client.connect(signal_name, func(frame: Dictionary) -> void: transitions.append(frame))
	write_json("ready.json", {"scene":path,"input":"external X11 OS events","state_injection":false})

func sample() -> Dictionary:
	var actor: Dictionary = session.presentation.local_actor
	var rig: Node = null
	if "first_person" in session and is_instance_valid(session.first_person): rig = session.first_person.rig
	var value := {
		"wall_usec":Time.get_ticks_usec()-started_usec,
		"phase":session.phase,"actor":actor.duplicate(true),
		"focused":root.has_focus(),"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"camera_position":[session.camera.global_position.x,session.camera.global_position.y,session.camera.global_position.z],
		"camera_rotation":[session.camera.rotation.x,session.camera.rotation.y,session.camera.rotation.z],
		"fov":session.camera.fov,"acks":session.client.last_ack,
		"stale":session.snapshot_watch.stale(),"rig_showing":is_instance_valid(rig) and rig.showing,
		"rendered_frames":Engine.get_frames_drawn(),
	}
	if session.has_method("aim_requested"): value["aim_requested"] = session.aim_requested()
	if is_instance_valid(rig):
		for field in ["ads_progress", "aim_progress", "recoil_count", "current_weapon"]:
			if field in rig: value[field] = rig.get(field)
	return value

func write_json(name: String, value: Variant) -> void:
	var file := FileAccess.open(output.path_join(name),FileAccess.WRITE)
	if file == null:
		push_error("Combat review could not save " + name)
		quit(1)
		return
	file.store_string(JSON.stringify(value))
	file.close()

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 180:
		push_error("Combat review deadline exceeded")
		quit(1)
		return false
	if not is_instance_valid(session) or busy: return false
	sample_age += delta
	if sample_age > 0.1:
		sample_age = 0
		write_json("latest.json",sample())
	var request_path := output.path_join("request.json")
	if FileAccess.file_exists(request_path):
		var request: Variant = JSON.parse_string(FileAccess.get_file_as_string(request_path))
		DirAccess.remove_absolute(request_path)
		if request is Dictionary:
			busy = true
			call_deferred("record_request",request)
	return false

func record_request(request: Dictionary) -> void:
	var marker := str(request.get("marker","sample"))
	if not marker.is_valid_filename():
		push_error("Invalid review marker")
		quit(1)
		return
	if request.get("capture",false):
		for index in range(3): await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(output.path_join(marker+".png")) != OK:
			push_error("Combat review screenshot failed")
			quit(1)
			return
	write_json(marker+".json",sample())
	if request.get("finish",false):
		write_json("recording.json",{"snapshots":rows,"events":events,"transitions":transitions,"normal_rate":true,"state_injection":false,"os_inputs":true})
		session.queue_free()
		await process_frame
		await process_frame
		quit(0)
	busy = false
