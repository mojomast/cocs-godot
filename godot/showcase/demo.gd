extends Node3D
## PRISM FOUNDRY — authored native exploration, independent from the nine-map catalog.
const Surfaces = preload("res://moth/surfaces.gd")
const Library = preload("res://moth/library.gd")
const Explorer = preload("res://showcase/player.gd")
const COOLANT = preload("res://showcase/coolant.gdshader")
const PRISM = preload("res://showcase/prism.gdshader")

var player: CharacterBody3D
var exploration_camera: Camera3D
var tour_camera: Camera3D
var materials: Dictionary = {}
var batches: Dictionary = {}
var rings: Array[Node3D] = []
var turbines: Array[Node3D] = []
var hud: CanvasLayer
var zone_label: Label
var mode_label: Label
var help_label: Label
var help_visible := false
var tour_index := -1
var elapsed := 0.0
var hud_clock := 0.0
var smoke_seconds := -1.0
var static_body_count := 0
var repeated_instances := 0
var frame_samples: Array[float] = []
var previous_msaa := Viewport.MSAA_DISABLED

const VIEWS := [
	{"title": "01 / REACTOR ATRIUM", "eye": Vector3(11.5, 7.2, 12.5), "target": Vector3(-1, 4.9, -2)},
	{"title": "02 / TURBINE HALL", "eye": Vector3(-21, 2.1, 7.0), "target": Vector3(-29, 2.7, -4)},
	{"title": "03 / COOLANT GARDEN", "eye": Vector3(1.8, 1.75, -20), "target": Vector3(-1, 1.3, -31)},
	{"title": "04 / THE SALT REACH", "eye": Vector3(34.6, 5.7, 3), "target": Vector3(83, 8, -28)},
	{"title": "05 / FOUNDRY OVERVIEW", "eye": Vector3(47, 35, -49), "target": Vector3(-3, 2.4, -7)}
]

func _ready() -> void:
	name = "PrismFoundry"
	previous_msaa = get_viewport().msaa_3d
	_make_materials()
	_environment()
	_atrium()
	_reactor()
	_mezzanine()
	_turbine_hall()
	_coolant_garden()
	_observation_deck()
	_vista()
	_flush_batches()
	player = Explorer.new()
	add_child(player)
	exploration_camera = player.camera
	tour_camera = Camera3D.new()
	tour_camera.name = "PhotoCamera"
	tour_camera.fov = 68
	tour_camera.far = 450
	add_child(tour_camera)
	_make_hud()
	for argument in OS.get_cmdline_user_args():
		if argument == "--smoke": smoke_seconds = 4.0
		if argument.begins_with("--smoke-seconds="): smoke_seconds = clampf(float(argument.get_slice("=", 1)), 1.0, 300.0)
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("PRISM_FOUNDRY_READY ", JSON.stringify(feature_summary()))

func _make_materials() -> void:
	for spec in [
		["concrete", "weathered_concrete-worn", "b7c7c5", 0.88, 0.0, 0.23],
		["warm", "rough_stucco-weathered", "d9c8aa", 0.94, 0.0, 0.20],
		["floor", "weathered_concrete", "778a91", 0.86, 0.0, 0.27],
		["dark", "brushed_metal", "283b48", 0.48, 0.45, 0.65],
		["metal", "metal", "9baeb0", 0.36, 0.62, 0.40],
		["copper", "metal-oxide", "b96b3e", 0.46, 0.48, 0.40],
		["tread", "hex_paneling-mottle", "879c9d", 0.60, 0.32, 0.75],
		["sand", "sand", "968675", 0.98, 0.0, 0.08],
		["rock", "rough_stucco", "9d7259", 0.94, 0.0, 0.14],
		["foliage", "grass", "8b9980", 0.90, 0.0, 0.60]
	]:
		var m := Surfaces.create_surface(spec[1], Color(spec[2]))
		m.set_shader_parameter("roughness", spec[3])
		m.set_shader_parameter("metallic", spec[4])
		m.set_shader_parameter("repeat_scale", spec[5])
		m.set_shader_parameter("texture_saturation", 0.20)
		m.set_shader_parameter("texture_strength", 0.46)
		m.set_shader_parameter("normal_strength", 0.28)
		materials[spec[0]] = m
	materials["cyan"] = _plain(Color("7ae1d9"), 0.3, Color("58b9bb") * 0.8)
	materials["amber"] = _plain(Color("edb879"), 0.4, Color("e3a85a") * 0.6)
	materials["white"] = _plain(Color("e3e8dd"), 0.6)
	materials["black"] = _plain(Color("15252d"), 0.8)
	var water := ShaderMaterial.new()
	water.shader = COOLANT
	water.set_shader_parameter("flow_map", Library.texture("flow-field"))
	materials["water"] = water
	var prism := ShaderMaterial.new()
	prism.shader = PRISM
	materials["prism"] = prism

func _plain(color: Color, roughness: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.emission_enabled = emission != Color.BLACK
	m.emission = emission
	return m

func _environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("194761")
	sky_material.sky_horizon_color = Color("a3b7bc")
	sky_material.ground_bottom_color = Color("a3b7bc")
	sky_material.ground_horizon_color = Color("a3b7bc")
	sky_material.sky_curve = 1.5
	sky_material.sun_angle_max = 6.0
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("adc8d5")
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("a0b3bb")
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.18
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "SingleShadowSun"
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("ffe0b3")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 105
	add_child(sun)
	_light(Vector3(0, 7, 0), Color("69ccc8"), 3.0, 15)
	_light(Vector3(-28, 4, 0), Color("efb46f"), 2.0, 13)
	_light(Vector3(0, 4, -27), Color("8fced3"), 1.5, 12)
	get_viewport().msaa_3d = Viewport.MSAA_2X

func _light(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	add_child(light)

func _box(at: Vector3, size: Vector3, material: String, solid: bool = false, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _mesh(mesh, at, material, parent)
	if parent == self: instance.set_meta("static_box_material", material)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		_collider(at, shape, parent)
	return instance

func _mesh(mesh: Mesh, at: Vector3, material: String, parent: Node3D = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = materials[material]
	instance.position = at
	parent.add_child(instance)
	return instance

func _collider(at: Vector3, shape: Shape3D, parent: Node3D = self) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 2
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	static_body_count += 1
	return body

func _cylinder(at: Vector3, radius: float, height: float, material: String, solid: bool = false, top: float = -1.0, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 48
	var instance := _mesh(mesh, at, material, parent)
	if solid:
		var shape := CylinderShape3D.new()
		shape.radius = maxf(radius, mesh.top_radius)
		shape.height = height
		_collider(at, shape, parent)
	return instance

func _torus(at: Vector3, radius: float, thickness: float, material: String, parent: Node3D = self) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 64
	mesh.ring_segments = 10
	return _mesh(mesh, at, material, parent)

func _beam(a: Vector3, b: Vector3, width: float, depth: float, material: String, parent: Node3D = self) -> void:
	var instance := _box((a + b) * 0.5, Vector3(width, a.distance_to(b), depth), material, false, parent)
	instance.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func _repeat_box(at: Vector3, size: Vector3, material: String, rotation_y: float = 0.0) -> void:
	if not batches.has(material): batches[material] = []
	var basis := Basis(Vector3.UP, rotation_y) * Basis.from_scale(size)
	batches[material].append(Transform3D(basis, at))

func _flush_batches() -> void:
	# Fold all static box parts (including rotated roof wings/braces) into shared batches.
	# Their separate collision bodies remain; animated children retain individual meshes.
	for child in get_children():
		if child is MeshInstance3D and child.has_meta("static_box_material"):
			var key: String = child.get_meta("static_box_material")
			if not batches.has(key): batches[key] = []
			var transform: Transform3D = child.transform
			transform.basis = transform.basis * Basis.from_scale(child.mesh.size)
			batches[key].append(transform)
			child.free()
	for material in batches:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = batches[material].size()
		for i in multi.instance_count: multi.set_instance_transform(i, batches[material][i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Batched_" + material
		instance.multimesh = multi
		instance.material_override = materials[material]
		add_child(instance)
		repeated_instances += multi.instance_count

func _rail(a: Vector3, b: Vector3, material: String = "metal") -> void:
	_beam(a + Vector3.UP * 1.10, b + Vector3.UP * 1.10, 0.085, 0.085, material)
	_beam(a + Vector3.UP * 0.47, b + Vector3.UP * 0.47, 0.055, 0.055, "dark")
	var count := ceili(a.distance_to(b) / 2.0)
	for i in count + 1:
		var at := a.lerp(b, float(i) / count)
		_repeat_box(at + Vector3.UP * 0.55, Vector3(0.075, 1.1, 0.075), "dark")
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.12, 1.3, a.distance_to(b))
	var body := _collider((a + b) * 0.5 + Vector3.UP * 0.64, shape)
	body.look_at_from_position(body.position, body.position + (b - a).normalized(), Vector3.UP)

func _sign(text: String, at: Vector3, size: int = 48, color: Color = Color("d9e6df"), yaw: float = 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.rotation.y = yaw
	label.font_size = size
	label.pixel_size = 0.009
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	add_child(label)
	return label

func _atrium() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(36, 1, 36), "floor", true)
	# Contrasting compass paths and fine floor joints are instanced, not separate nodes.
	for side in [-1, 1]:
		_box(Vector3(side * 8.5, 0.008, 0), Vector3(3.4, 0.012, 35), "concrete")
		_box(Vector3(0, 0.012, side * 8.5), Vector3(35, 0.014, 3.4), "concrete")
		_repeat_box(Vector3(side * 6.65, 0.028, 10), Vector3(0.09, 0.02, 12), "copper")
	for x in range(-16, 18, 2):
		for z in range(-16, 18, 2):
			_repeat_box(Vector3(x, 0.021, z), Vector3(0.018, 0.012, 1.85), "dark")
	# Massive piers, angled knees and open roof trusses give the hall its silhouette.
	for x in [-17.0, 17.0]:
		for z in [-15.0, -6.0, 6.0, 15.0]:
			_box(Vector3(x, 5, z), Vector3(1.2, 10, 1.5), "concrete", true)
			_box(Vector3(x, 0.3, z), Vector3(1.65, 0.6, 2), "dark", true)
			_box(Vector3(x, 7.8, z), Vector3(1.38, 0.5, 1.7), "copper")
			_beam(Vector3(x, 7.7, z), Vector3(x * 0.65, 11.8, z), 0.7, 0.7, "warm")
	for z in [-15.0, 0.0, 15.0]:
		_beam(Vector3(-17, 10, z), Vector3(0, 14.6, z), 0.65, 0.65, "dark")
		_beam(Vector3(0, 14.6, z), Vector3(17, 10, z), 0.65, 0.65, "dark")
		_beam(Vector3(-12, 11.3, z), Vector3(12, 11.3, z), 0.22, 0.32, "copper")
		for x in [-8.0, 0.0, 8.0]:
			_beam(Vector3(x, 11.3, z), Vector3(x, 14.6 - absf(x) * 0.27, z), 0.12, 0.15, "metal")
	for x in [-12.0, -6.0, 0.0, 6.0, 12.0]:
		_box(Vector3(x, 14.6 - absf(x) * 0.27, 0), Vector3(0.16, 0.18, 31), "metal")
	# Folded roof wings shade the side galleries; the engine sits under the central oculus.
	for side in [-1, 1]:
		var wing := _box(Vector3(side * 13.6, 10.92, 0), Vector3(7.0, 0.20, 31.6), "dark")
		wing.rotation.z = -side * atan(0.27)
		_box(Vector3(side * 10.2, 11.9, 0), Vector3(0.22, 0.23, 31.9), "copper")
		for z in [-12.0, -6.0, 6.0, 12.0]:
			_box(Vector3(side * 17.95, 4.8, z), Vector3(0.82, 9.7, 0.40), "dark")
	# Portal openings remain genuine connected spaces at ground level.
	for x in [-18.0, 18.0]:
		for z in [-12.5, 12.5]:
			_box(Vector3(x, 3.6, z), Vector3(0.7, 7.2, 11), "warm", true)
		_box(Vector3(x, 8.6, 0), Vector3(0.9, 2.5, 35), "concrete", true)
	for x in [-13.0, 13.0]:
		_box(Vector3(x, 3.8, -18), Vector3(10, 7.6, 0.7), "concrete", true)
	_box(Vector3(0, 8.6, -18), Vector3(36, 2.2, 0.8), "warm", true)
	_box(Vector3(0, 2.1, 18), Vector3(36, 4.2, 0.8), "concrete", true)
	_box(Vector3(0, 8.4, 18), Vector3(36, 2.4, 0.8), "concrete", true)
	_box(Vector3(0, 6.1, 18), Vector3(20, 2.2, 0.8), "concrete", true)
	for x in [-17.0, -13.5, 13.5, 17.0]:
		_box(Vector3(x, 5.6, 18), Vector3(0.3, 3.2, 0.9), "dark", true)
	_box(Vector3(0, 0.55, 18.5), Vector3(36.4, 1.1, 0.32), "dark")
	_box(Vector3(0, 6.4, 17.53), Vector3(19, 2.8, 0.12), "dark")
	_sign("P R I S M   F O U N D R Y", Vector3(0, 6.7, 17.42), 70, Color("d7e1d3"), PI)
	_sign("HELIO-THERMAL RESEARCH   /   STATION 07", Vector3(0, 5.65, 17.41), 27, Color("dfb787"), PI)
	_box(Vector3(0, 6.9, -17.65), Vector3(13, 1, 0.16), "dark")
	_sign("03   /   COOLANT GARDEN", Vector3(0, 6.9, -17.53), 43)
	_sign("01", Vector3(-15.8, 5.9, -11), 130, Color("e6bc83"))
	# Landing orientation plaque, set into the floor rather than a modal screen.
	_box(Vector3(3.6, 0.65, 14.7), Vector3(1.6, 1.3, 0.7), "dark", true)
	var plaque := _box(Vector3(3.6, 1.32, 14.7), Vector3(1.45, 0.10, 0.9), "metal")
	plaque.rotation.x = deg_to_rad(12)
	for i in 5: _repeat_box(Vector3(3.6, 1.40, 14.40 + i * 0.12), Vector3(1.05 - i * 0.14, 0.025, 0.028), "cyan")
	var floor_title := _sign("THE PRISM ENGINE", Vector3(0, 0.04, 10.9), 38)
	floor_title.rotation.x = -PI / 2

func _reactor() -> void:
	_cylinder(Vector3(0, 0.25, 0), 5.5, 0.5, "dark", true)
	_cylinder(Vector3(0, 0.54, 0), 5.22, 0.10, "water")
	_torus(Vector3(0, 0.68, 0), 5.25, 0.11, "copper")
	_cylinder(Vector3(0, 0.95, 0), 3.15, 1.3, "concrete", true, 2.8)
	_cylinder(Vector3(0, 1.65, 0), 2.85, 0.35, "dark")
	_cylinder(Vector3(0, 2.0, 0), 2.3, 0.42, "copper", false, 1.8)
	_cylinder(Vector3(0, 2.5, 0), 1.8, 0.5, "metal", false, 1.0)
	var prism := SurfaceTool.new()
	prism.begin(Mesh.PRIMITIVE_TRIANGLES)
	prism.set_smooth_group(-1)
	var levels := [Vector2(0, 0.18), Vector2(0.55, 0.92), Vector2(4.7, 0.70), Vector2(5.6, 0.04)]
	for layer in levels.size() - 1:
		for side in 6:
			var points: Array[Vector3] = []
			for index in [side, side + 1]:
				for level in [levels[layer], levels[layer + 1]]:
					points.append(Vector3(cos(index * TAU / 6) * level.y, level.x, sin(index * TAU / 6) * level.y))
			for index in [0, 1, 2, 2, 1, 3]: prism.add_vertex(points[index])
	prism.generate_normals()
	_mesh(prism.commit(), Vector3(0, 2.6, 0), "prism")
	for i in 3:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 4.2 + i * 1.30, 0)
		pivot.rotation_degrees = Vector3(18 + i * 17, i * 61, 12 - i * 19)
		add_child(pivot)
		rings.append(pivot)
		_torus(Vector3.ZERO, 2.9 + i * 0.20, 0.14, "copper", pivot)
		_torus(Vector3(0, 0.13, 0), 2.9 + i * 0.20, 0.042, "cyan", pivot)
		for j in 6:
			var angle := j * TAU / 6.0
			var vane := _box(Vector3(cos(angle) * 3.0, 0, sin(angle) * 3.0), Vector3(0.5, 0.32, 0.64), "dark", false, pivot)
			vane.rotation.y = -angle
	for i in 8:
		var angle := TAU * i / 8.0
		var p := Vector3(cos(angle) * 4.25, 0, sin(angle) * 4.25)
		_cylinder(p + Vector3.UP * 1.02, 0.23, 1.05, "metal")
		_cylinder(p + Vector3.UP * 1.61, 0.29, 0.14, "cyan")
		var outer := Vector3(cos(angle) * 5.45, 0, sin(angle) * 5.45)
		_beam(p + Vector3.UP * 0.70, outer + Vector3.UP * 0.55, 0.18, 0.18, "copper")
	# Opaque, bounded motes remain visible in GL Compatibility without bloom.
	var particles := CPUParticles3D.new()
	particles.name = "ReactorMotes_48"
	particles.position = Vector3(0, 2.5, 0)
	particles.amount = 48
	particles.lifetime = 5
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 2.0
	particles.direction = Vector3.UP
	particles.spread = 18
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 1.1
	particles.gravity = Vector3.ZERO
	particles.scale_amount_min = 0.025
	particles.scale_amount_max = 0.055
	var particle_mesh := SphereMesh.new()
	particle_mesh.radial_segments = 6
	particle_mesh.rings = 3
	particle_mesh.material = materials["cyan"]
	particles.mesh = particle_mesh
	add_child(particles)

func _ramp(center_x: float) -> void:
	# Wedge top from z=7/y=0 to z=-11/y=4, 12.5 degrees, no staircase snagging.
	var points := PackedVector3Array([
		Vector3(center_x - 1.6, -0.30, 7), Vector3(center_x + 1.6, -0.30, 7),
		Vector3(center_x - 1.6, -0.30, -11), Vector3(center_x + 1.6, -0.30, -11),
		Vector3(center_x - 1.6, 0, 7), Vector3(center_x + 1.6, 0, 7),
		Vector3(center_x - 1.6, 4, -11), Vector3(center_x + 1.6, 4, -11)])
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	_collider(Vector3.ZERO, shape)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[4, 7, 5], [4, 6, 7], [0, 4, 5], [0, 5, 1], [2, 3, 7], [2, 7, 6], [0, 2, 6], [0, 6, 4], [1, 5, 7], [1, 7, 3]]:
		for index in tri: surface.add_vertex(points[index])
	surface.generate_normals()
	_mesh(surface.commit(), Vector3.ZERO, "tread")
	for edge in [-1.64, 1.64]:
		_rail(Vector3(center_x + edge, 0.05, 6.9), Vector3(center_x + edge, 4.05, -11))
	for i in 36:
		var z := 6.7 - i * 0.49
		_repeat_box(Vector3(center_x, (7 - z) * 4.0 / 18 + 0.017, z), Vector3(2.9, 0.018, 0.045), "metal")
	_box(Vector3(center_x, 3.8, -12), Vector3(3.2, 0.4, 2.05), "tread", true)

func _mezzanine() -> void:
	for side in [-1, 1]:
		_box(Vector3(side * 15.3, 3.8, 0), Vector3(4, 0.4, 32), "tread", true)
		_box(Vector3(0, 3.8, side * 14.5), Vector3(27, 0.4, 3), "tread", true)
		_ramp(side * 10.5)
		_rail(Vector3(side * 13.25, 4, -12.9), Vector3(side * 13.25, 4, 12.9))
		for z in [-11.0, -5.0, 5.0, 11.0]:
			_beam(Vector3(side * 17.5, 1.0, z), Vector3(side * 13.6, 3.6, z), 0.26, 0.26, "dark")
			_repeat_box(Vector3(side * 15.3, 4.018, z), Vector3(3.1, 0.02, 0.09), "copper")
	_rail(Vector3(-13.3, 4, 12.95), Vector3(13.3, 4, 12.95))
	_rail(Vector3(-8.8, 4, -12.95), Vector3(8.8, 4, -12.95))
	_rail(Vector3(-13.3, 4, -16), Vector3(13.3, 4, -16))
	_rail(Vector3(-13.3, 4, 16), Vector3(13.3, 4, 16))
	_rail(Vector3(-17.38, 4, -6.9), Vector3(-17.38, 4, 6.9))
	_box(Vector3(-17.63, 6.3, 0), Vector3(0.12, 1, 10), "dark")
	_box(Vector3(17.63, 6.5, 0), Vector3(0.12, 1, 10), "dark")
	_sign("02  /  TURBINE HALL", Vector3(-17.50, 6.3, 0), 39, Color("ebbc83"), PI / 2)
	_sign("04  /  SALT REACH", Vector3(17.5, 6.5, 0), 43, Color("cde2dc"), -PI / 2)

func _turbine_hall() -> void:
	_box(Vector3(-27, -0.5, 0), Vector3(18, 1, 20), "warm", true)
	_box(Vector3(-36, 3.7, 0), Vector3(0.7, 7.4, 20), "concrete", true)
	for z in [-10, 10]:
		_box(Vector3(-27, 3.7, z), Vector3(18, 7.4, 0.6), "warm", true)
	_box(Vector3(-27, 7.5, 0), Vector3(18.6, 0.4, 20), "dark", true)
	for x in [-20.0, -25.0, -30.0, -35.0]:
		_box(Vector3(x, 6.9, 0), Vector3(0.20, 0.5, 19), "metal")
		_box(Vector3(x, 6.55, 0), Vector3(0.12, 0.10, 12), "amber")
	for z in [-5.5, 5.5]:
		_box(Vector3(-28.5, 0.25, z), Vector3(8, 0.5, 4), "dark", true)
		var shell := _cylinder(Vector3(-28.5, 2.3, z), 1.65, 5.8, "metal", false, -1)
		shell.rotation.z = PI / 2
		var shape := BoxShape3D.new()
		shape.size = Vector3(6.2, 3.8, 3.6)
		_collider(Vector3(-28.5, 1.9, z), shape)
		for x in [-31.35, -29.8, -27.8, -25.7]:
			var band := _torus(Vector3(x, 2.3, z), 1.7, 0.12, "copper")
			band.rotation.z = PI / 2
		var rotor := Node3D.new()
		rotor.position = Vector3(-25.5, 2.3, z)
		add_child(rotor)
		turbines.append(rotor)
		var mouth := _cylinder(Vector3(-25.52, 2.3, z), 1.47, 0.06, "black")
		mouth.rotation.z = PI / 2
		for i in 10:
			var angle := i * TAU / 10
			var blade := _box(Vector3(0.1, cos(angle) * 0.90, sin(angle) * 0.90), Vector3(0.16, 0.78, 0.24), "dark", false, rotor)
			blade.rotation.x = angle + 0.38
		var hub := _cylinder(Vector3.ZERO, 0.28, 0.35, "copper", false, -1, rotor)
		hub.rotation.z = PI / 2
		# Service cable trays and pressure vessels: repeated ribs are one MultiMesh.
		for i in 28:
			_repeat_box(Vector3(-31.1 + i * 0.2, 3.97, z), Vector3(0.065, 0.11, 1.05), "dark")
		_cylinder(Vector3(-34.3, 1.2, z), 0.55, 2.4, "copper", true)
		_beam(Vector3(-34.3, 2.4, z), Vector3(-34.3, 5.6, z), 0.22, 0.22, "metal")
	for z in [-8.7, 8.7]:
		_box(Vector3(-27, 0.025, z), Vector3(16.5, 0.035, 0.15), "copper")
	for z in [-9.62, 9.62]:
		_box(Vector3(-27, 1.15, z), Vector3(17, 2.3, 0.12), "dark")
		for x in range(-34, -18):
			_repeat_box(Vector3(x, 4.3, z), Vector3(0.04, 2.6, 0.08), "copper")
		_beam(Vector3(-35, 5.7, z), Vector3(-19, 5.7, z), 0.16, 0.16, "metal")
	_sign("TURBINE / 02", Vector3(-35.55, 5.4, 0), 67, Color("e8bc80"), PI / 2)
	_sign("KINETIC RECOVERY     •     TWO ROTORS ONLINE", Vector3(-35.54, 4.45, 0), 22, Color("cedad3"), PI / 2)
	_box(Vector3(-32.8, 1.0, 0), Vector3(1.6, 2, 2.2), "dark", true)
	for z in [-0.65, 0, 0.65]:
		_box(Vector3(-31.98, 1.4, z), Vector3(0.05, 0.58, 0.48), "cyan")

func _coolant_garden() -> void:
	_box(Vector3(0, -0.5, -27), Vector3(25, 1, 18), "warm", true)
	for side in [-1, 1]:
		_box(Vector3(side * 12.5, 2.4, -27), Vector3(0.6, 4.8, 18), "concrete", true)
		_box(Vector3(side * 6.7, 0.42, -27.8), Vector3(6.4, 0.84, 12), "dark", true)
		_box(Vector3(side * 6.7, 0.87, -27.8), Vector3(6.1, 0.06, 11.7), "water")
		for z in [-23.0, -27.8, -32.5]:
			_cylinder(Vector3(side * 6.7, 1, z), 0.75, 0.35, "warm")
			for i in 9:
				var angle := i * 2.399
				var stem := Vector3(side * 6.7 + cos(angle) * 0.5, 1.1, z + sin(angle) * 0.5)
				var height := 0.65 + (i % 4) * 0.16
				_repeat_box(stem + Vector3.UP * height * 0.5, Vector3(0.025, height, 0.025), "foliage", angle)
				_repeat_box(stem + Vector3.UP * height, Vector3(0.055, 0.25, 0.065), "copper", angle)
				_leaf(stem, angle, height * 0.85)
	# Open pergola: intentionally casts legible alternating light and shade.
	for x in [-11.0, 11.0]:
		for z in [-20.0, -27.0, -34.0]:
			_box(Vector3(x, 3, z), Vector3(0.42, 6, 0.42), "warm", true)
		_box(Vector3(x, 6, -27), Vector3(0.3, 0.35, 17), "copper")
	for z in range(-35, -18):
		_repeat_box(Vector3(0, 6.1, z), Vector3(23, 0.13, 0.19), "metal")
	_box(Vector3(0, 1.8, -36), Vector3(25, 3.6, 0.65), "warm", true)
	_sign("C O O L A N T   G A R D E N", Vector3(0, 2.6, -35.62), 45, Color("4c6366"))
	_sign("CLOSED LOOP / OPEN SKY", Vector3(0, 1.82, -35.61), 26, Color("4c6366"))
	for z in [-22.0, -29.0, -34.0]:
		_box(Vector3(0, 0.022, z), Vector3(5.2, 0.03, 0.11), "copper")
	_box(Vector3(0, 0.55, -33), Vector3(4.4, 1.1, 1.1), "concrete", true)
	_box(Vector3(0, 1.15, -33), Vector3(4.6, 0.12, 1.3), "copper")

func _observation_deck() -> void:
	# Deck flush with upper catwalk. No teleport is needed to reach the panorama.
	_box(Vector3(26.7, 3.7, 0), Vector3(19.5, 0.6, 13), "warm", true)
	for z in [-6.5, 6.5]:
		_rail(Vector3(18, 4, z), Vector3(36.5, 4, z))
	_rail(Vector3(36.5, 4, -6.5), Vector3(36.5, 4, 6.5))
	# Lower opening has an honest parapet: east exit belongs to the upper loop.
	_box(Vector3(18.2, 1.85, 0), Vector3(0.45, 3.7, 13), "dark", true)
	for x in [22.0, 30.0]:
		for z in [-6.1, 6.1]:
			_box(Vector3(x, 6, z), Vector3(0.32, 4, 0.32), "copper", true)
		_beam(Vector3(x, 8, -6.2), Vector3(x, 8, 6.2), 0.25, 0.25, "dark")
	for z in [-5.5, -3.8, -2.1, -0.4, 1.3, 3.0, 4.7]:
		_repeat_box(Vector3(25.8, 8.15, z), Vector3(8.7, 0.10, 0.30), "metal")
	for z in [-3.5, 3.5]:
		_box(Vector3(30, 4.5, z), Vector3(3.5, 1, 1), "concrete", true)
		_box(Vector3(30, 5.06, z), Vector3(3.6, 0.13, 1.1), "copper")
	_cylinder(Vector3(34.5, 4.65, 0), 0.18, 1.3, "dark", true)
	var scope := _cylinder(Vector3(34.5, 5.35, 0), 0.22, 1.0, "metal")
	scope.rotation.z = PI / 2
	_sign("THE SALT REACH", Vector3(35.5, 4.95, -2.6), 25, Color("e9d0a3"), -PI / 2)
	# Cantilever braces are visible from the ground and overview.
	for z in [-5.5, 5.5]:
		_beam(Vector3(18, -1.5, z), Vector3(31, 3.4, z), 0.5, 0.5, "dark")

func _vista() -> void:
	# Scenery has no player collision; only the bounded foundry is navigable.
	_box(Vector3(0, -6, 0), Vector3(650, 1, 650), "sand")
	# The hall is founded in the salt bed; the observation deck is the cantilever.
	_box(Vector3(0, -3.25, 0), Vector3(36, 4.5, 36), "dark")
	_box(Vector3(-27, -3.25, 0), Vector3(18, 4.5, 20), "dark")
	_box(Vector3(0, -3.25, -27), Vector3(25, 4.5, 18), "dark")
	var rng := RandomNumberGenerator.new()
	rng.seed = 71027
	for i in 19:
		var angle := TAU * i / 19.0
		var distance := rng.randf_range(106, 210)
		var pos := Vector3(cos(angle) * distance, -6, sin(angle) * distance)
		_mesa(pos, rng.randf_range(17, 38), rng.randf_range(14, 31), rng)
	# A distant solar receiver and sails form a specific recognisable skyline.
	_cylinder(Vector3(84, 9, -31), 2.5, 30, "warm", false, 1.4)
	_torus(Vector3(84, 25, -31), 4.6, 0.38, "copper")
	_cylinder(Vector3(84, 25, -31), 1.3, 4.0, "cyan", false, 0.9)
	for x in [53.0, 66.0, 79.0, 92.0]:
		for z in [15.0, 28.0, 41.0]:
			var panel := _box(Vector3(x, -1.5, z), Vector3(9.0, 0.2, 7.0), "metal")
			panel.rotation.z = -0.35
			_beam(Vector3(x, -5.5, z), Vector3(x, -1.5, z), 0.2, 0.2, "dark")

func _mesa(at: Vector3, height: float, radius: float, rng: RandomNumberGenerator) -> void:
	# Irregular strata, undercut ledges and flat-shaded faces, rather than smooth cones.
	var segments := 11
	var radii: Array[float] = []
	for i in segments: radii.append(rng.randf_range(0.7, 1.3))
	var tiers := [Vector2(0, 1.2), Vector2(0.18, 0.97), Vector2(0.50, 0.71), Vector2(0.52, 0.82), Vector2(0.64, 0.78), Vector2(0.92, 0.64), Vector2(1, 0.54)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var lean := Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
	for layer in tiers.size() - 1:
		for i in segments:
			var points: Array[Vector3] = []
			for j in [i, (i + 1) % segments]:
				for tier in [tiers[layer], tiers[layer + 1]]:
					var angle: float = j * TAU / segments
					points.append(Vector3(cos(angle) * radius * radii[j] * tier.y + lean.x * tier.x, height * tier.x, sin(angle) * radius * radii[j] * tier.y + lean.y * tier.x))
			for index in [0, 1, 2, 2, 1, 3]: surface.add_vertex(points[index])
	for i in segments:
		var a := TAU * i / segments
		var b := TAU * (i + 1) / segments
		surface.add_vertex(Vector3(lean.x, height, lean.y))
		surface.add_vertex(Vector3(cos(a) * radius * radii[i] * 0.54 + lean.x, height, sin(a) * radius * radii[i] * 0.54 + lean.y))
		surface.add_vertex(Vector3(cos(b) * radius * radii[(i + 1) % segments] * 0.54 + lean.x, height, sin(b) * radius * radii[(i + 1) % segments] * 0.54 + lean.y))
	surface.generate_normals()
	_mesh(surface.commit(), at, "rock")

func _leaf(stem: Vector3, angle: float, height: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dir := Vector3(cos(angle), 0, sin(angle))
	var side := Vector3(-sin(angle), 0, cos(angle)) * 0.07
	var mid := stem + dir * 0.25 + Vector3.UP * height * 0.6
	var tip := stem + dir * 0.4 + Vector3.UP * height
	for point in [stem, mid - side, mid + side, mid - side, tip, mid + side]: surface.add_vertex(point)
	surface.generate_normals()
	_mesh(surface.commit(), Vector3.ZERO, "foliage")

func _make_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "ExplorationHUD"
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var top := ColorRect.new()
	top.color = Color(0.035, 0.065, 0.08, 0.80)
	top.position = Vector2(20, 18)
	top.size = Vector2(283, 65)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var line := ColorRect.new()
	line.color = Color("83d2c7")
	line.position = Vector2(20, 18)
	line.size = Vector2(3, 65)
	root.add_child(line)
	_label(root, "P R I S M   F O U N D R Y", Vector2(35, 27), 19, Color("e5ece3"))
	zone_label = _label(root, "01 / REACTOR ATRIUM", Vector2(35, 55), 12, Color("90b6b9"))
	var bottom := ColorRect.new()
	bottom.color = Color(0.035, 0.065, 0.08, 0.78)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 16
	bottom.offset_right = 667
	bottom.offset_top = -58
	bottom.offset_bottom = -8
	mode_label = _label(root, "", Vector2.ZERO, 14, Color("e6e6d7"))
	mode_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	mode_label.offset_left = 24
	mode_label.offset_top = -48
	mode_label.offset_bottom = -27
	var controls := _label(root, "WASD move   ·   Shift sprint   ·   Space jump   ·   Esc cursor   ·   F1 help", Vector2.ZERO, 13, Color("c5d4d5"))
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 24
	controls.offset_top = -27
	controls.offset_bottom = -6
	help_label = _label(root, "LOCAL EXPLORATION\n\nMouse  Look    /    Click  Capture\nW A S D  Walk    /    Shift  Sprint\nSpace  Jump    /    R  Return to arrival\nEsc  Release cursor\nP  Photo viewpoints    /    [ ]  Previous / next\nF2  Hide HUD    /    F1  Close help\n\nFollow either copper-edged ramp to the\nupper loop and the Salt Reach deck.\nWest: turbines. North: coolant garden.", Vector2(24, 103), 15, Color("eff2e6"))
	help_label.add_theme_color_override("font_shadow_color", Color("10242d"))
	help_label.add_theme_constant_override("shadow_offset_x", 2)
	help_label.add_theme_constant_override("shadow_offset_y", 2)
	help_label.hide()
	var crosshair := _label(root, "·", Vector2.ZERO, 20, Color(0.9, 0.98, 0.95, 0.65))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -3
	crosshair.offset_top = -14

func _label(parent: Node, text: String, at: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func set_viewpoint(index: int) -> void:
	tour_index = index
	player.clear_controls()
	player.controls_enabled = index < 0
	if index < 0:
		exploration_camera.make_current()
	else:
		var view: Dictionary = VIEWS[posmod(index, VIEWS.size())]
		tour_camera.position = view.eye
		tour_camera.look_at(view.target)
		tour_camera.make_current()
		zone_label.text = view.title

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_F1:
			help_visible = not help_visible
			help_label.visible = help_visible
		KEY_F2: hud.visible = not hud.visible
		KEY_P: set_viewpoint(0 if tour_index < 0 else -1)
		KEY_BRACKETLEFT:
			if tour_index >= 0: set_viewpoint(posmod(tour_index - 1, VIEWS.size()))
		KEY_BRACKETRIGHT:
			if tour_index >= 0: set_viewpoint(posmod(tour_index + 1, VIEWS.size()))
		KEY_R:
			if tour_index >= 0: set_viewpoint(-1)

func _process(delta: float) -> void:
	elapsed += delta
	for i in rings.size(): rings[i].rotate_y(delta * (0.13 + i * 0.065) * (1 if i % 2 == 0 else -1))
	for turbine in turbines: turbine.rotate_x(delta * 0.85)
	hud_clock += delta
	if hud_clock >= 0.15:
		hud_clock = 0.0
		var pos := player.position
		zone_label.text = VIEWS[posmod(tour_index, VIEWS.size())].title if tour_index >= 0 else ("02 / TURBINE HALL" if pos.x < -18 else ("03 / COOLANT GARDEN" if pos.z < -18 else ("04 / THE SALT REACH" if pos.x > 18 else ("01 / UPPER REACTOR LOOP" if pos.y > 3.7 else "01 / REACTOR ATRIUM"))))
		mode_label.text = (VIEWS[posmod(tour_index, VIEWS.size())].title + "   ·   [ ] change view   ·   P return to walking") if tour_index >= 0 else ("LOCAL EXPLORATION   ·   R return to arrival   ·   P photo views" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "CURSOR RELEASED   ·   Click to explore")
	if smoke_seconds > 0:
		if elapsed > 1: frame_samples.append(delta * 1000)
		if elapsed >= smoke_seconds:
			print("PRISM_FOUNDRY_SMOKE_OK ", JSON.stringify(runtime_summary()))
			get_tree().quit()

func feature_summary() -> Dictionary:
	return {"experience": "Prism Foundry", "standalone": true, "renderer": RenderingServer.get_current_rendering_method(), "areas": 4, "walkable_ramps": 2, "elevation_m": 4, "shadow_lights": 1, "unshadowed_omni_lights": 3, "cpu_particles": 48, "animated_rings": rings.size(), "turbines": turbines.size(), "multimesh_batches": batches.size(), "multimesh_instances": repeated_instances, "static_bodies": static_body_count, "nodes": _node_count(self), "network": false}

func runtime_summary() -> Dictionary:
	var summary := feature_summary()
	var total := 0.0
	for sample in frame_samples: total += sample
	summary["sampled_frame_ms_mean"] = total / maxf(frame_samples.size(), 1)
	summary["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	summary["rendered_primitives"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	summary["samples"] = frame_samples.size()
	return summary

func _node_count(node: Node) -> int:
	var total := 1
	for child in node.get_children(): total += _node_count(child)
	return total

func _exit_tree() -> void:
	get_viewport().msaa_3d = previous_msaa
