extends "res://sports/chase.gd"
## Presentation only. Preserve all three source coordinates; no terrain sampling.
func infantry(a: Dictionary, yaw: float, pitch: float) -> Dictionary:
	var origin := Vector3(a.x, float(a.y)+float(a.get("eyeHeight", 1.45)), a.z)
	var forward := Basis.from_euler(Vector3(pitch, yaw, 0)) * Vector3.FORWARD
	return {"eye":origin, "target":origin+forward}

func mounted(v: Dictionary, a: Dictionary, yaw: float, pitch: float, delta: float) -> Dictionary:
	var settings := preload("res://ui/settings_access.gd").service()
	var reduced: bool = settings != null and settings.values.get("reduced_motion", false) == true
	var pose := follow(v, delta, yaw, pitch, str(a.get("vehicleSeat", "driver")), int(a.get("vehicleSeatIndex", 0)), reduced)
	if not first_person:
		# Match the wire yaw/pitch used by projectiles; chasing the chassis does
		# not silently replace the gun sight with the vehicle's nose direction.
		pose.target = pose.eye + Basis.from_euler(Vector3(pitch, yaw, 0)) * Vector3.FORWARD * 20.0
	return pose
