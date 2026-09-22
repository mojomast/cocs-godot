extends "res://native_arenas/client.gd"
## Synthetic transport: captured writes are NOT authority simulation evidence.
var writes: Array[Dictionary] = []

func connect_server(_endpoint: String, maps: Dictionary, map_id: String) -> Error:
	allowlist = maps
	requested_map = map_id
	return OK

func send_frame(frame: Dictionary) -> Error:
	writes.append(frame.duplicate(true))
	return OK

func _process(_delta: float) -> void:
	pass
