extends SceneTree
const Terrain = preload("res://campaign/terrain.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("_run")

func _collect(node: Node, bounds: Array, counts: Array) -> void:
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node
		bounds.append(instance.global_transform * instance.mesh.get_aabb())
		counts[0] += 1
		for i: int in instance.mesh.get_surface_count():
			counts[1] += instance.mesh.surface_get_array_index_len(i) / 3
			var material: Material = instance.mesh.surface_get_material(i)
			check(material is StandardMaterial3D and material.roughness >= 0.25, "imported opaque rough PBR surface")
	for child: Node in node.get_children(): _collect(child,bounds,counts)

func _run() -> void:
	for id: String in ["rootfall-verge", "crown-array"]:
		var world := Terrain.new()
		root.add_child(world)
		check(world.build(id), id + " builds")
		var node: Node3D = world.get_node("Scenery_FallenRelay" if id == "rootfall-verge" else "Scenery_CrownReceiver")
		if id == "rootfall-verge":
			# New optional workshops also use smaller fallen-relay silhouettes.
			# Select the original landmark by its authored site, not auto-node order.
			for block: Dictionary in world.recipe.arena.blocks:
				if block.id != "landmark-1-Fallen relay": continue
				for child: Node in world.get_children():
					if child is Node3D and child.scale.is_equal_approx(Vector3(26,4,4)) and Vector2(child.position.x,child.position.z).distance_to(Vector2(block.x,block.z)) < 0.001:
						node = child
			check(node.scale.is_equal_approx(Vector3(26,4,4)), "authored original fallen relay selected")
		var boxes: Array = []
		var counts := [0,0]
		_collect(node, boxes, counts)
		check(counts[0] <= 4 and counts[0] >= 2 and counts[1] < 8000, id + " bounded imported draw/triangle cost")
		var bounds: AABB = boxes[0]
		for box: AABB in boxes: bounds = bounds.merge(box)
		var position := node.position
		if id == "rootfall-verge":
			var left_ground: float = world.height_at(position.x-12.48, position.z-2.2)
			var right_ground: float = world.height_at(position.x+7.8, position.z)
			check(absf(position.y-left_ground) < 0.04, "wreck end rests on actual terrain")
			check(absf((position.y+4.0*0.34)-right_ground) < 0.8, "wreck opposite end meets rising slope")
			var relay: Dictionary = {}
			for block: Dictionary in world.recipe.arena.blocks:
				if block.id == "landmark-1-Fallen relay": relay = block
			check(absf((position.y+4.0*0.54)-float(relay.h)) < 0.25, "mast saddle borne on blocked relay roof")
			check(bounds.size.x > 17 and bounds.size.x < 23 and bounds.size.z < 5.5, "broken mast silhouette and compact footprint")
			check(bounds.position.y >= left_ground-0.25 and bounds.end.y < float(relay.h)+3.5, "mast seated and bounded in height")
		else:
			check(bounds.size.x > 27 and bounds.size.x < 31 and bounds.size.z > 25 and bounds.size.z < 31, "sector-open receiver stays within original diameter")
			check(bounds.position.y > 83.2 and bounds.position.y < 84.5 and bounds.end.y < 101.5, "dish bearings lap existing buttresses")
			for block: Dictionary in world.recipe.arena.blocks:
				if block.id.begins_with("court-buttress-4-"):
					check(absf(float(block.h)-84.17) < 0.3, "receiver bearing fitted to unchanged buttress")
		var clearance := INF
		var bent_mast: Array[Vector2] = []
		if id == "rootfall-verge":
			for pair: Vector2 in [Vector2(-0.48,-0.55),Vector2(-0.34,-0.35),Vector2(-0.18,-0.15),Vector2(0,0),Vector2(0.15,0),Vector2(0.30,0)]:
				bent_mast.append(Vector2(position.x+26*pair.x,position.z+4*pair.y))
		for route: Dictionary in world.recipe.routes:
			for point: Dictionary in route.points:
				var p := Vector2(float(point.x),float(point.z))
				var footprint := Vector2(clampf(p.x,bounds.position.x,bounds.end.x),clampf(p.y,bounds.position.z,bounds.end.z))
				if id == "rootfall-verge":
					# A single union AABB includes empty space beside the swept
					# western wreck. Conservatively bound every actual mast bay by
					# its widest triangle and a 15 cm outer joint margin instead.
					for i: int in range(bent_mast.size()-1):
						clearance = minf(clearance,p.distance_to(closest_on_segment(bent_mast[i],bent_mast[i+1],p))-1.31)
				else:
					if p.distance_to(footprint) < 0.1:
						check(bounds.position.y-float(point.y) > 9, "dish underside clears every routed player")
		if id == "rootfall-verge": check(clearance > 2.5, "wreck clear of critical and flank routes")
		var rocks: Array = world.recipe.arena.blocks.filter(func(b: Dictionary) -> bool: return b.material == "rock")
		check(world.get_node("AuthoritativeBlocks").get_child_count() == rocks.size(), "exact rock cover boxes retained alongside facade triangles")
		check(not world.get_node("StructureArt").find_children("*", "CollisionShape3D", true, false).is_empty(), "native facade contact surfaces present")
		print("LANDMARK ",id," meshes=",counts[0]," triangles=",counts[1]," bounds=",bounds," route_clearance=",clearance)
		world.queue_free()
		await process_frame
	print("LANDMARK failures=",failures)
	quit(0 if failures == 0 else 1)

func closest_on_segment(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var axis := b-a
	return a+axis*clampf((p-a).dot(axis)/axis.length_squared(),0,1)
