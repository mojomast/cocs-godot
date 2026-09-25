extends Node3D
## Public objective markers only; no capture simulation or missing-node inference.
const Guidance = preload("res://lattice/world_guidance.gd")
const Topology = preload("res://lattice/topology.gd")
const WorldTarget = preload("res://lattice/world_target.gd")
var markers: Dictionary = {}
var heights: Dictionary = {}
var nearest: Dictionary = {}
var distance := 0.0
var topology := Topology.new()
var target_selector := WorldTarget.new()
var authored_map_id := ""
var topology_model: Dictionary = {}
var target_model: Dictionary = {}

## Explicit composition seam: caller passes the catalog's authored map on map
## identity changes; no map geometry is inferred from recipient snapshots.
func bind_authored_map(map_id: String, source_map: Dictionary) -> bool:
	if map_id == authored_map_id and topology.authored: return true
	authored_map_id = map_id
	topology_model.clear()
	target_model.clear()
	return topology.set_authored(source_map)

func clear_round() -> void:
	for marker: Node3D in markers.values(): marker.free()
	markers.clear()
	nearest.clear()
	distance = 0.0
	topology_model.clear()
	target_model.clear()

func apply_projection(projection: Dictionary, actor: Dictionary) -> void:
	if projection.is_empty() or actor.is_empty():
		clear_round()
		return
	var present := {}
	var own_team: Variant = projection.get("team")
	topology_model = topology.model(projection.get("nodes", []), own_team, projection.get("cuts", []))
	target_model = target_selector.select(projection, topology_model, actor, target_model)
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
		var info: Dictionary = topology_model.get("by_id", {}).get(node.id, {})
		var owner_text := "ownership unknown" if not info.get("owner_known", false) else ("Neutral" if info.get("owner") == null else "Team %d" % int(info.owner))
		var supply_text: String = str(info.get("supply", "UNKNOWN"))
		marker.text = "%s\n%s · %s%s" % [node.get("label", node.id), "CONTESTED" if node.get("contested") == true else owner_text, supply_text, " · LEGAL" if info.get("capture_legal") else ""]
		marker.modulate = Color("f4b75e") if node.get("contested") == true else Color("9ba4ad") if not info.get("owner_known", false) else Color("f4b75e") if node.get("owner") == null else Color("f07872") if node.owner == 0 else Color("78b7ff")
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
	var selected := target_selector.select(projection, topology_model, actor, target_model, "", yaw)
	target_model = selected
	var result := "Goal: %s" % str(selected.get("text", "No confirmed target; hold known ground."))
	var target: Dictionary = topology_model.get("by_id", {}).get(selected.get("target_id", ""), {})
	if not target.is_empty():
		var progress: Array = target.get("progress", [])
		var range_m := Vector2(actor.x, actor.z).distance_to(Vector2(target.x, target.z)) if not actor.is_empty() else distance
		result = "Goal: %s · %s · %.0f m (planar)\n%s" % [target.get("label", target.id), Guidance.bearing(actor, target, yaw) if not actor.is_empty() else "bearing unknown", range_m, selected.get("text", "")]
		var activity := "CONTESTED" if target.get("contested") == true else "live" if target.get("live") == true else "inactive" if target.get("live") == false else "activity unknown"
		var own_progress := "unknown"
		if progress.size() == 2 and projection.get("team") is int: own_progress = "%.0f%%" % (float(progress[int(projection.team)]) * 100)
		result += "\nOwner %s · %s · capture %s · supply %s · your progress %s" % ["unknown" if not target.get("owner_known", false) else ("Neutral" if target.get("owner") == null else "Team %d" % int(target.owner)), activity, "LEGAL" if target.get("capture_legal") else "not legal/unknown", target.get("supply", "UNKNOWN"), own_progress]
	result += "\nTeam %s · FLUX %s · own REQ %s\nC: HOLD / recruitment. HOLD receipt ≠ node capture." % [str(projection.get("team")) if projection.get("team") != null else "unknown", known(projection.get("flux")), known(projection.get("req"))]
	if projection.get("coop") == true:
		var recruitment: Dictionary = projection.get("recruitment", {})
		result += "\nWave %s · %s · recruitment window %s" % [str(recruitment.get("wave")) if recruitment.get("wave") != null else "unknown", str(recruitment.get("phase")) if recruitment.get("phase") != null else "phase unknown", "open" if recruitment.get("open") == true else "closed" if recruitment.get("open") == false else "unknown"]
	return result
