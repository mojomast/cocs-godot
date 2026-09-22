extends SceneTree
## UI-polish lane probe: measures and renders the four owned surfaces at
## 960x640 and 1280x800. Synthetic state delivery only; no authority traffic.
##
##   <godot> --path godot --script <this path> -- --setup --capture-dir=DIR --report=FILE
##
## Cases:
##   setup    actual --setup session scene: panel rect, popup count, dismissal
##            (when the surface exposes it) and the live combat view after Start.
##   horde    actual horde/demo.tscn: live Tab board vs the vitals/weapon panels,
##            results board, pickup captions and the roster label.

const SessionScene = preload("res://world/session.tscn")
const HordeScene = preload("res://horde/demo.tscn")

var capture_dir := ""
var report_path := ""
var report: Dictionary = {"cases": [], "synthetic_horde_state": true, "probe_head": ""}

func _initialize() -> void:
	call_deferred("run")

func arg_value(prefix: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix): return arg.trim_prefix(prefix)
	return ""

func settle(frames: int = 3) -> void:
	for i: int in range(frames): await process_frame

func capture(name: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		report["capture_error"] = name
		return
	var path := capture_dir.path_join(name)
	if image.save_png(path) != OK: report["capture_error"] = path

func rect_json(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func popup_count(node: Node) -> int:
	var count := 1 if node is PopupMenu or node is OptionButton or node is Window else 0
	for child: Node in node.get_children(true): count += popup_count(child)
	return count

func record(name: String, data: Dictionary) -> void:
	var entry := data.duplicate(true)
	entry["case"] = name
	report["cases"].append(entry)

func press(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle(2)

func click_at(position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle(2)

func run() -> void:
	capture_dir = arg_value("--capture-dir=")
	report_path = arg_value("--report=")
	for size: Vector2i in [Vector2i(960, 640), Vector2i(1280, 800)]:
		root.size = size
		await settle(4)
		await setup_case(size)
		await horde_case(size)
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "  "))
	quit(0)

# ---------------------------------------------------------------------------
# Setup surface: real --setup session scene + stored authority frames.
# ---------------------------------------------------------------------------

func combat_snapshot() -> Dictionary:
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/protocol/captured.json"))
	for record: Dictionary in capture.frames:
		if record.direction == "server" and record.client == 1 and record.frame.type == "snapshot":
			return record.frame.duplicate(true)
	return {}

func setup_case(size: Vector2i) -> void:
	var session := SessionScene.instantiate()
	root.add_child(session)
	await settle(4)
	# Synthetic delivery: stop the outgoing input/handshake loop, exactly like the
	# owned protocol fixture does.
	session.set_process(false)
	var menu: Control = session.setup_menu
	if menu == null:
		record("setup-open-%d" % size.x, {"missing":true, "phase":session.phase})
		root.remove_child(session)
		session.free()
		await settle()
		return
	var viewport := root.get_visible_rect().size
	var panel: Rect2 = menu.get_global_rect()
	var fits: bool = panel.position.x >= 0.0 and panel.position.y >= 0.0 and panel.end.x <= viewport.x and panel.end.y <= viewport.y
	await capture("setup-%dx%d-open.png" % [size.x, size.y])
	record("setup-open-%d" % size.x, {
		"viewport":[size.x, size.y], "panel":rect_json(panel), "fits_viewport":fits,
		"popup_windows":popup_count(menu), "popups_session_wide":popup_count(session),
		"phase":session.phase, "dismissible":menu.has_method("dismiss")})
	if menu.has_method("dismiss"):
		# Dismiss with Escape, then reopen with Enter, both through real input.
		await press(KEY_ESCAPE)
		record("setup-dismissed-%d" % size.x, {
			"dismissed":menu.get("dismissed") == true, "panel":rect_json(menu.get_global_rect()),
			"body_visible":bool(menu.body.visible), "hint_visible":bool(menu.hint.visible)})
		await capture("setup-%dx%d-dismissed.png" % [size.x, size.y])
		await press(KEY_ENTER)
		record("setup-reopened-%d" % size.x, {
			"dismissed":menu.get("dismissed") == true, "panel":rect_json(menu.get_global_rect()),
			"body_visible":bool(menu.body.visible), "hint_visible":bool(menu.hint.visible)})
		# Dismiss again and reopen by clicking the hint strip itself.
		await press(KEY_ESCAPE)
		await click_at(menu.hint.get_global_rect().get_center())
		record("setup-click-reopened-%d" % size.x, {
			"dismissed":menu.get("dismissed") == true, "panel":rect_json(menu.get_global_rect()),
			"body_visible":bool(menu.body.visible), "hint_visible":bool(menu.hint.visible)})
	# Start the match from the setup surface itself, then deliver a stored live
	# snapshot so the rendered view is actual combat with the surface gone.
	session.start_selected_match("meridian-exchange", "deathmatch")
	await settle(2)
	session.client.actor_id = 0
	session.client.started.emit({"mapId":"meridian-exchange"})
	session.client.snapshot.emit(combat_snapshot())
	await settle(4)
	var hud: CanvasLayer = session.get_node("GameHUD")
	var hud_rect: Rect2 = hud.vitals.get_global_rect()
	record("setup-after-start-%d" % size.x, {
		"menu_visible":bool(menu.visible), "menu_dismissed":menu.get("dismissed") == true,
		"popups_in_surface":popup_count(menu), "phase":session.phase,
		"hud_visible":bool(hud.root.visible), "vitals_visible":bool(hud.vitals.visible),
		"vitals":rect_json(hud_rect),
		"status_panel":rect_json(hud.status_panel.get_global_rect()),
		"surface_over_vitals":menu.get_global_rect().intersects(hud_rect) if menu.visible else false})
	await capture("combat-%dx%d-unobstructed.png" % [size.x, size.y])
	root.remove_child(session)
	session.free()
	await settle()

# ---------------------------------------------------------------------------
# Horde board: real horde/demo.tscn + synthetic authoritative state.
# ---------------------------------------------------------------------------

func horde_state() -> Dictionary:
	var actors: Array = [{"id":0,"name":"Operator","x":0.0,"y":0.0,"z":0.0,"yaw":0.0,"pitch":0.0,
		"health":100,"dead":0,"frags":3,"deaths":0,"weapon":0,"ammo":["∞"]}]
	var kinds := ["husk", "husk", "spitter", "husk", "brute", "husk", "spitter", "husk", "brute", "husk", "spitter", "husk"]
	for i: int in range(kinds.size()):
		actors.append({"id":i + 1,"name":"Husk","x":float(i),"y":0.0,"z":0.0,"yaw":0.0,"pitch":0.0,
			"health":0 if i % 3 == 2 else 60,"dead":999 if i % 3 == 2 else 0,"frags":0,"deaths":1,
			"weapon":0,"ammo":["∞"],"isNpc":true,"npcType":kinds[i]})
	return {"mapId":"meridian-exchange","mapName":"Meridian Exchange","modeName":"Horde","time":83.9,
		"config":{"mode":"horde","botCount":0,"fragLimit":1,"timeLimit":60},"actors":actors,
		"pickups":[{"id":1,"kind":"health","x":1.6,"y":0.0,"z":-2.0,"wait":0.0},
			{"id":2,"kind":"armor","x":-1.6,"y":0.0,"z":-2.0,"wait":0.0},
			{"id":3,"kind":"rocket","x":0.0,"y":0.0,"z":-4.0,"wait":0.0}],
		"singleplayer":{"kind":"horde","phase":"won","winner":0,"wave":1,"waveTarget":1,"lives":3,"score":94,"enemiesAlive":0,"enemiesTotal":3},
		"over":true}

func world_labels(product: Node) -> Array:
	# Every world-space Label3D in the rendered composition, with its authored scale.
	var labels: Array = []
	for node: Node in product.find_children("*", "Label3D", true, false):
		var label: Label3D = node
		labels.append({"path":str(product.get_path_to(node)), "text":str(label.text),
			"font_size":label.font_size, "pixel_size":label.pixel_size,
			"visible":label.is_visible_in_tree(), "pickup":str(product.get_path_to(node)).contains("Pickup_")})
	return labels

func horde_case(size: Vector2i) -> void:
	var product := HordeScene.instantiate()
	root.add_child(product)
	await settle(4)
	# Synthetic delivery: the share of the loop that would send input frames is
	# stopped, the shared overlays keep processing and rendering.
	product.set_process(false)
	product.client.actor_id = 0
	product.client.started.emit({})
	product.client.snapshot.emit({"state":horde_state()})
	await settle(4)
	var hud: CanvasLayer = product.get_node("GameHUD")
	var board: Node = product.get_node("Scoreboard")
	# Live Tab board: the vitals and weapon panels are visible in this state.
	board.tab_held = true
	board.refresh_visibility()
	await settle(4)
	var panel: Rect2 = board.panel.get_global_rect()
	var vitals: Rect2 = hud.vitals.get_global_rect()
	var weapon: Rect2 = hud.weapon_panel.get_global_rect()
	record("horde-live-%d" % size.x, {
		"viewport":[size.x, size.y], "panel":rect_json(panel), "panel_visible":bool(board.panel.visible),
		"vitals":rect_json(vitals), "weapon":rect_json(weapon),
		"overlap_vitals":panel.intersects(vitals), "overlap_weapon":panel.intersects(weapon),
		"vitals_visible":bool(hud.vitals.visible), "page_size":board.page_size,
		"rows":board.entries.size(), "summary":board.summary.text, "footer":board.footer.text})
	await capture("horde-%dx%d-live-tab.png" % [size.x, size.y])
	# Results board: same card, results state.
	board.tab_held = false
	product.client.results.emit({"state":horde_state()})
	await settle(4)
	panel = board.panel.get_global_rect()
	var captions := 0
	var caption_detail: Array = []
	for node: Node in product.pickups.find_children("*", "Label3D", true, false):
		captions += 1
		caption_detail.append({"name":str(node.name), "text":str(node.text), "font_size":node.font_size, "pixel_size":node.pixel_size})
	record("horde-results-%d" % size.x, {
		"viewport":[size.x, size.y], "panel":rect_json(panel), "panel_visible":bool(board.panel.visible),
		"vitals":rect_json(vitals), "weapon":rect_json(weapon),
		"overlap_vitals":panel.intersects(vitals), "overlap_weapon":panel.intersects(weapon),
		"page_size":board.page_size, "rows":board.entries.size(), "finished":bool(board.finished),
		"summary":board.summary.text, "footer":board.footer.text,
		"pickup_markers":product.pickups.markers.size(), "pickup_captions":captions,
		"pickup_caption_detail":caption_detail, "world_labels":world_labels(product)})
	await capture("horde-%dx%d-results.png" % [size.x, size.y])
	root.remove_child(product)
	product.free()
	await settle()
