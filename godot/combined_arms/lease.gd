extends RefCounted
## Snapshot-only identity resolution. Proximity is a prompt, never a control lease.
static func actor_for(state: Dictionary, id: int) -> Dictionary:
	if id < 0: return {}
	for a: Dictionary in state.get("actors", []):
		if a.get("id") == id: return a
	return {}

static func alive(a: Dictionary) -> bool:
	return not a.is_empty() and float(a.get("health", 0)) > 0 and float(a.get("dead", 1)) <= 0

static func vehicle_for(state: Dictionary, a: Dictionary) -> Dictionary:
	if not alive(a) or a.get("vehicleId") == null: return {}
	for v: Dictionary in state.get("vehicles", []):
		if v.get("id") != a.vehicleId or float(v.get("health", 0)) <= 0 or float(v.get("respawnTimer", 1)) > 0: continue
		var seat: Variant = a.get("vehicleSeat")
		if seat in ["driver", "gunner"] and v.get(seat) == a.get("id"): return v
		if seat == "passenger" and a.get("id") in v.get("passengers", []): return v
	return {}

static func permitted(state: Dictionary, a: Dictionary, v: Dictionary, age: float) -> bool:
	if state.get("config", {}).get("mode") != "combined-arms" or state.get("over", false) or age >= 0.5 or not alive(a): return false
	# Missing/mismatched mounted vehicle fails closed, never falls back to infantry.
	return a.get("vehicleId") == null or not v.is_empty()

static func nearby(state: Dictionary, a: Dictionary) -> Dictionary:
	if not alive(a) or a.get("vehicleId") != null: return {}
	for flag: Dictionary in state.get("flags", []):
		if flag.get("carrier") == a.get("id"): return {}
	# Source enterVehicle chooses first eligible vehicle, not nearest, and has no team lock.
	for v: Dictionary in state.get("vehicles", []):
		if float(v.get("health", 0)) <= 0 or float(v.get("respawnTimer", 1)) > 0: continue
		var open: bool = v.get("driver") == null or (v.get("kind") != "scout" and v.get("gunner") == null)
		var capacity: int = {"puma":2,"titan":1,"scout":1,"transport":4,"hornet":1}.get(v.get("kind"), 0)
		var passengers: Array = v.get("passengers", [])
		for index in range(capacity):
			if index >= passengers.size() or passengers[index] == null: open = true
		if not open: continue
		if Vector2(a.x, a.z).distance_to(Vector2(v.x, v.z)) < 2.4 and absf(float(a.y)-float(v.y)) < (3.2 if v.get("flight", false) else 2.4): return v
	return {}
