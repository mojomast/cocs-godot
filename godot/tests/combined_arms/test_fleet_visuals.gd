extends SceneTree
const Fleet = preload("res://combined_arms/fleet.gd")
const Shots = preload("res://vehicles/shot_fx.gd")
const HUD = preload("res://combined_arms/hud.gd")
var failures := 0
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL ", label)

func vehicle(id: int, kind: String) -> Dictionary:
	return {"id":id, "kind":kind, "x":float(id), "y":2.0, "z":-3.0, "yaw":PI / 2,
		"pitchBody":0.14, "roll":-0.12, "turretYaw":0.25, "vx":2.0, "vz":0.0,
		"health":100, "respawnTimer":0, "driver":null, "gunner":null, "passengers":[]}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fleet = Fleet.new()
	root.add_child(fleet)
	var state := {"vehicles":[], "actors":[], "time":1.0}
	var kinds := ["puma", "hornet", "titan", "scout", "transport"]
	for i in kinds.size(): state.vehicles.append(vehicle(i, kinds[i]))
	check(fleet.apply_state(state), "complete five-kind roster")
	for i in kinds.size():
		var model: Node3D = fleet.vehicle_node(i)
		check(model != null and model.position.is_equal_approx(Vector3(i, 2, -3)), "source XYZ " + kinds[i])
		check(model.rotation_order == EULER_ORDER_XYZ and model.rotation.is_equal_approx(Vector3(0.14, PI / 2, -0.12)), "source yaw/roll/pitch " + kinds[i])
		check(is_equal_approx(model.turret.rotation.y, 0.25), "relative turret " + kinds[i])
		check(model.get("kind") == kinds[i] and model.get_child_count() > 1, "source-specific chassis geometry " + kinds[i])
		if i > 0:
			check(model.wheels.size() == {"hornet":0, "titan":16, "scout":4, "transport":6}[kinds[i]], "wheel/flight layout " + kinds[i])
	var original: Node3D = fleet.vehicle_node(2)
	state.time = 1.05
	check(fleet.apply_state(state) and fleet.vehicle_node(2) == original and original.wheels[0].rotation.x > 0, "stable node and signed wheel roll")
	state.vehicles[2].health = 0
	check(fleet.apply_state(state) and not original.visible, "destroyed hidden")
	state.vehicles[2].health = 650
	state.vehicles[2].respawnTimer = 2
	check(fleet.apply_state(state) and not original.visible, "respawn waiting hidden")
	state.vehicles[2].respawnTimer = 0
	check(fleet.apply_state(state) and original.visible, "respawn visible")
	state.vehicles[3].x = NAN
	check(not fleet.apply_state(state) and original.visible, "atomic invalid roster")
	state.vehicles[3].x = 3.0
	var shots = Shots.new()
	root.add_child(shots)
	var shot := {"type":"vehicle-shot", "id":9, "actor":1, "vehicle":2, "barrel":0,
		"from":{"x":0,"y":1,"z":0}, "to":{"x":3,"y":1,"z":5}}
	shots.apply_events([shot, shot])
	check(shots.traces.size() == 1 and shots.seen.size() == 1, "source identity deduplicated")
	for i in 100:
		var next := shot.duplicate(true)
		next.id = 10 + i
		shots.apply_events([next])
	check(shots.traces.size() == Shots.MAX_TRACES, "bounded source traces")
	shots.clear_round()
	check(shots.traces.is_empty() and shots.seen.is_empty(), "shot round reset")
	var hud = HUD.new()
	var card: String = hud.vehicle_card({"kind":"titan", "health":200, "maxHealth":650, "heat":1.0, "overheated":true,
		"respawnTimer":3.5, "driver":0, "gunner":null, "passengers":[2]}, "driver")
	check(card.contains("Seats 2/3") and card.contains("200 / 650") and card.contains("OVERHEATED") and card.contains("3.5s"), "read-only source vehicle card")
	check(hud.vehicle_card({"kind":"titan"}, "driver").contains("Hull —") and hud.vehicle_card({"kind":"titan"}, "driver").contains("Heat —"), "missing telemetry cannot become fabricated zero")
	check(hud.vehicle_card({"kind":"puma", "health":0, "maxHealth":300, "heat":0.0}, "driver").contains("0 / 300") and hud.vehicle_card({"kind":"puma", "health":0, "maxHealth":300, "heat":0.0}, "driver").contains("DESTROYED"), "source hull health telemetry preserves zero and destruction")
	state.vehicles.clear()
	check(fleet.apply_state(state) and fleet.vehicle_node(2) == null, "roster disappearance")
	fleet.clear_round()
	check(fleet.secondary.is_empty() and fleet.secondary_stamps.is_empty() and fleet.nodes.is_empty(), "full round reset")
	print("FLEET VISUALS checks=", checks, " failures=", failures, " synthetic=true")
	quit(1 if failures else 0)
