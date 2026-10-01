extends "res://campaign/telegraphs.gd"
## Same authority-clock telegraphs as campaign. Source/identity Horde builders
## have colliders but no height_at API; sample one physical support point per
## ring from the received human foot height, not 72 rays per ring per frame.
var ring_height := 0.0

func height_at(_x: float, _z: float) -> float:
	return ring_height

func _draw(entry: Dictionary) -> void:
	var foot := 0.0
	if actors.has(0): foot = float(actors[0].get("y", 0.0))
	var start := Vector3(float(entry.x), foot + 2.0, float(entry.z))
	var end := Vector3(start.x, foot - 6.0, start.z)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, end))
	ring_height = float(hit.position.y) if not hit.is_empty() else foot
	super._draw(entry)
