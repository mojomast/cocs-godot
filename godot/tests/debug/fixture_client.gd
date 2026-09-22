extends "res://net/client.gd"
## Synthetic transport for the debug-panel contract test: captured writes are
## NOT authority simulation evidence (the node harness proves the authority).

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
