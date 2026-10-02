extends Node3D
## Public movement anchors make the shared Qwen route discoverable. No physics,
## target searches or replicated gameplay. Existing shield/dash FX keep ownership.
const Status = preload("res://player_gameplay/status.gd")
const LIMIT := 32
var slots: Dictionary = {}
var power_seen: Dictionary = {}
var highest := -1
var bursts: Array[Dictionary] = []
var reduced_motion := false
var accepted_powers := 0

static func point(value: Variant) -> Variant:
	if not value is Dictionary: return null
	for key in ["x", "y", "z"]:
		if not (value.get(key) is float or value.get(key) is int) or not is_finite(float(value[key])) or absf(float(value[key])) > 10000: return null
	return Vector3(value.x, value.y, value.z)

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.albedo_color = color
	return result

func mesh_node(mesh: Mesh, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func cable(key: String, start: Vector3, end: Vector3, rope: bool) -> void:
	var length := start.distance_to(end)
	if length < 0.02 or length > 100.0: return
	if not slots.has(key):
		if slots.size() >= LIMIT: return
		var beam := CylinderMesh.new()
		beam.top_radius = 0.028
		beam.bottom_radius = 0.028
		beam.height = 1.0
		beam.radial_segments = 6
		var marker := TorusMesh.new()
		marker.inner_radius = 0.34
		marker.outer_radius = 0.42
		marker.rings = 16
		marker.ring_segments = 6
		slots[key] = {"beam":mesh_node(beam, Color("79e7d1")), "marker":mesh_node(marker, Color("ffd166"))}
	var slot: Dictionary = slots[key]
	slot.beam.position = (start + end) * 0.5
	var direction := (end - start).normalized()
	slot.beam.quaternion = Quaternion(Vector3.UP, direction)
	slot.beam.scale = Vector3(1, length, 1)
	slot.marker.position = start + Vector3(0, 0.07, 0)
	slot.marker.visible = rope

func apply_state(state: Dictionary) -> void:
	var present := {}
	if state.get("over", false):
		clear_visuals()
		return
	for actor: Dictionary in state.get("actors", []):
		if Status.number(actor.get("health")) <= 0.0 or actor.get("vehicleId") != null: continue
		var movement: Variant = actor.get("movement")
		if not movement is Dictionary or movement.get("enabled") != true: continue
		var anchor: Variant = movement.get("anchor")
		var key := "rope:%s" % actor.get("id")
		if anchor is Dictionary and Status.number(anchor.get("life")) > 0.0:
			var start: Variant = point(anchor.get("from"))
			var end: Variant = point(anchor)
			if start != null and end != null:
				# Core._ropePlace stores from at feet, whereas movement.anchor is eye.
				start.y -= float(actor.get("eyeHeight", 1.45))
				# Thin route indicator floats above source endpoints, including flat
				# floor casts; it is not a collision or a simulated sagging cable.
				cable(key, start + Vector3(0, 0.08, 0), end + Vector3(0, 0.08, 0), true)
				present[key] = true
		var hook: Variant = point(movement.get("grapple"))
		var origin: Variant = point(actor)
		if hook != null and origin != null and movement.get("phase") == "active":
			key = "hook:%s" % actor.get("id")
			cable(key, origin + Vector3(0, float(actor.get("eyeHeight", 1.45)) - 0.2, 0), hook, false)
			present[key] = true
	for key: String in slots.keys():
		if not present.has(key):
			for node: Node in slots[key].values(): node.free()
			slots.erase(key)

func apply_events(events: Array, allowed: bool) -> void:
	for event: Variant in events:
		if not event is Dictionary or not (event.get("id") is int or event.get("id") is float): continue
		var id := int(event.id)
		if id < 0 or power_seen.has(id) or id < highest - 2048: continue
		highest = maxi(highest, id)
		power_seen[id] = true
		if power_seen.size() > 512:
			for old: int in power_seen.keys():
				if old < highest - 256: power_seen.erase(old)
		if not allowed or event.get("type") != "power": continue
		# Guardrail/Phase Step have existing interference/dash presentation.
		var colors := {"openclaw":"ff8b5c", "hermes":"ffd166", "opencode":"70ffe6", "codex":"8affc1", "roo":"b797ff"}
		if not colors.has(event.get("harness")): continue
		var position_value: Variant = point(event.get("pos"))
		if position_value == null: continue
		accepted_powers += 1
		if bursts.size() >= 16: bursts.pop_front().node.free()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.8
		ring.outer_radius = 0.88
		ring.rings = 24
		ring.ring_segments = 6
		var node := mesh_node(ring, Color(colors[event.harness]))
		node.position = position_value - Vector3(0, 0.9, 0)
		# Five silhouettes: upright heal, crossed parallel fire, low burst,
		# elevated speed halo and tilted jam. Visual radii imply no hit volume.
		match str(event.harness):
			"codex": node.rotation.x = PI / 2.0
			"opencode": node.rotation.z = PI / 2.0
			"hermes": node.position.y += 1.0
			"roo": node.rotation.z = PI / 4.0
		bursts.append({"node":node, "remaining":0.6})

func advance(delta: float) -> void:
	for index in range(bursts.size() - 1, -1, -1):
		bursts[index].remaining -= delta
		if bursts[index].remaining <= 0.0:
			bursts[index].node.free()
			bursts.remove_at(index)
		elif not reduced_motion: bursts[index].node.scale = Vector3.ONE * (1.0 + (0.6 - bursts[index].remaining) * 1.5)

func clear_visuals() -> void:
	for slot: Dictionary in slots.values():
		for node: Node in slot.values(): node.free()
	slots.clear()
	for burst: Dictionary in bursts: burst.node.free()
	bursts.clear()

func clear_round() -> void:
	clear_visuals()
	power_seen.clear()
	highest = -1
	accepted_powers = 0
