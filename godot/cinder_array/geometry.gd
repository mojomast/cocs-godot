extends RefCounted
## Small deterministic native mesh builder. Repeated solids are material-batched.

var root: Node3D
var body: StaticBody3D
var batches: Dictionary = {}
var meshes := 0
var triangles := 0
var instances := 0
var collision_shapes := 0

func _init(parent: Node3D) -> void:
	root = parent
	body = StaticBody3D.new()
	body.name = "WalkableCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)

func add_mesh(label: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	root.add_child(node)
	meshes += 1
	triangles += _triangle_count(mesh)
	return node

func _triangle_count(mesh: Mesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var indices: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else 0
		count += int((indices if indices > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3)
	return count

func batch(label: String, mesh: Mesh, material: Material, transform: Transform3D) -> void:
	if not batches.has(label):
		batches[label] = {"mesh": mesh, "material": material, "transforms": []}
	batches[label].transforms.append(transform)

func flush() -> void:
	for label: String in batches:
		var data: Dictionary = batches[label]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = data.mesh
		mm.instance_count = data.transforms.size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, data.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.name = label
		node.multimesh = mm
		node.material_override = data.material
		root.add_child(node)
		meshes += 1
		instances += mm.instance_count
		triangles += _triangle_count(data.mesh) * mm.instance_count
	batches.clear()

func box(label: String, center: Vector3, size: Vector3, material: Material, solid: bool = false, basis: Basis = Basis.IDENTITY) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	batch(label, mesh, material, Transform3D(basis.scaled_local(size), center))
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		add_shape(shape, Transform3D(basis, center))

func beam(label: String, a: Vector3, b: Vector3, width: float, depth: float, material: Material, solid: bool = false) -> void:
	var up := (b - a).normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.1:
		right = up.cross(Vector3.RIGHT).normalized()
	var basis := Basis(right, up, right.cross(up).normalized())
	box(label, (a + b) * 0.5, Vector3(width, a.distance_to(b), depth), material, solid, basis)

func cylinder(label: String, center: Vector3, radius: float, height: float, material: Material, sides: int = 12, taper: float = 1.0, basis: Basis = Basis.IDENTITY) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = taper
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = sides
	mesh.rings = 1
	batch(label, mesh, material, Transform3D(basis.scaled_local(Vector3(radius, height, radius)), center))

func add_shape(shape: Shape3D, transform: Transform3D = Transform3D.IDENTITY) -> void:
	var node := CollisionShape3D.new()
	node.shape = shape
	node.transform = transform
	body.add_child(node)
	collision_shapes += 1

func convex(points: PackedVector3Array) -> void:
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	add_shape(shape)

func prism(label: String, polygon: PackedVector3Array, thickness: float, material: Material, solid: bool = true) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, polygon.size() - 1):
		triangle(st, polygon[0], polygon[i], polygon[i + 1])
		triangle(st, polygon[0] - Vector3.UP * thickness, polygon[i + 1] - Vector3.UP * thickness, polygon[i] - Vector3.UP * thickness)
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		quad(st, a, a - Vector3.UP * thickness, b - Vector3.UP * thickness, b)
	st.generate_normals()
	add_mesh(label, st.commit(), material)
	if solid:
		var vertices := polygon.duplicate()
		for point in polygon: vertices.append(point - Vector3.UP * thickness)
		convex(vertices)

static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	triangle(st, a, b, c)
	triangle(st, a, c, d)
