extends SceneTree
## Observer only; input comes from the private X11 server's XTest extension.
const DEMO = preload("res://showcase/demo.tscn")
var output := ""
var scene: Node3D
var accumulator := 0.0
var elapsed := 0.0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--control-dir="): output = arg.get_slice("=", 1)
	root.title = "Prism Foundry - isolated native input verification"
	call_deferred("build")

func build() -> void:
	if output.is_empty():
		quit(1)
		return
	scene = DEMO.instantiate()
	root.add_child(scene)

func _process(delta: float) -> bool:
	if scene == null: return false
	elapsed += delta
	accumulator += delta
	if accumulator > 0.08:
		accumulator = 0.0
		var p: CharacterBody3D = scene.player
		var file := FileAccess.open(output.path_join("state.tmp"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"time": elapsed, "position": [p.position.x, p.position.y, p.position.z], "yaw": p.rotation.y, "pitch": p.camera.rotation.x, "mouse_mode": Input.mouse_mode, "keys": p.keys, "jump_pending": p.jump_pending, "focus": root.has_focus(), "reset_count": p.reset_count, "on_floor": p.is_on_floor(), "tour": scene.tour_index}))
		file.close()
		DirAccess.rename_absolute(output.path_join("state.tmp"), output.path_join("state.json"))
	if FileAccess.file_exists(output.path_join("finish")):
		print("PRISM_NATIVE_OBSERVER_OK")
		scene.queue_free()
		quit()
	if elapsed > 90:
		push_error("Native input driver timeout")
		quit(1)
	return false
