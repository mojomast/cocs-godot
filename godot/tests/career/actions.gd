extends SceneTree
const Actions = preload("res://career/actions_model.gd")
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
		push_error("career actions: " + label)

func run() -> void:
	var service := root.get_node("Career")
	var client := Probe.new()
	root.add_child(client)
	client.room_id = "room-a"
	client.career_seated = true
	var raw := {"id":"player-one", "level":4, "xp":10, "unlocks":{"gear-command-kit":true}, "gear":{"armor":"plating"}, "attachments":{}, "finish":null}
	service.receive(client, {"type":"welcome", "profile":raw})
	var item := {"kind":"gear", "id":"command-kit", "slot":"primary", "level":50, "unlockId":"gear-command-kit"}
	check(Actions.available(service.profile, item), "source grant unlocks capstone")
	service.open_panel()
	var rows := service.details.find_child("CatalogRows", true, false) as VBoxContainer
	var command_button: Button
	var locked_button: Button
	var armor_button: Button
	for row: Node in rows.get_children():
		var label := row.get_child(0) as Label
		if label.text.begins_with("Command Kit"): command_button = row.get_child(row.get_child_count() - 1) as Button
		if label.text.begins_with("Heavy Barrel"): locked_button = row.get_child(row.get_child_count() - 1) as Button
		if label.text.begins_with("Composite Plating"): armor_button = row.get_child(row.get_child_count() - 1) as Button
	check(command_button != null and not command_button.disabled and locked_button != null and locked_button.disabled, "rendered unlocked choice actionable, locked choice disabled")
	check(command_button != null and command_button.name == "Equip_gear-command-kit" and command_button.get_meta("catalog_kind") == "gear", "stable catalog action selector")
	check(armor_button != null and not armor_button.disabled and armor_button.text.begins_with("UNEQUIP"), "equipped slot can be cleared in UI")
	var stripped: Dictionary = Actions.request(service.profile, {"kind":"gear", "id":"plating", "slot":"armor", "level":3, "unlockId":"gear-plating"}, true)
	check(stripped.get("gear") == {}, "clear preserves remaining complete loadout")
	check(Actions.request(service.profile, {"kind":"finish", "id":"finish-ion", "slot":"", "level":4, "unlockId":"finish-ion"}, true).is_empty(), "cannot clear a finish that is not equipped")
	var partial := CareerProfile.project({"id":"player-one", "level":4, "unlocks":{}, "gear":{"armor":"plating", "primary":9}, "attachments":{}})
	var ordinary := {"kind":"gear", "id":"scope", "slot":"primary", "level":2, "unlockId":"gear-scope"}
	check(not partial.has("gear") and Actions.request(partial, ordinary).is_empty(), "malformed gear cannot turn into destructive partial write")
	check(Actions.request({"id":"player-one", "level":4, "unlocks":{}, "gear":{"primary":false}, "attachments":{}}, ordinary).is_empty(), "pure request rejects malformed direct map")
	partial = CareerProfile.project({"id":"player-one", "level":4, "unlocks":{}, "gear":{}, "attachments":{"optic":"red-dot", "alien":"x"}})
	check(not partial.has("attachments") and Actions.request(partial, ordinary).is_empty(), "unknown attachment slot invalidates whole equipment map")
	var locked := {"kind":"gear", "id":"heavy-barrel", "slot":"primary", "level":5, "unlockId":"gear-heavy-barrel"}
	check(Actions.request(service.profile, locked).is_empty(), "locked choice cannot emit")
	if command_button != null: command_button.pressed.emit()
	check(client.sent.size() == 1 and client.sent[0].get("gear") == {"armor":"plating", "primary":"command-kit"}, "complete gear submitted through seated client")
	check(not service.pending.is_empty() and service.profile.gear == {"armor":"plating"}, "pending never optimistic")
	service.select_item(item)
	check(client.sent.size() == 1, "one write pending at a time")
	var award := {"type":"progression", "profile":raw.duplicate(true), "gained":42}
	service.receive(client, award)
	check(not service.pending.is_empty(), "unrelated XP award cannot ACK")
	var bad_ack := raw.duplicate(true)
	bad_ack.gear = {"armor":"plating", "primary":12}
	service.receive(client, {"type":"progression", "profile":bad_ack, "gear":bad_ack.gear, "attachments":bad_ack.attachments})
	check(not service.pending.is_empty() and service.action_status.contains("awaiting"), "malformed partial ACK cannot claim adjustment")
	service.receive(client, {"type":"progression", "profile":raw, "gear":{"primary":"command-kit"}, "attachments":{}})
	check(not service.pending.is_empty(), "inconsistent top-level ACK cannot settle")
	var other := raw.duplicate(true)
	other.id = "player-two"
	service.receive(client, {"type":"progression", "profile":other, "gear":{}, "attachments":{}})
	check(not service.pending.is_empty(), "foreign identity cannot ACK")
	service.receive(client, {"type":"progression", "profile":raw, "gear":raw.gear, "attachments":raw.attachments})
	check(service.pending.is_empty() and service.action_status.contains("adjusted/refused"), "source normalization shown as adjustment")
	service.last_send_ms = -1000
	service.select_item(item)
	var applied := raw.duplicate(true)
	applied.gear.primary = "command-kit"
	service.receive(client, {"type":"progression", "profile":applied, "gear":applied.gear, "attachments":applied.attachments})
	check(service.pending.is_empty() and service.action_status.contains("confirmed"), "only source echo confirms")
	service.close_panel()
	service.last_send_ms = -1000
	var finish := {"kind":"finish", "id":"finish-ion", "slot":"", "level":4, "unlockId":"finish-ion"}
	service.select_item(finish)
	check(client.sent.back().get("finish") == "finish-ion", "finish on legitimate GEAR wire")
	var finish_applied := applied.duplicate(true)
	finish_applied.finish = "finish-ion"
	service.receive(client, {"type":"progression", "profile":finish_applied, "gear":finish_applied.gear, "attachments":finish_applied.attachments})
	check(service.pending.is_empty() and service.profile.finish == "finish-ion", "finish confirms from known source field")
	var clear_finish: Dictionary = Actions.request(service.profile, finish, true)
	check(clear_finish.has("finish") and clear_finish.finish == null, "explicit null finish clears source cosmetic")
	service.last_send_ms = -1000
	service.select_item(finish, true)
	var unknown_finish := finish_applied.duplicate(true)
	unknown_finish.erase("finish")
	service.receive(client, {"type":"progression", "profile":unknown_finish, "gear":unknown_finish.gear, "attachments":unknown_finish.attachments})
	check(not service.pending.is_empty(), "missing finish cannot settle finish clear")
	service.pending.sent_at = Time.get_ticks_msec() - Actions.TIMEOUT_MS - 1
	service._process(0.0)
	check(not service.pending.is_empty() and service.action_status.contains("unknown"), "timeout is indeterminate and holds the serial wire")
	service.select_item(finish)
	check(client.sent.size() == 4, "timeout cannot retry without reply or reconnect")
	service.clear_connection(client)
	check(service.profile.is_empty() and service.pending.is_empty(), "disconnect clears owner and pending")
	service.receive(client, {"type":"progression", "profile":applied, "gear":applied.gear, "attachments":applied.attachments})
	check(service.profile.is_empty(), "late reply cannot resurrect")
	client.queue_free()
	print("CAREER_ACTIONS_OK")
	quit(1 if failed else 0)
