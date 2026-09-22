extends RefCounted
## Conservative, immutable map voxel atlas. Built once per configure, never per particle.
## Surface/box cells are solid; empty space below bridges stays empty. Rasterization
## deliberately over-clips sub-cell details instead of leaking cues through walls.
const GRID := Vector3i(96, 48, 96)
const WIDTH := 1152 # 12 z slices across, 8 down
const HEIGHT := 384
var bounds := AABB()
var cell := Vector3.ONE
var bytes := PackedByteArray()
var texture: ImageTexture
var solid_cells := 0
var source_shapes := 0
var unsupported_shapes := 0

func build(world_bounds: AABB, map: Dictionary, collision_root: Node = null) -> void:
	bounds = world_bounds
	cell = bounds.size / Vector3(GRID)
	bytes.resize(WIDTH * HEIGHT)
	bytes.fill(0)
	solid_cells = 0
	source_shapes = 0
	unsupported_shapes = 0
	for b: Dictionary in map.get("blocks", []):
		box(AABB(Vector3(b.x - b.w / 2.0, 0, b.z - b.d / 2.0), Vector3(b.w, b.h, b.d)))
	for t: Dictionary in map.get("terrain", {}).get("support_triangles", []):
		var v: Array = t.vertices
		triangle(Vector3(v[0][0], v[0][1], v[0][2]), Vector3(v[1][0], v[1][1], v[1][2]), Vector3(v[2][0], v[2][1], v[2][2]))
	# Native arena authority publishes triangle-list surfaces. Actual native
	# CollisionShape3D roots add sealed solid volumes and vertical walls.
	var native_surfaces: Array = map.get("terrain", {}).get("surfaces", []) if map.get("terrain", {}).get("support_triangles", []).is_empty() else []
	for surface: Dictionary in native_surfaces:
		var vertices: Array = surface.get("vertices", [])
		for i in range(0, vertices.size() - 2, 3):
			var a: Array = vertices[i]
			var b: Array = vertices[i + 1]
			var c: Array = vertices[i + 2]
			triangle(Vector3(a[0], a[1], a[2]), Vector3(b[0], b[1], b[2]), Vector3(c[0], c[1], c[2]))
	if collision_root != null: _visit(collision_root)
	# Bounds-only integration still has a lower boundary; it does not pretend to
	# know interior geometry. snapshot explicitly reports the supplied shape count.
	texture = ImageTexture.create_from_image(Image.create_from_data(WIDTH, HEIGHT, false, Image.FORMAT_R8, bytes))

func _visit(node: Node) -> void:
	if node is CollisionShape3D and not node.disabled and node.shape != null:
		var shape: Shape3D = node.shape
		if shape is BoxShape3D:
			box(node.global_transform * AABB(-shape.size / 2.0, shape.size))
		elif shape is ConcavePolygonShape3D:
			var faces: PackedVector3Array = shape.get_faces()
			for i in range(0, faces.size(), 3): triangle(node.global_transform * faces[i], node.global_transform * faces[i + 1], node.global_transform * faces[i + 2])
		elif shape is SphereShape3D:
			box(node.global_transform * AABB(Vector3.ONE * -shape.radius, Vector3.ONE * shape.radius * 2.0))
		elif shape is CylinderShape3D or shape is CapsuleShape3D:
			var size := Vector3(shape.radius * 2.0, shape.height, shape.radius * 2.0)
			box(node.global_transform * AABB(-size / 2.0, size))
		elif shape is ConvexPolygonShape3D:
			var points: PackedVector3Array = shape.points
			if not points.is_empty():
				var aabb := AABB(points[0], Vector3.ZERO)
				for point: Vector3 in points: aabb = aabb.expand(point)
				box(node.global_transform * aabb)
		else:
			unsupported_shapes += 1
	for child: Node in node.get_children(): _visit(child)

func voxel(p: Vector3) -> Vector3i:
	return Vector3i(((p - bounds.position) / cell).floor())

func _mark(v: Vector3i) -> void:
	if v.x < 0 or v.y < 0 or v.z < 0 or v.x >= GRID.x or v.y >= GRID.y or v.z >= GRID.z: return
	var index := (v.z / 12 * GRID.y + v.y) * WIDTH + (v.z % 12) * GRID.x + v.x
	if bytes[index] == 0:
		bytes[index] = 255
		solid_cells += 1

func solid(p: Vector3) -> bool:
	if not bounds.has_point(p): return true
	var v := voxel(p)
	return bytes[(v.z / 12 * GRID.y + v.y) * WIDTH + (v.z % 12) * GRID.x + v.x] != 0

func box(aabb: AABB) -> void:
	source_shapes += 1
	var lo := voxel(aabb.position).clamp(Vector3i.ZERO, GRID - Vector3i.ONE)
	var hi := voxel(aabb.end).clamp(Vector3i.ZERO, GRID - Vector3i.ONE)
	for z in range(lo.z, hi.z + 1):
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1): _mark(Vector3i(x, y, z))

func triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	# Barycentric grid sampling in the triangle plane, with <= half-cell spacing.
	# Covers vertical walls as well as horizontal support; bridges are thin shells.
	source_shapes += 1
	var ab := (b - a) / cell
	var ac := (c - a) / cell
	var steps := maxi(1, ceili(maxf(ab.length(), ac.length()) * 2.0))
	for i in range(steps + 1):
		for j in range(steps - i + 1):
			_mark(voxel(a + (b - a) * float(i) / steps + (c - a) * float(j) / steps))
