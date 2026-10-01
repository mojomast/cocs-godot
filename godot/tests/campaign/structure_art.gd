extends SceneTree
const Terrain = preload("res://campaign/terrain.gd")
const Art = preload("res://campaign/structure_art.gd")
var failures := 0

func check(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error(description)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	for id: String in Terrain.IDS:
		var world := Terrain.new()
		root.add_child(world)
		check(world.build(id), id + " builds")
		var art: Node3D = world.get_node("StructureArt")
		var expected := 0
		for b: Dictionary in world.recipe.arena.blocks:
			if b.material == "rock": continue
			expected += 1
			var base: float = Art.fitted_base(world, b)
			check(base >= float(b.baseY) and base < float(b.h), id + " fitted foundation remains in authoritative block " + str(b.id))
			for u: float in [-0.5, 0.0, 0.5]:
				for v: float in [-0.5, 0.0, 0.5]:
					var sample: float = world.height_at(float(b.x)+u*float(b.w), float(b.z)+v*float(b.d))
					if is_finite(sample): check(base <= sample + 0.001, id + " foundation under footprint ground " + str(b.id))
		check(art.placements >= expected and art.placements < expected * 6, id + " fitted segmented architecture")
		check(art.batches < 240, id + " bounded chunked material batches")
		var physics_count := 0
		for child: Node in world.get_children():
			if child is StaticBody3D: physics_count += 1
		check(physics_count == world.terrain_chunks + 1, id + " authoritative collision bodies only")
		check(world.get_node("AuthoritativeBlocks").get_child_count() == world.recipe.arena.blocks.size(), id + " block collision count unchanged")
		var triangles := 0
		for key: String in art._sources:
			var source: Array = art._sources[key]
			var continuous := false
			for part: Dictionary in source:
				var mesh: Mesh = part.mesh
				var bound: AABB = part.transform * mesh.get_aabb()
				check(bound.position.x >= -0.501 and bound.end.x <= 0.501 and bound.position.z >= -0.501 and bound.end.z <= 0.501, "fitted footprint " + id)
				check(bound.position.y >= -0.001 and bound.end.y <= 1.001, "fitted height " + id)
				for surface: int in mesh.get_surface_count():
					var mat := mesh.surface_get_material(surface)
					check(mat is StandardMaterial3D and mat.albedo_color.a >= 0.99 and mat.roughness > 0.25, "opaque rough imported PBR material " + id)
					triangles += mesh.surface_get_array_index_len(surface) / 3
					if key.begins_with("relay-") or key.begins_with("outpost-"): continue
					var arrays: Array = mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					for i: int in range(0, indices.size(), 3):
						var y0: float = (part.transform * vertices[indices[i]]).y
						var y1: float = (part.transform * vertices[indices[i+1]]).y
						var y2: float = (part.transform * vertices[indices[i+2]]).y
						if minf(y0, minf(y1, y2)) < 0.001 and maxf(y0, maxf(y1, y2)) > 0.999:
							continuous = true
							break
			if not (key.begins_with("relay-") or key.begins_with("outpost-")):
				check(continuous, id + " contiguous full-height load core in " + key)
		check(triangles < 32000, id + " both LOD source triangle budget")
		for batch: Node in art.get_children():
			check(batch is MultiMeshInstance3D and batch.multimesh.instance_count > 0, id + " no empty draw batches")
		print("STRUCTURE_ART ", id, " blocks=", expected, " segments=", art.placements, " draws=", art.batches, " loaded_source_tris=", triangles)
		world.queue_free()
		await process_frame
	print("STRUCTURE_ART failures=", failures)
	quit(0 if failures == 0 else 1)
