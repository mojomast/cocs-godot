extends SceneTree

const Actor = preload("res://world/actor_visual.gd")

func _initialize() -> void:
	var actor := Actor.new()
	var vertices := 0
	var triangles := 0
	var surfaces := 0
	var meshes := 0
	var materials := {}
	var bounds := AABB()
	var first := true
	for child in actor.get_children():
		if child is MeshInstance3D:
			meshes += 1
			materials[child.material_override.get_instance_id()] = true
			var box: AABB = child.transform * child.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
			for surface in range(child.mesh.get_surface_count()):
				surfaces += 1
				var arrays: Array = child.mesh.surface_get_arrays(surface)
				vertices += arrays[Mesh.ARRAY_VERTEX].size()
				triangles += int(arrays[Mesh.ARRAY_INDEX].size() / 3)
	var populations := []
	for count in [1, 16, 32]:
		var samples := []
		for repetition in range(11):
			var actors := []
			var start := Time.get_ticks_usec()
			for index in range(count):
				actors.append(Actor.new())
			samples.append(Time.get_ticks_usec() - start)
			for item in actors:
				item.free()
		populations.append({"count": count, "construction_usec": samples})
	print("PLAYER_MODEL_BASELINE ", JSON.stringify({"engine": Engine.get_version_info().string, "meshes": meshes, "vertices": vertices, "triangles": triangles, "surfaces": surfaces, "materials": materials.size(), "nodes": actor.get_child_count() + 1, "bounds_min": [bounds.position.x,bounds.position.y,bounds.position.z], "bounds_max": [bounds.end.x,bounds.end.y,bounds.end.z], "synthetic_cpu_construction_only": populations}))
	actor.free()
	quit(0)
