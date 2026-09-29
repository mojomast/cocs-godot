extends SceneTree
# Live helper for the native Career player-flow clarity journey.
#
# One owned source authority and one real `world/session.tscn`. The observer opens
# the shipped Career LOADOUT tab and drives the reader through the states a player
# actually meets, capturing each at 760x520 @150% for readability:
#   pending   the selection was sent but not yet answered -> "awaiting source
#             confirmation", never an optimistic item;
#   unknown   the source did not reply within its window -> the honest timeout
#             ("outcome unknown"), still no item and the write held;
#   confirmed the source-marked GEAR reply names the item and only then does the
#             saved summary show it;
#   results   the accepted round and its same-round award XP in the pinned header.
#
# It freezes only `session.client.set_process(false)` (the shipped client's own
# `_process`, where `peer.poll()` runs) so a pending write cannot leave the client
# before the capture; it is re-enabled to let the real source settle. The shipped
# gameplay, lobby, net and Career handlers stay read-only. Samples print as
# CAREER_CLARITY_SAMPLE lines.
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
var frozen := false
var pressed := false
var equip_slot := ""
var equip_id := ""
var equip_name := ""
var pending_captured := false
var unknown_captured := false
var confirmed := false
var confirmed_captured := false
var results_captured := false
var results_seen := 0
var pending: Array = []
const KEYS := {"Escape":KEY_ESCAPE,"Enter":KEY_ENTER,"Tab":KEY_TAB,"W":KEY_W,"A":KEY_A,"S":KEY_S,"D":KEY_D}
const Actions = preload("res://career/actions_model.gd")

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
	if session != null and session.client != null:
		session.client.results.connect(func(_frame: Dictionary) -> void: results_seen += 1)

func key(code: int, pressed_state: bool, unicode_value := 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode_value
	event.pressed = pressed_state
	Input.parse_input_event(event)

func named(control_name: String) -> Control:
	if career == null or career.panel == null: return null
	return career.panel.find_child(control_name, true, false) as Control

func command(c: Dictionary) -> void:
	match str(c.get("op", "")):
		"focus": root.grab_focus()
		"resize": root.size = Vector2i(int(c.get("width", 760)), int(c.get("height", 520)))
		"scale": root.content_scale_factor = float(c.get("value", 1.0))
		"key": key(KEYS.get(str(c.get("key", "")), KEY_ESCAPE), bool(c.get("pressed", true)))
		"focus_named":
			var control := named(str(c.get("name", "")))
			if control != null: control.grab_focus()
		"press_named":
			var button := named(str(c.get("name", ""))) as Button
			if button != null and not button.disabled: button.pressed.emit()
		"select":
			if career != null: career.select_category(str(c.get("category", "loadout")))
		"capture": capture.call_deferred(str(c.get("name", "capture")))

func capture(name: String) -> void:
	if out.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")

func rect(control: Control) -> Array:
	if control == null: return []
	var r := control.get_global_rect()
	return [r.position.x, r.position.y, r.size.x, r.size.y]

func rows_control() -> Control:
	if career == null or career.details == null: return null
	return career.details.find_child("CatalogRows", true, false) as Control

func row_texts() -> Array:
	var texts: Array = []
	var rows := rows_control()
	if rows == null: return texts
	for child: Node in rows.get_children():
		if child is Label: texts.append((child as Label).text)
		for node: Node in child.get_children():
			if node is Label: texts.append((node as Label).text)
			elif node is Button: texts.append("[" + (node as Button).text + "]")
	return texts

func choose_starter() -> Dictionary:
	for candidate: Dictionary in career.catalog.items:
		if candidate.kind != "attachment" or int(candidate.level) != 1: continue
		if not Actions.available(career.profile, candidate): continue
		if career.profile.get("attachments", {}).get(candidate.slot) == candidate.id: continue
		return candidate
	return {}

func compact() -> void:
	root.content_scale_factor = 1.5
	root.size = Vector2i(760, 520)

func drive_equip() -> bool:
	var item := choose_starter()
	if item.is_empty(): return false
	equip_slot = str(item.slot)
	equip_id = str(item.id)
	equip_name = str(item.name)
	career.select_category("attachment")
	var button := named("Equip_" + str(item.unlockId)) as Button
	if button == null or button.disabled: return false
	# Hold the wire before the write can leave the client so the pending state is
	# observable; only this shipped node's own _process is paused.
	session.client.set_process(false)
	frozen = true
	button.pressed.emit()
	# Return to LOADOUT so the capture shows the pending saved-loadout reader.
	career.select_category("loadout")
	pressed = true
	return true

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 240.0: quit(9)
	if not is_instance_valid(session) or not is_instance_valid(session.client): return false
	if not pending.is_empty():
		var character: int = pending.pop_front()
		key(0, true, character)
		key(0, false, character)
	# 1. host one real match once the lobby is ready
	if not connected and session.phase == -3 and not endpoint.is_empty():
		connected = true
		session.lobby_connect(endpoint, "Clarity host", "", map_id, mode, false)
	elif not started and connected and session.phase == 12 and session.lobby_host_allowed():
		started = true
		session.lobby_start()
	# 2. a little play so the source has live actors until it resolves
	if started and not frozen and session.phase == 3 and session.client.actor_id >= 0 and fmod(elapsed, 0.5) < delta:
		session.client.send_input({"forward": true, "fire": fmod(elapsed, 2.0) < 1.0})
	# 3. open the shipped LOADOUT reader and walk the states.
	if started and session.phase == 3 and not opened and career != null:
		opened = true
		career.open_panel()
		career.select_category("loadout")
	if opened and not pressed and not confirmed:
		drive_equip()
	# pending: frozen immediately after the write, before any reply.
	if frozen and pressed and not pending_captured:
		pending_captured = true
		compact()
		career.refresh()
		capture.call_deferred("clarity-pending-compact")
	# unknown: the reader's own no-reply window elapses while the wire is held.
	if frozen and pressed and not unknown_captured and not career.pending.is_empty() and Time.get_ticks_msec() - int(career.pending.get("sent_at", 0)) > Actions.TIMEOUT_MS:
		unknown_captured = true
		career._process(0.0)
		compact()
		career.refresh()
		capture.call_deferred("clarity-unknown-compact")
		# Release the held write so the real source can settle it.
		session.client.set_process(true)
		frozen = false
	# confirmed: the source-marked GEAR reply names the item.
	if pressed and not confirmed and not frozen and career.pending.is_empty() and career.profile.get("attachments", {}).get(equip_slot) == equip_id:
		confirmed = true
		confirmed_captured = true
		compact()
		career.refresh()
		capture.call_deferred("clarity-confirmed-compact")
	# results: the real round resolves; the accepted result and award are shown.
	if confirmed and not results_captured and results_seen >= 1 and session.phase == 4:
		results_captured = true
		career.select_category("results")
		compact()
		career.refresh()
		capture.call_deferred("clarity-results-compact")
	sampled += delta
	if sampled < 0.2: return false
	sampled = 0
	if FileAccess.file_exists(inbox):
		var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(inbox))
		if c is Dictionary and int(c.get("id", -1)) > last_command:
			last_command = int(c.id)
			command(c)
	var attributed: Dictionary = career.attributed_award() if career != null else {}
	print("CAREER_CLARITY_SAMPLE ", JSON.stringify({
		"seconds": elapsed, "command": last_command, "phase": session.phase,
		"room": session.client.room_id, "actor": session.client.actor_id, "spectating": session.client.spectating,
		"opened": opened, "frozen": frozen, "pressed": pressed, "results_seen": results_seen,
		"pending_captured": pending_captured, "unknown_captured": unknown_captured,
		"confirmed": confirmed, "results_captured": results_captured,
		"category": career.category if career != null else "",
		"equip": {"slot": equip_slot, "id": equip_id, "name": equip_name},
		"pending": not career.pending.is_empty() if career != null else false,
		"timed_out": bool(career.pending.get("timed_out", false)) if career != null else false,
		"action_status": career.action_status if career != null else "",
		"summary": career.summary_label.text if career != null else "",
		"state_text": career.state_label.text if career != null else "",
		"attributed": attributed,
		"result": career.result if career != null else {},
		"back": rect(named("CareerBack")),
		"tab_loadout": rect(named("Tab_loadout")), "tab_results": rect(named("Tab_results")),
		"summary_rect": rect(career.summary_label) if career != null else [],
		"rows": row_texts(), "rows_bounds": rect(rows_control()),
		"viewport": [root.get_visible_rect().size.x, root.get_visible_rect().size.y],
		"error": session.label.text if session.phase == -1 else "" }))
	return false
