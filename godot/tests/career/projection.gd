extends SceneTree
const Projection = preload("res://career/profile.gd")
const Network = preload("res://net/client.gd")
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, name: String) -> void:
	if not ok:
		push_error("career: " + name)
		failed = true

func run() -> void:
	var service := root.get_node("Career")
	var client := Network.new()
	root.add_child(client)
	check(Projection.project(null).is_empty(), "unknown is not a zero profile")
	check(Projection.project({"xp":"0", "id":"a"}).get("xp") == null, "malformed numeric unknown")
	var raw := {"id":"a", "ownerToken":"secret-private", "progressToken":"secret-private", "level":4, "xp":1200, "unlocks":{"gear-command-kit":true}, "gear":{"primary":"command-kit"}, "byMode":{"deathmatch":{"matches":2}}}
	var clean: Dictionary = Projection.project(raw)
	check(not JSON.stringify(clean).contains("secret-private"), "ownership credentials removed")
	check(Projection.item_state(clean, {"kind":"gear", "id":"command-kit", "slot":"primary", "level":50, "unlockId":"gear-command-kit"}) == "EQUIPPED", "source grant survives level gate")
	check(Projection.item_state({}, {"kind":"gear", "level":2}) == "NOT LOADED", "unknown lock state")
	check(client.decode_text(JSON.stringify({"type":"welcome", "v":3, "roomId":"room-a", "peerId":1, "profile":raw, "progressToken":"secret-private"})), "wire welcome accepted")
	check(service.profile.get("xp") == 1200, "welcome profile projected")
	check(client.decode_text(JSON.stringify({"type":"progression", "profile":{"id":"other", "xp":9000}})), "foreign wire reply accepted by transport")
	check(service.profile.get("xp") == 1200, "foreign progression ignored")
	service.close_panel()
	client.disconnect_server()
	client.decode_text(JSON.stringify({"type":"progression", "profile":raw}))
	check(service.profile.is_empty(), "late reply after disconnect ignored")
	client.queue_free()
	print("CAREER_PROJECTION_OK")
	quit(1 if failed else 0)
