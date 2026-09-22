extends Node3D
## Consumes a complete decoded snapshot state, not its protocol envelope.
const Puma = preload("res://vehicles/puma.gd")
var nodes: Dictionary = {}
var stamps: Dictionary = {}

func vehicle_node(id: Variant) -> Node3D:
	return nodes.get(id)

func clear_round() -> void:
	for n: Node3D in nodes.values():
		remove_child(n)
		n.queue_free()
	nodes.clear()
	stamps.clear()

func numeric(v: Variant) -> bool:
	return (v is float or v is int) and is_finite(float(v))

func valid_id(v: Variant) -> bool:
	return (v is String and not v.is_empty()) or (numeric(v) and float(v) >= 0 and float(v) == floorf(float(v)))

func apply_state(state: Dictionary, local_actor_id: int = -1) -> bool:
	# Reject malformed complete rosters atomically; caller handles ordering/rounds.
	if not state.get("vehicles") is Array or not state.get("actors", []) is Array: return false
	var seen: Dictionary = {}
	for v: Variant in state.vehicles:
		if not v is Dictionary or not valid_id(v.get("id")) or seen.has(v.id): return false
		seen[v.id] = true
		if v.get("kind") != "puma": continue
		for field: String in ["x", "y", "z", "yaw", "roll", "pitchBody", "health", "respawnTimer", "vx", "vz", "turretYaw"]:
			if not numeric(v.get(field)): return false
	var active: Dictionary = {}
	for v: Dictionary in state.vehicles:
		if v.get("kind") != "puma": continue
		active[v.id] = true
		if not nodes.has(v.id):
			var created = Puma.new()
			add_child(created)
			nodes[v.id] = created
		var n = nodes[v.id]
		n.position = Vector3(v.x, v.y, v.z)
		# Three.js default Euler XYZ corresponds to Godot EULER_ORDER_XYZ.
		n.rotation_order = EULER_ORDER_XYZ
		n.rotation = Vector3(v.pitchBody, v.yaw, v.roll)
		n.visible = v.health > 0 and v.respawnTimer <= 0
		n.turret.rotation.y = v.turretYaw
		var team := -1
		for a: Variant in state.get("actors", []):
			if a is Dictionary and a.get("id") == v.get("driver") and numeric(a.get("team")):
				team = int(a.team)
		n.set_team(team)
		n.set_meta("driver", v.get("driver"))
		n.set_meta("local_driver", local_actor_id >= 0 and v.get("driver") == local_actor_id)
		# No steer angle exists on wire: leave wheel steering neutral.
		# Cosmetic rolling from signed forward velocity, bounded to 100ms per snapshot.
		if numeric(state.get("time")):
			var stamp: float = float(state.time)
			var previous: float = float(stamps.get(v.id, stamp))
			if stamp >= previous:
				if n.visible:
					var speed: float = float(v.vx) * sin(float(v.yaw)) + float(v.vz) * cos(float(v.yaw))
					for wheel: Node3D in n.wheels:
						wheel.rotation.x = wrapf(wheel.rotation.x + speed * clampf(stamp - previous, 0, 0.1) / 0.42, -PI, PI)
				stamps[v.id] = stamp
	for id: Variant in nodes.keys():
		if not active.has(id):
			var n: Node3D = nodes[id]
			remove_child(n)
			n.queue_free()
			nodes.erase(id)
			stamps.erase(id)
	return true
