extends SceneTree
## Read-only live observer. All controls come from ordinary external XTest events.
const Scene = preload("res://sports/demo.tscn")
var demo
var directory := ""
var age := 0.0
var sample_age := 0.0
var capturing := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--bearing-out="): directory = arg.trim_prefix("--bearing-out=")
	demo = Scene.instantiate()
	root.add_child.call_deferred(demo)

func sample() -> Dictionary:
	var camera: Camera3D = demo.world.camera
	var targets := {}
	var race: Dictionary = demo.state.get("race", {})
	if not demo.vehicle.is_empty():
		var selected: Dictionary = demo.guidance.expected(race, demo.net.actor_id)
		if not selected.is_empty(): targets.gate = selected.gate
		if not demo.soccer_guidance.selection.is_empty():
			targets.ball = demo.soccer_guidance.selection.ball
			targets.opponent = demo.soccer_guidance.selection.opponent
	var projections := {}
	for key: String in targets:
		var target: Dictionary = targets[key]
		var point := Vector3(target.x, float(target.get("y", 0)), target.z)
		var pixel := camera.unproject_position(point)
		projections[key] = {"pixel":[pixel.x, pixel.y], "behind_camera":camera.is_position_behind(point), "source":target}
	return {"seq":demo.net.last_snapshot_seq, "ack":demo.net.last_ack, "phase":demo.phase,
		"eligible":demo.eligible(), "vehicle":demo.vehicle, "race":race, "hud":demo.hud.text,
		"camera_transform":str(camera.global_transform), "projections":projections,
		"viewport":[root.size.x, root.size.y], "elapsed_wall":age}

func save_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "  ") + "\n")

func _process(delta: float) -> bool:
	age += delta
	sample_age += delta
	if age > 75:
		quit()
		return false
	if not is_instance_valid(demo) or not demo.is_node_ready(): return false
	if sample_age > 0.1:
		sample_age = 0
		save_json(directory.path_join("latest.json"), sample())
	var request := directory.path_join("capture.txt")
	if not capturing and FileAccess.file_exists(request):
		var label := FileAccess.get_file_as_string(request).strip_edges()
		DirAccess.remove_absolute(request)
		capture.call_deferred(label)
	return false

func capture(label: String) -> void:
	if capturing: return
	capturing = true
	await RenderingServer.frame_post_draw
	var receipt := sample()
	var result := root.get_texture().get_image().save_png(directory.path_join(label + ".png"))
	receipt["png_error"] = result
	save_json(directory.path_join(label + ".json"), receipt)
	print("BEARING_LIVE_CAPTURE ", label, " seq=", receipt.seq)
	capturing = false
