extends Node3D
## Additive, offline native exploration. No combat-map or server data is consumed.
const Surfaces = preload("res://moth/surfaces.gd")
const Library = preload("res://moth/library.gd")
const AURORA = preload("res://aurora_basin/aurora.gdshader")
const SKY = preload("res://aurora_basin/sky.gdshader")
const FISSURE = preload("res://aurora_basin/fissure.gdshader")
const SNOW = preload("res://aurora_basin/snow.gdshader")

const SEED := 740219
const LAKE_RADIUS := 24.5
const LOOP_RADIUS := 27.0
const DECK_WIDTH := 4.6
const SPAWN_YAW := -0.455
const SPAWN_PITCH := 0.106
var spawn := Vector3(-23, 0.12, 34)
var route_points := PackedVector3Array()
var skywalk_points := PackedVector3Array()
var landing_points := PackedVector3Array()
var built := false
var build_ms := 0.0
var materials: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _beacon_bodies: Array[Transform3D] = []
var _beacon_heads: Array[Transform3D] = []

func get_spawn() -> Vector3:
	return spawn

func build() -> void:
	if built: return
	built = true
	var start := Time.get_ticks_usec()
	_rng.seed = SEED
	_make_materials()
	_make_environment()
	_make_terrain()
	_make_lake()
	_make_routes()
	_make_observatory()
	_make_arches()
	_make_scatter()
	_make_aurora()
	_make_snow()
	_flush_beacons()
	build_ms = (Time.get_ticks_usec() - start) / 1000.0

func _make_materials() -> void:
	materials.snow = Surfaces.create_surface("ice-cracked", Color("bdd7df"), true)
	materials.snow.set_shader_parameter("texture_strength", 0.22)
	materials.snow.set_shader_parameter("roughness", 0.88)
	materials.snow.set_shader_parameter("repeat_scale", 0.14)
	materials.ice = Surfaces.create_surface("ice-cracked", Color("70adbf"), true)
	materials.ice.set_shader_parameter("texture_strength", 0.44)
	materials.ice.set_shader_parameter("albedo_gain", 2.1)
	materials.ice.set_shader_parameter("repeat_scale", 0.28)
	materials.ice.set_shader_parameter("normal_strength", 0.19)
	Surfaces.apply_lut(materials.ice, "entanglement-ceramic", 0.035, 0.7)
	materials.lake = Surfaces.create_surface("ice-cracked", Color("386c87"), true)
	materials.lake.set_shader_parameter("albedo_gain", 2.4)
	materials.lake.set_shader_parameter("texture_strength", 0.45)
	materials.lake.set_shader_parameter("repeat_scale", 0.12)
	materials.lake.set_shader_parameter("roughness", 0.27)
	materials.lake.set_shader_parameter("metallic", 0.15)
	materials.deck = Surfaces.create_surface("hex_paneling-mottle", Color("bed0d4"))
	materials.deck.set_shader_parameter("texture_strength", 0.23)
	materials.deck.set_shader_parameter("repeat_scale", 0.38)
	materials.metal = Surfaces.create_surface("brushed_metal", Color("304d60"))
	materials.metal.set_shader_parameter("texture_strength", 0.27)
	materials.shell = Surfaces.create_surface("weathered_concrete-worn", Color("c2d5da"))
	materials.shell.set_shader_parameter("texture_strength", 0.21)
	materials.gold = Surfaces.create_surface("brushed_metal", Color("b89462"))
	materials.gold.set_shader_parameter("texture_strength", 0.20)
	materials.dark = _plain(Color("0f233b"))
	materials.teal = _plain(Color("72d9dd"), true)
	materials.warm = _plain(Color("f4c887"), true)
	materials.fissure = ShaderMaterial.new()
	materials.fissure.shader = FISSURE

func _plain(color: Color, unshaded := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _make_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "PolarAtmosphere"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY
	sky_material.set_shader_parameter("frost_panorama", Library.sky("frost"))
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a0c2e3")
	environment.ambient_light_energy = 0.52
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("41647a")
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.0028
	environment.fog_sky_affect = 0.0
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-36, -28, -12)
	moon.light_color = Color("c5e3f2")
	moon.light_energy = 0.85
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 90.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(moon)
	_light(Vector3(-28, 4.5, 19), Color("ffcd8f"), 1.1, 13.0)
	_light(Vector3(2, 5, -7), Color("6fd5df"), 0.75, 16.0)

func _light(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	add_child(light)

func terrain_height(x: float, z: float) -> float:
	var radius := Vector2(x, z * 0.92).length()
	if radius < 42.0: return -0.24
	var angle := atan2(z, x)
	var band := smoothstep(42.0, 66.0, radius)
	var ridge := 15.0 + 7.0 * sin(angle * 5.0 + 0.4) + 5.0 * sin(angle * 9.0 - 0.7)
	var waves := sin(x * 0.12 + z * 0.045) * sin(z * 0.14) * 3.0
	return -0.24 + band * (ridge + waves) * (1.0 - smoothstep(73.0, 103.0, radius) * 0.5)

func _make_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STEPS := 90
	const STEP := 2.4
	for z in STEPS:
		for x in STEPS:
			var a := Vector3((x - STEPS / 2.0) * STEP, 0, (z - STEPS / 2.0) * STEP)
			var b := a + Vector3(0, 0, -STEP)
			var c := a + Vector3(STEP, 0, 0)
			var d := a + Vector3(STEP, 0, -STEP)
			a.y = terrain_height(a.x, a.z)
			b.y = terrain_height(b.x, b.z)
			c.y = terrain_height(c.x, c.z)
			d.y = terrain_height(d.x, d.z)
			var normal := (c - a).cross(b - a).normalized()
			var tint := Color("c6e0e7").lerp(Color("42627f"), clampf((1.0 - normal.y) * 1.7, 0, 0.8))
			_tri(st, a, b, c, tint)
			_tri(st, c, b, d, tint)
	st.generate_normals()
	_make_mesh("SculptedSnowBasin", st.commit(), materials.snow, true)

func _make_lake() -> void:
	_cylinder("RecessedFissureInlays", Vector3(0, -0.38, 0), LAKE_RADIUS, 0.54, materials.fissure, false, 96)
	var body := StaticBody3D.new()
	body.name = "SealedFrozenLake"
	var shape := CylinderShape3D.new()
	shape.height = 0.56
	shape.radius = LAKE_RADIUS
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = -0.24
	body.add_child(collider)
	add_child(body)
	# Build clipped Voronoi plates once, as one opaque mesh. The narrow inlays
	# represent sealed fractures: the entire lake has continuous collision.
	var seeds := PackedVector2Array([Vector2(-1, -1)])
	for ring in 3:
		var count := 8 + ring * 8
		for i in count:
			var angle := TAU * (i + 0.27 * ring) / count
			var radius := 6.0 + ring * 7.2 + _rng.randf_range(-1.5, 1.5)
			seeds.append(Vector2(cos(angle), sin(angle)) * radius)
	var boundary := PackedVector2Array()
	for i in 96: boundary.append(Vector2(cos(TAU * i / 96.0), sin(TAU * i / 96.0)) * LAKE_RADIUS)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for seed_index in seeds.size():
		var polygon := boundary.duplicate()
		for other in seeds.size():
			if other == seed_index: continue
			var midpoint := (seeds[seed_index] + seeds[other]) * 0.5
			polygon = _clip_polygon(polygon, midpoint, seeds[other] - seeds[seed_index])
			if polygon.size() < 3: break
		if polygon.size() < 3: continue
		var center := Vector2.ZERO
		for p in polygon: center += p
		center /= polygon.size()
		var tint := Color.WHITE.lerp(Color("8babd0"), _rng.randf_range(0.0, 0.40))
		for i in polygon.size():
			var p := polygon[i].lerp(center, 0.014)
			var q := polygon[(i + 1) % polygon.size()].lerp(center, 0.014)
			_tri(st, Vector3(center.x, 0.038, center.y), Vector3(p.x, 0.038, p.y), Vector3(q.x, 0.038, q.y), tint)
	_make_mesh("FortyNineSealedIcePlates", st.commit(), materials.lake)

func _clip_polygon(poly: PackedVector2Array, midpoint: Vector2, normal: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var da := (a - midpoint).dot(normal)
		var db := (b - midpoint).dot(normal)
		if da <= 0.0: result.append(a)
		if (da <= 0.0) != (db <= 0.0): result.append(a.lerp(b, da / (da - db)))
	return result

func _make_routes() -> void:
	for i in 145:
		var angle := deg_to_rad(132.0) + TAU * i / 144.0
		route_points.append(Vector3(cos(angle) * LOOP_RADIUS, 0.08, sin(angle) * LOOP_RADIUS))
	_strip("LakesideCircuit", route_points, 5.0, 0.32, materials.snow, true)
	for i in range(0, 144, 6):
		var p := route_points[i]
		var outside := Vector3(p.x, 0, p.z).normalized()
		_beacon(p + outside * 2.13)
	landing_points = _smooth(PackedVector3Array([Vector3(-23, 0.08, 30), Vector3(-19, 0.08, 25), Vector3(-16, 0.08, 21), Vector3(-14, 0.08, 20)]), 8)
	_strip("LandingAccessRamp", landing_points, 5.0, 0.26, materials.deck, true)
	skywalk_points = _smooth(PackedVector3Array([
		Vector3(25, 0.08, 12), Vector3(31, 0.08, 13), Vector3(36, 1.1, 7), Vector3(36, 3.3, -3),
		Vector3(34, 5.6, -15), Vector3(28, 9.0, -26), Vector3(18, 9.0, -31),
		Vector3(8, 9.0, -31), Vector3(-4, 6.3, -33), Vector3(-16, 3.0, -33),
		Vector3(-27, 0.08, -27), Vector3(-30, 0.08, -16), Vector3(-25, 0.08, -11)
	]), 9)
	_strip("CrownSkywalk", skywalk_points, DECK_WIDTH, 0.35, materials.deck, true)
	_make_rails()
	_cylinder("CrownVistaDeck", Vector3(16, 8.68, -34), 6.0, 0.64, materials.deck, true, 64)
	_ring("VistaCompass", Vector3(16, 9.016, -34), 4.7, 0.055, materials.warm)
	_cylinder("VistaInstrumentBase", Vector3(16, 9.45, -37.8), 0.65, 0.9, materials.metal, true)
	var optic := _cylinder("VistaOptic", Vector3(16, 10.23, -37.8), 0.30, 1.35, materials.shell)
	optic.rotation_degrees.x = 61
	_beacon(Vector3(11.5, 9.0, -34.9))
	_beacon(Vector3(20.7, 9.0, -32.8))
	# Rounded lookout's exposed northern edge; bridge access remains open.
	var guard := PackedVector3Array()
	for i in 33:
		var angle := PI + PI * i / 32.0
		guard.append(Vector3(16 + cos(angle) * 5.8, 9.0, -34 + sin(angle) * 5.8))
	_guard_line("VistaOuterGuard", guard)
	_sign(Vector3(26.8, 1.45, 12.4), -0.45, "03  /  THE CROWN", "SKYWALK  /  +9 M", 2.8)
	_sign(Vector3(-18.2, 1.40, 20.0), -0.35, "02  /  THE FRACTURE", "SEALED ICE  /  LOOP", 3.0)

func _smooth(points: PackedVector3Array, subdivisions: int) -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in points.size() - 1:
		var a := points[maxi(i - 1, 0)]
		var b := points[i]
		var c := points[i + 1]
		var d := points[mini(i + 2, points.size() - 1)]
		for step in subdivisions:
			var t := float(step) / subdivisions
			var point := 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t)
			# Linear elevation prevents Catmull-Rom overshoot at flat deck joins.
			point.y = lerpf(b.y, c.y, t)
			result.append(point)
	result.append(points[-1])
	return result

func _side(points: PackedVector3Array, i: int) -> Vector3:
	var tangent := points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
	return Vector3(-tangent.z, 0, tangent.x).normalized()

func _strip(label: String, points: PackedVector3Array, width: float, depth: float, mat: Material, collide: bool) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size() - 1:
		var a := points[i] - _side(points, i) * width * 0.5
		var b := points[i + 1] - _side(points, i + 1) * width * 0.5
		var c := points[i] + _side(points, i) * width * 0.5
		var d := points[i + 1] + _side(points, i + 1) * width * 0.5
		_tri(st, a, b, c)
		_tri(st, c, b, d)
		var down := Vector3.DOWN * depth
		_quad(st, a + down, b + down, a, b, Color("759aad"))
		_quad(st, c, d, c + down, d + down, Color("759aad"))
		_quad(st, a + down, c + down, b + down, d + down, Color("759aad"))
	return _make_mesh(label, st.commit(), mat, collide)

func _make_rails() -> void:
	var supports: Array[Transform3D] = []
	for sign_value in [-1.0, 1.0]:
		var edge := PackedVector3Array()
		for i in skywalk_points.size():
			var p: Vector3 = skywalk_points[i] + _side(skywalk_points, i) * (DECK_WIDTH * 0.5 - 0.12) * sign_value
			# The lookout is a walk-in widening, with no rail through its entrance.
			var inside_vista := Vector2(p.x - 16, p.z + 34).length() < 5.95 and p.y >= 8.95
			if inside_vista or p.y < 0.5:
				if edge.size() >= 2: _guard_line("SkywalkGuard", edge)
				edge.clear()
			else:
				edge.append(p)
		if edge.size() >= 2: _guard_line("SkywalkGuard", edge)
	for i in range(6, skywalk_points.size() - 6, 6):
		var p := skywalk_points[i]
		var height := maxf(p.y + 0.22, 0.2)
		supports.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.65, height, 0.65)), Vector3(p.x, height * 0.5 - 0.24, p.z)))
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.8
	mesh.height = 1.0
	mesh.radial_segments = 8
	_multimesh("SkywalkPiers", mesh, materials.metal, supports)

func _guard_line(label: String, edge: PackedVector3Array) -> void:
	var top := PackedVector3Array()
	var lower := PackedVector3Array()
	var posts: Array[Transform3D] = []
	for i in edge.size():
		top.append(edge[i] + Vector3.UP * 1.08)
		lower.append(edge[i] + Vector3.UP * 0.52)
		if i % 3 == 0: posts.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.11, 1.12, 0.11)), edge[i] + Vector3.UP * 0.56))
		if i < edge.size() - 1:
			var a := edge[i]
			var b := edge[i + 1]
			var barrier := StaticBody3D.new()
			barrier.name = label + "Collision"
			var collider := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.14, 1.12, a.distance_to(b) + 0.08)
			collider.shape = shape
			barrier.add_child(collider)
			add_child(barrier)
			barrier.position = (a + b) * 0.5 + Vector3.UP * 0.56
			barrier.look_at(barrier.position + (b - a))
	_tube(label + "Top", top, 0.046, materials.teal, 6)
	_tube(label + "Lower", lower, 0.037, materials.metal, 6)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_multimesh(label + "Posts", box, materials.metal, posts)

func _make_observatory() -> void:
	_cylinder("HalcyonLanding", Vector3(-23, -0.145, 29), 10.5, 0.50, materials.deck, true, 72)
	_ring("LandingPerimeter", Vector3(-23, 0.098, 29), 9.65, 0.075, materials.warm)
	_ring("LandingMarking", Vector3(-23, 0.102, 29), 5.4, 0.055, materials.teal)
	for i in 8:
		var angle := i * TAU / 8.0
		_beacon(Vector3(-23 + cos(angle) * 9.9, 0.08, 29 + sin(angle) * 9.9))
	# Landing and lake share a datum: crossings cannot hide an abrupt step.
	_strip("ObservatoryApron", PackedVector3Array([Vector3(-26, 0.09, 27), Vector3(-31, 0.09, 20), Vector3(-33, 0.09, 16)]), 7.0, 0.32, materials.deck, true)
	var center := Vector3(-34, 0, 13)
	_cylinder("ObservatoryPlinth", center + Vector3.UP * 0.35, 7.3, 1.15, materials.metal, true, 64)
	_cylinder("ObservatoryDrum", center + Vector3.UP * 2.3, 5.7, 3.0, materials.shell, true, 64)
	_cylinder("PanoramicWindowBand", center + Vector3.UP * 3.6, 5.79, 0.96, materials.dark, false, 64)
	_ring("ObservatoryWindowSill", center + Vector3.UP * 3.18, 5.83, 0.065, materials.warm)
	_ring("ObservatoryCornice", center + Vector3.UP * 4.12, 5.85, 0.12, materials.metal)
	# Segmented dome, an intentionally open telescope slot, and external ribs.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dome_center := center + Vector3.UP * 4.13
	for longitude in 64:
		var u0 := TAU * longitude / 64.0
		var u1 := TAU * (longitude + 1) / 64.0
		if longitude >= 11 and longitude <= 15: continue
		for latitude in 14:
			var v0 := PI * 0.5 * latitude / 14.0
			var v1 := PI * 0.5 * (latitude + 1) / 14.0
			_quad(st, dome_center + _dome_point(u0, v0), dome_center + _dome_point(u1, v0), dome_center + _dome_point(u0, v1), dome_center + _dome_point(u1, v1))
	st.generate_normals()
	_make_mesh("SlottedObservatoryDome", st.commit(), materials.shell)
	for longitude in range(0, 64, 8):
		var ribs := PackedVector3Array()
		for latitude in 20: ribs.append(dome_center + _dome_point(TAU * longitude / 64.0, PI * 0.5 * latitude / 19.0) * 1.008)
		_tube("DomeMeridian", ribs, 0.055, materials.metal, 6)
	var telescope := _cylinder("PolarTelescope", center + Vector3(1.8, 7.3, 3.4), 0.70, 5.4, materials.metal)
	telescope.rotation_degrees = Vector3(48, 24, 0)
	var lens := _cylinder("TelescopeLens", center + Vector3(2.62, 9.08, 5.27), 0.71, 0.10, materials.teal)
	lens.rotation_degrees = telescope.rotation_degrees
	var gantry := PackedVector3Array()
	for i in 49:
		var angle := -0.15 + PI * 1.2 * i / 48.0
		gantry.append(center + Vector3(cos(angle) * 8.2, 1.7 + sin(angle) * 11.0, -1.0))
	_tube("ObservatoryOrbitalFrame", gantry, 0.22, materials.metal, 10)
	var inner := PackedVector3Array()
	for p in gantry: inner.append(p + Vector3(0, 0, 0.24))
	_tube("OrbitalFrameLight", inner, 0.05, materials.warm, 6)
	_sign(Vector3(-28.6, 1.45, 24.2), 0.18, "01  /  HALCYON", "POLAR OBSERVATORY", 3.4)
	var mast := center + Vector3(-7.6, 0.0, 5.0)
	_cylinder("WeatherMast", mast + Vector3.UP * 4.0, 0.11, 8.0, materials.metal)
	_cylinder("WeatherMastCap", mast + Vector3.UP * 8.1, 0.24, 0.25, materials.warm)

func _dome_point(u: float, v: float) -> Vector3:
	return Vector3(cos(u) * cos(v) * 5.85, sin(v) * 5.6, sin(u) * cos(v) * 5.85)

func _make_arches() -> void:
	_ice_arch("TheFrozenGate", Vector3(3, -0.6, -9.0), 11.5, 15.0, -0.10)
	_ice_arch("WesternIceArch", Vector3(-13, -0.5, -10.0), 6.0, 9.0, -0.48)
	# Sculpture groups are off the signed route and each gets a coarse solid hull.
	for i in 13:
		var angle := i * 2.39996
		var radius := 2.0 + sqrt(float(i)) * 0.65
		var at := Vector3(-2.5 + cos(angle) * radius, 0.0, -6 + sin(angle) * radius)
		var height := _rng.randf_range(3.2, 8.0)
		var shard := _make_mesh("PressureRidge", _crystal_mesh(), materials.ice)
		shard.position = at
		shard.scale = Vector3(_rng.randf_range(0.7, 1.5), height, _rng.randf_range(0.6, 1.35))
		shard.rotation = Vector3(_rng.randf_range(-0.16, 0.16), angle, _rng.randf_range(-0.22, 0.22))
		shard.create_convex_collision()
	for i in 15:
		var angle := -0.12 - i * 0.14 + _rng.randf_range(-0.04, 0.04)
		var radius := _rng.randf_range(50.0, 54.0)
		var at := Vector3(cos(angle) * radius, -0.5, sin(angle) * radius)
		at.y = terrain_height(at.x, at.z) - 1.0
		var shard := _make_mesh("GlacialCliff", _crystal_mesh(), materials.ice)
		shard.position = at
		shard.scale = Vector3(_rng.randf_range(3.0, 6.5), _rng.randf_range(7.0, 21.0), _rng.randf_range(3.5, 6.0))
		shard.rotation = Vector3(_rng.randf_range(-0.16, 0.16), angle, _rng.randf_range(-0.20, 0.20))
		shard.create_convex_collision()

func _ice_arch(label: String, center: Vector3, half_width: float, height: float, yaw: float) -> void:
	var points := PackedVector3Array()
	var rotation_basis := Basis(Vector3.UP, yaw)
	for i in 49:
		var angle := PI * i / 48.0
		var point := Vector3(cos(angle) * half_width, sin(angle) * height, sin(angle * 2.0) * 1.7)
		points.append(center + rotation_basis * point)
	_tube(label, points, 1.65, materials.ice, 10, true, true)
	var ridge := PackedVector3Array()
	for p in points: ridge.append(p + Vector3(0, 0.82, -0.56))
	_tube(label + "SnowCrest", ridge, 0.88, materials.snow, 8)

func _crystal_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var angle := TAU * i / 6.0
		var next := TAU * (i + 1) / 6.0
		var a := Vector3(cos(angle), 0, sin(angle))
		var b := Vector3(cos(next), 0, sin(next))
		var c := Vector3(cos(angle) * 0.72 + 0.14, 0.70 + 0.07 * sin(angle * 2.0), sin(angle) * 0.72)
		var d := Vector3(cos(next) * 0.72 + 0.14, 0.70 + 0.07 * sin(next * 2.0), sin(next) * 0.72)
		var tint := Color("72aec2").lerp(Color("deedf0"), (cos(angle - 0.7) + 1.0) * 0.5)
		_quad(st, a, b, c, d, tint)
		_tri(st, c, d, Vector3(0.25, 1.0, -0.12), Color("d0e9ed"))
	return st.commit()

func _make_scatter() -> void:
	var transforms: Array[Transform3D] = []
	for i in 180:
		var angle := _rng.randf() * TAU
		var radius := _rng.randf_range(30.5, 41.0)
		var at := Vector3(cos(angle) * radius, -0.15, sin(angle) * radius)
		if at.distance_to(Vector3(-34, 0, 13)) < 12.0 or at.distance_to(Vector3(-23, 0, 29)) < 13.0: continue
		var clear := true
		for p in skywalk_points:
			if Vector2(at.x - p.x, at.z - p.z).length() < 4.5: clear = false; break
		if not clear: continue
		var scale_value := Vector3(_rng.randf_range(0.20, 0.6), _rng.randf_range(0.3, 1.4), _rng.randf_range(0.20, 0.6))
		transforms.append(Transform3D(Basis(Vector3.UP, angle).scaled(scale_value), at))
	_multimesh("ShoreIceScatter", _crystal_mesh(), materials.ice, transforms)

func _make_aurora() -> void:
	for layer in 2:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 160:
			var u := i / 160.0
			var v := (i + 1) / 160.0
			var a := _aurora_point(u, layer)
			var b := _aurora_point(v, layer)
			var height := Vector3.UP * (23.0 + layer * 6.0)
			_uv_tri(st, a, a + height, b, Vector2(u, 0), Vector2(u, 1), Vector2(v, 0))
			_uv_tri(st, b, a + height, b + height, Vector2(v, 0), Vector2(u, 1), Vector2(v, 1))
		var material := ShaderMaterial.new()
		material.shader = AURORA
		material.set_shader_parameter("phase", layer * 3.1)
		material.set_shader_parameter("strength", 0.86 if layer == 0 else 0.46)
		var curtain := _make_mesh("AuroraCurtain%d" % layer, st.commit(), material)
		curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _aurora_point(u: float, layer: int) -> Vector3:
	return Vector3(-110 + u * 220, 29.0 + layer * 15.0 + sin(u * 11.0 + layer) * 5.0, -66.0 - layer * 24.0 + sin(u * 13.0 + layer * 2.0) * 12.0)

func _make_snow() -> void:
	for at in [Vector3(-19, 7, 23), Vector3(11, 8, 3), Vector3(16, 16, -32)]:
		var snow := CPUParticles3D.new()
		snow.name = "LocalSnow128"
		snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		snow.position = at
		snow.amount = 128
		snow.lifetime = 10.0
		snow.preprocess = 6.0
		snow.local_coords = false
		snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		snow.emission_box_extents = Vector3(12, 4, 12)
		snow.direction = Vector3(-0.25, -1, 0.08)
		snow.spread = 15.0
		snow.initial_velocity_min = 0.35
		snow.initial_velocity_max = 0.8
		snow.gravity = Vector3(-0.035, -0.025, 0)
		snow.scale_amount_min = 0.025
		snow.scale_amount_max = 0.065
		snow.fixed_fps = 30
		snow.visibility_aabb = AABB(Vector3(-20, -18, -18), Vector3(40, 30, 36))
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0))
		fade.set_color(1, Color(1, 1, 1, 0))
		fade.add_point(0.12, Color.WHITE)
		fade.add_point(0.8, Color.WHITE)
		snow.color_ramp = fade
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		var mat := ShaderMaterial.new()
		mat.shader = SNOW
		quad.material = mat
		snow.mesh = quad
		add_child(snow)

func _beacon(at: Vector3) -> void:
	_beacon_bodies.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.13, 0.86, 0.13)), at + Vector3.UP * 0.43))
	_beacon_heads.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.22, 0.16, 0.22)), at + Vector3.UP * 0.88))

func _flush_beacons() -> void:
	var cylinder := CylinderMesh.new()
	cylinder.height = 1.0
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.radial_segments = 8
	_multimesh("RouteBeaconBases", cylinder, materials.metal, _beacon_bodies)
	_multimesh("RouteBeaconLenses", cylinder, materials.warm, _beacon_heads)

func _sign(at: Vector3, yaw: float, title: String, subtitle: String, width: float) -> void:
	var root := Node3D.new()
	root.name = "Wayfinding"
	root.position = at
	root.rotation.y = yaw
	add_child(root)
	var panel := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.83, 0.10)
	panel.mesh = box
	panel.material_override = materials.dark
	root.add_child(panel)
	for i in 2:
		var label := Label3D.new()
		label.text = title if i == 0 else subtitle
		label.font_size = 40 if i == 0 else 28
		label.pixel_size = 0.006
		label.position = Vector3(0, 0.15 if i == 0 else -0.16, 0.065)
		label.modulate = Color("dcecf1") if i == 0 else Color("a5c9d2")
		label.outline_size = 0
		label.no_depth_test = false
		root.add_child(label)
	for x in [-width * 0.37, width * 0.37]:
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.height = 1.6
		post_mesh.top_radius = 0.055
		post_mesh.bottom_radius = 0.055
		post_mesh.radial_segments = 6
		post.mesh = post_mesh
		post.position = Vector3(x, -0.8, 0)
		post.material_override = materials.metal
		root.add_child(post)

func _ring(label: String, center: Vector3, radius: float, thickness: float, mat: Material) -> void:
	var points := PackedVector3Array()
	for i in 97: points.append(center + Vector3(cos(TAU * i / 96.0), 0, sin(TAU * i / 96.0)) * radius)
	_tube(label, points, thickness, mat, 6)

func _tube(label: String, points: PackedVector3Array, radius: float, mat: Material, sides := 8, collide := false, organic := false) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for i in points.size():
		var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var u := tangent.cross(Vector3.FORWARD).normalized()
		if u.length_squared() < 0.1: u = tangent.cross(Vector3.UP).normalized()
		var v := tangent.cross(u).normalized()
		var ring := PackedVector3Array()
		for j in sides:
			var angle := TAU * j / sides
			var wobble := (1.0 + 0.19 * sin(i * 0.47 + j * 1.8)) if organic else 1.0
			ring.append(points[i] + (cos(angle) * u + sin(angle) * v) * radius * wobble)
		rings.append(ring)
	for i in points.size() - 1:
		for j in sides:
			var next := (j + 1) % sides
			_quad(st, rings[i][j], rings[i][next], rings[i + 1][j], rings[i + 1][next])
	return _make_mesh(label, st.commit(), mat, collide)

func _cylinder(label: String, at: Vector3, radius: float, height: float, mat: Material, collide := false, sides := 32) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	var instance := _make_mesh(label, mesh, mat)
	instance.position = at
	if collide:
		var body := StaticBody3D.new()
		var shape := CylinderShape3D.new()
		shape.height = height
		shape.radius = radius
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		instance.add_child(body)
	return instance

func _make_mesh(label: String, mesh: Mesh, mat: Material, collide := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = mat
	add_child(instance)
	if collide: instance.create_trimesh_collision()
	return instance

func _multimesh(label: String, mesh: Mesh, mat: Material, transforms: Array[Transform3D]) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size(): multimesh.set_instance_transform(i, transforms[i])
	instance.multimesh = multimesh
	instance.material_override = mat
	add_child(instance)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color := Color.WHITE) -> void:
	st.set_color(color)
	var normal := (c - a).cross(b - a).normalized()
	if normal.length_squared() < 0.1: normal = Vector3.UP
	st.set_normal(normal)
	# Inherited Moth vertex-tint surfaces reserve UV.x for a semantic depth bias.
	# Native triplanar geometry needs no UVs; zero avoids world-position bias.
	st.set_uv(Vector2.ZERO)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color := Color.WHITE) -> void:
	_tri(st, a, b, c, color)
	_tri(st, c, b, d, color)

func _uv_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_normal(Vector3.BACK)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)

func area_at(at: Vector3) -> String:
	if at.y > 2.0 or at.x > 28.0: return "03   THE CROWN  /  SKYWALK"
	if at.distance_to(Vector3(-26, 0, 28)) < 16.0: return "01   HALCYON  /  OBSERVATORY"
	return "02   THE FRACTURE  /  FROZEN LAKE"

func camera_views() -> Dictionary:
	return {
		"landing": {"eye": Vector3(spawn.x, 1.705, spawn.z), "target": Vector3(0, 7.3, -13), "eye_level": true},
		"observatory": {"eye": Vector3(-17, 1.705, 34), "target": Vector3(-33, 5.0, 12), "eye_level": true},
		"fracture": {"eye": Vector3(15, 1.64, 17), "target": Vector3(-4, 7.8, -12), "eye_level": true},
		"vista": {"eye": Vector3(18, 10.6, -29.5), "target": Vector3(-7, 0.5, 6), "eye_level": true},
		"overview": {"eye": Vector3(84, 72, 99), "target": Vector3(0, 4.0, -3), "eye_level": false}
	}

func resource_report() -> Dictionary:
	var report := {"nodes": 0, "meshes": 0, "mesh_triangles": 0, "multimeshes": 0, "multimesh_instances": 0, "multimesh_triangles": 0, "collision_shapes": 0, "lights": 0, "shadow_lights": 0, "particle_emitters": 0, "particle_capacity": 0, "invalid_transforms": 0, "build_ms": build_ms}
	var pending: Array[Node] = [self]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		report.nodes += 1
		for child in node.get_children(): pending.append(child)
		if node is Node3D and not node.transform.is_finite(): report.invalid_transforms += 1
		if node is MeshInstance3D:
			report.meshes += 1
			report.mesh_triangles += _triangle_count(node.mesh)
		if node is MultiMeshInstance3D:
			report.multimeshes += 1
			report.multimesh_instances += node.multimesh.instance_count
			report.multimesh_triangles += _triangle_count(node.multimesh.mesh) * node.multimesh.instance_count
			for i in node.multimesh.instance_count:
				if not node.multimesh.get_instance_transform(i).is_finite(): report.invalid_transforms += 1
		if node is CollisionShape3D: report.collision_shapes += 1
		if node is Light3D:
			report.lights += 1
			if node.shadow_enabled: report.shadow_lights += 1
		if node is CPUParticles3D:
			report.particle_emitters += 1
			report.particle_capacity += node.amount
	report.moth_cache = Library.cache_stats()
	return report

func _triangle_count(mesh: Mesh) -> int:
	var count := 0
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var indices = arrays[Mesh.ARRAY_INDEX]
		count += (indices.size() if indices != null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return count
