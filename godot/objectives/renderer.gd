extends Node3D
## Presentation only. Never changes input or authoritative dictionaries.
var markers: Dictionary = {}
var mode := ""
var hud_text := "Objectives unavailable"
var rendered: Dictionary = {}
const RED := Color("ff775f")
const BLUE := Color("69c9ff")

static func numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func point(value: Variant) -> bool:
	return value is Dictionary and numeric(value.get("x")) and numeric(value.get("y")) and numeric(value.get("z"))

static func team_name(value: Variant) -> String:
	return "RED [1]" if value == 0 else ("BLUE [2]" if value == 1 else "UNKNOWN")

func clear_round() -> void:
	for node: Node in markers.values(): node.free()
	markers.clear()
	rendered.clear()
	mode = ""
	hud_text = "Objectives unavailable"

func shape(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)

func marker(key: String, kind: String, color: Color) -> Node3D:
	if markers.has(key): return markers[key]
	var node := Node3D.new()
	node.name = key
	add_child(node)
	markers[key] = node
	if kind == "flag":
		shape(node, Vector3(0.1, 2.8, 0.1), Vector3(0, 1.4, 0), Color.WHITE)
		shape(node, Vector3(1.2, 0.8, 0.08), Vector3(0.6, 2.3, 0), color)
	elif kind == "cart":
		shape(node, Vector3(2.2, 1.0, 1.4), Vector3(0, 1.0, 0), color)
		shape(node, Vector3(1.3, 0.4, 1.0), Vector3(0, 1.7, 0), Color("ece2c4"))
		for x: float in [-0.9, 0.9]:
			for z: float in [-0.8, 0.8]: shape(node, Vector3(0.5, 0.6, 0.3), Vector3(x, 0.3, z), Color("27313c"))
	else:
		shape(node, Vector3(2.2, 0.08, 2.2), Vector3(0, 0.04, 0), color)
	var title := Label3D.new()
	title.name = "Title"
	title.font_size = 32
	title.pixel_size = 0.018
	title.position.y = 3.2 if kind == "flag" else 2.4
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.add_child(title)
	return node

func put(key: String, kind: String, data: Dictionary, text: String, color: Color, seen: Dictionary) -> void:
	if not point(data): return
	var node := marker(key, kind, color)
	node.position = Vector3(data.x, data.y, data.z)
	node.get_node("Title").text = text
	seen[key] = true
	rendered[key] = {"x":node.position.x,"y":node.position.y,"z":node.position.z,"text":text}

func configure_map(map: Dictionary, selected_mode: String) -> void:
	clear_round()
	mode = selected_mode
	var seen: Dictionary = {}
	if mode == "ctf":
		var bases: Variant = map.get("flagSpawns")
		if bases is Dictionary:
			for team: int in [0, 1]:
				var base: Variant = bases.get(str(team), bases.get(team))
				if base is Dictionary and numeric(base.get("x")) and numeric(base.get("z")):
					put("guide_base_%d" % team, "base", {"x":base.x,"y":base.get("y",0),"z":base.z}, team_name(team) + " HOME", RED if team == 0 else BLUE, seen)
	elif mode == "payload":
		var routes: Variant = map.get("routes")
		if routes is Array:
			for route: Variant in routes:
				if not route is Dictionary or route.get("id") != "sunscar-freight-road": continue
				var points: Variant = route.get("points")
				if not points is Array or points.size() > 32: continue
				for index: int in range(points.size()):
					var p: Variant = points[index]
					if p is Array and p.size() == 2 and numeric(p[0]) and numeric(p[1]):
						put("guide_road_%d" % index, "base", {"x":p[0],"y":0,"z":p[1]}, "ROAD %d / guidance" % (index+1), Color("978567"), seen)

func apply_state(state: Dictionary, local_actor_id: int) -> void:
	var config: Variant = state.get("config")
	var next_mode: String = str(config.get("mode", "")) if config is Dictionary else ""
	if mode != next_mode: clear_round()
	mode = next_mode
	var seen: Dictionary = {}
	rendered.clear()
	var local_team: Variant = null
	var actors: Variant = state.get("actors", [])
	if actors is Array:
		for actor: Variant in actors:
			if actor is Dictionary and actor.get("id") == local_actor_id: local_team = actor.get("team")
	var scores: Variant = state.get("teamScores")
	var score := "? : ?"
	if scores is Dictionary: score = "%s : %s" % [str(scores.get("0", scores.get(0, "?"))), str(scores.get("1", scores.get(1, "?")))]
	var lines: Array[String] = ["%s  |  YOU: %s  |  %s" % [mode.to_upper(), team_name(local_team), score]]
	if mode == "ctf":
		var flags: Variant = state.get("flags")
		if flags is Array and flags.size() <= 2:
			for flag: Variant in flags:
				if not flag is Dictionary or not numeric(flag.get("team")): continue
				if flag.team != 0 and flag.team != 1: continue
				var team: int = int(flag.team)
				var key := "flag_%d" % team
				if seen.has(key): continue
				var status: String = str(flag.get("state", "unknown"))
				if status not in ["at-base", "carried", "dropped"]: continue
				var title := "%s / %s" % [team_name(team), status]
				if status == "carried": title += " / actor %s" % str(flag.get("carrier", "?"))
				# Snapshot position remains authoritative even if carrier was omitted.
				put(key, "flag", flag, title, RED if team == 0 else BLUE, seen)
				lines.append(title)
		if seen.is_empty(): lines.append("Flag state unavailable")
		lines.append("Touch enemy flag to carry; E: nearby teammate pass, otherwise drop.")
		lines.append("Touch friendly dropped flag to return. Capture at uncontested home flag.")
	elif mode == "payload":
		var objective: Variant = state.get("objectives")
		if objective is Dictionary and objective.get("kind") == "payload":
			var payload: Variant = objective.get("payload")
			if payload is Dictionary:
				var status := "UNKNOWN"
				if payload.get("delivered") == true: status = "DELIVERED"
				elif payload.get("contested") == true: status = "CONTESTED"
				elif payload.has("pushing") and payload.get("contested") == false:
					status = "IDLE" if payload.pushing == null else "PUSHING " + team_name(payload.pushing)
				var position: Variant = payload.get("position")
				if point(position): put("cart", "cart", position, "PAYLOAD / " + status, Color("edba59"), seen)
				lines.append("%s | distance %s / %s | checkpoints %s / %s" % [status, str(payload.get("distance", "?")), str(payload.get("total", "?")), str(payload.get("checkpointsReached", "?")), str(payload.get("checkpointCount", "?"))])
				lines.append("Role: " + ("ESCORT" if local_team != null and local_team == objective.get("attacker") else ("DEFEND" if local_team != null and local_team == objective.get("defender") else "UNKNOWN")))
			var zones: Variant = objective.get("zones")
			if zones is Array and zones.size() <= 6:
				for zone: Variant in zones:
					if not zone is Dictionary or not zone.get("id") is String or zone.id.length() > 64: continue
					var label := str(zone.id) + " / " + ("BANKED" if zone.get("owner") != null and zone.get("owner") == objective.get("attacker") else "CHECKPOINT")
					put("cp_" + zone.id, "base", zone, label, Color("bcd98c"), seen)
		lines.append("Escort automatically in cart radius; both teams contest; defenders roll back.")
	else: lines = ["Objectives unavailable"]
	if state.get("over") == true: lines.append("ROUND OVER / authoritative winner: " + str(state.get("winner", "unknown")))
	for key: String in markers.keys():
		if not seen.has(key) and not key.begins_with("guide_"):
			markers[key].free()
			markers.erase(key)
	hud_text = "\n".join(lines)
