extends SceneTree
## Trap-site inspection (trap-fix lane): lists colliders and visible meshes
## near given XZ points on a native DM arena map so a step face can be
## attributed to its authored source before it is reshaped.
## Usage: godot --headless --path godot --script res://tests/native_arenas/geometry/inspect_sites.gd -- --map=cinder-array --sites=x,z;x,z

func _initialize() -> void:
	call_deferred("run")

func _world_bounds(child: CollisionShape3D) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var points: PackedVector3Array = child.shape.points if child.shape is ConvexPolygonShape3D else PackedVector3Array()
	if child.shape is BoxShape3D:
		var half: Vector3 = (child.shape as BoxShape3D).size * 0.5
		for x in [-half.x, half.x]:
			for y in [-half.y, half.y]:
				for z in [-half.z, half.z]:
					var w: Vector3 = child.global_transform * Vector3(x, y, z)
					lo = lo.min(w); hi = hi.max(w)
	else:
		for p in points:
			var w: Vector3 = child.global_transform * p
			lo = lo.min(w); hi = hi.max(w)
	return AABB(lo, hi - lo)

func run() -> void:
	var map_id := "cinder-array"
	var sites: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): map_id = arg.trim_prefix("--map=")
		if arg.begins_with("--sites="):
			for spec in arg.trim_prefix("--sites=").split(";"):
				var parts := spec.split(",")
				if parts.size() == 2: sites.append(Vector2(float(parts[0]), float(parts[1])))
	var map := load("res://native_arenas/maps/" + map_id + ".gd").new() as Node3D
	root.add_child(map)
	map.build()
	for site in sites:
		print("\n=== SITE ", site.x, ", ", site.y)
		_report(map, site, 3.5)
	map.free()
	quit()

func _near(bounds: AABB, site: Vector2, radius: float) -> bool:
	var cx := clampf(site.x, bounds.position.x, bounds.end.x)
	var cz := clampf(site.y, bounds.position.z, bounds.end.z)
	return (cx - site.x) * (cx - site.x) + (cz - site.y) * (cz - site.y) <= radius * radius

func _report(node: Node, site: Vector2, radius: float) -> void:
	for child in node.get_children():
		if child is CollisionShape3D:
			var bounds := _world_bounds(child)
			if _near(bounds, site, radius):
				var desc: String = child.shape.get_class()
				if child.shape is BoxShape3D:
					desc += " size=" + str((child.shape as BoxShape3D).size)
				elif child.shape is ConvexPolygonShape3D:
					desc += " pts=%d" % (child.shape as ConvexPolygonShape3D).points.size()
				print("  COLLIDER %s parent=%s shape=%s y=[%.2f,%.2f] x=[%.2f,%.2f] z=[%.2f,%.2f] walkable_meta=%s" % [
					node.get_path_to(child), child.get_parent().name, desc,
					bounds.position.y, bounds.end.y, bounds.position.x, bounds.end.x, bounds.position.z, bounds.end.z,
					str(child.has_meta("dm_walkable"))])
		if child is MeshInstance3D and child.mesh != null:
			var mesh_aabb: AABB = child.global_transform * child.mesh.get_aabb()
			if _near(mesh_aabb, site, radius):
				var mat = child.material_override if child.material_override != null else (child.mesh.surface_get_material(0) if child.mesh.get_surface_count() > 0 else null)
				print("  MESH %s name=%s mat=%s y=[%.2f,%.2f] x=[%.2f,%.2f] z=[%.2f,%.2f]" % [
					node.get_path_to(child), child.name, str(mat),
					mesh_aabb.position.y, mesh_aabb.end.y, mesh_aabb.position.x, mesh_aabb.end.x, mesh_aabb.position.z, mesh_aabb.end.z])
		_report(child, site, radius)
