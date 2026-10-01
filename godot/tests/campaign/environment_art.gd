extends SceneTree
const Terrain = preload("res://campaign/terrain.gd")

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
		var visual: Node3D = host.get_node("CampaignEnvironmentArt")
		var expected_replacements := 0
		for prop: Dictionary in host.recipe.art:
			if prop.kind in ["tree","fern","crag"]: expected_replacements += 1
		assert(visual.replacement_instances == expected_replacements, id + " missing or duplicated authored scenery")
		assert(visual.accent_instances > 0 and visual.accent_instances < 100, id + " accent budget")
		assert(visual.batch_count < 280 and visual.surface_draws < 850, id + " excessive surface draws")
		assert(visual.triangle_instances > visual.replacement_instances and visual.triangle_instances < 550000, id + " triangle budget")
		var solids := 0
		for node in host.get_children():
			if node is StaticBody3D: solids += 1
		assert(solids == original_solids, id + " collision changed")
		for i in range(locations.size()):
			assert(host.height_at(locations[i].x, locations[i].y) == baseline[i], id + " height changed")
		for child in visual.get_children():
			assert(child is MultiMeshInstance3D and child.multimesh.instance_count > 0)
			assert(child.multimesh.custom_aabb.has_volume())
			for transform: Transform3D in child.get_meta("instance_transforms"):
				assert(child.multimesh.custom_aabb.encloses(transform * child.multimesh.mesh.get_aabb()), id + " visual cull box clips imported GLB")
			for surface in range(child.multimesh.mesh.get_surface_count()):
				assert(child.multimesh.mesh.surface_get_material(surface) != null, id + " missing Blender material")
			if child.name.begins_with("Accent_"):
				for t: Transform3D in child.get_meta("instance_transforms"):
					assert(visual._clear_site(host,child.position+t.origin),id + " accent on mission route")
		print("BIOME_ART ",id," replaced=",visual.replacement_instances," accents=",visual.accent_instances," batches=",visual.batch_count," surface_draws=",visual.surface_draws," triangle_instances=",visual.triangle_instances)
		host.free()
	print("CAMPAIGN_ENVIRONMENT_ART_OK")
	quit()
