extends SceneTree
## Engine-slot-gated test. Source causality is exercised by the Node fixtures;
## this verifies that received masks really change native physics and visuals.
const Drydock = preload("res://horde_maps/cinderwake.gd")
const Occlusion = preload("res://world/combat_occlusion.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func gate_hit(map: Node3D, z: float) -> bool:
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 2, z + 3), Vector3(0, 2, z - 3))
	return not map.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func run() -> void:
	var map := Drydock.new()
	root.add_child(map)
	check(map.build("cinderwake-drydock"), "new literal recipe builds")
	check(Occlusion.native_root(map, "cinderwake-drydock") == map, "combat queries Cinderwake's collider-backed native geometry")
	check(Occlusion.native_root(map, "nacre-engine") == null, "Cinderwake cannot masquerade as an identity arena")
	await physics_frame
	for mask: int in 4:
		map.apply_source_stage({"geometryRevision": mask, "gateMask": mask, "stageId": "B", "transit": null}, "round-1")
		await physics_frame
		check(gate_hit(map, 20.0) == ((mask & 1) == 0), "BC native ray mask %d" % mask)
		check(gate_hit(map, -26.0) == ((mask & 2) == 0), "CD native ray mask %d" % mask)
		for i: int in 2:
			check(map.gate_bodies[i].visible == ((mask & (1 << i)) == 0), "slab visibility matches source")
	map.apply_source_stage({"geometryRevision": 1, "gateMask": 0, "stageId": "B"}, "round-1")
	await physics_frame
	check(not gate_hit(map, 20.0), "stale revision cannot restore false cover")
	map.apply_source_stage({"geometryRevision": 0, "gateMask": 0, "stageId": "B", "transit": null}, "round-2")
	await physics_frame
	check(gate_hit(map, 20.0) and gate_hit(map, -26.0), "restart restores both gates from new source round")
	map.free()
	for failure: String in failures: push_error(failure)
	print("Cinderwake native gate tests: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
