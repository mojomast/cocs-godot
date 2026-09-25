extends SceneTree
## Short engine-driven Start probe; ordinary server wire, synthetic UI action.
## Never a natural full-round or human-input witness.
var scene: Node
var requested_start := false
var finished := false
var began := 0
var capture_path := ""

func _initialize() -> void:
	began = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
	call_deferred("start_scene")

func start_scene() -> void:
	scene = load("res://lattice/world_demo.tscn").instantiate()
	root.add_child(scene)

func _process(_delta: float) -> bool:
	if scene == null or finished: return false
	if Time.get_ticks_msec() - began > 30000:
		print("LATTICE_PROBE ", JSON.stringify({"status":"timeout","phase":scene.get("phase"),"requested_start":requested_start,"error":scene.get("world_error")}))
		quit(1)
		return false
	if scene.get("phase") == 12 and not requested_start:
		requested_start = true
		scene.call("world_start_requested")
	var client: Node = scene.get("client")
	if scene.get("phase") == 3 and client.get("last_snapshot_seq") >= 1:
		var projection: Dictionary = client.get("projection")
		if projection.is_empty(): return false
		finished = true
		print("LATTICE_PROBE ", JSON.stringify({"status":"active","phase":scene.get("phase"),"requested_start":requested_start,
			"map":projection.get("map"),"mode":projection.get("mode"),"actor":client.get("actor_id"),"revision":client.get("revision"),
			"nodes":projection.get("nodes", []).size(),"source_sequence":projection.get("source_sequence"),"config":client.get("session_config")}))
		call_deferred("finish_capture")
	return false

func finish_capture() -> void:
	if not capture_path.is_empty():
		await RenderingServer.frame_post_draw
		var err := root.get_texture().get_image().save_png(capture_path)
		if err != OK: quit(2); return
	quit()
