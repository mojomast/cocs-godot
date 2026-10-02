extends "res://world/session.gd"
## Controlled 30-second source round using ordinary session input; no actor writes.
func on_lobby(frame: Dictionary) -> void:
	if phase == 1:
		client.send_frame({"type":"host", "mapId":current_id, "config":{"mode":"deathmatch", "botCount":1, "timeLimit":30, "fragLimit":100}})
		phase = 2
		return
	super.on_lobby(frame)
