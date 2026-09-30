extends Node3D
## Patch: small, feet-anchored, collision-free companion. -Z is forward.
static var materials: Dictionary = {}
static var spheres: Dictionary = {}
var body: Node3D
var head: Node3D
var tail: Node3D
var ears: Array[Node3D] = []
var paws: Array[Node3D] = []
var time := 0.0
var reaction := 0.0
var pose := "idle"
var lod := 0

static func coat(color: String) -> StandardMaterial3D:
	if not materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color)
		mat.roughness = 0.91
		materials[color] = mat
	return materials[color]

static func sphere(color: String) -> SphereMesh:
	if not spheres.has(color):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 12
		mesh.rings = 6
		mesh.material = coat(color)
		spheres[color] = mesh
	return spheres[color]

func part(parent: Node3D, name_: String, color: String, at: Vector3, scale_: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = name_
	pivot.position = at
	parent.add_child(pivot)
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere(color)
	mesh.scale = scale_
	pivot.add_child(mesh)
	return pivot

func _ready() -> void:
	body = Node3D.new()
	body.name = "BodyMotion"
	add_child(body)
	part(body, "Back", "b77847", Vector3(0, 0.48, 0.09), Vector3(0.34, 0.29, 0.48))
	part(body, "Chest", "f2ddae", Vector3(0, 0.42, -0.29), Vector3(0.25, 0.28, 0.19))
	for side: int in [-1, 1]:
		for z: float in [-0.29, 0.40]:
			paws.append(part(body, "Paw", "e9cc98", Vector3(side * 0.23, 0.13, z), Vector3(0.105, 0.13, 0.15)))
	tail = part(body, "Tail", "b77847", Vector3(0, 0.65, 0.49), Vector3(0.095, 0.25, 0.10))
	tail.rotation.x = -0.8
	head = Node3D.new()
	head.name = "HeadMotion"
	head.position = Vector3(0, 0.72, -0.40)
	body.add_child(head)
	part(head, "Face", "bb7b47", Vector3.ZERO, Vector3(0.31, 0.30, 0.29))
	part(head, "Blaze", "f2ddae", Vector3(0, 0.02, -0.257), Vector3(0.11, 0.20, 0.055))
	part(head, "Muzzle", "f2ddae", Vector3(0, -0.13, -0.26), Vector3(0.22, 0.14, 0.19))
	part(head, "Nose", "28252a", Vector3(0, -0.085, -0.427), Vector3(0.083, 0.060, 0.057))
	for side: int in [-1, 1]:
		part(head, "Eye", "211e21", Vector3(side * 0.17, 0.072, -0.244), Vector3(0.047, 0.053, 0.028))
		part(head, "EyeGlint", "ffffff", Vector3(side * 0.158, 0.088, -0.269), Vector3(0.014, 0.015, 0.009))
		var ear := part(head, "FloppyEar", "754b36", Vector3(side * 0.255, 0.23, 0.015), Vector3(0.13, 0.24, 0.125))
		ear.rotation.z = side * 0.36
		ears.append(ear)

func set_pose(value: String) -> void:
	pose = value

func pet() -> void:
	reaction = 1.8

func select_distance(distance: float) -> void:
	var next := 2 if distance > 48 else (1 if distance > 18 else 0)
	if next == lod: return
	lod = next
	# Distant detail only; keep unmistakable ears, head, feet and tail.
	for part_: Node in head.get_children():
		if part_.name in ["EyeGlint", "Blaze"]: part_.visible = lod == 0

func _process(dt: float) -> void:
	if body == null: return
	time += dt
	reaction = maxf(0, reaction - dt)
	var happy := reaction > 0 or pose == "happy"
	var sitting := pose == "sit"
	# Keep the paws at or just above the authoritative ground plane, even sitting.
	body.position.y = (0.09 if sitting else 0.02) + sin(time * (7 if happy else 2.8)) * (0.012 if happy else 0.008)
	body.rotation.x = 0.12 if sitting else 0.0
	for i: int in range(paws.size()):
		paws[i].position.y = 0.13 + (maxf(0, sin(time * 9 + (PI if i in [0, 3] else 0))) * 0.09 if pose == "walk" else 0.0)
	head.rotation.z = sin(time * 2.1) * 0.10 + (0.20 if happy else 0.0)
	head.rotation.x = (0.18 if pose == "work" else 0.0) - (0.26 * sin(reaction * 4.5) if reaction > 0 else 0.0)
	# Lean toward the offered hand, then settle. No camera or player rig movement.
	head.position.z = -0.40 - (0.12 * sin(PI * clampf(reaction / 1.8, 0, 1)) if reaction > 0 else 0.0)
	tail.rotation.z = sin(time * (19 if happy else 6)) * (0.85 if happy else 0.28)
	for ear: Node3D in ears: ear.rotation.x = sin(time * 5) * (0.15 if happy else 0.04)
