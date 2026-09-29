extends SceneTree
## Player-flow clarity: the saved-loadout reader never blurs disconnected,
## unknown, known-stock and named states, and its one-line summary stays bounded.
##
## The service is the real Career autoload; the client is a seated probe whose
## `send_frame` succeeds without a socket. No credential is read, written or
## serialized. The model is pure, so the first half pins the six per-slot states
## directly and the second half pins what the shipped LOADOUT tab actually prints.
const EquippedModel = preload("res://career/equipped_model.gd")
const CareerProfile = preload("res://career/profile.gd")
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
		push_error("player flow clarity model: " + label)

func field_slot(summary: Dictionary, key: String, slot: String) -> Dictionary:
	return summary.get("fields", {}).get(key, {}).get(slot, {})

func rows_text(service: Node) -> String:
	var rows := service.details.find_child("CatalogRows", true, false) as VBoxContainer
	var text := ""
	if rows == null: return text
	for child: Node in rows.get_children():
		if child is Label: text += (child as Label).text + "\n"
		for node: Node in child.get_children():
			if node is Label: text += (node as Label).text + "\n"
	return text

func seats(service: Node, client: Node, profile: Dictionary) -> void:
	service.receive(client, {"type":"welcome", "profile":profile})

func catalog() -> Dictionary:
	return {"schema":1, "items":[
		{"id":"scope","unlockId":"gear-scope","kind":"gear","slot":"primary","name":"Precision Scope"},
		{"id":"plating","unlockId":"gear-plating","kind":"gear","slot":"armor","name":"Composite Plating"},
		{"id":"stim","unlockId":"gear-stim","kind":"gear","slot":"utility","name":"Combat Stim"},
		{"id":"red-dot","unlockId":"attachment-red-dot","kind":"attachment","slot":"optic","name":"Red Dot"},
		{"id":"muzzle","unlockId":"attachment-muzzle","kind":"attachment","slot":"barrel","name":"Compensator"},
		{"id":"extended-mag","unlockId":"attachment-extended-mag","kind":"attachment","slot":"magazine","name":"Extended Magazine"},
		{"id":"grip","unlockId":"attachment-grip","kind":"attachment","slot":"underbarrel","name":"Angled Grip"},
		{"id":"finish-ion","unlockId":"finish-ion","kind":"finish","slot":"","name":"Ion Finish"},
	]}

func run() -> void:
	var service := root.get_node("Career")
	var client := Probe.new()
	root.add_child(client)
	client.room_id = "room-a"
	client.career_seated = true
	var cat := catalog()

	# --- 1. pure model: disconnected vs known stock vs unknown vs null slot ----
	var disconnected: Dictionary = EquippedModel.summary({}, cat, null)
	check(not disconnected.ready, "an empty profile is not ready")
	check(service.loadout_empty_line(disconnected) == "Not connected · no confirmed saved loadout to show.", "disconnected is never rendered as an empty loadout")
	check(EquippedModel.short_line(disconnected) == "Unknown (not connected)", "disconnected summary is explicitly unknown")

	var stock: Dictionary = EquippedModel.summary({"id":"player-one", "gear":{}, "attachments":{}, "finish":null}, cat, null)
	check(not service.has_unknown_slot(stock), "known empty maps report no unknown slot")
	check(service.loadout_empty_line(stock) == "Stock gear and mods · no slot equipped for the next match.", "only known stock gear and mods may claim no slot is equipped")
	check(EquippedModel.finish_text(stock.finish) == "Stock / none", "explicit source null finish is stock")

	var missing: Dictionary = EquippedModel.summary({"id":"player-one", "attachments":{}}, cat, null)
	check(field_slot(missing, "gear", "primary").state == EquippedModel.STATE_UNKNOWN, "a missing gear map is unknown, not stock")
	check(service.has_unknown_slot(missing), "a missing field is unknown, never an empty loadout")
	check(service.loadout_empty_line(missing) == "Saved loadout unknown · the source did not report every equipped slot.", "an unreported field is never a no-slot claim")
	check(EquippedModel.finish_text(missing.finish) == "Unknown", "a missing finish is unknown")

	var null_slot: Dictionary = EquippedModel.slot_entry(true, {"primary":null}, cat, "gear", "primary")
	check(null_slot.state == EquippedModel.STATE_UNKNOWN, "a null slot value is unknown, not stock")

	var named: Dictionary = EquippedModel.summary({"id":"player-one", "gear":{"primary":"scope"}, "attachments":{}, "finish":"finish-ion"}, cat, null)
	check(field_slot(named, "gear", "primary").state == EquippedModel.STATE_EQUIPPED, "a resolvable ID is equipped")
	check(not service.has_unknown_slot(named), "a named slot is not unknown")

	var unknown_id: Dictionary = EquippedModel.summary({"id":"player-one", "gear":{"primary":"ghost-item"}, "attachments":{}, "finish":null}, cat, null)
	check(field_slot(unknown_id, "gear", "primary").state == EquippedModel.STATE_UNKNOWN_ID, "an unresolved catalog ID is its own state, never stock")
	check(EquippedModel.entry_text(field_slot(unknown_id, "gear", "primary")).contains("ghost-item"), "an unresolved ID stays a bounded literal")

	# --- 2. bounded summary line ---------------------------------------------
	var full: Dictionary = EquippedModel.summary({"id":"player-one",
		"gear":{"primary":"scope","armor":"plating","utility":"stim"},
		"attachments":{"optic":"red-dot","barrel":"muzzle","magazine":"extended-mag","underbarrel":"grip"},
		"finish":"finish-ion"}, cat, null)
	var full_line: String = EquippedModel.short_line(full)
	check(full_line.contains("+4 more"), "a fully equipped summary is capped and counts the remainder")
	check(full_line.contains("Precision Scope"), "the cap still names the first equipped item")
	check(full_line.count(" · ") <= EquippedModel.MAX_SUMMARY_PARTS, "the summary never exceeds the bounded part count")

	var long_id: String = "z".repeat(400)
	var long_summary: Dictionary = EquippedModel.summary({"id":"player-one", "gear":{"primary":long_id}, "attachments":{}, "finish":null}, cat, null)
	var long_line: String = EquippedModel.short_line(long_summary)
	check(long_line.contains("…"), "a long unresolved ID is truncated in the one-line summary")
	check(long_line.length() <= 80, "the one-line summary stays bounded for a long unresolved ID")
	check(EquippedModel.bounded_id(long_id).length() <= EquippedModel.MAX_SUMMARY_ID + 1, "bounded_id caps the displayed literal")
	check(field_slot(long_summary, "gear", "primary").get("id", "").length() <= EquippedModel.MAX_ID, "the stored slot detail keeps the larger bound")

	# --- 3. shipped LOADOUT tab text -----------------------------------------
	service.open_panel()
	var loadout_tab := service.panel.find_child("Tab_loadout", true, false) as Button
	# Disconnected: the reader never claims an empty loadout.
	loadout_tab.pressed.emit()
	var text := rows_text(service)
	check(text.contains("Not connected · no confirmed saved loadout to show."), "LOADOUT says not connected when there is no profile")
	check(not text.contains("No slot equipped · saved for the next match."), "the false empty-loadout claim is gone")

	# Known empty maps: explicit stock.
	seats(service, client, {"id":"player-one","level":4,"unlocks":{},"gear":{},"attachments":{},"finish":null})
	loadout_tab.pressed.emit()
	text = rows_text(service)
	check(text.contains("Stock gear and mods · no slot equipped for the next match."), "LOADOUT labels known stock gear and mods as stock")
	check(text.contains("Finish: Stock / none"), "LOADOUT labels an explicit null finish as stock")
	check(not text.contains("Saved loadout unknown"), "a known stock loadout is never called unknown")
	check(service.summary_label.text.contains("Saved for next match · Stock / unselected"), "the summary line agrees with the slot detail")

	# A missing field: unknown.
	seats(service, client, {"id":"player-two","level":4})
	loadout_tab.pressed.emit()
	text = rows_text(service)
	check(text.contains("Saved loadout unknown · the source did not report every equipped slot."), "LOADOUT labels an unreported field as unknown")
	check(not text.contains("Stock gear and mods · no slot equipped"), "unknown is never rendered as stock gear and mods")
	service.close_panel()
	client.queue_free()
	print("PLAYER_FLOW_CLARITY_MODEL_OK")
	quit(1 if failed else 0)
