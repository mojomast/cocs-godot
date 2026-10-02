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
var quality := 1
var channels: Dictionary = {}
var catalog: Dictionary = Status.new().catalog

func set_quality(value: int) -> void:
	quality = clampi(value, 0, 2)
	var budget := channel_budget()
	while channels.size() > budget:
		var key: String = channels.keys().back()
		channels[key].free()
		channels.erase(key)
	while bursts.size() > burst_budget(): bursts.pop_front().node.free()

func channel_budget() -> int:
	return [8, 24, 32][quality]

func burst_budget() -> int:
	return [4, 12, 16][quality]

func channel(key: String, at: Vector3, radius: float, color: Color, present: Dictionary) -> void:
	present[key] = true
	if not channels.has(key):
		if channels.size() >= channel_budget(): return
		var ring := TorusMesh.new()
		ring.inner_radius = 0.88
		ring.outer_radius = 1.0
		ring.rings = 16
		ring.ring_segments = 6
		channels[key] = mesh_node(ring, color)
	channels[key].position = at
	channels[key].scale = Vector3.ONE * radius

func passive_channels(actor: Dictionary, present: Dictionary) -> void:
	# Source ability-vfx._verb: snapshot channels, never inferred ability timers.
	# Alignment Review remains owned by combat_shields; no duplicate shield shell.
	var verb: Variant = actor.get("verbState")
	var at: Variant = point(actor)
	if not verb is Dictionary or verb.get("active") != true or at == null: return
	var key := "passive:%s" % actor.get("id")
	match str(verb.get("verb", "")):
		"heat":
			var maximum := Status.number(catalog.get("verbs", {}).get("heat", {}).get("numbers", {}).get("maxFireRateBonus"))
			var heat := clampf(Status.number(verb.get("heat")) / maxf(maximum, 0.001), 0.0, 1.0)
			if heat > 0.0: channel(key, at + Vector3(0, 1.12, 0.18), 0.08 + 0.32 * heat, Color("ff8b4d"), present)
		"deep-compute":
			var charge := clampf(Status.number(verb.get("charge")), 0.0, 1.0)
			if charge > 0.0: channel(key, at + Vector3(0, 0.35, 0), 0.5 + 0.85 * charge, Color("56c5f2"), present)
		"tool-use":
			if Status.number(verb.get("windowIn")) > 0.0: channel(key, at + Vector3(0, 0.12, 0), 1.05, Color("b797ff"), present)
		"braced":
			if actor.get("grounded") == true and Status.number(verb.get("combatIn")) <= 0.0 and Status.number(actor.get("spawnArmor")) > Status.number(actor.get("armor")):
				channel(key, at + Vector3(0, 0.12, 0), 0.4, Color("57b9ff"), present)

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

func cable(key: String, start: Vector3, end: Vector3, rope: bool) -> bool:
	var length := start.distance_to(end)
	if length < 0.02 or length > 100.0: return false
	if not slots.has(key):
		if slots.size() >= LIMIT: return false
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
	return true

func apply_state(state: Dictionary) -> void:
	var present := {}
	var live_channels := {}
	if state.get("over", false):
		clear_visuals()
		return
	for actor: Dictionary in state.get("actors", []):
		if Status.number(actor.get("health")) <= 0.0 or Status.number(actor.get("dead")) > 0.0 or actor.get("vehicleId") != null: continue
		passive_channels(actor, live_channels)
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
				if cable(key, start + Vector3(0, 0.08, 0), end + Vector3(0, 0.08, 0), true): present[key] = true
		var hook: Variant = point(movement.get("grapple"))
		var origin: Variant = point(actor)
		if hook != null and origin != null and movement.get("phase") == "active":
			key = "hook:%s" % actor.get("id")
			if cable(key, origin + Vector3(0, float(actor.get("eyeHeight", 1.45)) - 0.2, 0), hook, false): present[key] = true
	for key: String in slots.keys():
		if not present.has(key):
			for node: Node in slots[key].values(): node.free()
			slots.erase(key)
	for key: String in channels.keys():
		if not live_channels.has(key):
			channels[key].free()
			channels.erase(key)

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
		if bursts.size() >= burst_budget(): bursts.pop_front().node.free()
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
	for node: Node in channels.values(): node.free()
	channels.clear()
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
