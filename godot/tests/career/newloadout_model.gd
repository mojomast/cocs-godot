extends SceneTree
## Saved-loadout model + service-ownership contract.
##
## The model is pure: a confirmed profile plus the shipped catalog become a
## readable overview. These checks pin the distinctions the UI relies on:
## unknown field vs known-empty stock vs a named item vs an unresolved ID, plus
## the saved-vs-current finish split and the owner-gated service accessor.
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
		push_error("career loadout: " + label)

func field_slot(summary: Dictionary, key: String, slot: String) -> Dictionary:
	return summary.get("fields", {}).get(key, {}).get(slot, {})

func run() -> void:
	var catalog := {"schema":1, "items":[
		{"id":"scope","unlockId":"gear-scope","kind":"gear","slot":"primary","name":"Precision Scope"},
		{"id":"plating","unlockId":"gear-plating","kind":"gear","slot":"armor","name":"Composite Plating"},
		{"id":"stim","unlockId":"gear-stim","kind":"gear","slot":"utility","name":"Combat Stim"},
		{"id":"red-dot","unlockId":"attachment-red-dot","kind":"attachment","slot":"optic","name":"Red Dot"},
		{"id":"extended-mag","unlockId":"attachment-extended-mag","kind":"attachment","slot":"magazine","name":"Extended Magazine"},
		{"id":"finish-ion","unlockId":"finish-ion","kind":"finish","slot":"","name":"Ion Finish"},
	]}
	# 1. No connected profile is unknown, never a fabricated stock loadout.
	var empty: Dictionary = EquippedModel.summary({}, catalog, null)
	check(not empty.ready and EquippedModel.short_line(empty) == "Unknown (not connected)", "empty profile is unknown, not stock")
	# 2. A saved profile names every slot through the catalog.
	var saved := {"id":"player-one", "gear":{"primary":"scope","armor":"plating"}, "attachments":{"optic":"red-dot"}, "finish":"finish-ion"}
	var summary: Dictionary = EquippedModel.summary(saved, catalog, null)
	check(summary.ready, "saved profile is ready")
	check(field_slot(summary, "gear", "primary").get("name") == "Precision Scope", "gear slot resolves readable name")
	check(field_slot(summary, "gear", "armor").state == EquippedModel.STATE_EQUIPPED, "armor equipped")
	check(field_slot(summary, "gear", "utility").state == EquippedModel.STATE_STOCK, "absent slot in a known map is stock, not unknown")
	check(field_slot(summary, "attachments", "optic").get("name") == "Red Dot", "attachment resolves readable name")
	check(summary.finish.state == EquippedModel.STATE_EQUIPPED and summary.finish.get("name") == "Ion Finish", "finish resolves readable name")
	check(EquippedModel.short_line(summary).contains("Precision Scope") and EquippedModel.short_line(summary).contains("Ion Finish"), "short line names equipped items")
	check(not EquippedModel.short_line(summary).contains("Stock"), "short line omits stock slots")
	# 3. A missing field stays unknown; a known empty map is explicit stock.
	var missing := {"id":"player-one", "attachments":{}}
	var partial: Dictionary = EquippedModel.summary(missing, catalog, null)
	check(field_slot(partial, "gear", "primary").state == EquippedModel.STATE_UNKNOWN, "missing gear field is unknown, not stock")
	check(field_slot(partial, "attachments", "optic").state == EquippedModel.STATE_STOCK, "known empty attachment map is stock")
	check(partial.finish.state == EquippedModel.STATE_UNKNOWN, "missing finish is unknown")
	var stock := {"id":"player-one", "gear":{}, "attachments":{}, "finish":null}
	var stock_summary: Dictionary = EquippedModel.summary(stock, catalog, null)
	check(field_slot(stock_summary, "gear", "primary").state == EquippedModel.STATE_STOCK, "complete known empty gear is stock")
	check(stock_summary.finish.state == EquippedModel.STATE_STOCK, "explicit null finish is stock")
	check(EquippedModel.finish_text(stock_summary.finish) == "Stock / none", "stock finish label is explicit")
	check(EquippedModel.short_line(stock_summary) == "Stock / unselected", "all-stock saved loadout says so")
	# 4. An unresolved catalog ID is a bounded literal, never stock or a name.
	var unknown_id := EquippedModel.summary({"id":"player-one", "gear":{"primary":"ghost-item"}, "attachments":{}, "finish":"ghost-finish"}, catalog, null)
	check(field_slot(unknown_id, "gear", "primary").state == EquippedModel.STATE_UNKNOWN_ID, "unknown catalog ID is not stock")
	check(EquippedModel.entry_text(field_slot(unknown_id, "gear", "primary")).contains("ghost-item"), "unknown ID is shown literally")
	check(unknown_id.finish.state == EquippedModel.STATE_UNKNOWN_ID, "unknown finish ID is not stock")
	var long_id: String = "z".repeat(400)
	var bounded := EquippedModel.summary({"id":"player-one", "gear":{"primary":long_id}, "attachments":{}, "finish":null}, catalog, null)
	check(field_slot(bounded, "gear", "primary").get("id", "").length() <= EquippedModel.MAX_ID, "unknown ID display is bounded")
	# 5. profile.gd drops a malformed/oversized map whole: every slot is unknown.
	var malformed: Dictionary = CareerProfile.project({"id":"player-one", "gear":{"primary":"scope", "armor":"plating", "utility":"stim", "alien":"x"}, "attachments":{}})
	check(not malformed.has("gear"), "malformed gear map is omitted whole")
	var malformed_summary: Dictionary = EquippedModel.summary(malformed, catalog, null)
	check(field_slot(malformed_summary, "gear", "primary").state == EquippedModel.STATE_UNKNOWN, "dropped gear map leaves slots unknown")
	# 6. A parent actor snapshot exposes a current finish; without one the finish
	#    is saved-for-next only.
	check(not summary.finish.has("current"), "no hook means no claimed current finish")
	var with_current: Dictionary = EquippedModel.summary(saved, catalog, {"finish":"finish-ion"})
	check(with_current.finish.get("current") is Dictionary and with_current.finish.current.get("name") == "Ion Finish", "a valid current finish resolves a readable name")
	var ghost_current: Dictionary = EquippedModel.summary(saved, catalog, {"finish":"ghost-finish"})
	check(ghost_current.finish.get("current") is Dictionary and ghost_current.finish.current.state == EquippedModel.STATE_UNKNOWN_ID, "an unresolved current ID stays a literal unknown")
	var hooked: Dictionary = EquippedModel.summary(saved, catalog, {"finish":null})
	check(hooked.finish.get("current") is Dictionary and hooked.finish.current.state == EquippedModel.STATE_STOCK, "hook with explicit null shows a current stock finish")
	# 7. Service accessor is owner-gated and never optimistic.
	var service := root.get_node("Career")
	var client := Probe.new()
	root.add_child(client)
	client.room_id = "room-a"
	client.career_seated = true
	var raw := {"id":"player-one", "level":4, "unlocks":{"attachment-red-dot":true}, "gear":{"primary":"scope"}, "attachments":{}, "finish":null}
	service.receive(client, {"type":"welcome", "profile":raw})
	check(service.owned(client), "welcome binds the owner")
	var live: Dictionary = service.equipment_summary()
	check(field_slot(live, "gear", "primary").get("name") == "Precision Scope", "service summary reads the confirmed profile")
	check(field_slot(live, "attachments", "optic").state == EquippedModel.STATE_STOCK, "service summary reports known stock")
	var red_dot := {"kind":"attachment", "id":"red-dot", "slot":"optic", "level":1, "unlockId":"attachment-red-dot"}
	service.last_send_ms = -1000
	service.select_item(red_dot)
	check(not service.pending.is_empty(), "selection is pending")
	var optimistic: Dictionary = service.equipment_summary()
	check(field_slot(optimistic, "attachments", "optic").state == EquippedModel.STATE_STOCK, "pending write never appears in the saved summary")
	# A second seated client cannot read the first owner's summary.
	var other := Probe.new()
	root.add_child(other)
	other.room_id = "room-b"
	other.career_seated = true
	check(not service.owned(other), "a different client is not the owner")
	service.clear_connection(other)
	check(service.owned(client) and field_slot(service.equipment_summary(), "gear", "primary").get("name") == "Precision Scope", "non-owner disconnect cannot erase the owner summary")
	service.clear_connection(client)
	check(service.profile.is_empty() and not service.equipment_summary().ready, "owner disconnect clears the saved summary")
	check(service.summary_label.text == "Connect to load source loadout.", "disconnected summary is the explicit connect prompt")
	client.queue_free()
	other.queue_free()
	print("CAREER_NEWLOADOUT_MODEL_OK")
	quit(1 if failed else 0)
