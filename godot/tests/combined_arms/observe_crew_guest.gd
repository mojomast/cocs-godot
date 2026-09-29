extends "res://tests/combined_arms/observe_crew_shared.gd"
## Separate native Godot process; receives --join-room=<host CREW_ROOM.join_room>.
func _initialize() -> void:
	role = "guest"
	super._initialize()
