extends SceneTree
const CareerProfile = preload("res://career/profile.gd")
const Network = preload("res://net/client.gd")
var failed := false

class Probe extends Network:
	func career_wire_open() -> bool: return true
	func send_frame(_frame: Dictionary) -> Error: return OK

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, name: String) -> void:
	if not ok:
		push_error("career: " + name)
		failed = true

func run() -> void:
	var service := root.get_node("Career")
	var client := Probe.new()
	root.add_child(client)
	check(CareerProfile.project(null).is_empty(), "unknown is not a zero profile")
	check(CareerProfile.project({"xp":"0", "id":"player-one"}).get("xp") == null, "malformed numeric unknown")
	var raw := {"id":"player-one", "ownerToken":"secret-private", "progressToken":"secret-private", "level":4, "xp":1200, "unlocks":{"gear-command-kit":true}, "gear":{"primary":"command-kit"}, "byMode":{"deathmatch":{"matches":2}}}
	var clean: Dictionary = CareerProfile.project(raw)
	check(not JSON.stringify(clean).contains("secret-private"), "ownership credentials removed")
	check(CareerProfile.item_state(clean, {"kind":"gear", "id":"command-kit", "slot":"primary", "level":50, "unlockId":"gear-command-kit"}) == "EQUIPPED", "source grant survives level gate")
	check(CareerProfile.item_state({}, {"kind":"gear", "level":2}) == "NOT LOADED", "unknown lock state")
	var capstone := {"kind":"gear", "id":"command-kit", "slot":"primary", "level":50, "unlockId":"gear-command-kit"}
	check(CareerProfile.item_state(CareerProfile.project({"id":"player-one", "level":4}), capstone) == "NOT LOADED", "missing unlock map cannot prove lock")
	check(CareerProfile.item_state(CareerProfile.project({"id":"player-one", "unlocks":{"gear-command-kit":true}}), capstone) == "UNLOCKED", "grant proves unlock without level")
	check(CareerProfile.item_state(CareerProfile.project({"id":"player-one", "level":4, "unlocks":{}}), capstone).begins_with("LOCKED"), "complete low-level facts prove lock")
	check(CareerProfile.item_state(CareerProfile.project({"id":"player-one", "level":4, "unlocks":{"gear-command-kit":"no"}}), capstone) == "NOT LOADED", "malformed grant does not prove lock")
	check(client.create_room() == OK, "explicit create admits next welcome")
	check(client.decode_text(JSON.stringify({"type":"welcome", "v":3, "roomId":"room-a", "peerId":1, "profile":raw, "progressToken":"secret-private"})), "wire welcome accepted")
	check(service.profile.get("xp") == 1200, "welcome profile projected")
	check(client.decode_text(JSON.stringify({"type":"progression", "profile":{"id":"other", "xp":9000}})), "foreign wire reply accepted by transport")
	check(service.profile.get("xp") == 1200, "foreign progression ignored")
	service.close_panel()
	client.disconnect_server()
	client.decode_text(JSON.stringify({"type":"progression", "profile":raw}))
	check(service.profile.is_empty(), "late reply after disconnect ignored")
	client.decode_text(JSON.stringify({"type":"welcome", "v":3, "roomId":"room-a", "peerId":1, "profile":raw}))
	check(service.profile.is_empty(), "late welcome without new create cannot resurrect")
	check(client.create_room() == OK, "new explicit room attempt")
	check(client.decode_text(JSON.stringify({"type":"welcome", "v":3, "roomId":"room-b", "peerId":2, "profile":{"id":"player-two", "level":1,"unlocks":{}}})), "new room welcome")
	check(service.profile.get("id") == "player-two", "new identity replaces prior")
	client.decode_text(JSON.stringify({"type":"progression", "profile":raw}))
	check(service.profile.get("id") == "player-two", "old identity update rejected")
	client.queue_free()
	print("CAREER_PROJECTION_OK")
	quit(1 if failed else 0)
