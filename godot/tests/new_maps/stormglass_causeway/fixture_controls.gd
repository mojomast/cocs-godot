extends "res://sports/controls.gd"
## Test stimulus only. The production network serializes this ordinary input.
var command: Dictionary = {}
var sent := 0
func packet(yaw: float, eligible: bool) -> Dictionary:
	if not eligible: return {"yaw":yaw}
	engaged = true
	sent += 1
	return command.get("input",{}).duplicate()
