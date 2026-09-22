extends Node3D
## Public objective markers only; no capture simulation or missing-node inference.
var markers: Dictionary = {}
var heights: Dictionary = {}
var nearest: Dictionary = {}
var distance := 0.0

func clear_round() -> void:
	for marker: Node3D in markers.values(): marker.free()
	markers.clear()
	nearest.clear()
	distance = 0.0

func apply_projection(projection: Dictionary, actor: Dictionary) -> void:
	if projection.is_empty() or actor.is_empty():
		clear_round()
		return
	var present := {}
	nearest = {}
	distance = INF
	for node: Dictionary in projection.get("nodes", []):
		present[node.id] = true
		if not markers.has(node.id):
			var marker := Label3D.new()
			marker.font_size = 48
			marker.pixel_size = 0.018
			marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.no_depth_test = false
			add_child(marker)
			markers[node.id] = marker
		var marker: Label3D = markers[node.id]
		marker.position = Vector3(node.x, float(node.get("y", heights.get(node.id, 0))) + 3.0, node.z)
		marker.text = "%s\n%s" % [node.get("label", node.id), "CONTESTED" if node.get("contested") == true else "Team %d" % int(node.owner) if node.get("owner") != null else "Neutral"]
		marker.modulate = Color("f4b75e") if node.get("owner") == null else Color("f07872") if node.owner == 0 else Color("78b7ff")
		var d := Vector2(actor.x, actor.z).distance_to(Vector2(node.x, node.z))
		# Near objectives use the compact HUD instead of a giant close-up glyph.
		marker.visible = d >= 10.0 and d <= 110.0
		if d < distance:
			distance = d
			nearest = node
	for id: String in markers.keys():
		if not present.has(id):
			markers[id].free()
			markers.erase(id)

func known(value: Variant) -> String:
	return "unknown" if value == null else "%.1f" % float(value)

func text(projection: Dictionary) -> String:
	if projection.is_empty(): return "Recipient projection unavailable — controls released"
	var result := "Team %d  |  FLUX %s  |  own REQ %s" % [int(projection.team), known(projection.get("flux")), known(projection.get("req"))]
	if not nearest.is_empty():
		var progress: Array = nearest.get("progress", [])
		result += "\nNearby: %s · %.1fm · %s\n%s · progress %s" % [nearest.get("label", nearest.id), distance, "Neutral" if nearest.get("owner") == null else "Team %d" % int(nearest.owner), "CONTESTED" if nearest.get("contested") == true else "live" if nearest.get("live") == true else "inactive", "%.0f%%" % (float(progress[int(projection.team)]) * 100) if progress.size() == 2 else "unknown"]
	return result
