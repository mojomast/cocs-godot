extends SceneTree
## UI wiring for the RESULTS/HISTORY tabs: the existing catalog actions stay
## unchanged, the new reader renders accepted result/award facts and the
## server-wide history list, and Back stays reachable at the compact size.
const Client = preload("res://net/client.gd")
var failed := false

class Probe extends Client:
	var sent: Array[Dictionary] = []
	func career_wire_open() -> bool: return true
	func send_frame(frame: Dictionary) -> Error:
		sent.append(frame)
		return OK

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("career results ui: " + label)

func rows_text(service: Node) -> String:
	var rows := service.details.find_child("CatalogRows", true, false) as VBoxContainer
	var text := ""
	if rows == null: return text
	for child: Node in rows.get_children():
		for node: Node in child.get_children():
			if node is Label: text += (node as Label).text + "\n"
		if child is Label: text += (child as Label).text + "\n"
	return text

func run() -> void:
	var service := root.get_node("Career")
	var client := Probe.new()
	root.add_child(client)
	client.room_id = "room-a"
	client.career_seated = true
	client.actor_id = 0
	var raw := {"id":"player-one","level":4,"xp":10,"unlocks":{},"gear":{},"attachments":{}}
	service.receive(client, {"type":"welcome","profile":raw})
	service.receive(client, {"type":"start","roundRevision":1,"mapId":"crosswire"})
	service.receive(client, {"type":"progression","profile":raw.duplicate(true),"gained":12,"baseGained":12,"mode":"deathmatch"})
	service.receive(client, {"type":"results","state":{"mapId":"crosswire","config":{"mode":"deathmatch"},"overReason":"time","time":60,"actors":[{"id":0,"frags":3,"deaths":1}]}})
	service.open_panel()
	check(service.active(), "panel opens")
	var back := service.panel.find_child("CareerBack", true, false) as Button
	check(back != null and back.focus_mode != Control.FOCUS_NONE and back.custom_minimum_size.y >= 44, "Back is a real focus target")
	var results_tab := service.panel.find_child("Tab_results", true, false) as Button
	var history_tab := service.panel.find_child("Tab_history", true, false) as Button
	check(results_tab != null and history_tab != null, "RESULTS and HISTORY tabs present")
	results_tab.pressed.emit()
	check(service.category == "results", "RESULTS category active")
	var text := rows_text(service)
	check(text.contains("Round complete"), "accepted result headline rendered")
	check(text.contains("+12 XP"), "attributed same-round award rendered")
	history_tab.pressed.emit()
	check(service.category == "history", "HISTORY category active")
	check(client.sent.size() == 1 and client.sent[0].get("type") == "history", "HISTORY requests the source once")
	service.receive(client, {"type":"history","matches":[{"mapId":"crosswire","mode":"deathmatch","endedBy":"time","duration":60,"players":[{"name":"A","frags":3}]}]})
	text = rows_text(service)
	check(text.contains("Recent server matches"), "history labelled as server-wide, not personal")
	check(text.contains("crosswire"), "source record rendered")
	var gear_tab := service.panel.find_child("Tab_gear", true, false) as Button
	gear_tab.pressed.emit()
	check(service.category == "gear", "GEAR category active again")
	var equip: Button = null
	var rows := service.details.find_child("CatalogRows", true, false) as VBoxContainer
	for row: Node in rows.get_children():
		for node: Node in row.get_children():
			if node is Button and (node as Button).name.begins_with("Equip_"):
				equip = node
				break
	check(equip != null, "existing catalog equip actions still render unchanged")
	# Compact reader: 760x520 at 150% keeps Back inside the viewport.
	root.size = Vector2i(760, 520)
	root.content_scale_factor = 1.5
	service.refresh()
	var viewport := root.get_visible_rect().size
	var back_rect := back.get_global_rect()
	check(viewport.x > 0 and viewport.y > 0, "compact viewport measurable")
	check(back_rect.position.x >= -1 and back_rect.position.y >= -1 and back_rect.end.x <= viewport.x + 1 and back_rect.end.y <= viewport.y + 1, "Back reachable without scrolling at 760x520 @150%")
	service.close_panel()
	check(not service.active(), "panel closes cleanly")
	client.queue_free()
	print("CAREER_RESULTS_UI_OK")
	quit(1 if failed else 0)
