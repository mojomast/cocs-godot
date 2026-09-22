extends Node3D

# Original native supply icons. Root position/visibility belong to PortPickups.
# Labels use depth testing and a short visibility range, never an HUD overlay.
var kind: String = ""
var built: bool = false

func apply_kind(value: String) -> void:
	if built and kind == value: return
	kind = value
	built = true
	for child: Node in get_children():
		remove_child(child)
		child.free()
	var dark := _material(Color("233044"))
	var white := _material(Color("ecf7ff"), true)
	var color := Color("d9a75b")
	if kind == "health": color = Color("4ce3a0")
	elif kind == "armor": color = Color("59baff")
	elif kind == "rocket": color = Color("ff8850")
	elif kind in ["haste", "overcharge", "overshield"]: color = Color("bd8aff")
	var accent := _material(color, true)
	_cylinder("Pedestal", Vector3(0, -0.42, 0), 0.39, 0.39, 0.08, dark)
	_cylinder("AvailabilityRim", Vector3(0, -0.37, 0), 0.34, 0.34, 0.025, accent)
	match kind:
		"health":
			_box("MedicalCase", Vector3.ZERO, Vector3(0.55, 0.44, 0.28), accent)
			_box("Handle", Vector3(0, 0.27, 0), Vector3(0.24, 0.1, 0.12), dark)
			for side: float in [-1.0, 1.0]:
				_box("CrossVertical", Vector3(0, 0, side * 0.15), Vector3(0.085, 0.29, 0.025), white)
				_box("CrossHorizontal", Vector3(0, 0, side * 0.15), Vector3(0.29, 0.085, 0.025), white)
		"armor":
			_box("ShieldTop", Vector3(0, 0.15, 0), Vector3(0.55, 0.3, 0.17), accent)
			var tip := PrismMesh.new()
			tip.size = Vector3(0.55, 0.3, 0.17)
			var part := _part("ShieldPoint", tip, Vector3(0, -0.15, 0), accent)
			part.rotation.z = PI
			_box("ShieldSpine", Vector3(0, 0.07, -0.095), Vector3(0.06, 0.35, 0.035), white)
		"rocket":
			for x: float in [-0.15, 0.15]:
				_cylinder("RocketBody", Vector3(x, -0.025, 0), 0.085, 0.085, 0.43, white)
				_cylinder("RocketNose", Vector3(x, 0.27, 0), 0, 0.09, 0.17, accent)
				_box("RocketFin", Vector3(x, -0.22, 0), Vector3(0.23, 0.15, 0.055), accent)
		_:
			if kind in ["haste", "overcharge", "overshield"]:
				var crystal := _box("PowerCore", Vector3(0, 0.04, 0), Vector3(0.34, 0.34, 0.34), accent)
				crystal.rotation_degrees = Vector3(0, 45, 45)
			else:
				_box("SupplyCase", Vector3(0, -0.06, 0), Vector3(0.52, 0.32, 0.3), dark)
				for x: float in [-0.16, 0, 0.16]:
					_cylinder("SupplyCell", Vector3(x, 0.12, 0), 0.055, 0.055, 0.43, accent)
	var label := Label3D.new()
	label.name = "CloseLabel"
	label.text = kind.to_upper().left(24)
	label.position.y = 0.58
	label.font_size = 32
	label.pixel_size = 0.005
	label.modulate = color.lightened(0.3)
	label.outline_modulate = Color("172030")
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end = 12.0
	label.visibility_range_end_margin = 2.0
	add_child(label)
	set_meta("kind", kind)

func _material(color: Color, luminous: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	mat.emission_enabled = luminous
	mat.emission = color
	mat.emission_energy_multiplier = 0.2
	return mat

func _part(part_name: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = mat
	part.position = pos
	add_child(part)
	return part

func _box(part_name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(part_name, mesh, pos, mat)

func _cylinder(part_name: String, pos: Vector3, top: float, bottom: float, height: float, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	_part(part_name, mesh, pos, mat)
