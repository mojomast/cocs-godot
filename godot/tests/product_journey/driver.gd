extends SceneTree
const CareerActions = preload("res://career/actions_model.gd")
## Actual menu/route scenes and source servers, driven by scripted UI actions.
## This is bounded lifecycle evidence, not natural rounds or human acceptance.
var scene: Node
var settings: Node
var career: Node
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
	career = root.get_node("Career")
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
		if record.get("player_flow", false):
			call_deferred("player_flow_step")
		else:
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
	if not await home_career_step(visit): return
	if visit > 0:
		if not require_value(scene.current_route.get("id") == record.route, "menu did not restore last activity"): return
		for key: String in record.get("options", {}):
			if not require_value(scene.selections.get(key) == record.options[key], "menu did not restore " + key): return
	if visit == int(record.cycles) * record.itinerary.size():
		write_record()
		print("PRODUCT_JOURNEY_COMPLETE ", JSON.stringify(record))
		scene.quit_menu()
		return
	var entry: Dictionary = record.itinerary[visit % record.itinerary.size()]
	var next_route: String = entry.route
	var descriptor: Dictionary = scene.registry.route_by_id(next_route)
	scene.select_category(str(descriptor.category))
	scene.select_route(next_route)
	# Drive actual Home widgets, with map first so dependent choices rederive.
	var choices: Array = entry.options.keys()
	choices.sort()
	if "map" in choices:
		choices.erase("map")
		choices.push_front("map")
	for key: String in choices:
		if scene.choice_rows.has(key):
			var picker: Control = scene.choice_rows[key]
			var found := false
			for index: int in picker.item_count:
				if picker.get_item_metadata(index) == entry.options[key]:
					picker.select(index)
					picker.item_selected.emit(index)
					found = true
					break
			if not require_value(found, "unavailable Home choice: " + key): return
		elif scene.slider_rows.has(key):
			scene.slider_rows[key].value = entry.options[key]
		else:
			require_value(false, "unsupported Home widget: " + key)
			return
		if not require_value(scene.selections.get(key) == entry.options[key], "Home rejected option: " + key): return
	# Drive the real Settings/Home control seam, not a private store mutation.
	scene.settings_button.pressed.emit()
	if not require_value(settings.overlay_open(), "Home Settings did not open"): return
	var volume := 40 + (visit % 10) * 5
	if not require_value(settings.set_value("master_volume", volume), "settings save failed"): return
	settings.rows.back.pressed.emit()
	if not require_value(not settings.overlay_open(), "Back did not close Settings"): return
	record.expected_volume = volume
	record.route = next_route
	record.options = entry.options
	record.visits = visit + 1
	write_record()
	print("PRODUCT_JOURNEY_HOME ", JSON.stringify({"visit":visit + 1,"route":next_route,"volume":volume}))
	scene.on_start()

func career_bounds() -> bool:
	var scroll := career.details.get_parent() as Control
	var viewport: Vector2 = root.get_visible_rect().size
	var back := career.panel.find_child("CareerBack", true, false) as Control
	var rows := career.details.find_child("CatalogRows", true, false) as VBoxContainer
	if not require_value(rows != null and rows.get_child_count() > 0, "Career catalog did not load any rows"): return false
	var first := rows.get_child(0) as Control
	for control: Control in [scroll, career.details, back, first]:
		var bounds := control.get_global_rect()
		if not require_value(bounds.position.x >= -1 and bounds.end.x <= viewport.x + 1 and bounds.size.x > 0,
			"Career content clips horizontally at this display scale"): return false
	var back_rect := back.get_global_rect()
	return require_value(back_rect.position.y >= 0 and back_rect.end.y <= viewport.y + 1,
		"Career Back action is not visible without scrolling")

func career_back() -> void:
	var button := career.panel.find_child("CareerBack", true, false) as Button
	button.pressed.emit()

func home_career_step(visit: int) -> bool:
	if not require_value(career.profile.is_empty(), "Home has a stale career from a previous process"): return false
	scene.career_button.pressed.emit()
	await process_frame
	await process_frame
	if not require_value(career.active() and not settings.overlay_open(), "Home Career button did not open a single overlay"): return false
	if not require_value(career.state_label.text.contains("NO CONNECTED CAREER"), "Home fabricated a connected profile"): return false
	var home_rows := career.details.find_child("CatalogRows", true, false) as VBoxContainer
	if not require_value(home_rows != null and home_rows.get_child_count() > 0, "Home catalog missing"): return false
	var first_label := home_rows.get_child(0).get_child(0) as Label
	if not require_value(first_label != null and first_label.text.contains("NOT LOADED"), "Home catalog fabricated unlock status"): return false
	if not career_bounds(): return false
	if visit == 0 and OS.get_environment("COCS_JOURNEY_CAPTURE") == "1":
		if not career_bounds(): return false
		await capture_view("career-home-1280x800")
		root.size = Vector2i(760,520)
		await process_frame
		if not career_bounds(): return false
		await capture_view("career-home-760x520")
		settings.set_value("ui_scale",150,false)
		await process_frame
		await process_frame # Nested containers settle after the viewport scale change.
		if not career_bounds(): return false
		await capture_view("career-home-760x520-scale150")
		settings.set_value("ui_scale",100,false)
		root.size = Vector2i(1280,800)
		await process_frame
	career_back()
	if not require_value(not career.active() and not scene.quitting and scene.career_button.has_focus(), "Home Career Back quit or lost focus"): return false
	record.career_home_checks = int(record.get("career_home_checks",0)) + 1
	print("PRODUCT_JOURNEY_CAREER ", JSON.stringify({"route":"home","has_profile":false,"bounds":true}))
	return true

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
	elif "received_pose" in scene:
		ready = scene.phase == 3 and scene.received_pose
		if route_id == "lattice-world": ready = ready and not scene.client.projection.is_empty()
	else:
		require_value(false, "route does not expose the source-world readiness seam: " + route_id)
		return false
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
	if not await live_career_step(): return
	if not require_value(settings.overlay_open() and settings.rows.leave.visible, "Career Back did not restore live Settings/Leave"): return
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

func live_career_step() -> bool:
	if not require_value(settings.career_button.visible, "live Settings has no Career entry"): return false
	settings.career_button.pressed.emit()
	await process_frame
	await process_frame
	if not require_value(career.active() and not settings.overlay_open() and not paused, "live Career did not open while authority continued"): return false
	var has_profile: bool = not career.profile.is_empty()
	if route_id in ["combat", "lattice-world", "lobby"]:
		if not require_value(has_profile and scene.client.career_seated and scene.client.room_id != "", "source welcome did not seat a Career profile"): return false
	if has_profile:
		if not require_value(career.state_label.text.contains("CONNECTED SOURCE CAREER") and not career.state_label.text.contains("NO CONNECTED CAREER"), "live source profile not projected"): return false
		# Compare identity without retaining its source-issued ID or credentials in
		# the public evidence. Every route process must recover the same career.
		var identity_hash: String = str(career.profile.id).sha256_text()
		if record.has("career_identity_hash"):
			if not require_value(record.career_identity_hash == identity_hash, "source career changed across native processes"): return false
		else:
			record.career_identity_hash = identity_hash
		if record.has("career_selection"):
			var selected: Dictionary = record.career_selection
			if not require_value(career.profile.get("attachments", {}).get(selected.slot) == selected.id, "source equipment did not survive route/server restart"): return false
		elif route_id == "combat":
			if not await equip_starter_attachment(): return false
	else:
		if not require_value(career.state_label.text.contains("NO CONNECTED CAREER"), "adapter without source profile invented progress"): return false
	if not career_bounds(): return false
	if route_id == "lattice-world" and int(record.visits) == 2 and OS.get_environment("COCS_JOURNEY_CAPTURE") == "1":
		if not career_bounds(): return false
		await capture_view("career-live-profile-1280x800")
		root.size = Vector2i(760,520)
		await process_frame
		if not career_bounds(): return false
		await capture_view("career-live-profile-760x520")
		settings.set_value("ui_scale",150,false)
		await process_frame
		await process_frame
		if not career_bounds(): return false
		await capture_view("career-live-profile-760x520-scale150")
		settings.set_value("ui_scale",100,false)
		root.size = Vector2i(1280,800)
		await process_frame
	career_back()
	await process_frame
	if not require_value(not career.active() and settings.overlay_open() and settings.rows.back.has_focus(), "live Career Back did not restore SettingsBack focus"): return false
	record.career_live_checks = int(record.get("career_live_checks",0)) + 1
	write_record()
	print("PRODUCT_JOURNEY_CAREER ", JSON.stringify({"route":route_id,"has_profile":has_profile,"bounds":true}))
	return true

func equip_starter_attachment() -> bool:
	# Level-one starter mods make this a real source request without granting XP
	# or editing a profile fixture. Drive the displayed tab and action button.
	var item := {}
	for candidate: Dictionary in career.catalog.items:
		if candidate.kind == "attachment" and candidate.level == 1 and CareerActions.available(career.profile, candidate) and career.profile.get("attachments", {}).get(candidate.slot) != candidate.id:
			item = candidate
			break
	if not require_value(not item.is_empty(), "source catalog has no available starter attachment"): return false
	for button: Node in career.details.find_children("*", "Button", true, false):
		if button.text == "MODS":
			button.pressed.emit()
			break
	await process_frame
	var equip := career.panel.find_child("Equip_" + str(item.unlockId), true, false) as Button
	if not require_value(equip != null and not equip.disabled, "starter attachment has no usable UI action"): return false
	equip.pressed.emit()
	if not require_value(not career.pending.is_empty(), "UI selection was not queued for source confirmation"): return false
	var deadline := Time.get_ticks_msec() + 7000
	while not career.pending.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if not require_value(career.pending.is_empty() and career.profile.get("attachments", {}).get(item.slot) == item.id, "source did not confirm starter attachment"): return false
	record.career_selection = {"kind":"attachment", "slot":item.slot, "id":item.id}
	record.career_equipment_confirmed = true
	write_record()
	print("PRODUCT_JOURNEY_EQUIPMENT ", JSON.stringify({"status":"source-confirmed", "kind":"attachment", "slot":item.slot, "id":item.id}))
	return true

func flow_check(ok: bool, message: String) -> bool:
	if not require_value(ok, "player flow: " + message): return false
	var checks: Array = record.get("player_flow_checks", [])
	checks.append(message)
	record.player_flow_checks = checks
	return true

func flow_wait(predicate: Callable, message: String, timeout_ms: int = 12000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	return flow_check(bool(predicate.call()), message)

func flow_actor_attachments() -> Array:
	var actor := flow_latest_actor()
	var ids := []
	for item: Dictionary in actor.get("attachments", {}).get("items", []):
		ids.append(item.get("id", ""))
	return ids

func flow_latest_actor() -> Dictionary:
	if scene.client.snapshots.is_empty(): return {}
	var snapshot: Dictionary = scene.client.snapshots.back()
	for actor: Dictionary in snapshot.get("state", {}).get("actors", []):
		if actor.get("id", -1) != scene.client.actor_id: continue
		return actor
	return {}

func flow_capture(name: String) -> void:
	if OS.get_environment("COCS_JOURNEY_CAPTURE") == "1": await capture_view(name)

## One integrated journey through the real supervisor, owned source server and
## shipping scenes. UI buttons are scripted signal activations; F12 uses engine
## input. A deliberate WebSocket close is the only fault injection. The source
## runs its legal 60-second round normally; this is not human gameplay evidence.
func player_flow_step() -> void:
	if not await flow_wait(func() -> bool: return scene.phase == -3, "Home opened disconnected multiplayer setup"): return
	var menu: Node = scene.lobby_menu
	var rooms_seen := [false]
	scene.client.rooms.connect(func(_items: Array) -> void: rooms_seen[0] = true)
	menu.room_browser.refresh_button.pressed.emit()
	if not await flow_wait(func() -> bool: return scene.phase == -4 and rooms_seen[0], "browser received a selected-server room list"): return
	if not flow_check(career.profile.is_empty(), "browsing did not invent a seated Career"): return
	await flow_capture("flow-room-browser")
	menu.back_button.pressed.emit()
	if not await flow_wait(func() -> bool: return scene.phase == -3, "cancel browsing returned to explicit setup"): return
	menu.connect_button.pressed.emit()
	if not await flow_wait(func() -> bool: return scene.phase == 12 and scene.lobby_host_allowed() and not career.profile.is_empty(), "source seated host and confirmed Career"): return
	var identity: String = str(career.profile.id) # Internal equality only, never retained.
	var room: String = scene.client.room_id
	await process_frame
	menu.arsenal_button.pressed.emit()
	await process_frame
	if not flow_check(career.active() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "lobby Arsenal opened with released pointer"): return
	career_back()
	await process_frame
	if not flow_check(not career.active() and menu.arsenal_button.has_focus(), "Arsenal Back restored lobby action focus"): return
	menu.start_button.pressed.emit()
	if not await flow_wait(func() -> bool: return scene.phase == 3 and scene.received_pose, "first source round became live"): return
	var config: Dictionary = scene.client.snapshots.back().get("state", {}).get("config", {})
	if not flow_check(config.get("timeLimit") == 60 and config.get("mode") == "deathmatch" and config.get("fragLimit") == 100, "source echoed the legal 60-second deathmatch preset"): return
	var actor_id: int = scene.client.actor_id
	var revision: int = scene.client.resumed_revision
	scene.client.peer.close(4000, "Scripted player-flow transport interruption")
	if not await flow_wait(func() -> bool: return scene.phase == -5, "transport interruption exposed explicit Retry"): return
	if not flow_check(career.profile.is_empty() and not scene.received_pose and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "disconnect cleared stale Career and pose and released controls"): return
	await process_frame
	if not flow_check(menu.reconnect_button.visible and not menu.reconnect_button.disabled, "same-room reconnect action is available"): return
	await flow_capture("flow-retry")
	menu.reconnect_button.pressed.emit()
	if not await flow_wait(func() -> bool: return scene.phase == 3 and scene.received_pose and not career.profile.is_empty(), "explicit Retry recovered the live source round"): return
	if not flow_check(scene.client.actor_id == actor_id and scene.client.resumed_revision == revision and scene.client.room_id == room and str(career.profile.id) == identity, "Retry preserved source seat round and Career identity"): return
	if not flow_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Retry did not recapture controls"): return
	if not await flow_wait(func() -> bool: return scene.phase == 4 and not career.result.is_empty(), "source settled the normal timed round", 75000): return
	if not flow_check(career.result.get("ending") == "time" and float(career.result.get("time", -1)) >= 60.0 and float(career.result.get("time", INF)) <= 61.0, "accepted result reports a time-limit ending at 60 source seconds"): return
	settings_key()
	await process_frame
	settings.career_button.pressed.emit()
	await process_frame
	career.select_category("results")
	await process_frame
	if not flow_check(career.active() and not career.attributed_award().is_empty(), "Results displays an accepted result with its same-round award"): return
	root.size = Vector2i(760, 520)
	settings.set_value("ui_scale", 150, false)
	for i in 4: await process_frame
	if not career_bounds(): return
	await flow_capture("flow-results-760x520-scale150")
	var actor: Dictionary = flow_latest_actor()
	if not flow_check(actor.get("attachments") is Dictionary and actor.attachments.get("items") is Array, "retained actor attachment presentation is known"): return
	var before: Array = flow_actor_attachments()
	if not await equip_starter_attachment(): return
	# The client ignores fresh snapshots after results. This proves presentation
	# stability only; source non-mutation is covered by career-equipment-source.
	if not flow_check(flow_actor_attachments() == before, "confirmed equipment did not overwrite the retained actor presentation"): return
	career.select_category("loadout")
	await process_frame
	await flow_capture("flow-loadout-760x520-scale150")
	career_back()
	await process_frame
	if not flow_check(settings.overlay_open(), "Career Back restored match Settings"): return
	settings.rows.back.pressed.emit()
	await process_frame
	if not flow_check(not settings.overlay_open() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Settings Back released controls at results"): return
	menu.restart_button.pressed.emit()
	if not await flow_wait(func() -> bool: return scene.phase == 3 and scene.received_pose and scene.client.resumed_revision > revision, "Rematch started a new source round"): return
	if not await flow_wait(func() -> bool: return record.career_selection.id in flow_actor_attachments(), "new source actor carries the confirmed saved attachment"): return
	settings.set_value("ui_scale", 100, false)
	root.size = Vector2i(1280, 800)
	record.player_flow_complete = true
	write_record()
	# The common final step verifies Settings/Career once more, then the actual
	# supervisor returns Home and proves the owned authority has shut down.
	await route_step()
