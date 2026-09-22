extends SceneTree
## Passive instrumentation around the actual shipped scene and source transport.
var session: Node
var output := OS.get_environment("COMBAT_REVIEW_OUTPUT")
var rows: Array = []
var events: Array = []
var elapsed := 0.0
var sample_age := 0.0
var busy := false
var started := 0

func _initialize() -> void: call_deferred("start")

func start() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	started = Time.get_ticks_usec()
	session.client.snapshot.connect(func(frame: Dictionary) -> void: rows.append({"snapshot":frame,"view":sample()}))
	session.client.events.connect(func(items: Array) -> void: events.append_array(items))
	write_json("ready.json", {"scene":"res://world/session.tscn","state_injection":false,"input":"XTest OS"})

func sample() -> Dictionary:
	var feedback: Node = session.combat
	var rig: Node = session.first_person.rig if is_instance_valid(session.first_person) else null
	return {"wall_usec":Time.get_ticks_usec()-started,"phase":session.phase,"actor":session.presentation.local_actor.duplicate(true),
		"focused":root.has_focus(),"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"fov":session.camera.fov,
		"viewport":[root.size.x,root.size.y],"acks":session.client.last_ack,"stale":session.snapshot_watch.stale(),
		"rig_showing":is_instance_valid(rig) and rig.showing,"aim_requested":session.aim_requested(),
		"recoil_count":rig.recoil_count if is_instance_valid(rig) else 0,
		"particles":feedback.world_particles.snapshot(),"shields":feedback.shields.debug_state(),
		"quality":feedback.quality_controls.quality,"metrics":feedback.quality_controls.metrics,
		"telemetry":feedback.quality_controls.telemetry,"occlusion":feedback.occlusion.snapshot(),
		"weapon_flashes":feedback.weapon_effects.flashes,"weapon_tracers":feedback.weapon_effects.tracer_count,
		"legacy_tracers":feedback.tracers.size(),"legacy_blasts":feedback.blasts.size(),"legacy_moth":feedback.moth_effects.slots.size(),
		"shots":feedback.shots,"hits":feedback.hits,"rendered_frames":Engine.get_frames_drawn()}

func write_json(name: String, value: Variant) -> void:
	var file := FileAccess.open(output.path_join(name),FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 120: quit(1)
	if not is_instance_valid(session) or busy: return false
	sample_age += delta
	if sample_age > 0.1:
		sample_age = 0
		write_json("latest.json",sample())
	var path := output.path_join("request.json")
	if FileAccess.file_exists(path):
		var request: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		DirAccess.remove_absolute(path)
		if request is Dictionary:
			busy = true
			call_deferred("record",request)
	return false

func record(request: Dictionary) -> void:
	var marker := str(request.marker)
	if request.get("capture",true):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(marker+".png"))
	write_json(marker+".json",sample())
	if request.get("finish",false):
		write_json("recording.json",{"snapshots":rows,"events":events,"normal_rate":true,"state_injection":false,"os_inputs":true})
		session.queue_free()
		await process_frame
		await process_frame
		quit(0)
	busy = false
