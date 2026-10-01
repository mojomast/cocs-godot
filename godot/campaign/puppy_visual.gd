extends Node3D
const Motion = preload("res://source_operators/motion_math.gd")
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
var walk_weight := 0.0
var walk_velocity := 0.0
var sit_weight := 0.0
var sit_velocity := 0.0
var happy_weight := 0.0
var happy_velocity := 0.0
var gait_phase := 0.0
var movement_speed := 0.0
var sampled_movement := false
var automatic_animation := true

func set_movement(speed: float) -> void:
	movement_speed = clampf(speed,0.0,4.0)
	sampled_movement = true

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
	if automatic_animation: advance(dt)

func advance(dt: float) -> void:
	if body == null: return
	if not is_finite(dt) or dt <= 0.0: return
	time += dt
	reaction = maxf(0, reaction - dt)
	var happy := reaction > 0 or pose == "happy"
	var walk := Motion.spring(walk_weight,walk_velocity,clampf(movement_speed/0.8,0,1) if sampled_movement else (1.0 if pose=="walk" else 0.0),18.0,dt)
	walk_weight = walk.x; walk_velocity = walk.y
	var sit := Motion.spring(sit_weight,sit_velocity,1.0 if pose=="sit" else 0.0,14.0,dt)
	sit_weight = sit.x; sit_velocity = sit.y
	var joy := Motion.spring(happy_weight,happy_velocity,1.0 if happy else 0.0,16.0,dt)
	happy_weight = joy.x; happy_velocity = joy.y
	var speed := movement_speed if sampled_movement else (0.9 if pose=="walk" else 0.0)
	if speed > 0.02: gait_phase = fposmod(gait_phase + speed*dt*TAU/0.65,TAU)
	# Breathing belongs to chest/head, never the support paws or entire body.
	body.position.y = sit_weight*0.035
	body.rotation.x = sit_weight*0.08
	for i: int in range(paws.size()):
		var step := Motion.contact(gait_phase + (PI if i in [0,3] else 0.0),0.65,0.09)*walk_weight
		paws[i].position.z = (-0.29 if i%2==0 else 0.40)-step.x
		paws[i].position.y = 0.13 + step.y - body.position.y + sin(body.rotation.x)*paws[i].position.z
	head.rotation.z = sin(time*1.1)*0.035 + happy_weight*0.16
	head.rotation.x = (0.18 if pose == "work" else 0.0) - happy_weight*0.08*sin(time*3.0)
	# Lean toward the offered hand, then settle. No camera or player rig movement.
	head.position.z = -0.40 - (0.12 * sin(PI * clampf(reaction / 1.8, 0, 1)) if reaction > 0 else 0.0)
	tail.rotation.z = sin(time*8.0)*(0.18+happy_weight*0.55)
	for ear: Node3D in ears: ear.rotation.x = sin(time*8.0-0.55)*(0.025+happy_weight*0.10)+head.rotation.x*-0.25
