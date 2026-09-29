extends SceneTree
# Live helper for the native Career saved-loadout journey.
#
# It owns one real world session on an owned source authority, hosts a legal
# short match (the session's own lobby path pins `timeLimit:60`), then drives the
# shipped Career panel: it equips a level-one starter attachment through the
# displayed MODS tab, waits for the source-marked GEAR reply (never optimistic),
# reads the LOADOUT summary, proves the *current* actor's resolved attachments
# are unchanged, lets the round resolve, and restarts. After the authoritative
# round start the new actor must carry the saved attachment.
#
# The shipment stays read-only: input events, panel category/buttons, window size
# and interface scale are the only levers. Samples print as CAREER_NEWLOADOUT_SAMPLE.
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
var equipped := false
var confirmed := false
var restarted := false
var equip_slot := ""
var equip_id := ""
var first_actor_ids: Array = []
var second_actor_ids: Array = []
var actor_finish: Variant = null
var summary_line := ""
var pending := []
const KEYS := {"Escape":KEY_ESCAPE,"Enter":KEY_ENTER,"Tab":KEY_TAB,"W":KEY_W,"A":KEY_A,"S":KEY_S,"D":KEY_D}
const CareerActions = preload("res://career/actions_model.gd")

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

func key(code: int, pressed: bool, unicode_value := 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode_value
	event.pressed = pressed
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
		"text":
			for character: String in str(c.get("text", "")): pending.append(character.unicode_at(0))
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

func live_actor_ids() -> Array:
	# The source snapshot serializes each actor's *resolved* attachments; the
	# reader never reverse-maps those back into item names.
	if session == null or session.client == null: return []
	var actor_id: int = int(session.client.actor_id)
	if actor_id < 0 or session.client.snapshots.is_empty(): return []
	var snapshot: Dictionary = session.client.snapshots.back()
	var state: Variant = snapshot.get("state")
	if not state is Dictionary: return []
	var actors: Array = (state as Dictionary).get("actors", [])
	for entry: Variant in actors:
		if not entry is Dictionary: continue
		var actor: Dictionary = entry
		if int(actor.get("id", -1)) != actor_id: continue
		var attachments: Variant = actor.get("attachments")
		if not attachments is Dictionary: return []
		var ids: Array = []
		for item: Variant in (attachments as Dictionary).get("items", []):
			if item is Dictionary: ids.append(str((item as Dictionary).get("id", "")))
		return ids
	return []

func live_actor_finish() -> Variant:
	if session == null or session.client == null: return null
	var actor_id: int = int(session.client.actor_id)
	if actor_id < 0 or session.client.snapshots.is_empty(): return null
	var snapshot: Dictionary = session.client.snapshots.back()
	var state: Variant = snapshot.get("state")
	if not state is Dictionary: return null
	var actors: Array = (state as Dictionary).get("actors", [])
	for entry: Variant in actors:
		if not entry is Dictionary: continue
		var actor: Dictionary = entry
		if int(actor.get("id", -1)) == actor_id: return actor.get("finish")
	return null

func choose_starter() -> Dictionary:
	for candidate: Dictionary in career.catalog.items:
		if candidate.kind != "attachment" or int(candidate.level) != 1: continue
		if not CareerActions.available(career.profile, candidate): continue
		if career.profile.get("attachments", {}).get(candidate.slot) == candidate.id: continue
		return candidate
	return {}

func drive_equip() -> bool:
	var item := choose_starter()
	if item.is_empty(): return false
	equip_slot = str(item.slot)
	equip_id = str(item.id)
	# `select_category` rebuilds the rows synchronously, so the action button
	# exists without waiting a frame.
	career.select_category("attachment")
	var button := named("Equip_" + str(item.unlockId)) as Button
	if button == null or button.disabled: return false
	button.pressed.emit()
	equipped = true
	return true

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 240.0: quit(9)
	if not is_instance_valid(session) or not is_instance_valid(session.client): return false
	if not pending.is_empty():
		var character: int = pending.pop_front()
		key(0, true, character)
		key(0, false, character)
	if not connected and session.phase == -3 and not endpoint.is_empty():
		connected = true
		session.lobby_connect(endpoint, "Loadout host", "", map_id, mode, false)
	elif not started and connected and session.phase == 12 and session.lobby_host_allowed():
		started = true
		session.lobby_start()
	# 1. Open the shipped panel in the live round and read the saved overview.
	if started and session.phase == 3 and not opened and career != null:
		opened = true
		career.open_panel()
		career.select_category("loadout")
		summary_line = career.summary_label.text
	if opened and not equipped and session.phase == 3:
		first_actor_ids = live_actor_ids()
		drive_equip()
	# 2. Only a source ACK confirms; then the saved overview names the item.
	if equipped and not confirmed and career.pending.is_empty() and career.profile.get("attachments", {}).get(equip_slot) == equip_id:
		confirmed = true
		summary_line = career.summary_label.text
		career.select_category("loadout")
	# 3. The current actor keeps its round-start loadout; capture before restart.
	if confirmed and first_actor_ids.is_empty():
		first_actor_ids = live_actor_ids()
		actor_finish = live_actor_finish()
	# 4. Restart after the authoritative result, then read the next actor's loadout.
	if confirmed and not restarted and session.phase == 4 and session.lobby_host_allowed():
		restarted = true
		session.request_restart()
	if restarted and session.phase == 3 and session.round_starts >= 2 and second_actor_ids.is_empty():
		second_actor_ids = live_actor_ids()
	sampled += delta
	if sampled < 0.2: return false
	sampled = 0
	if FileAccess.file_exists(inbox):
		var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(inbox))
		if c is Dictionary and int(c.get("id", -1)) > last_command:
			last_command = int(c.id)
			command(c)
	var rows := rows_control()
	print("CAREER_NEWLOADOUT_SAMPLE ", JSON.stringify({
		"seconds": elapsed, "command": last_command, "phase": session.phase,
		"room": session.client.room_id, "actor": session.client.actor_id, "spectating": session.client.spectating,
		"round_starts": session.round_starts, "results": session.round_results,
		"opened": opened, "equipped": equipped, "confirmed": confirmed, "restarted": restarted,
		"category": career.category if career != null else "",
		"equip": {"slot": equip_slot, "id": equip_id},
		"summary": summary_line,
		"saved": career.equipment_summary() if career != null else {},
		"pending": career.pending.is_empty() == false if career != null else false,
		"action_status": career.action_status if career != null else "",
		"actor_ids_before": first_actor_ids, "actor_ids_after": second_actor_ids, "actor_finish": actor_finish,
		"state_text": career.state_label.text if career != null else "",
		"back": rect(named("CareerBack")), "tab_loadout": rect(named("Tab_loadout")),
		"rows_bounds": rect(rows),
		"viewport": [root.get_visible_rect().size.x, root.get_visible_rect().size.y],
		"error": session.label.text if session.phase == -1 else "" }))
	return false
