extends SceneTree
# Live helper for the native Career RESULTS/HISTORY journey.
#
# It owns one real world session on an owned source authority, hosts a legal
# short match (the session's own lobby path pins `timeLimit:60`), plays until the
# source reports results, then opens the shipped Career panel and drives the
# RESULTS and HISTORY tabs. The shipped gameplay, lobby and Career handlers stay
# read-only; input events, window size and interface scale are the only levers.
# Samples are printed as CAREER_RESULTS_SAMPLE lines for the Node harness.
#
# The Career panel only receives `start`/`results`/`history` through the parent's
# planned `client.career_receive` routing; without that routing a sample reports
# `results_status`/`history_status` as not-ready rather than a false pass.
var session: Node
var career: Node
var inbox := ""
var out := ""
var elapsed := 0.0
var sampled := 0.0
var last_command := -1
var endpoint := ""
var map_id := "meridian-exchange"
var mode := "deathmatch"
var connected := false
var started := false
var opened := false
var results_seen := 0
var round_revision := -1
var pending: Array = []
const KEYS := {"Escape":KEY_ESCAPE,"Enter":KEY_ENTER,"Tab":KEY_TAB,"W":KEY_W,"A":KEY_A,"S":KEY_S,"D":KEY_D}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--career-inbox="): inbox = arg.trim_prefix("--career-inbox=")
		if arg.begins_with("--career-out="): out = arg.trim_prefix("--career-out=")
		if arg.begins_with("--career-endpoint="): endpoint = arg.trim_prefix("--career-endpoint=")
		if arg.begins_with("--career-map="): map_id = arg.trim_prefix("--career-map=")
		if arg.begins_with("--career-mode="): mode = arg.trim_prefix("--career-mode=")
	call_deferred("begin")

func begin() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	current_scene = session
	career = root.get_node_or_null("Career")
	session.client.results.connect(func(_frame: Dictionary) -> void: results_seen += 1)
	session.client.started.connect(func(frame: Dictionary) -> void: round_revision = int(frame.get("roundRevision", -1)))

func key(code: int, pressed: bool, unicode_value := 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode_value
	event.pressed = pressed
	Input.parse_input_event(event)

func named(control_name: String) -> Control:
	if career == null or control_name.is_empty(): return null
	if career.panel == null: return null
	return career.panel.find_child(control_name, true, false) as Control

func command(c: Dictionary) -> void:
	match str(c.get("op", "")):
		"focus": root.grab_focus()
		"resize": root.size = Vector2i(int(c.get("width", 760)), int(c.get("height", 520)))
		"scale": root.content_scale_factor = float(c.get("value", 1.0))
		"key": key(KEYS.get(str(c.get("key", "")), KEY_ESCAPE), bool(c.get("pressed", true)))
		"text":
			for character: String in str(c.get("text", "")): pending.append(character.unicode_at(0))
		"focus_named":
			var control := named(str(c.get("name", "")))
			if control != null: control.grab_focus()
		"press_named":
			var button := named(str(c.get("name", ""))) as Button
			if button != null and not button.disabled: button.pressed.emit()
		"select":
			if career != null:
				career.select_category(str(c.get("category", "results")))
				if str(c.get("category", "")) == "history": career.request_history(true)
		"capture": capture.call_deferred(str(c.get("name", "capture")))

func capture(name: String) -> void:
	if out.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")

func rect(control: Control) -> Array:
	if control == null: return []
	var r := control.get_global_rect()
	return [r.position.x, r.position.y, r.size.x, r.size.y]

func row_texts() -> Array:
	var texts: Array = []
	if career == null or career.details == null: return texts
	var rows := career.details.find_child("CatalogRows", true, false)
	if rows == null: return texts
	for child: Node in rows.get_children():
		if child is Label: texts.append((child as Label).text)
		for node: Node in child.get_children():
			if node is Label: texts.append((node as Label).text)
			elif node is Button: texts.append("[" + (node as Button).text + "]")
	return texts

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 180.0: quit(9)
	if not is_instance_valid(session) or not is_instance_valid(session.client): return false
	if not pending.is_empty():
		var character: int = pending.pop_front()
		key(0, true, character)
		key(0, false, character)
	# 1. host one real match once the lobby is ready
	if not connected and session.phase == -3 and not endpoint.is_empty():
		connected = true
		session.lobby_connect(endpoint, "Career host", "", map_id, mode, false)
	elif not started and connected and session.phase == 12 and session.lobby_host_allowed():
		started = true
		session.lobby_start()
	# 2. a little play so the source has live actors until it resolves
	if started and session.phase == 3 and session.client.actor_id >= 0 and fmod(elapsed, 0.5) < delta:
		session.client.send_input({"forward": true, "fire": fmod(elapsed, 2.0) < 1.0})
	# 3. open the Career reader after the first accepted result
	if not opened and results_seen >= 1 and career != null:
		opened = true
		career.open_panel()
		career.select_category("results")
		career.select_category("history")
	if FileAccess.file_exists(inbox):
		var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(inbox))
		if c is Dictionary and int(c.get("id", -1)) > last_command:
			last_command = int(c.id)
			command(c)
	sampled += delta
	if sampled < 0.2: return false
	sampled = 0
	var attributed: Dictionary = career.attributed_award() if career != null else {}
	print("CAREER_RESULTS_SAMPLE ", JSON.stringify({
		"seconds": elapsed, "command": last_command, "phase": session.phase,
		"room": session.client.room_id, "actor": session.client.actor_id, "spectating": session.client.spectating,
		"round_revision": round_revision, "results_seen": results_seen, "opened": opened,
		"category": career.category if career != null else "",
		"results_status": career.results_status if career != null else "",
		"result": career.result if career != null else {},
		"attributed": attributed,
		"latest": career.latest_award if career != null else {},
		"history_status": career.history_status if career != null else "",
		"history_count": career.history_records.size() if career != null else 0,
		"state_text": career.state_label.text if career != null else "",
		"rows": row_texts(),
		"back": rect(named("CareerBack")), "refresh": rect(named("HistoryRefresh")),
		"tab_results": rect(named("Tab_results")), "tab_history": rect(named("Tab_history")),
		"viewport": [root.get_visible_rect().size.x, root.get_visible_rect().size.y],
		"captured": Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"error": session.label.text if session.phase == -1 else "" }))
	return false
