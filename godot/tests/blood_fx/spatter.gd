extends SceneTree
## Wall spatter contracts. Death bursts and spurting impacts must mark vertical
## surfaces as well as the floor, only on surfaces that face the body and that the
## burst can physically reach, inside the plane they were queried on.
##
## Everything here is an arranged fixture: a floor, a wide wall, a narrow pillar
## and a low ledge. Never live gameplay.

const Controller = preload("res://blood_fx/controller.gd")
const SurfaceQuery = preload("res://blood_fx/surface_query.gd")

## Wall occupies x [-5, 5], y [0, 6], z [-7, -6]; the body faces its +Z face.
const WALL := {"x": 0.0, "z": -6.5, "w": 10.0, "h": 6.0, "d": 1.0}
const WALL_NEAR_Z := -6.0
const WALL_FAR_Z := -7.0
## Pillar occupies x [6.4, 7.6], y [0, 5], z [-6.6, -5.4].
const PILLAR_FACE_Z := -5.4
const PILLAR := {"x": 7.0, "z": -6.0, "w": 1.2, "h": 5.0, "d": 1.2}
const LEDGE := {"x": -8.0, "z": -6.0, "w": 3.0, "h": 1.2, "d": 3.0}

var failed := false
var checks := 0
var notes: Array[String] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error(message)
		notes.append(message)


func fixture_map() -> Dictionary:
	return {
		"id": "blood-fx-spatter-fixture",
		"bounds": {"minX": -25.0, "maxX": 25.0, "minZ": -25.0, "maxZ": 25.0},
		"blocks": [WALL, PILLAR, LEDGE],
		"terrain": {"support_triangles": [
			{"indices": [0, 1, 2], "normal": [0, 1, 0], "vertices": [[-25, 0, -25], [-25, 0, 25], [25, 0, 25]]},
			{"indices": [0, 1, 2], "normal": [0, 1, 0], "vertices": [[-25, 0, -25], [25, 0, 25], [25, 0, -25]]},
		]},
	}


func actor(id: int, x: float, z: float, health: float = 100.0) -> Dictionary:
	return {"id": id, "x": x, "y": 0.0, "z": z, "health": health, "maxHealth": 100.0, "armor": 0.0,
		"temporaryShield": 0.0, "vx": 0.0, "vy": 0.0, "vz": 0.0}


func state(actors: Array, time: float = 1.0) -> Dictionary:
	return {"time": time, "mapId": "blood-fx-spatter-fixture", "actors": actors}


func hit(id: int, amount: float) -> Dictionary:
	return {"type": "damage", "id": id, "actor": 2, "source": 1, "amount": amount, "shield": 0.0}


func death(id: int, position: Vector3, direction: Variant, seed: float = 3.0) -> Dictionary:
	var event := {"type": "death", "id": id, "actor": 2, "killer": 1, "seed": seed,
		"pos": {"x": position.x, "y": position.y, "z": position.z}}
	if direction is Vector3: event["direction"] = {"x": direction.x, "y": direction.y, "z": direction.z}
	return event


func live_marks(controller: Node) -> Array:
	var marks := []
	for slot: Dictionary in controller.stain_slots:
		if slot.remaining <= 0.0: continue
		var basis: Basis = slot.node.global_transform.basis
		marks.append({"position": slot.node.global_position, "normal": basis.z,
			"half": Vector3(slot.node.scale.x * 0.5, slot.node.scale.y * 0.5, 0.0), "basis": basis,
			"surface": int(slot.surface)})
	return marks


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 2.0, 2.0)
	camera.current = true
	var controller := Controller.new()
	world.add_child(controller)
	var map := fixture_map()
	var configured: Dictionary = controller.configure(camera, map)
	check(configured.ok and configured.surface_ready, "spatter fixture configures")
	var provider := SurfaceQuery.semantic_provider(map)

	var actors := [actor(1, 0.0, -2.0), actor(2, 0.0, -4.2), actor(4, 12.0, 12.0)]
	controller.apply_state(state(actors, 1.0), 1)
	check(controller.active, "public state activates the controller")

	# --- 1) impact spatter: a jet that visibly reaches the wall ------------------
	var before: Dictionary = controller.snapshot()
	controller.apply_events([hit(10, 30.0)], 1)
	var after: Dictionary = controller.snapshot()
	var cluster: int = int(after.impact_marks) - int(before.impact_marks)
	check(cluster >= 2, "an impact that reaches the wall places a cluster, not one quad (got %d)" % cluster)
	var impact_wall: int = int(after.marks_wall) - int(before.marks_wall)
	check(impact_wall >= 2, "the impact cluster lands on the vertical surface (got %d wall marks)" % impact_wall)
	for mark: Dictionary in live_marks(controller):
		if absf(float(mark.position.z) - (WALL_NEAR_Z + 0.012)) > 0.05: continue
		check(float(mark.normal.z) > 0.9, "impact marks keep the wall normal")
		check(float(mark.position.x) > -5.0 + mark.half.x and float(mark.position.x) < 5.0 - mark.half.x,
			"impact marks stay inside the wall face, never straddling an edge")

	# --- 2) death burst reaches the wall ---------------------------------------
	controller.reset()
	controller.apply_state(state(actors, 2.0), 1)
	var phase: Dictionary = controller.snapshot()
	controller.apply_events([death(11, Vector3(0.0, 1.2, -4.2), Vector3(0, 0, -1))], 1)
	var burst: Dictionary = controller.snapshot()
	var new_wall: int = int(burst.marks_wall) - int(phase.marks_wall)
	var new_floor: int = int(burst.marks_floor) - int(phase.marks_floor)
	var new_marks: int = int(burst.stains_placed) - int(phase.stains_placed)
	check(new_wall >= 2, "a death next to a wall spatters the wall (got %d wall marks)" % new_wall)
	check(new_floor >= 1, "the same death still pools on the floor below (got %d floor marks)" % new_floor)
	var budget: int = controller.settings.death_mark_count(controller.quality) + controller.settings.death_drip_count(controller.quality) + 1
	check(new_marks <= budget, "marks per death stay bounded (%d <= %d)" % [new_marks, budget])
	check(int(burst.fan_rays_cast) > 0 and int(burst.clusters_placed) > 0, "the radial fan really cast rays")
	check(int(burst.marks_skipped_facing) >= 0, "the facing filter is reported")

	# Independent verification of every placed mark.
	var body := Vector3(0.0, 1.2, -4.2)
	var marks := live_marks(controller)
	check(marks.size() > 0, "the death placed marks")
	var far_side := 0
	var floating := 0
	var behind_body := 0
	var unreachable := 0
	var straddling := 0
	var non_facing := 0
	var offender: Array = []
	for mark: Dictionary in marks:
		var position: Vector3 = mark.position
		var normal: Vector3 = mark.normal
		# a) far side of THE WALL: inside/behind its near plane within the wall's own
		#    extent, or sitting on its far plane with a normal pointing away.
		if absf(float(position.x)) <= 5.2 and float(position.y) >= -0.05 and float(position.y) <= 6.2:
			if float(position.z) < WALL_NEAR_Z - 0.02: far_side += 1
			if absf(float(position.z) - WALL_FAR_Z) < 0.25 and float(normal.z) < -0.5: far_side += 1
		# b) normal must face the body
		var toward: Vector3 = body - position
		if toward.length_squared() > 0.0004 and normal.dot(toward.normalized()) <= 0.1: non_facing += 1
		# c) reachable from the body without passing through geometry
		var end := position + normal * 0.06
		var direction := end - body
		var distance := direction.length()
		if distance > 0.2:
			var probe: Dictionary = provider.call(body, end - direction / distance * 0.06)
			if not probe.is_empty():
				unreachable += 1
				offender.append([mark.position, mark.normal, int(mark.surface), probe.get("position")])
		# d) a wall mark's quad corners must all stay on the same flat face
		if int(mark.surface) == Controller.SURFACE_WALL:
			var half: Vector3 = mark.half
			var basis: Basis = mark.basis
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					var corner: Vector3 = position + basis.x * half.x * sx + basis.y * half.y * sy
					if absf(corner.z - position.z) > 0.02: floating += 1
					if float(corner.y) < 0.02 or float(corner.y) > 6.0 or absf(float(corner.x)) > 5.0: straddling += 1
		if body.z < position.z + 0.001 and normal.z < -0.5: behind_body += 1
	check(far_side == 0, "no mark lands on the far side of the wall (got %d) %s" % [far_side, str(notes)])
	check(non_facing == 0, "every mark faces the body (got %d wrong)" % non_facing)
	check(unreachable == 0, "every mark is reachable from the body (got %d blocked) offender=%s" % [unreachable, str(offender)])
	check(floating == 0, "every wall quad stays in the wall plane (got %d floating)" % floating)
	check(straddling == 0, "no wall quad straddles an edge or leaves its face (got %d)" % straddling)
	check(behind_body == 0, "no mark faces away behind the body")

	# --- 3) death away from any wall: floor only -------------------------------
	controller.reset()
	controller.apply_state(state([actor(1, 14.0, 8.0), actor(2, 12.0, 12.0)], 3.0), 1)
	var open_before: Dictionary = controller.snapshot()
	controller.apply_events([death(12, Vector3(12.0, 1.2, 12.0), null, 5.0)], 1)
	var open_after: Dictionary = controller.snapshot()
	check(int(open_after.marks_wall) == int(open_before.marks_wall), "no wall marks are invented far from any wall")
	check(int(open_after.marks_floor) > int(open_before.marks_floor), "an unbiased death still marks the floor")
	var open_marks := live_marks(controller)
	var facing_ok := true
	for mark: Dictionary in open_marks:
		var toward: Vector3 = Vector3(12.0, 1.2, 12.0) - mark.position
		if toward.length_squared() > 0.0004 and mark.normal.dot(toward.normalized()) <= 0.1: facing_ok = false
	check(facing_ok, "an unbiased fan still only marks surfaces that face the body")
	check(controller.snapshot().stains_live <= controller.snapshot().stain_cap, "the live cap still holds")

	# --- 4) a narrow pillar: marks fit or are skipped --------------------------
	controller.reset()
	controller.apply_state(state([actor(1, 7.0, -2.0), actor(2, 7.0, -4.6)], 4.0), 1)
	controller.apply_events([death(13, Vector3(7.0, 1.2, -4.6), Vector3(0, 0, -1), 9.0)], 1)
	var pillar_marks := live_marks(controller)
	var pillar_wall := 0
	for mark: Dictionary in pillar_marks:
		if absf(float(mark.position.z) - (PILLAR_FACE_Z + 0.012)) > 0.06: continue
		pillar_wall += 1
		var half: Vector3 = mark.half
		check(absf(float(mark.position.x) - 7.0) + half.x <= 0.6 + 0.001,
			"narrow pillar marks clamp inside the face (%f + %f)" % [absf(float(mark.position.x) - 7.0), half.x])
	check(pillar_wall >= 1, "the narrow pillar still receives spatter (got %d)" % pillar_wall)

	# --- 5) counters stay consistent -------------------------------------------
	var snapshot: Dictionary = controller.snapshot()
	check(int(snapshot.marks_wall) + int(snapshot.marks_floor) + int(snapshot.marks_slope) == int(snapshot.stains_placed),
		"wall + floor + slope placement counters add up to stains_placed")
	check(int(snapshot.stains_wall) <= int(snapshot.stains_live), "live wall marks are counted inside live stains")
	check(int(snapshot.stains_live) <= int(snapshot.stain_cap), "live stains stay inside the cap")

	print("BLOOD_FX_SPATTER ", "FAIL" if failed else "PASS", " checks=", checks)
	print("BLOOD_FX_SPATTER_METRICS ", JSON.stringify({
		"checks": checks, "failed": notes.size(),
		"marks_wall": snapshot.marks_wall, "marks_floor": snapshot.marks_floor, "marks_slope": snapshot.marks_slope,
		"marks_skipped_edge": snapshot.marks_skipped_edge, "marks_skipped_facing": snapshot.marks_skipped_facing,
		"marks_skipped_reach": snapshot.marks_skipped_reach, "clusters_placed": snapshot.clusters_placed,
		"fan_rays_cast": snapshot.fan_rays_cast, "fan_marks": snapshot.fan_marks, "impact_marks": snapshot.impact_marks,
		"stains_live": snapshot.stains_live, "stain_cap": snapshot.stain_cap,
		"death_wall_marks": new_wall, "death_floor_marks": new_floor, "death_total_marks": new_marks,
		"impact_cluster_marks": cluster, "budget_per_death": budget,
	}))
	quit(1 if failed else 0)
