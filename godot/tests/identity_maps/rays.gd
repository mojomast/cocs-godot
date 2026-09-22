extends SceneTree
## Source rayWorld fixtures vs Godot static collision.
##
## Fixture groups (see port/native-identity-maps/ray-oracle.mjs):
##   block-cover  exact box faces
##   wall-face    authored collision polygons, probed from their own normal
##   route-floor  downward rays at route points (floors are exact both sides)
##   sightline    spawn/pickup/objective/route pairs at eye height
##   eye-grid     4 m eye grid x 8 compass directions x 5 lengths
## Every ray carries the source distance and a tolerance; a ray the source did
## not hit must also miss here. `mode: classification` rays assert the same
## blocked/unblocked answer as the source and report the distance delta.
const MapBuilder = preload("res://identity_maps/map.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/identity_maps/source-rays.json"))
	var failures: Array = []
	var count := 0
	var classification := 0
	var grazing := 0
	var grazing_divergence := 0
	var max_delta := 0.0
	var groups := {}
	for fixture: Dictionary in fixtures:
		var map := MapBuilder.new()
		root.add_child(map)
		if not map.build(str(fixture.id)):
			failures.append({"map": fixture.id, "error": "build failed"})
			continue
		await physics_frame
		await physics_frame
		var space := map.get_world_3d().direct_space_state
		for ray: Dictionary in fixture.rays:
			var a := Vector3(ray.from[0], ray.from[1], ray.from[2])
			var b := Vector3(ray.to[0], ray.to[1], ray.to[2])
			var length := a.distance_to(b)
			var query := PhysicsRayQueryParameters3D.create(a, b)
			query.hit_back_faces = true
			query.hit_from_inside = true
			var hit := space.intersect_ray(query)
			var distance := length if hit.is_empty() else a.distance_to(hit.position)
			var source := float(ray.source)
			var tolerance := float(ray.get("tolerance", 0.02))
			var group := str(ray.get("group", "unknown"))
			var record: Dictionary = groups.get(group, {"rays": 0, "failures": 0, "max_delta": 0.0})
			record.rays += 1
			count += 1
			if str(ray.get("mode", "distance")) == "classification":
				classification += 1
				var grazing_ray := bool(ray.get("grazing", false))
				if grazing_ray: grazing += 1
				var blocked := distance < length - 0.08
				if blocked != bool(ray.blocked):
					if grazing_ray:
						# Knife-edge: the source itself flips verdict under a 4 mm
						# or 0.03 degree perturbation, so sub-float corner agreement
						# is not claimed. Counted, not failed.
						grazing_divergence += 1
					else:
						failures.append({"map": fixture.id, "group": group, "label": ray.label, "mode": "classification",
							"source_blocked": ray.blocked, "godot_blocked": blocked, "source": source, "godot": distance, "length": length})
						record.failures += 1
			elif absf(distance - source) > tolerance:
				failures.append({"map": fixture.id, "group": group, "label": ray.label, "mode": "distance",
					"source": source, "godot": distance, "tolerance": tolerance})
				record.failures += 1
			elif source < length - 0.08 and absf(distance - source) > max_delta:
				max_delta = absf(distance - source)
			record.max_delta = maxf(float(record.max_delta), absf(distance - source))
			groups[group] = record
		map.queue_free()
		await process_frame
	var result := {
		"checks": count, "classification_rays": classification, "grazing_rays": grazing,
		"grazing_divergence": grazing_divergence, "max_hit_delta": max_delta,
		"groups": groups, "failures": failures,
		"scope": "Source rayWorld vs Godot static collision; no muzzle, actor or projectile-hit proof",
	}
	print("IDENTITY_RAYS ", JSON.stringify(result))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			var file := FileAccess.open(arg.trim_prefix("--output="), FileAccess.WRITE)
			file.store_string(JSON.stringify(result, "\t"))
	quit(0 if failures.is_empty() else 1)
