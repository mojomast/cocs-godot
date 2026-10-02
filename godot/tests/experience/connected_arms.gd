extends "res://combined_arms/demo.gd"
## Test-only bounded round config, queued through the real native client. All
## rendering, controls, callbacks and joins remain the production route's code.
func on_lobby(frame: Dictionary) -> void:
	if not configured and join_room_id.is_empty() and frame.get("hostId", -1) == net.peer_id:
		configured = true
		roster = frame
		checked(net.send_frame({"type":"host", "mapId":map_id, "config":{"mode":"combined-arms", "botCount":bot_count, "timeLimit":120, "fragLimit":1000}}))
		return
	super.on_lobby(frame)
