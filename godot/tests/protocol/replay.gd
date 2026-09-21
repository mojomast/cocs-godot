extends SceneTree

const Client = preload("res://net/client.gd")
const Catalog = preload("res://world/catalog.gd")

func _initialize() -> void:
	var catalog := Catalog.new()
	if not catalog.open():
		push_error(catalog.error)
		quit(1)
		return
	var client := Client.new()
	client.allowlist = catalog.entries
	client.requested_map = "meridian-exchange"
	var captured: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/protocol/captured.json"))
	var decoded: int = 0
	var acknowledged: bool = false
	for record: Dictionary in captured.frames:
		if record.direction != "server" or record.client != 1: continue
		if not client.decode_text(JSON.stringify(record.frame)):
			push_error(client.error)
			client.free()
			quit(1)
			return
		if client.last_ack >= 1: acknowledged = true
		decoded += 1
	if not acknowledged or client.actor_id != 0 or client.peer_id != 1:
		push_error("Identity or string-key ack mismatch")
		client.free()
		quit(1)
		return
	var event_frame: Dictionary = {}
	for record: Dictionary in captured.frames:
		if record.direction == "server" and record.frame.type == "events" and not record.frame.get("items", []).is_empty():
			event_frame = record.frame
			break
	if event_frame.is_empty():
		push_error("Capture has no real events for deduplication test")
		client.free()
		quit(1)
		return
	client.reset_round()
	client.decode_text(JSON.stringify(event_frame))
	var unique_events: int = client.seen_events.size()
	client.decode_text(JSON.stringify(event_frame))
	if unique_events == 0 or client.seen_events.size() != unique_events:
		client.free()
		quit(1)
		return
	if client.decode_text('{"type":"start","mapId":"unknown"}'):
		client.free()
		quit(1)
		return
	if client.decode_text('{"type":"welcome","v":2,"peerId":1}'):
		client.free()
		quit(1)
		return
	print("PORT_PROTOCOL_REPLAY_OK frames=", decoded, " ack=true actor=0 peer=1 unknown=rejected version2=rejected")
	client.free()
	quit(0)
