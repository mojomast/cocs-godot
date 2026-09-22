extends Node3D
## Public objective markers only; no capture simulation or missing-node inference.
const Guidance = preload("res://lattice/world_guidance.gd")
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

func approach_node(projection: Dictionary, actor: Dictionary) -> Dictionary:
	# Public live is a useful exploration hint, not team-specific capture legality.
	# Prefer an unowned/enemy live objective to repeatedly coaching own HQ.
	var target: Dictionary = {}
	var closest := INF
	if actor.is_empty(): return nearest
	for node: Dictionary in projection.get("nodes", []):
		if node.get("live") != true or node.get("owner") == projection.get("team"): continue
		var d := Vector2(actor.x, actor.z).distance_to(Vector2(node.x, node.z))
		if d < closest:
			closest = d
			target = node
	return nearest if target.is_empty() else target

func text(projection: Dictionary, actor: Dictionary = {}, yaw: float = 0.0) -> String:
	if projection.is_empty(): return "Recipient projection unavailable — controls released"
	var result := "Goal: explore toward a public node; C opens tactical commands."
	var target := approach_node(projection, actor)
	if not target.is_empty():
		var progress: Array = target.get("progress", [])
		var range_m := Vector2(actor.x, actor.z).distance_to(Vector2(target.x, target.z)) if not actor.is_empty() else distance
		result = "Goal: approach %s · %s · %.0f m (planar)" % [target.get("label", target.id), Guidance.bearing(actor, target, yaw) if not actor.is_empty() else "bearing unknown", range_m]
		var activity := "CONTESTED" if target.get("contested") == true else "live" if target.get("live") == true else "inactive" if target.get("live") == false else "activity unknown"
		result += "\nSource node: %s · %s · team progress %s" % ["Neutral" if target.get("owner") == null else "Team %d" % int(target.owner), activity, "%.0f%%" % (float(progress[int(projection.team)]) * 100) if progress.size() == 2 else "unknown"]
	result += "\nTeam %d · FLUX %s · own REQ %s\nC: HOLD / recruitment. HOLD receipt ≠ node capture." % [int(projection.team), known(projection.get("flux")), known(projection.get("req"))]
	if projection.get("coop") == true:
		var recruitment: Dictionary = projection.get("recruitment", {})
		result += "\nWave %s · %s · recruitment window %s" % [str(recruitment.get("wave")) if recruitment.get("wave") != null else "unknown", str(recruitment.get("phase")) if recruitment.get("phase") != null else "phase unknown", "open" if recruitment.get("open") == true else "closed" if recruitment.get("open") == false else "unknown"]
	return result
