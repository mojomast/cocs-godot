extends SceneTree
## Scripted UI seam over the canonical externally hosted LATTICE world scene.
var scene: Node
var settings: Node
var elapsed := 0.0
var stage := 0

func _initialize() -> void:
	call_deferred("begin")

func fail(message: String) -> void:
	push_error("GUEST_LEAVE " + message)
	quit(1)

func begin() -> void:
	settings = root.get_node_or_null("LocalSettings")
	if settings == null or OS.get_environment("COCS_GUEST_SCENE") != "res://lattice/world_demo.tscn":
		fail("missing settings or canonical world scene")
		return
	var packed: PackedScene = load(OS.get_environment("COCS_GUEST_SCENE"))
	if packed == null:
		fail("cannot load world scene")
		return
	scene = packed.instantiate()
	root.add_child(scene)
	current_scene = scene

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 45.0:
		fail("guest source snapshot deadline")
		return false
	if scene == null or not is_instance_valid(scene): return false
	if scene.phase == -1:
		fail("guest connection: " + str(scene.client.error))
		return false
	if stage == 0 and scene.phase == 11:
		stage = 1
		print("GUEST_LEAVE_WAITING ", JSON.stringify({"room":scene.client.room_id,"peer":scene.client.peer_id}))
	if stage == 1 and scene.phase == 3 and scene.received_pose and not scene.client.projection.is_empty():
		stage = 2
		call_deferred("exercise_settings")
	return false

func settings_key() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F12
	event.physical_keycode = KEY_F12
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func exercise_settings() -> void:
	var actor: int = scene.client.actor_id
	var room: String = scene.client.room_id
	settings_key()
	await process_frame
	if not settings.overlay_open() or not settings.rows.leave.visible or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE or paused:
		fail("F12 did not expose live guest Settings/Leave")
		return
	settings.rows.back.pressed.emit()
	await process_frame
	if settings.overlay_open() or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		fail("Back did not restore visible-pointer game state")
		return
	settings_key()
	await process_frame
	if not settings.overlay_open():
		fail("Settings did not reopen")
		return
	print("GUEST_LEAVE_READY ", JSON.stringify({"room":room,"actor":actor,"peer":scene.client.peer_id,"source_snapshots":scene.client.snapshots.size(),"settings_path":settings.path,"pointer_released":true,"scripted_ui":true}))
	settings.rows.leave.pressed.emit()
	await scene_changed
	if current_scene == null or current_scene.scene_file_path != "res://ui/main_menu.tscn":
		fail("Leave did not return Home")
		return
	# This is an external direct-route launcher. The user can quit Home normally;
	# the scripted journey must do so after observing the successful transition.
	print("GUEST_LEAVE_HOME ", JSON.stringify({"scene":current_scene.scene_file_path}))
	quit(0)
