extends SceneTree
## Run only after heavy-slot grant. Synthetic policy/lifecycle and optional real
## mixer capture are distinct from the source-wire journey and human listening.
const Policy = preload("res://audio/threat_policy.gd")
const Router = preload("res://audio/event_router.gd")
const Threat = preload("res://audio/threat_service.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	preload("res://audio/buses.gd").ensure()
	var file := FileAccess.open("res://tests/audio_expansion/policy_cases.json", FileAccess.READ)
	var cases: Dictionary = JSON.parse_string(file.get_as_text())
	for row: Array in cases.distance:
		check(is_equal_approx(Policy.gain_at({"x":row[0],"z":row[1]}, {"x":0,"z":0}), row[2]), "falloff")
	for row: Dictionary in cases.slots:
		check(Policy.slot(row.active,row.weights,row.starts,row.weight,row.now) == int(row.expected), "priority slot")
	check(not Policy.position({"x":NAN,"z":0}), "reject NaN")
	var router := Router.new()
	router.start_round("native-threat")
	var event := {"id":1,"type":"enemy-telegraph","kind":"boss","actor":9,"time":1.0,"duration":0.8,"x":6,"z":0}
	var plan: Array[Dictionary] = router.consume([event], 1, "blue", true)
	check(plan.size() == 1 and plan[0].kind == "boss" and plan[0].from.x == 6, "wire descriptor")
	check(router.consume([event],1,"blue",true).is_empty(), "wire duplicate")
	event.id = 2
	check(router.consume([event],1,"blue",false).is_empty(), "unready consumes")
	check(router.consume([event],1,"blue",true).is_empty(), "no recovery catchup")
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.position.y = 1.6
	var service := Threat.new()
	world.add_child(service)
	service.set_mode("campaign")
	check(service.streams.size() == 8 and service.mode_root == 54, "mode assets")
	var recorder := AudioEffectRecord.new()
	var record_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--record="): record_path = arg.trim_prefix("--record=")
	var bus := AudioServer.get_bus_index("Effects")
	if not record_path.is_empty():
		check(AudioServer.get_driver_name() != "Dummy", "Dummy is not rendered audio evidence")
		AudioServer.add_bus_effect(bus, recorder)
		recorder.set_recording_active(true)
	check(service.event_plan(plan[0], {"x":0,"y":0,"z":0}, 1.0), "current boss")
	await create_timer(0.7).timeout
	check(not service.event_plan(plan[0], {"x":0,"z":0}, 2.0), "expired windup")
	service.apply_settings({"mute":true})
	check(not service.event_plan(plan[0], {"x":0,"z":0}, 1.0), "mute")
	check(service.status().voices == 0, "mute releases voices")
	service.apply_settings({"mute":false,"effects_volume":0})
	check(not service.event_plan(plan[0], {"x":0,"z":0}, 1.0), "effects zero")
	service.apply_settings({"effects_volume":100})
	service.set_focus(false)
	check(not service.event_plan(plan[0], {"x":0,"z":0}, 1.0), "focus")
	service.set_focus(true)
	check(service.event_plan(plan[0], {"x":0,"z":0}, 1.0), "recovery current only")
	service.stop_all()
	check(service.status().voices == 0, "stop")
	await create_timer(0.15).timeout
	if not record_path.is_empty():
		recorder.set_recording_active(false)
		var recording := recorder.get_recording()
		check(recording != null and recording.data.size() > 0, "mixer PCM exists")
		if recording != null: check(recording.save_to_wav(record_path) == OK, "save mixer evidence")
		AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus)-1)
	world.queue_free()
	await process_frame
	print("THREAT_GATE failures=", failures, " driver=", AudioServer.get_driver_name())
	quit(1 if failures else 0)
