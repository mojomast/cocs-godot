extends SceneTree
## Independent evidence fixture: loads actual production scenes, observes only.
## No controller/camera mutation, gameplay/source authority, or network access.
## Writes PNG evidence only to REVIEW_OUTPUT. F8/F9/F10/F11 are harness keys.
var scene_path := "res://%s/demo.tscn" % OS.get_environment("REVIEW_SCENE")
var output := OS.get_environment("REVIEW_OUTPUT")
var elapsed := 0.0
var capture_index := 0
var busy := false
var cycle := 0

func _initialize() -> void:
	root.window_input.connect(_on_input)
	_load.call_deferred()

func _load() -> void:
	change_scene_to_file(scene_path)
	await process_frame
	await process_frame
	print("REVIEW_READY " + JSON.stringify(snapshot()))

func vector(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func counters() -> Dictionary:
	return {"objects": Performance.get_monitor(Performance.OBJECT_COUNT), "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), "static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}

func snapshot() -> Dictionary:
	var s := {"scene": scene_path, "cycle": cycle, "ticks_ms": Time.get_ticks_msec(), "frames": Engine.get_frames_drawn(), "focus": root.has_focus(), "mouse_mode": Input.mouse_mode, "size": [root.size.x, root.size.y], "display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "counters": counters()}
	if not is_instance_valid(current_scene): return s
	var actor: CharacterBody3D
	if OS.get_environment("REVIEW_SCENE") == "showcase": actor = current_scene.player
	elif OS.get_environment("REVIEW_SCENE") in ["aurora_basin", "cinder_array"]: actor = current_scene.walker
	if actor:
		s["actor_script"] = actor.get_script().resource_path
		s["position"] = vector(actor.global_position)
		s["velocity"] = vector(actor.velocity)
		s["yaw"] = actor.rotation.y
		s["camera_position"] = vector(actor.camera.global_position)
		s["camera_pitch"] = actor.camera.rotation.x
		s["camera_current"] = actor.camera.current
		s["reset_count"] = actor.reset_count
	elif OS.get_environment("REVIEW_SCENE") == "particle_lab":
		s["statistics"] = current_scene.statistics()
		s["clock"] = current_scene.field.clock
		s["paused"] = current_scene.field.paused
		s["backend_text"] = current_scene.backend_label.text
		s["status_text"] = current_scene.status_label.text
		s["telemetry_text"] = current_scene.telemetry.text
		s["buttons"] = []
		_buttons(current_scene, s.buttons)
	elif OS.get_environment("REVIEW_SCENE") == "shader_lab":
		s["selected"] = current_scene.selected
		s["seconds"] = current_scene.seconds
		s["paused"] = current_scene.paused
		s["intensity"] = current_scene.intensity
		s["phase"] = current_scene.phase_amount
		s["yaw"] = current_scene.yaw
		s["factory"] = current_scene.factory.state()
		s["stats_text"] = current_scene.stats.text
		var sidebar: Control = current_scene.ui.get_node("Sidebar")
		var rect := sidebar.get_global_rect()
		s["sidebar_rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		s["sidebar_right"] = rect.end.x
	return s

func _buttons(node: Node, results: Array) -> void:
	if node is Button:
		var r: Rect2 = node.get_global_rect()
		results.append({"text": node.text, "rect": [r.position.x, r.position.y, r.size.x, r.size.y]})
	for child in node.get_children(): _buttons(child, results)

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 0.25 and not busy and is_instance_valid(current_scene):
		elapsed = 0.0
		print("REVIEW_SAMPLE " + JSON.stringify(snapshot()))
	return false

func _on_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or busy: return
	if event.keycode == KEY_F8:
		busy = true
		await RenderingServer.frame_post_draw
		var path := "%s/capture-%02d.png" % [output, capture_index]
		root.get_texture().get_image().save_png(path)
		capture_index += 1
		print("REVIEW_CAPTURE " + JSON.stringify({"path": path, "state": snapshot()}))
		busy = false
	elif event.keycode == KEY_F9:
		print("REVIEW_MARK " + JSON.stringify(snapshot()))
	elif event.keycode in [KEY_F10, KEY_F11]:
		busy = true
		var reload_scene: bool = event.keycode == KEY_F11
		var before := counters()
		unload_current_scene()
		for i in range(12): await process_frame
		print("REVIEW_TEARDOWN " + JSON.stringify({"cycle": cycle, "before": before, "after": counters(), "mouse_mode": Input.mouse_mode}))
		if reload_scene:
			cycle += 1
			await _load()
			busy = false
		else: quit()
