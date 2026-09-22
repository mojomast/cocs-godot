extends Node3D
## Bounded secondary silhouettes. Puma uses the existing detailed native model.
var turret := Node3D.new()
func box(size: Vector3, at: Vector3, color: Color, parent: Node3D = self) -> void:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	n.material_override = mat
	n.position = at
	parent.add_child(n)

func _init(kind: String = "titan") -> void:
	var hull := Color("72806d")
	var dark := Color("252c30")
	var steel := Color("a4b3b4")
	add_child(turret)
	match kind:
		"titan":
			box(Vector3(2.5, 0.8, 4.7), Vector3(0, 0.9, 0), hull)
			for x: float in [-1.2, 1.2]: box(Vector3(0.6, 0.8, 5.4), Vector3(x, 0.5, 0), dark)
			turret.position.y = 1.4
			box(Vector3(1.8, 0.8, 1.8), Vector3.ZERO, hull, turret)
			box(Vector3(0.25, 0.25, 2.5), Vector3(0, 0.1, 1.6), steel, turret)
		"transport":
			box(Vector3(2.3, 1.5, 5.8), Vector3(0, 1.05, 0), hull)
			box(Vector3(1.8, 0.45, 0.15), Vector3(0, 1.5, 2.94), dark)
			for x: float in [-1.15, 1.15]:
				for z: float in [-2.1, 0, 2.1]: box(Vector3(0.3, 0.8, 0.8), Vector3(x, 0.45, z), dark)
			turret.position = Vector3(0, 1.9, -1.3)
			box(Vector3(0.7, 0.35, 0.7), Vector3.ZERO, hull, turret)
			for x: float in [-0.2, 0.2]: box(Vector3(0.12, 0.12, 1.2), Vector3(x, 0, 0.6), steel, turret)
		"scout":
			box(Vector3(0.85, 0.35, 2.1), Vector3(0, 0.6, 0), hull)
			box(Vector3(0.6, 0.5, 0.8), Vector3(0, 0.9, -0.3), dark)
			for x: float in [-0.45, 0.45]:
				for z: float in [-0.7, 0.7]: box(Vector3(0.2, 0.6, 0.6), Vector3(x, 0.3, z), dark)
			turret.position.y = 0.95
			box(Vector3(0.1, 0.1, 0.9), Vector3(0, 0, 0.6), steel, turret)
		"hornet":
			box(Vector3(1.6, 0.8, 4.8), Vector3(0, 0.35, 0), hull)
			box(Vector3(1.3, 0.65, 1.6), Vector3(0, 0.8, 1.1), dark)
			box(Vector3(4.8, 0.2, 1.5), Vector3(0, 0.3, -0.4), hull)
			for x: float in [-2.2, 2.2]:
				box(Vector3(0.8, 0.65, 2.7), Vector3(x, 0.35, -0.5), dark)
				box(Vector3(0.9, 0.08, 2.5), Vector3(x, 0.72, -0.5), steel)
			for x: float in [-1.6, 1.6]: box(Vector3(0.12, 0.12, 1.3), Vector3(x, 0.1, 0.65), steel, turret)
