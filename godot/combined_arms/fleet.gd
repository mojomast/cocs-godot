extends "res://vehicles/renderer.gd"
const Chassis = preload("res://combined_arms/chassis.gd")
const SECONDARY := ["titan", "scout", "transport", "hornet"]
var secondary: Dictionary = {}
var secondary_stamps: Dictionary = {}
func vehicle_node(id: Variant) -> Node3D:
	return nodes.get(id, secondary.get(id))
func clear_round() -> void:
	super.clear_round()
	for n: Node3D in secondary.values():
		remove_child(n)
		n.queue_free()
	secondary.clear()
	secondary_stamps.clear()
func apply_state(state: Dictionary, local_actor_id: int = -1) -> bool:
	if not state.get("vehicles") is Array or state.vehicles.size() > 64: return false
	for v: Variant in state.vehicles:
		if not v is Dictionary: return false
		if v.get("kind") in SECONDARY:
			for field: String in ["x", "y", "z", "yaw", "roll", "pitchBody", "health", "respawnTimer", "turretYaw", "vx", "vz"]:
				if not numeric(v.get(field)): return false
	if not super.apply_state(state, local_actor_id): return false
	var seen: Dictionary = {}
	for v: Dictionary in state.vehicles:
		if not v.get("kind") in SECONDARY: continue
		seen[v.id] = true
		if secondary.has(v.id) and secondary[v.id].kind != v.kind:
			var old: Node3D = secondary[v.id]
			remove_child(old)
			old.queue_free()
			secondary.erase(v.id)
			secondary_stamps.erase(v.id)
		if not secondary.has(v.id):
			var n := Chassis.new(v.kind)
			add_child(n)
			secondary[v.id] = n
		var n = secondary[v.id]
		n.position = Vector3(v.x, v.y, v.z)
		n.rotation_order = EULER_ORDER_XYZ
		n.rotation = Vector3(v.pitchBody, v.yaw, v.roll)
		n.visible = v.health > 0 and v.respawnTimer <= 0
		n.turret.rotation.y = v.turretYaw
		if numeric(state.get("time")):
			var stamp: float = float(state.time)
			var previous: float = float(secondary_stamps.get(v.id, stamp))
			if stamp >= previous:
				if n.visible:
					var speed: float = float(v.vx) * sin(float(v.yaw)) + float(v.vz) * cos(float(v.yaw))
					for wheel: Node3D in n.wheels:
						wheel.rotation.x = wrapf(wheel.rotation.x + speed * clampf(stamp - previous, 0, 0.1) / wheel.position.y, -PI, PI)
				secondary_stamps[v.id] = stamp
	for id: Variant in secondary.keys():
		if not seen.has(id):
			var n: Node3D = secondary[id]
			remove_child(n)
			n.queue_free()
			secondary.erase(id)
			secondary_stamps.erase(id)
	return true
