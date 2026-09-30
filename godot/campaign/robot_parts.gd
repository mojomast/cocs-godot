extends RefCounted
## Bake colored low-poly primitives into one surface per rigid moving assembly.
const DARK := Color("263442")
const STEEL := Color("889baa")
const RUBBER := Color("111b26")
var tool := SurfaceTool.new()
var triangles: int = 0

func _init() -> void:
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

func primitive(mesh: PrimitiveMesh, pos: Vector3, color: Color, rotation := Vector3.ZERO, size_scale := Vector3.ONE) -> void:
	var arrays := mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var basis := Basis.from_euler(rotation)
	for i: int in range(indices.size() if not indices.is_empty() else vertices.size()):
		var index: int = indices[i] if not indices.is_empty() else i
		tool.set_color(color)
		tool.set_normal((basis * (normals[index] / size_scale)).normalized())
		tool.add_vertex(basis * (vertices[index] * size_scale) + pos)
	triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3

func box(pos: Vector3, size: Vector3, color: Color, rotation := Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	primitive(mesh, pos, color, rotation)

func cylinder(pos: Vector3, radius: float, height: float, color: Color, sides: int = 8, rotation := Vector3.ZERO, taper: float = 1.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * taper
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	primitive(mesh, pos, color, rotation)

func beam(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, a.distance_to(b), width)
	var direction := (b - a).normalized()
	primitive(mesh, (a + b) * 0.5, color, Quaternion(Vector3.UP, direction).get_euler())

func shell(pos: Vector3, size: Vector3, color: Color, sides: int = 10) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = sides
	mesh.rings = 4
	primitive(mesh, pos, color, Vector3.ZERO, size)

func finish(parent: Node3D, material: Material, label: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = tool.commit()
	instance.material_override = material
	instance.set_meta("triangles", triangles)
	parent.add_child(instance)
	return instance
