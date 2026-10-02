extends Node3D
const AssetAttachments = preload("res://vehicle_assets/attachment.gd")
## Source vehicle dimensions and +Z nose; seats/crew are rendered by Astra.
var turret := Node3D.new()
var wheels: Array[Node3D] = []
var kind := ""

func box(size: Vector3, at: Vector3, color: Color, parent: Node3D = self) -> void:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	n.material_override = mat
	n.position = at
	parent.add_child(n)

func wheel(x: float, z: float, radius: float, color: Color) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, radius, z)
	add_child(pivot)
	wheels.append(pivot)
	var tire := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.22 if kind == "scout" else 0.32
	cylinder.radial_segments = 16
	tire.mesh = cylinder
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	tire.material_override = mat
	tire.rotation.z = PI / 2
	pivot.add_child(tire)
	box(Vector3(0.025, radius * 0.95, radius * 0.95), Vector3.ZERO, Color("9caaa1"), pivot)

func _init(vehicle_kind: String = "titan") -> void:
	kind = vehicle_kind
	var dark := Color("202c30")
	var steel := Color("a4b3b4")
	var glass := Color("193e4b")
	add_child(turret)
	match kind:
		"titan":
			var armor := Color("626b59")
			box(Vector3(2.3, 0.65, 5.1), Vector3(0, 0.9, 0), armor)
			box(Vector3(2.3, 0.28, 1.2), Vector3(0, 1.28, 1.72), steel)
			for x: float in [-1.28, 1.28]:
				box(Vector3(0.45, 0.8, 5.15), Vector3(x, 0.55, 0), dark)
				box(Vector3(0.15, 0.34, 4.5), Vector3(x * 1.12, 1.05, 0), armor)
				for i in 8: wheel(x, -2.1 + i * 0.6, 0.37, dark)
			turret.position = Vector3(0, 1.5, -0.72)
			box(Vector3(1.95, 0.6, 1.95), Vector3(0, 0.1, 0), armor, turret)
			box(Vector3(0.36, 0.36, 2.15), Vector3(0, 0.12, 1.45), steel, turret)
			box(Vector3(0.5, 0.48, 0.2), Vector3(0, 0.12, 2.35), dark, turret)
		"scout":
			var recon := Color("708578")
			box(Vector3(0.78, 0.2, 1.8), Vector3(0, 0.37, 0), recon)
			box(Vector3(0.74, 0.19, 0.65), Vector3(0, 0.58, 0.64), recon)
			for x: float in [-0.45, 0.45]:
				for z: float in [-0.75, 0.75]: wheel(x, z, 0.245, dark)
			for x: float in [-0.34, 0.34]:
				box(Vector3(0.05, 0.6, 0.05), Vector3(x, 0.78, -0.25), steel)
				box(Vector3(0.05, 0.05, 0.95), Vector3(x, 1.04, -0.2), steel)
			box(Vector3(0.26, 0.25, 0.3), Vector3(-0.2, 0.65, 0.1), dark)
			box(Vector3(0.26, 0.25, 0.3), Vector3(0.2, 0.65, -0.5), dark)
			box(Vector3(0.04, 0.8, 0.04), Vector3(0.3, 1.05, -0.85), steel)
			turret.position = Vector3(0, 0.79, 0.04)
			box(Vector3(0.18, 0.16, 0.25), Vector3.ZERO, recon, turret)
			box(Vector3(0.05, 0.05, 0.55), Vector3(0, 0.11, 0.36), steel, turret)
		"transport":
			var armor := Color("657767")
			box(Vector3(2.32, 0.76, 5.8), Vector3(0, 1.04, 0), armor)
			box(Vector3(2.06, 0.88, 4.48), Vector3(0, 1.62, -0.52), armor)
			box(Vector3(2.05, 0.25, 1.25), Vector3(0, 1.52, 2.25), steel)
			for x: float in [-1.09, 1.09]:
				for z: float in [-2.14, 0.0, 2.14]: wheel(x, z, 0.56, dark)
				box(Vector3(0.08, 0.42, 0.78), Vector3(x, 1.8, 1.18), glass)
				for z: float in [-2.12, -0.94, 0.24]: box(Vector3(0.1, 0.55, 0.85), Vector3(x, 1.66, z), steel)
			box(Vector3(1.5, 1.0, 0.12), Vector3(0, 1.45, -2.94), dark)
			turret.position = Vector3(0, 2.16, -1.34)
			box(Vector3(0.94, 0.3, 0.7), Vector3(0, 0.32, 0), armor, turret)
			for x: float in [-0.31, 0.31]: box(Vector3(0.12, 0.12, 1.12), Vector3(x, 0.33, 0.73), steel, turret)
		"hornet":
			var hull := Color("929eae")
			box(Vector3(1.65, 0.65, 4.65), Vector3(0, 0.35, 0), hull)
			box(Vector3(1.28, 0.56, 1.4), Vector3(0, 0.75, -0.7), glass)
			box(Vector3(0.5, 0.45, 0.9), Vector3(0, 0.35, 2.22), hull)
			for x: float in [-1.75, 1.75]:
				# Four canted solar S-foils, paired engine nacelles, wingtip guns.
				for y: float in [0.12, 0.7]:
					box(Vector3(1.75, 0.09, 1.5), Vector3(x, y, 0.3), hull)
					box(Vector3(1.55, 0.025, 1.3), Vector3(x, y + 0.06, 0.3), dark)
				box(Vector3(0.55, 0.5, 1.9), Vector3(x, 0.35, 0.9), dark)
				box(Vector3(0.34, 0.34, 0.12), Vector3(x, 0.35, 1.9), Color("ff794b"))
				box(Vector3(0.13, 0.13, 1.55), Vector3(x * 1.45, 0.22, -0.65), steel)
			box(Vector3(1.8, 0.12, 0.65), Vector3(0, 0.6, 2.15), hull)
	AssetAttachments.install(self, kind)
