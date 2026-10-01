extends SceneTree
const Blackwater = preload("res://horde_maps/blackwater.gd")
const FILE := "res://horde_maps/generated/blackwater-reclamation.json"
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var map: Node3D = Blackwater.new()
	root.add_child(map)
	check(map.build("blackwater-reclamation"), "Blackwater renderer builds")
	await physics_frame
	await process_frame
	var recipe: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	check(recipe is Dictionary and map.get_arena_id() == recipe.id, "renderer recipe identity")
	var bodies := map.find_children("*", "StaticBody3D", true, false)
	var art: Node = map.get_node_or_null("BlenderStructures")
	var meshes := art.find_children("*", "MeshInstance3D", true, false) if art != null else []
	check(bodies.size() == recipe.arena.blocks.size() + recipe.arena.terrain.surfaces.size() + 2, "exact static collision bodies")
	check(meshes.size() == 5, "five Blender-authored material batches imported")
	check(map.station_signs.size() == 4 and map.gate_bodies.size() == 2, "four stations and two actual gates")
	var hits := {}
	for row: Array in [["intake", -170.0, 78.0], ["switchyard", 0.0, 78.0], ["spillway", 170.0, -82.0], ["gantry", 0.0, -12.0]]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(row[1], 40, row[2]), Vector3(row[1], -20, row[2]))
		var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
		hits[str(row[0])] = hit.get("position", Vector3.ZERO).y if not hit.is_empty() else null
		check(not hit.is_empty(), str(row[0]) + " has a real collision floor")
	check(absf(float(hits.get("gantry", -100)) - 5.0) < 0.1, "upper gantry is a five-metre physical route")
	map.apply_source_stage({"geometryRevision":1,"gateMask":1,"stageId":"B"},"epoch-1")
	check(not map.gate_bodies[0].visible and map.gate_bodies[0].collision_layer == 0 and map.gate_bodies[1].visible, "received gate mask controls real bodies")
	for gate_index: int in 2:
		var x: float = float(recipe.arena.hordeStagePlan.gates[gate_index].x)
		for mask: int in [0, 1, 3]:
			map.apply_source_stage({"geometryRevision":mask + 2,"gateMask":mask,"stageId":"C"},"gate-physics-%d-%d" % [gate_index,mask])
			await physics_frame
			for direction: int in [-1,1]:
				var start := Vector3(x + direction * 4.0, 3, 0)
				var query := PhysicsRayQueryParameters3D.create(start, Vector3(x - direction * 4.0, 3, 0))
				var result := root.get_world_3d().direct_space_state.intersect_ray(query)
				var expected := (mask & (1 << gate_index)) == 0
				check((not result.is_empty() and result.collider == map.gate_bodies[gate_index]) == expected,
					"gate %d mask %d side %d physical crossing" % [gate_index,mask,direction])
	map.apply_station_state({"active":"north-feeder","completed":[],"stations":[{"id":"north-feeder","caption":"NORTH FEEDER","available":true,"progress":1.5,"required":5.0}]})
	check(map.station_signs["north-feeder"].visible and "1.5 / 5.0" in map.station_signs["north-feeder"].text,
		"authority progress reaches actual native wayfinding")
	print("BLACKWATER_MAP ", JSON.stringify({"checks":checks,"failures":failures,"colliders":bodies.size(),"blender_batches":meshes.size(),"floor_hits":hits}))
	map.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
