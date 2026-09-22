extends SceneTree
const DM = preload("res://native_arenas/maps/geometry.gd")
var maps := ["prism-foundry", "aurora-basin", "cinder-array"]

func _initialize() -> void:
	call_deferred("run")

func ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Variant:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.hit_back_faces = true
	var hit := space.intersect_ray(query)
	return null if hit.is_empty() else DM.vector(hit.position)

func run() -> void:
	var reports: Array = []
	for id in maps:
		var data := DM.data(id)
		var map := load("res://native_arenas/maps/" + id + ".gd").new() as Node3D
		root.add_child(map)
		map.build()
		var initial_count := map.get_child_count()
		map.build()
		assert(initial_count == map.get_child_count(), "build must be idempotent")
		await physics_frame
		await physics_frame
		var space := map.get_world_3d().direct_space_state
		var samples: Array = []
		var points: Array = data.spawnPoints.duplicate()
		for route in data.routes: points.append_array(route.points)
		for point in points:
			var p := Vector3(point.x, point.y, point.z)
			var sample := {"point": DM.vector(p), "floor": ray(space, p + Vector3.UP * 1.4, p - Vector3.UP * 2), "rays": []}
			for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3.UP]:
				var origin := p + Vector3.UP * 1.45
				sample.rays.append({"origin": DM.vector(origin), "direction": DM.vector(direction), "hit": ray(space, origin, origin + direction * 20)})
			samples.append(sample)
		var sealed_origin: Vector3
		var sealed_direction: Vector3
		if id == "prism-foundry":
			sealed_origin = Vector3(-12, 1.5, 4)
			sealed_direction = Vector3.LEFT
		elif id == "aurora-basin":
			sealed_origin = Vector3(16, 1.5, -25)
			sealed_direction = Vector3.FORWARD
		else:
			sealed_origin = Vector3(7, 13.5, -24)
			sealed_direction = Vector3.FORWARD
		var sealed := {"origin": DM.vector(sealed_origin), "direction": DM.vector(sealed_direction), "hit": ray(space, sealed_origin, sealed_origin + sealed_direction * 20)}
		reports.append({"id": id, "geometryHash": data.geometryHash, "samples": samples, "sealedVolume": sealed, "idempotent": true})
		map.free()
	var file := FileAccess.open("/tmp/opencode/native-dm-physics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(reports))
	file.close()
	print("NATIVE_DM_PHYSICS_PROBED samples=spawns+all-routes file=/tmp/opencode/native-dm-physics.json")
	quit()
