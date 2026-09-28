extends SceneTree
## Actual menu/route scenes and source servers, driven by scripted UI actions.
## This is bounded lifecycle evidence, not natural rounds or human acceptance.
var scene: Node
var settings: Node
var record: Dictionary = {}
var state_path := ""
var scene_path := ""
var route_id := ""
var running := false
var elapsed := 0.0
var start_requested := false

func _initialize() -> void:
	call_deferred("begin")

func require_value(ok: bool, message: String) -> bool:
	if ok: return true
	push_error("PRODUCT_JOURNEY " + message)
	running = false
	quit(1)
	return false

func write_record() -> void:
	var file := FileAccess.open(state_path, FileAccess.WRITE)
	if not require_value(file != null, "cannot write fixture state"): return
	file.store_string(JSON.stringify(record))
	file.close()

func begin() -> void:
	state_path = OS.get_environment("COCS_JOURNEY_STATE")
	scene_path = OS.get_environment("COCS_JOURNEY_SCENE")
	settings = root.get_node("LocalSettings")
	record = JSON.parse_string(FileAccess.get_file_as_string(state_path))
	if not require_value(settings.values.master_volume == record.expected_volume, "settings did not survive process boundary"): return
	var packed: PackedScene = load(scene_path)
	scene = packed.instantiate()
	if scene_path == "res://ui/main_menu.tscn":
		scene.preferences_path = state_path.get_base_dir().path_join("menu_preferences.json")
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	if scene_path == "res://ui/main_menu.tscn":
		await menu_step()
	else:
		route_id = str(record.route)
		running = true

func menu_step() -> void:
	var visit := int(record.visits)
	if visit == 0 and OS.get_environment("COCS_JOURNEY_CAPTURE") == "1":
		await capture_view("home-1280x800")
		root.size = Vector2i(760,520)
		await capture_view("home-760x520")
		settings.set_value("ui_scale",150,false)
		await capture_view("home-760x520-scale150")
		settings.set_value("ui_scale",100,false)
		root.size = Vector2i(1280,800)
		await process_frame
	if visit > 0:
		if not require_value(scene.current_route.get("id") == record.route, "menu did not restore last activity"): return
	if visit == 9:
		print("PRODUCT_JOURNEY_COMPLETE ", JSON.stringify(record))
		scene.quit_menu()
		return
	var routes := ["combat", "lattice-world", "sports"]
	var next_route: String = routes[visit % routes.size()]
	var descriptor: Dictionary = scene.registry.route_by_id(next_route)
	scene.select_category(str(descriptor.category))
	scene.select_route(next_route)
	# Drive the real Settings/Home control seam, not a private store mutation.
	scene.settings_button.pressed.emit()
	if not require_value(settings.overlay_open(), "Home Settings did not open"): return
	var volume := 40 + visit * 5
	if not require_value(settings.set_value("master_volume", volume), "settings save failed"): return
	settings.rows.back.pressed.emit()
	if not require_value(not settings.overlay_open(), "Back did not close Settings"): return
	record.expected_volume = volume
	record.route = next_route
	record.visits = visit + 1
	write_record()
	print("PRODUCT_JOURNEY_HOME ", JSON.stringify({"visit":visit + 1,"route":next_route,"volume":volume}))
	scene.on_start()

func _process(delta: float) -> bool:
	if not running: return false
	elapsed += delta
	if elapsed > 45.0:
		require_value(false, "source session did not become ready: " + route_id)
		return false
	if route_id == "lattice-world" and scene.phase == 12 and not start_requested:
		start_requested = true
		scene.session_panel.start_requested.emit()
	var ready := false
	if route_id == "sports":
		ready = scene.phase == "active" and not scene.actor.is_empty() and not scene.vehicle.is_empty()
	else:
		ready = scene.phase == 3 and scene.received_pose
		if route_id == "lattice-world": ready = ready and not scene.client.projection.is_empty()
	if ready:
		running = false
		call_deferred("route_step")
	return false

func tap_key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func settings_key() -> void:
	tap_key(KEY_F12)

func open_deck() -> bool:
	tap_key(KEY_C)
	for i in 4: await RenderingServer.frame_post_draw
	if not require_value(scene.world_commands.visible, "command deck did not open"): return false
	var bounds: Rect2 = scene.world_commands.panel.get_rect()
	var viewport: Vector2 = root.get_visible_rect().size
	if not require_value(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= viewport.x + 1 and bounds.end.y <= viewport.y + 1,
		"live first-open command deck exceeds viewport"): return false
	print("PRODUCT_JOURNEY_DECK ", JSON.stringify({"visit":record.visits,"first_open_fits":true,
		"viewport":[viewport.x,viewport.y],"position":[bounds.position.x,bounds.position.y],"size":[bounds.size.x,bounds.size.y]}))
	return true

func capture_view(name: String) -> void:
	for i in 4: await RenderingServer.frame_post_draw
	var output := state_path.get_base_dir().path_join(name + ".png")
	if not require_value(root.get_texture().get_image().save_png(output) == OK, "capture save failed"): return
	print("PRODUCT_JOURNEY_CAPTURE ", JSON.stringify({"name":name,"path":output,"source_route":route_id,
		"window":[root.size.x,root.size.y],"scale":settings.values.ui_scale}))

func capture_deck() -> void:
	if not await open_deck(): return
	if scene.world_commands.nodes.item_count > 2:
		scene.world_commands.nodes.select(2)
		scene.world_commands.nodes.item_selected.emit(2)
	root.size = Vector2i(1280,800)
	await capture_view("deck-1280x800")
	root.size = Vector2i(760,520)
	await capture_view("deck-760x520")
	settings.set_value("ui_scale",150,false)
	await capture_view("deck-760x520-scale150")
	settings.open_panel()
	await capture_view("settings-760x520-scale150")
	settings.close_panel()
	settings.set_value("ui_scale",100,false)
	root.size = Vector2i(1280,800)
	scene.world_close_commands()
	await process_frame
	await capture_view("tactical-1280x800")
	root.size = Vector2i(760,520)
	settings.set_value("ui_scale",150,false)
	await capture_view("tactical-760x520-scale150")
	var hud: Control = scene.tactical_hud
	if not require_value(not hud.objective_card.get_rect().intersects(hud.status_card.get_rect()), "scaled live tactical cards overlap"): return
	if not require_value(hud.objective_card.get_rect().end.y <= hud.bottom.position.y and hud.status_card.get_rect().end.y <= hud.bottom.position.y,
		"scaled live tactical cards overlap the control ribbon"): return
	settings.set_value("ui_scale",100,false)
	root.size = Vector2i(1280,800)
	await process_frame

func route_step() -> void:
	if route_id == "lattice-world" and int(record.visits) == 2 and OS.get_environment("COCS_JOURNEY_CAPTURE") == "1":
		await capture_deck()
	elif route_id == "lattice-world":
		if not await open_deck(): return
		scene.world_close_commands()
		await process_frame
	settings_key()
	await process_frame
	if not require_value(settings.overlay_open() and settings.rows.leave.visible, "F12 did not expose match Settings/Leave"): return
	if not require_value(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Settings retained pointer capture"): return
	if not require_value(not paused, "Settings paused the client while authority runs"): return
	await create_timer(0.2).timeout
	settings.rows.back.pressed.emit()
	await process_frame
	if not require_value(not settings.overlay_open() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Back recaptured controls"): return
	settings_key()
	await process_frame
	if not require_value(settings.overlay_open(), "Settings cannot reopen"): return
	print("PRODUCT_JOURNEY_MATCH ", JSON.stringify({"visit":record.visits,"route":route_id,"source_ready":true,
		"settings_path":settings.path,"volume":settings.values.master_volume,"pointer_released":true}))
	settings.rows.leave.pressed.emit()
