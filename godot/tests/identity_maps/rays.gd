extends SceneTree
const MapBuilder = preload("res://identity_maps/map.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/identity_maps/source-rays.json"))
	var failures: Array = []
	var count := 0
	for fixture: Dictionary in fixtures:
		var map := MapBuilder.new()
		root.add_child(map)
		map.build(str(fixture.id))
		await physics_frame
		await physics_frame
		var space := map.get_world_3d().direct_space_state
		for ray: Dictionary in fixture.rays:
			var a := Vector3(ray.from[0],ray.from[1],ray.from[2])
			var b := Vector3(ray.to[0],ray.to[1],ray.to[2])
			var query := PhysicsRayQueryParameters3D.create(a,b)
			query.hit_back_faces = true
			query.hit_from_inside = true
			var hit := space.intersect_ray(query)
			var distance := a.distance_to(b) if hit.is_empty() else a.distance_to(hit.position)
			count += 1
			if absf(distance-float(ray.distance)) > 0.015:
				failures.append({"map":fixture.id,"label":ray.label,"source":ray.distance,"godot":distance})
		map.queue_free()
		await process_frame
	var result := {"checks":count,"failures":failures,"scope":"Source rayWorld vs Godot static collision, no muzzle/actor hit proof"}
	print("IDENTITY_RAYS ",JSON.stringify(result))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			var file := FileAccess.open(arg.trim_prefix("--output="),FileAccess.WRITE)
			file.store_string(JSON.stringify(result,"\t"))
	quit(0 if failures.is_empty() else 1)
