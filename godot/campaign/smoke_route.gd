extends RefCounted
## Smoke-only input guidance. Never changes actor state, time, or encounter gates.
const ARRIVAL_RADIUS := 0.8
const ARRIVAL_HEIGHT := 1.5
const BLOCKED_SECONDS := 12.0
var points: Array[Vector3] = []
var index := 0
var best_distance := INF
var progress_time := 0.0
var error := ""

func configure(recipe: Dictionary, now: float) -> bool:
	points.clear()
	index = 0
	best_distance = INF
	progress_time = now
	error = ""
	var campaign: Variant = recipe.get("campaign")
	var path: Variant = campaign.get("criticalPath") if campaign is Dictionary else null
	if not path is Array or path.size() < 2:
		error = "Campaign smoke requires an authored critical path"
		return false
	for vertex: Variant in path:
		if not vertex is Dictionary:
			error = "Invalid campaign smoke path vertex"
			return false
		for axis: String in ["x", "y", "z"]:
			var value: Variant = vertex.get(axis)
			if not (value is int or value is float) or not is_finite(float(value)):
				error = "Nonfinite or missing campaign smoke path coordinate"
				return false
		points.append(Vector3(vertex.x, vertex.y, vertex.z))
	return true

func sample(feet: Vector3, now: float) -> Dictionary:
	var controls := {"x":0.0, "z":0.0, "yaw":0.0, "pitch":0.0, "fire":true}
	if not error.is_empty(): return controls
	if not feet.is_finite() or not is_finite(now):
		error = "Campaign smoke received a nonfinite authoritative pose/time"
		return controls
	# Consume vertices in authored order. Never jump to a nearby later leg, which
	# would cut switchbacks or skip a gate on a self-near/looping path.
	while index < points.size():
		var offset := points[index] - feet
		var horizontal := Vector2(offset.x, offset.z)
		if horizontal.length() <= ARRIVAL_RADIUS and absf(offset.y) <= ARRIVAL_HEIGHT:
			index += 1
			best_distance = INF
			progress_time = now
			continue
		var distance := offset.length()
		if distance < best_distance - 0.2:
			best_distance = distance
			progress_time = now
		if now - progress_time >= BLOCKED_SECONDS:
			error = "Campaign smoke blocked at criticalPath vertex %d (%.1f m remaining)" % [index, distance]
			return controls
		var direction := horizontal.normalized()
		controls.x = direction.x
		controls.z = direction.y
		controls.yaw = atan2(-direction.x, -direction.y)
		return controls
	# Keep firing through the last network observation; the scene's overall
	# deadline still fails if no genuine robot model/effects evidence arrives.
	return controls
