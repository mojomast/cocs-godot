extends "res://zone_modes/demo.gd"
## Keep production _ready() and its signal binding, skip only authority connect.
func connect_selected_match() -> void:
	phase = 0

func on_error(message: String) -> void:
	push_error("Zone event-binding fixture setup: " + message)
	phase = -1
