extends RefCounted
## Collider export is deliberately strict: unsupported shapes are a build failure.

static func vector(p: Vector3) -> Array:
	return [snappedf(p.x, 0.000001), snappedf(p.y, 0.000001), snappedf(p.z, 0.000001)]

static func box(root: Node3D, label: String, center: Vector3, size: Vector3, material: Material, walkable := false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = material
	visual.position = center
	root.add_child(visual)
	var body := StaticBody3D.new()
	visual.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.set_meta("dm_walkable", walkable)
	body.add_child(collision)

static func prism(root: Node3D, label: String, top: PackedVector3Array, bottom: float, material: Material) -> void:
	var points := top.duplicate()
	for p in top: points.append(Vector3(p.x, bottom, p.z))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, top.size() - 1):
		for p in [top[0], top[i], top[i + 1]]: st.add_vertex(p)
		for p in [points[top.size()], points[top.size() + i + 1], points[top.size() + i]]: st.add_vertex(p)
	for i in top.size():
		var j := (i + 1) % top.size()
		for index in [i, j, j + top.size(), i, j + top.size(), i + top.size()]: st.add_vertex(points[index])
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = st.commit()
	mesh.material_override = material
	# Mesh uses both face orientations; source compiler orients the convex hull outward.
	if material is BaseMaterial3D: material.cull_mode = BaseMaterial3D.CULL_DISABLED
	root.add_child(mesh)
	var body := StaticBody3D.new()
	mesh.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collision.shape = shape
	collision.set_meta("dm_walkable", true)
	body.add_child(collision)

static func collect(root: Node3D, id: String) -> Array:
	var records: Array = []
	if not _collect(root, root, id, records):
		root.get_tree().quit(1)
		return []
	return records

static func _collect(node: Node, root: Node3D, id: String, records: Array) -> bool:
	if node is CollisionShape3D and not node.disabled:
		var shape: Shape3D = node.shape
		var points := PackedVector3Array()
		var kind := "convex"
		if shape is BoxShape3D:
			for x in [-0.5, 0.5]:
				for y in [-0.5, 0.5]:
					for z in [-0.5, 0.5]: points.append(Vector3(x, y, z) * shape.size)
		elif shape is CylinderShape3D:
			# Replace analytic cylinders with the exported faceted hull in native physics too.
			for y in [-shape.height * 0.5, shape.height * 0.5]:
				for i in 64: points.append(Vector3(cos(i * TAU / 64) * shape.radius, y, sin(i * TAU / 64) * shape.radius))
			var replacement := ConvexPolygonShape3D.new()
			replacement.points = points
			node.shape = replacement
		elif shape is ConvexPolygonShape3D:
			points = shape.points
		elif shape is ConcavePolygonShape3D:
			# Source rayWorld is two-sided; native physics must agree for the
			# exploration builders' inward-wound tube sections as well.
			shape.backface_collision = true
			points = shape.get_faces()
			kind = "triangles"
		else:
			push_error("Unsupported DM collider: " + shape.get_class())
			return false
		var path := str(root.get_path_to(node))
		var vertices: Array = []
		var low := Vector3(INF, INF, INF)
		var high := -low
		for p in points:
			var world: Vector3 = root.global_transform.affine_inverse() * node.global_transform * p
			vertices.append(vector(world))
			low = low.min(world)
			high = high.max(world)
		var walkable := bool(node.get_meta("dm_walkable", false))
		if not node.has_meta("dm_walkable"):
			if id == "prism-foundry":
				walkable = (high.y <= 4.01 and (high - low).x > 2.5 and (high - low).z > 1.9 and high.y - low.y < 1.1) or (shape is ConvexPolygonShape3D and high.y <= 4.01 and low.y < 0)
				if shape is CylinderShape3D: walkable = false
			elif id == "aurora-basin":
				for label in ["SculptedSnowBasin", "SealedFrozenLake", "LakesideCircuit", "LandingAccessRamp", "CrownSkywalk", "CrownVistaDeck", "HalcyonLanding", "ObservatoryApron"]:
					if path.contains(label): walkable = true
			elif id == "cinder-array":
				walkable = shape is ConvexPolygonShape3D and (high - low).x > 2.5 and (high - low).z > 2.5 and high.y <= 16.01 and high.y - low.y < 6.0
		records.append({"id": "collider-%04d" % records.size(), "path": path, "kind": kind, "walkable": walkable, "vertices": vertices})
	for child in node.get_children():
		if not _collect(child, root, id, records): return false
	return true

static func data(id: String) -> Dictionary:
	var path := "res://native_arenas/generated/" + id + ".json"
	if not FileAccess.file_exists(path): return {}
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func spawns(id: String, fallback: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for p in data(id).get("spawnPoints", []): result.append(Vector3(p.x, p.y, p.z))
	return fallback if result.is_empty() else result
