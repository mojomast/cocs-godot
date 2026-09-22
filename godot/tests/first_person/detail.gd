extends SceneTree
## First-person weapon detail contract: the detail augmentation that makes the
## ten weapons distinct must stay inside every hard invariant.
##
## Machine-checked here (display-free, uses the exported manifest):
##   1. exactly eight material batches (MeshInstance3D, one surface each) per
##      imported weapon,
##   2. triangles inside the documented band, real detail recovered per weapon,
##   3. six identity channels, each distinct across all ten weapons,
##   4. every authored detail box clear of the two grip stations and the reload
##      feed station, measured through the *live* animated assemblies (the exact
##      point-to-box distance is computed in each box's own rest frame, so a
##      rotating feed cannot produce a false positive),
##   5. no authored detail within 12 mm of the sight line (the rendered ADS gate
##      `tests/first_person/ads.gd` separately proves the 4x4 px target gap),
##   6. per-weapon idle sway is distinct between weapons and exactly zero at a
##      settled cheek weld.
const Rig = preload("res://first_person/rig.gd")
const BARREL_NAMES: Array[String] = ["barrel-assembly", "shock-emitter", "flak-barrel"]
const GRIP_CLEARANCE := 0.045
const SIGHT_CLEARANCE := 0.012
var failures: Array[String] = []
var checks := 0
var measured: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func step(rig: Node, frames: int, delta: float = 1.0 / 60.0) -> void:
	for i: int in frames: rig.advance(delta)

## Resolve the live node and rest transform of the assembly a detail box
## belongs to (the barrel group is named per family in the source builders).
func assembly_nodes(rig: Node, key: String) -> Array:
	match key:
		"barrel":
			for name: String in BARREL_NAMES:
				if rig.parts.has(name): return [rig.parts[name], rig.rest[name]]
		"feed":
			if rig.parts.has("feed"): return [rig.parts["feed"], rig.rest["feed"]]
		"bolt":
			if rig.parts.has("bolt"): return [rig.parts["bolt"], rig.rest["bolt"]]
	return [rig.weapon, Transform3D.IDENTITY]

## Maps live weapon-space points into the rest frame the exported detail box is
## axis-aligned in, for the assembly that owns the box.
func box_frame(rig: Node, key: String) -> Transform3D:
	var nodes: Array = assembly_nodes(rig, key)
	var live: Transform3D = rig.weapon.global_transform.affine_inverse() * (nodes[0] as Node3D).global_transform
	return (nodes[1] as Transform3D) * live.affine_inverse()

func live_position(rig: Node, key: String, point: Vector3) -> Vector3:
	var nodes: Array = assembly_nodes(rig, key)
	var live: Transform3D = rig.weapon.global_transform.affine_inverse() * (nodes[0] as Node3D).global_transform
	return live * ((nodes[1] as Transform3D).affine_inverse() * point)

func box_distance(point: Vector3, box: Dictionary) -> float:
	var closest := Vector3(
		clampf(point.x, box.min[0], box.max[0]),
		clampf(point.y, box.min[1], box.max[1]),
		clampf(point.z, box.min[2], box.max[2]))
	return point.distance_to(closest)

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	var rig := Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	var actor := {"id": 7, "weapon": 0, "health": 100, "reloadDuration": 2.0, "reloadTimer": 1.0}
	var traces: Array[PackedFloat32Array] = []
	var identities := {"massing": {}, "feed": {}, "muzzle": {}, "stock": {}, "sight": {}, "accent": {}}
	for id: int in 10:
		rig.reset()
		actor.weapon = id
		actor.reloading = false
		rig.apply_actor(actor, true)
		step(rig, 10, 0.05)
		var info: Dictionary = rig.manifest.weapons[id]
		# 1. Batch budget: one material per moving assembly slot, eight per weapon.
		var meshes := rig.weapon.find_children("*", "MeshInstance3D")
		check(meshes.size() == 8, "eight material batches weapon %d (%d)" % [id, meshes.size()])
		var surfaces := 0
		for mesh: MeshInstance3D in meshes: surfaces += mesh.mesh.get_surface_count()
		check(surfaces == 8, "one surface per batch weapon %d (%d)" % [id, surfaces])
		# 2. Triangle band and recovered detail.
		var triangles := int(info.triangles)
		check(triangles > 3000 and triangles < 6500, "triangle band weapon %d (%d)" % [id, triangles])
		check(int(info.detailTriangles) >= 380, "recovered detail weapon %d (%d)" % [id, int(info.detailTriangles)])
		check(int(info.detailPrimitives) >= 16, "detail primitives weapon %d (%d)" % [id, int(info.detailPrimitives)])
		check(float(info.nearestHandClearance) >= GRIP_CLEARANCE, "exported hand clearance weapon %d" % id)
		# 3. Identity: every weapon owns a distinct choice in every channel.
		for channel: String in identities:
			var text: String = String(info.identity[channel])
			check(text.length() > 20, "identity channel authored weapon %d %s" % [id, channel])
			check(not identities[channel].has(text), "identity channel distinct weapon %d %s" % [id, channel])
			identities[channel][text] = id
		# 4. Hands: grip stations stay clear of every authored detail box in the
		#    live pose, settled and mid-reload (feed travelling and rotating).
		var stations := {"GripRight": "body", "GripSupport": "body", "GripReload": "feed"}
		if id == 3: stations["GripSupport"] = "barrel"
		var worst_hand := INF
		var worst_note := {}
		for phase: Array in [[false, 0.0], [true, 0.5], [true, 0.94]]:
			rig.reset()
			actor.weapon = id
			actor.reloading = bool(phase[0])
			actor.reloadTimer = 2.0 * (1.0 - float(phase[1]))
			rig.apply_actor(actor, true)
			step(rig, 12, 0.05)
			var anchors := {"GripRight": rig.anchors.GripRight, "GripSupport": rig.anchors.GripSupport, "GripReload": rig.anchors.GripReload}
			for box: Dictionary in info.detailBoxes:
				var frame := box_frame(rig, String(box.a))
				for station_name: String in anchors:
					var station_live := live_position(rig, stations[station_name], Vector3(info.anchors[station_name].weaponPosition[0], info.anchors[station_name].weaponPosition[1], info.anchors[station_name].weaponPosition[2]))
					var gap := box_distance(frame * station_live, box)
					if gap < worst_hand:
						worst_hand = gap
						worst_note = {"station": station_name, "channel": box.c, "assembly": box.a, "gap": gap, "reloading": phase[0]}
			# The anchors themselves must not drift either.
			for station_name: String in anchors:
				var authored: Array = info.anchors[station_name].weaponPosition
				var live := live_position(rig, stations[station_name], Vector3(authored[0], authored[1], authored[2]))
				check((anchors[station_name] as Node3D).global_position.distance_to(rig.weapon.global_transform * live) < 0.0001,
					"authored station rest position weapon %d %s" % [id, station_name])
		actor.reloading = false
		rig.apply_actor(actor, true)
		step(rig, 10, 0.05)
		check(worst_hand >= GRIP_CLEARANCE, "detail clear of the hands weapon %d (%.4f m, %s)" % [id, worst_hand, str(worst_note)])
		# 5. Sight line: no authored detail may enter the sight corridor.
		var rear: Vector3 = rig.anchors.SightRear.global_position
		var front: Vector3 = rig.anchors.SightFront.global_position
		var worst_sight := INF
		for box: Dictionary in info.detailBoxes:
			var frame := box_frame(rig, String(box.a))
			for sample: int in 41:
				var point := frame * rear.lerp(front, sample / 40.0)
				worst_sight = minf(worst_sight, box_distance(point, box))
		check(worst_sight >= SIGHT_CLEARANCE, "detail clear of the sight line weapon %d (%.4f m)" % [id, worst_sight])
		# 6. Presentation: distinct idle sway per weapon, exactly zero at ADS.
		var trace := PackedFloat32Array()
		for frame: int in 90:
			rig.advance(1.0 / 60.0)
			trace.append(rig.pivot.position.y)
		traces.append(trace)
		rig.apply_aim(true)
		step(rig, 150)
		var settled := rig.pivot.transform
		step(rig, 30)
		check(rig.pivot.transform == settled, "settled cheek weld is exactly still weapon %d" % id)
		rig.apply_aim(false)
		step(rig, 10)
		measured.append({"weapon": id, "name": info.name, "batches": meshes.size(), "triangles": triangles,
			"detail_triangles": int(info.detailTriangles), "detail_primitives": int(info.detailPrimitives),
			"hand_clearance_m": worst_hand, "sight_clearance_m": worst_sight, "sway_rate": float(info.presentation.sway.rate)})
	for a: int in traces.size():
		for b: int in range(a + 1, traces.size()):
			check(not traces[a] == traces[b], "idle sway differs weapon %d vs %d" % [a, b])
	rig.free()
	camera.free()
	print("FIRST_PERSON_DETAIL ", JSON.stringify({"checks": checks, "failures": failures, "weapons": measured}))
	quit(0 if failures.is_empty() else 1)
