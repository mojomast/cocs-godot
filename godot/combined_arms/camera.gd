extends "res://sports/chase.gd"
## Presentation only. Preserve all three source coordinates; no terrain sampling.
func infantry(a: Dictionary, yaw: float, pitch: float) -> Dictionary:
	var origin := Vector3(a.x, float(a.y)+float(a.get("eyeHeight", 1.45)), a.z)
	var forward := Basis.from_euler(Vector3(pitch, yaw, 0)) * Vector3.FORWARD
	return {"eye":origin, "target":origin+forward}

func mounted(v: Dictionary, a: Dictionary, yaw: float, pitch: float, delta: float) -> Dictionary:
	# Aim follows current look for every role, while the anchor remains source-owned.
	# Driver chase keeps the chassis readable; gunner/passenger use their source seat.
	if a.get("vehicleSeat") == "driver":
		var pose := follow(v, delta)
		var forward := Basis.from_euler(Vector3(pitch, yaw, 0)) * Vector3.FORWARD
		pose.target = pose.eye + forward * 20.0
		return pose
	return infantry(a, yaw, pitch)
