extends SceneTree
## Player-flow clarity: the pinned Career reader shows the important text and it
## stays inside the viewport at 760x520 @150%, 960x640 @100% and 1280x800 @100%.
##
## Unlike a viewport-root/Back-only check, this asserts the actual rendered text:
## the accepted result/XP in the pinned header on RESULTS, the pending status in
## the summary, the honest unknown/stock LOADOUT line, and the visible bounds of
## the controls that carry them. No credential is read, written or serialized.
const Client = preload("res://net/client.gd")
const CareerActions = preload("res://career/actions_model.gd")
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
		push_error("player flow clarity ui: " + label)

func rows_text(service: Node) -> String:
	var rows := service.details.find_child("CatalogRows", true, false) as VBoxContainer
	var text := ""
	if rows == null: return text
	for child: Node in rows.get_children():
		if child is Label: text += (child as Label).text + "\n"
		for node: Node in child.get_children():
			if node is Label: text += (node as Label).text + "\n"
	return text

func rect_inside(control: Control, viewport: Vector2) -> bool:
	if control == null: return false
	var r := control.get_global_rect()
	return r.position.x >= -1 and r.position.y >= -1 and r.end.x <= viewport.x + 1 and r.end.y <= viewport.y + 1

func starts_inside(control: Control, viewport: Vector2) -> bool:
	if control == null: return false
	var r := control.get_global_rect()
	return r.position.x >= -1 and r.position.y >= -1 and r.position.y <= viewport.y + 1 and r.position.x <= viewport.x + 1

func geometry(service: Node, width: int, height: int, scale: float, label: String) -> void:
	root.size = Vector2i(width, height)
	root.content_scale_factor = scale
	service.refresh()
	# A container relayout is deferred: without settling, every rect reads the
	# previous frame's layout and the bounds checks pass vacuously. This is the
	# point where the previous lane's Back-only check was weakest.
	await process_frame
	await process_frame
	var viewport := root.get_visible_rect().size
	check(viewport.x > 0 and viewport.y > 0, label + ": viewport measurable")
	var back := service.panel.find_child("CareerBack", true, false) as Button
	check(rect_inside(back, viewport), label + ": Back is reachable without scrolling")
	check(rect_inside(service.state_label, viewport), label + ": the pinned reader header is fully inside the viewport")
	var rows := service.details.find_child("CatalogRows", true, false) as Control
	check(rows != null and rows.get_global_rect().end.x <= viewport.x + 1, label + ": the reader never clips horizontally")
	check(rect_inside(service.summary_label, viewport) or starts_inside(service.summary_label, viewport), label + ": the summary wraps inside the viewport")

func find_attachment(service: Node) -> Dictionary:
	for candidate: Dictionary in service.catalog.get("items", []):
		if candidate.kind != "attachment": continue
		if not CareerActions.available(service.profile, candidate): continue
		if service.profile.get("attachments", {}).get(candidate.slot) == candidate.id: continue
		return candidate
	return {}

func run() -> void:
	var service := root.get_node("Career")
	var client := Probe.new()
	root.add_child(client)
	client.room_id = "room-a"
	client.career_seated = true
	client.actor_id = 0
	var raw := {"id":"player-one","level":4,"xp":10,"unlocks":{},"gear":{},"attachments":{},"finish":null}

	# --- RESULTS: the pinned header carries the important result/XP -----------
	service.receive(client, {"type":"welcome","profile":raw})
	service.receive(client, {"type":"start","roundRevision":1,"mapId":"meridian-exchange"})
	service.receive(client, {"type":"progression","profile":raw.duplicate(true),"gained":40,"baseGained":40,"actor":{"id":0}})
	service.receive(client, {"type":"results","state":{"mapId":"meridian-exchange","config":{"mode":"deathmatch"},"overReason":"time","time":60,"actors":[{"id":0,"frags":3,"deaths":1}]}})
	service.open_panel()
	var results_tab := service.panel.find_child("Tab_results", true, false) as Button
	results_tab.pressed.emit()
	check(service.category == "results", "RESULTS category active")
	check(service.state_label.text.contains("CONNECTED SOURCE CAREER"), "RESULTS keeps the source identity line")
	check(service.state_label.text.contains("ROUND COMPLETE") and service.state_label.text.contains("+40 XP"), "the pinned header shows the accepted result and award XP")
	var text := rows_text(service)
	check(text.contains("Round complete"), "RESULTS renders the accepted result headline")
	check(text.contains("Source award · +40 XP"), "RESULTS renders the attributed same-round award")
	check(not text.contains("+0 XP"), "RESULTS never invents a zero award")

	# The compact first screen keeps the important result text visible.
	root.size = Vector2i(760, 520)
	root.content_scale_factor = 1.5
	service.refresh()
	await process_frame
	await process_frame
	var compact := root.get_visible_rect().size
	check(service.state_label.text.contains("+40 XP"), "the award XP survives the compact header")
	check(rect_inside(service.state_label, compact), "the result/award header is inside the compact viewport")
	var first_row := service.details.find_child("CatalogRows", true, false).get_child(0) as Control
	check(starts_inside(first_row, compact), "the first result row starts inside the compact viewport")
	await geometry(service, 760, 520, 1.5, "760x520 @150%")
	await geometry(service, 960, 640, 1.0, "960x640 @100%")
	await geometry(service, 1280, 800, 1.0, "1280x800 @100%")

	# --- Reconnect replay: an award is unknown, never a zero ------------------
	service.receive(client, {"type":"welcome","profile":raw})
	service.receive(client, {"type":"results","state":{"mapId":"meridian-exchange","config":{"mode":"deathmatch"},"overReason":"time","time":60,"actors":[{"id":0,"frags":3,"deaths":1}]}})
	service.refresh()
	check(service.state_label.text.contains("award unknown"), "a replayed result header states the award is unknown")
	text = rows_text(service)
	check(text.contains("Source award · unknown"), "a replayed result renders an unknown award")
	check(not text.contains("+0 XP"), "a replayed result never fabricates +0 XP")

	# --- HISTORY: the header and list are labelled server-wide ----------------
	service.select_category("history")
	check(service.history_status == "loading", "HISTORY requests the source on first visit")
	check(service.state_label.text.contains("Recent server matches"), "the HISTORY header is labelled server-wide")
	service.receive(client, {"type":"history","matches":[{"mapId":"crosswire","mode":"deathmatch","endedBy":"time","duration":60,"players":[{"name":"A","frags":3}]}]})
	text = rows_text(service)
	check(text.contains("Recent server matches"), "the HISTORY list is labelled server-wide, not personal")
	check(service.state_label.text.contains("1 of up to 50"), "the HISTORY header reports the bounded source list")

	# --- LOADOUT pending/confirmed: only confirmation is applied --------------
	service.select_category("loadout")
	check(service.summary_label.text.contains("Stock / unselected"), "a known stock saved loadout is stated, not invented")
	check(rows_text(service).contains("Stock gear and mods · no slot equipped for the next match."), "the LOADOUT tab states known stock honestly")
	var item := find_attachment(service)
	check(not item.is_empty(), "the shipped catalog offers a usable starter attachment")
	if not item.is_empty():
		service.last_send_ms = -1000
		service.select_item(item)
		check(not service.pending.is_empty(), "selection is pending")
		check(service.summary_label.text.contains("awaiting source confirmation"), "pending is stated as awaiting, never applied")
		check(not service.summary_label.text.contains(str(item.name)), "a pending write never appears in the saved summary")
		check(rows_text(service).contains("Pending source confirmation"), "the LOADOUT tab states the pending selection")
		var acked := raw.duplicate(true)
		acked.attachments = {str(item.slot): str(item.id)}
		service.receive(client, {"type":"progression","profile":acked,"gear":acked.gear,"attachments":acked.attachments})
		check(service.pending.is_empty(), "the source ACK settles the selection")
		check(service.summary_label.text.contains(str(item.name)), "only the confirmed item appears in the saved summary")

	# --- Unknown (unreported field): never a stock claim ----------------------
	service.receive(client, {"type":"welcome","profile":{"id":"player-two","level":4}})
	service.select_category("loadout")
	check(rows_text(service).contains("Saved loadout unknown · the source did not report every equipped slot."), "an unreported field is shown as unknown")
	check(not rows_text(service).contains("No slot equipped · saved for the next match."), "the false empty-loadout claim is gone")

	service.close_panel()
	check(not service.active(), "panel closes cleanly")
	client.queue_free()
	print("PLAYER_FLOW_CLARITY_UI_OK")
	quit(1 if failed else 0)
