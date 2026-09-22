extends SceneTree
## Review-lane visual/collision agreement probe for the three native DM maps.
##
## It builds the delivered renderer for each arena and walks the actual scene:
##   * visible visual instance with no covering collider -> walk-through cover
##   * collider with no covering visible visual instance -> invisible wall
##   * collision under a hidden mesh                      -> invisible blocker
##
## Handles individual MeshInstance3D AND MultiMeshInstance3D batches (the
## delivered builders fold static boxes into batches after their separate
## collision bodies are created).
##
## Usage:
##   GODOT_BIN=... $GODOT_BIN --headless --path godot \
##     --script res://tests/native_arena_review/probe_visual_collision.gd
##
## Prints one NATIVE_REVIEW_VISUAL_AUDIT JSON line per map. Read-only.
const IDS := ["prism-foundry", "aurora-basin", "cinder-array"]
const MIN_OVERLAP := 0.05

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for id: String in IDS:
		var path := "res://native_arenas/maps/%s.gd" % id
		var script: Variant = load(path)
		if script == null or not script is GDScript or not script.can_instantiate():
			print("NATIVE_REVIEW_VISUAL_AUDIT_ERROR ", JSON.stringify({"map": id, "error": "renderer missing"}))
			continue
		var builder: Node3D = (script as GDScript).new()
		root.add_child(builder)
		builder.build()
		await process_frame
		audit(id, builder)
		builder.free()
	quit(0)

func shape_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var half: Vector3 = (shape as BoxShape3D).size * 0.5
		return AABB(-half, half * 2.0)
	if shape is SphereShape3D:
		var r: float = (shape as SphereShape3D).radius
		return AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	if shape is CylinderShape3D:
		var c := shape as CylinderShape3D
		var h := Vector3(c.radius, c.height * 0.5, c.radius)
		return AABB(-h, h * 2.0)
	if shape is CapsuleShape3D:
		var cap := shape as CapsuleShape3D
		var hh := Vector3(cap.radius, cap.height * 0.5 + cap.radius, cap.radius)
		return AABB(-hh, hh * 2.0)
	var points := PackedVector3Array()
	if shape is ConvexPolygonShape3D:
		points = (shape as ConvexPolygonShape3D).points
	elif shape is ConcavePolygonShape3D:
		points = (shape as ConcavePolygonShape3D).get_faces()
	if points.is_empty():
		return AABB(Vector3.ZERO, Vector3.ZERO)
	var box := AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points: box = box.expand(p)
	return box

func world_aabb(xform: Transform3D, local: AABB) -> AABB:
	var world := AABB(xform * local.position, Vector3.ZERO)
	for i in 8:
		var corner := local.position + Vector3(
			local.size.x if (i & 1) else 0.0,
			local.size.y if (i & 2) else 0.0,
			local.size.z if (i & 4) else 0.0)
		world = world.expand(xform * corner)
	return world

func overlap_volume(a: AABB, b: AABB) -> float:
	var hit := a.intersection(b)
	if hit.size.x <= 0.0 or hit.size.y <= 0.0 or hit.size.z <= 0.0: return 0.0
	return hit.size.x * hit.size.y * hit.size.z

func collect_visuals(builder: Node3D) -> Array:
	var out: Array = []
	for node: Node in builder.find_children("*", "VisualInstance3D", true, false):
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			if mesh_node.mesh == null: continue
			out.append({"aabb": world_aabb(mesh_node.global_transform, mesh_node.mesh.get_aabb()),
				"visible": mesh_node.is_visible_in_tree(), "name": String(mesh_node.name), "kind": "mesh",
				"path": str(builder.get_path_to(mesh_node))})
		elif node is MultiMeshInstance3D:
			var multi_node := node as MultiMeshInstance3D
			if multi_node.multimesh == null or multi_node.multimesh.mesh == null: continue
			var unit: AABB = multi_node.multimesh.mesh.get_aabb()
			for i in multi_node.multimesh.instance_count:
				var xform: Transform3D = multi_node.global_transform * multi_node.multimesh.get_instance_transform(i)
				out.append({"aabb": world_aabb(xform, unit), "visible": multi_node.is_visible_in_tree(),
					"name": "%s#%d" % [multi_node.name, i], "kind": "multimesh",
					"path": str(builder.get_path_to(multi_node))})
	return out

func audit(id: String, builder: Node3D) -> void:
	var visuals := collect_visuals(builder)
	var shapes: Array = []
	for node: Node in builder.find_children("*", "CollisionShape3D", true, false):
		var shape_node := node as CollisionShape3D
		if shape_node.shape == null or shape_node.disabled: continue
		shapes.append({"node": shape_node, "aabb": world_aabb(shape_node.global_transform, shape_aabb(shape_node.shape)),
			"kind": shape_node.shape.get_class(), "name": String(shape_node.name), "path": str(builder.get_path_to(shape_node)),
			"visible_in_tree": shape_node.is_visible_in_tree()})
	var visual_without_collision: Array = []
	var collision_without_visual: Array = []
	var collision_under_hidden: Array = []
	for m: Dictionary in visuals:
		var box: AABB = m.aabb
		var covered := false
		for s: Dictionary in shapes:
			if overlap_volume(box, s.aabb) > MIN_OVERLAP:
				covered = true
				break
		if not covered:
			visual_without_collision.append({"name": m.name, "kind": m.kind, "path": m.path, "visible": m.visible,
				"center": [box.get_center().x, box.get_center().y, box.get_center().z],
				"size": [box.size.x, box.size.y, box.size.z]})
	var hidden_seen := {}
	for s: Dictionary in shapes:
		var box: AABB = s.aabb
		var covered := false
		for m: Dictionary in visuals:
			if overlap_volume(box, m.aabb) > MIN_OVERLAP:
				covered = true
				if not m.visible and not hidden_seen.has(s.path):
					hidden_seen[s.path] = true
					collision_under_hidden.append({"shape": s.name, "shapePath": s.path, "mesh": m.name,
						"center": [box.get_center().x, box.get_center().y, box.get_center().z],
						"size": [box.size.x, box.size.y, box.size.z]})
				break
		if not covered:
			collision_without_visual.append({"name": s.name, "path": s.path, "kind": s.kind,
				"center": [box.get_center().x, box.get_center().y, box.get_center().z],
				"size": [box.size.x, box.size.y, box.size.z]})
	var visible_visuals := 0
	for m: Dictionary in visuals: if m.visible: visible_visuals += 1
	var visible_missing := 0
	for m: Dictionary in visual_without_collision: if m.visible: visible_missing += 1
	print("NATIVE_REVIEW_VISUAL_AUDIT ", JSON.stringify({"map": id,
		"visuals": visuals.size(), "visibleVisuals": visible_visuals, "shapes": shapes.size(),
		"visualWithoutCollision": {"count": visual_without_collision.size(), "visibleCount": visible_missing,
			"sample": visual_without_collision.slice(0, 40)},
		"collisionWithoutVisual": {"count": collision_without_visual.size(), "sample": collision_without_visual.slice(0, 40)},
		"collisionUnderHiddenMesh": {"count": collision_under_hidden.size(), "sample": collision_under_hidden.slice(0, 40)}}))
