extends RefCounted
const PASSENGERS := {"puma":2, "hornet":1, "titan":1, "scout":1, "transport":4}
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
		if not PASSENGERS.has(v.get("kind")): continue
		var claims := int(v.get("driver") == a.get("id")) + int(v.get("gunner") == a.get("id"))
		for occupant: Variant in v.get("passengers", []):
			if occupant == a.get("id"): claims += 1
		if claims != 1: continue
		var seat: Variant = a.get("vehicleSeat")
		var index: Variant = a.get("vehicleSeatIndex")
		if not (index is int or index is float) or not is_finite(float(index)) or float(index) != floorf(float(index)): continue
		if seat == "driver" and index == 0 and v.get("driver") == a.get("id"): return v
		if seat == "gunner" and index == 0 and v.kind != "scout" and v.get("gunner") == a.get("id"): return v
		var passengers: Array = v.get("passengers", [])
		if seat == "passenger" and index >= 0 and index < PASSENGERS[v.kind] and index < passengers.size() and passengers[int(index)] == a.get("id"): return v
	return {}

static func permitted(state: Dictionary, a: Dictionary, v: Dictionary, age: float) -> bool:
	if state.get("over", false) or not is_finite(age) or age < 0 or age >= 0.5 or not alive(a): return false
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
		var capacity: int = PASSENGERS.get(v.get("kind"), 0)
		var passengers: Array = v.get("passengers", [])
		for index in range(capacity):
			if index >= passengers.size() or passengers[index] == null: open = true
		if not open: continue
		if Vector2(a.x, a.z).distance_to(Vector2(v.x, v.z)) < 2.4 and absf(float(a.y)-float(v.y)) < (3.2 if v.get("flight", false) else 2.4): return v
	return {}
