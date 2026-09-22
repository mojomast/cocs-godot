extends "res://sports/chase.gd"
## Presentation only. Preserve all three source coordinates; no terrain sampling.
func infantry(a: Dictionary, yaw: float, pitch: float) -> Dictionary:
	var origin := Vector3(a.x, float(a.y)+float(a.get("eyeHeight", 1.45)), a.z)
	var forward := Basis.from_euler(Vector3(pitch, yaw, 0)) * Vector3.FORWARD
	return {"eye":origin, "target":origin+forward}
