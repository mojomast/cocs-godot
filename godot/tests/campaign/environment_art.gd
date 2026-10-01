extends SceneTree
const Terrain = preload("res://campaign/terrain.gd")
const EnvironmentArt = preload("res://campaign/environment_art.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for id: String in Terrain.IDS:
		var host := Terrain.new()
		root.add_child(host)
		assert(host.build(id), "missing recipe " + id)
		var original_solids := 0
		var baseline: Array[float] = []
		var locations := [Vector2(0,0),Vector2(8,8),Vector2(-16,12)]
		for point: Vector2 in locations: baseline.append(host.height_at(point.x,point.y))
		for node in host.get_children():
			if node is StaticBody3D: original_solids += 1
		var visual := EnvironmentArt.new()
		host.add_child(visual)
		visual.build(host)
		assert(visual.replacement_instances > 200, id + " missing authored scenery")
		assert(visual.accent_instances > 0 and visual.accent_instances < 100, id + " accent budget")
		assert(visual.batch_count < 180, id + " excessive batches")
		var solids := 0
		for node in host.get_children():
			if node is StaticBody3D: solids += 1
		assert(solids == original_solids, id + " collision changed")
		for i in range(locations.size()):
			assert(host.height_at(locations[i].x, locations[i].y) == baseline[i], id + " height changed")
		for child in visual.get_children():
			assert(child is MultiMeshInstance3D and child.multimesh.instance_count > 0)
			assert(child.multimesh.custom_aabb.has_volume())
			if child.name.begins_with("Accent_"):
				for t: Transform3D in child.get_meta("instance_transforms"):
					assert(visual._clear_site(host,child.position+t.origin),id + " accent on mission route")
		print("BIOME_ART ",id," replaced=",visual.replacement_instances," accents=",visual.accent_instances," batches=",visual.batch_count)
		host.free()
	print("CAMPAIGN_ENVIRONMENT_ART_OK")
	quit()
