extends SceneTree
## Saved-loadout panel UI: the LOADOUT tab, the one-line summary above the item
## list, the preserved default GEAR rows and the compact 760x520 @150% geometry.
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
		push_error("career loadout ui: " + label)

func rows_text(service: Node) -> String:
	var rows := service.details.find_child("CatalogRows", true, false) as VBoxContainer
	var text := ""
	if rows == null: return text
	for child: Node in rows.get_children():
		if child is Label: text += (child as Label).text + "\n"
		for node: Node in child.get_children():
			if node is Label: text += (node as Label).text + "\n"
			elif node is Button: text += "[" + (node as Button).text + "]\n"
	return text

func first_row_label(service: Node) -> String:
	var rows := service.details.find_child("CatalogRows", true, false) as VBoxContainer
	if rows == null or rows.get_child_count() == 0: return ""
	var child := rows.get_child(0)
	if child is Label: return (child as Label).text
	for node: Node in child.get_children():
		if node is Label: return (node as Label).text
	return ""

func run() -> void:
	var service := root.get_node("Career")
	var client := Probe.new()
	root.add_child(client)
	client.room_id = "room-a"
	client.career_seated = true
	# Home: no profile, the existing default GEAR rows and marker must survive.
	service.open_panel()
	check(service.active(), "panel opens")
	check(service.category == "gear", "GEAR stays the default category for the Home journey")
	check(service.state_label.text.contains("NO CONNECTED CAREER"), "Home keeps the no-career marker")
	check(service.summary_label.text == "Connect to load source loadout.", "preconnect summary is the explicit connect prompt")
	check(first_row_label(service).contains("NOT LOADED"), "default GEAR rows still render NOT LOADED on Home")
	var loadout_tab := service.panel.find_child("Tab_loadout", true, false) as Button
	check(loadout_tab != null, "LOADOUT tab is present")
	var back := service.panel.find_child("CareerBack", true, false) as Button
	check(back != null and back.custom_minimum_size.y >= 44, "CareerBack keeps its control name and size")
	# Seat a confirmed profile and read the saved overview.
	var raw := {"id":"player-one","level":4,"xp":10,"unlocks":{"attachment-red-dot":true},"gear":{"primary":"scope"},"attachments":{},"finish":null}
	service.receive(client, {"type":"welcome","profile":raw})
	check(service.state_label.text.contains("CONNECTED SOURCE CAREER"), "connected header keeps its marker")
	check(service.summary_label.text.contains("Saved for next match"), "summary labels the saved loadout")
	check(service.summary_label.text.contains("Precision Scope"), "summary names a confirmed item")
	loadout_tab.pressed.emit()
	check(service.category == "loadout", "LOADOUT category active")
	var text := rows_text(service)
	check(text.contains("SAVED LOADOUT"), "LOADOUT tab renders the saved overview")
	check(text.contains("Precision Scope") and text.contains("Stock"), "LOADOUT names equipped slots and marks stock")
	var gear_tab := service.panel.find_child("Tab_gear", true, false) as Button
	gear_tab.pressed.emit()
	check(first_row_label(service).contains("Precision Scope") or first_row_label(service).contains("UNLOCKED"), "GEAR rows render normally")
	# Pending selection is never optimistic.
	service.last_send_ms = -1000
	service.select_item({"kind":"attachment","id":"red-dot","slot":"optic","level":1,"unlockId":"attachment-red-dot"})
	check(not service.pending.is_empty(), "selection is pending")
	check(not service.summary_label.text.contains("Red Dot"), "pending write never appears in the summary")
	# Only a source ACK updates the saved overview.
	var acked := raw.duplicate(true)
	acked.attachments = {"optic":"red-dot"}
	service.receive(client, {"type":"progression","profile":acked,"gear":acked.gear,"attachments":acked.attachments})
	check(service.pending.is_empty(), "source ACK settles the selection")
	check(service.summary_label.text.contains("Red Dot"), "ACKed selection appears in the summary")
	loadout_tab.pressed.emit()
	check(rows_text(service).contains("Red Dot"), "ACKed selection appears on the LOADOUT tab")
	# Compact geometry: 760x520 @150% keeps Back and the summary inside the view.
	root.size = Vector2i(760, 520)
	root.content_scale_factor = 1.5
	service.refresh()
	var viewport := root.get_visible_rect().size
	var back_rect := back.get_global_rect()
	check(viewport.x > 0 and viewport.y > 0, "compact viewport measurable")
	check(back_rect.position.x >= -1 and back_rect.position.y >= -1 and back_rect.end.x <= viewport.x + 1 and back_rect.end.y <= viewport.y + 1, "Back reachable without scrolling at 760x520 @150%")
	var summary_rect: Rect2 = service.summary_label.get_global_rect()
	check(summary_rect.position.x >= -1 and summary_rect.end.x <= viewport.x + 1, "summary wraps inside the compact width")
	service.close_panel()
	check(not service.active(), "panel closes cleanly")
	client.queue_free()
	print("CAREER_NEWLOADOUT_UI_OK")
	quit(1 if failed else 0)
