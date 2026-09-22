extends Node3D
## Native stylized Puma. Vehicle forward is +Z (not the actor camera's -Z).
var wheels: Array[Node3D] = []
var accent := StandardMaterial3D.new()
var turret := Node3D.new()

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	return m

func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	parent.add_child(n)
	return n

func _init() -> void:
	var olive := material(Color("626b42"))
	var dark := material(Color("222831"))
	var steel := material(Color("aebac5"))
	accent.albedo_color = Color("dfc98d")
	box(self, Vector3(1.8, 0.3, 3.3), Vector3(0, 0.55, 0), olive)
	box(self, Vector3(1.7, 0.3, 1.1), Vector3(0, 0.83, 1.03), olive)
	box(self, Vector3(1.9, 0.2, 0.2), Vector3(0, 0.43, 1.7), dark)
	box(self, Vector3(1.5, 0.3, 0.1), Vector3(0, 0.7, 1.64), dark)
	for x: float in [-0.55, 0.55]:
		box(self, Vector3(0.24, 0.15, 0.08), Vector3(x, 0.84, 1.62), material(Color("fff0ba")))
		box(self, Vector3(0.24, 0.15, 0.08), Vector3(x, 0.75, -1.65), material(Color("e34b38")))
		box(self, Vector3(0.48, 0.5, 0.18), Vector3(x, 1.0, -0.15), dark)
	for x: float in [-0.7, 0.7]:
		box(self, Vector3(0.1, 0.7, 0.1), Vector3(x, 1.22, 0.45), dark)
		box(self, Vector3(0.1, 0.7, 0.1), Vector3(x, 1.22, -0.7), dark)
		box(self, Vector3(0.12, 0.12, 1.3), Vector3(x, 1.59, -0.1), steel)
		box(self, Vector3(0.15, 0.4, 1.0), Vector3(x, 0.85, -1.05), accent)
	box(self, Vector3(1.5, 0.12, 0.12), Vector3(0, 1.59, 0.45), steel)
	box(self, Vector3(1.5, 0.4, 0.12), Vector3(0, 0.85, -1.55), accent)
	for x: float in [-0.9, 0.9]:
		for z: float in [-1.18, 1.18]:
			var wheel := Node3D.new()
			wheel.position = Vector3(x, 0.42, z)
			add_child(wheel)
			wheels.append(wheel)
			var tire := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.42
			cylinder.bottom_radius = 0.42
			cylinder.height = 0.3
			cylinder.radial_segments = 12
			tire.mesh = cylinder
			tire.material_override = dark
			tire.rotation.z = PI / 2
			wheel.add_child(tire)
			box(wheel, Vector3(0.32, 0.5, 0.08), Vector3.ZERO, steel)
			box(wheel, Vector3(0.32, 0.08, 0.5), Vector3.ZERO, steel)
	add_child(turret)
	turret.position = Vector3(0, 1.1, -0.95)
	box(turret, Vector3(0.5, 0.32, 0.5), Vector3(0, 0.22, 0), olive)
	for x: float in [-0.13, 0.13]:
		box(turret, Vector3(0.1, 0.1, 0.85), Vector3(x, 0.25, 0.55), steel)

func set_team(team: int) -> void:
	accent.albedo_color = Color("e56859") if team == 0 else (Color("58a7ed") if team == 1 else Color("dfc98d"))
