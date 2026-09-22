extends Node3D
## Cinder Array: standalone native exploration geography; all coordinates are metres.
## No catalog, server, source-map, or combat dependency.

const Geometry = preload("res://cinder_array/geometry.gd")
const Surfaces = preload("res://moth/surfaces.gd")
const Library = preload("res://moth/library.gd")
const LAVA_SHADER = preload("res://cinder_array/molten.gdshader")
const STRATA_SHADER = preload("res://cinder_array/strata.gdshader")
const SKY_SHADER = preload("res://cinder_array/caldera_sky.gdshader")
const OPAQUE_SHADER = preload("res://cinder_array/opaque_surface.gdshader")
const EMBER_BUDGET := 48
const STEAM_BUDGET := 16
const SPAWN := Vector3(-24.0, 7.06, 28.0)
const ROUTE := [
	Vector3(-24, 7, 28), Vector3(-21, 7, 21), Vector3(14, 12, 0),
	Vector3(22, 12, -5), Vector3(26, 12, -14), Vector3(26, 12, -29),
	Vector3(19, 12, -31), Vector3(7, 12, -31), Vector3(-7, 12, -31),
	Vector3(-23, 16, -28), Vector3(-29, 16, -26), Vector3(-35, 16, -21),
	Vector3(-41, 12, -6), Vector3(-40, 12, -1), Vector3(-31, 7, 22),
	Vector3(-24, 7, 28),
]
const ZONES := [
	{"name": "TRANSFER DECK", "code": "01", "point": Vector3(-29, 7, 25)},
	{"name": "SUSPENDED SPAN", "code": "02", "point": Vector3(-3, 9.5, 10.5)},
	{"name": "EXTRACTOR GANTRY", "code": "03", "point": Vector3(22, 12, -6)},
	{"name": "BASALT BORE", "code": "04", "point": Vector3(7, 12, -31)},
	{"name": "RIM OBSERVATORY", "code": "05", "point": Vector3(-29, 16, -26)},
	{"name": "COOLING TRAVERSE", "code": "06", "point": Vector3(-41, 12, -5)},
]

var built := false
var geo: RefCounted
var materials: Dictionary = {}
var connections: Array[Dictionary] = []
var walk_surfaces: Array[Dictionary] = []
var environment: Environment
var respawns := 0

func _ready() -> void:
	build()

func build() -> void:
	if built: return
	built = true
	name = "CinderArrayMap"
	geo = Geometry.new(self)
	_make_materials()
	_make_environment()
	_register_connections()
	_caldera()
	_lava()
	_decks_and_route()
	_suspension()
	_gantry()
	_bore()
	_cooling_array()
	_observation()
	_dressing()
	_particles()
	geo.flush()

func get_spawn() -> Dictionary:
	return {"position": SPAWN, "yaw": -0.85, "pitch": 0.035}

func get_route_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for point: Vector3 in ROUTE: points.append(point)
	return points

func get_location(point: Vector3) -> Dictionary:
	var nearest: Dictionary = ZONES[0]
	var distance := INF
	for zone: Dictionary in ZONES:
		var d: float = point.distance_squared_to(zone.point)
		if d < distance:
			distance = d
			nearest = zone
	return nearest.duplicate()

func needs_respawn(point: Vector3) -> bool:
	return not point.is_finite() or point.y < 2.0 or point.y > 85.0 or absf(point.x) > 92.0 or absf(point.z) > 82.0

func enforce_boundary(walker: Node3D) -> bool:
	if not needs_respawn(walker.position): return false
	if walker.has_method("reset_to_spawn"):
		walker.reset_to_spawn()
	else:
		walker.position = SPAWN
		if walker is CharacterBody3D: walker.velocity = Vector3.ZERO
	respawns += 1
	return true

func get_diagnostics() -> Dictionary:
	return {
		"experience": "cinder-array", "native_only": true, "built": built,
		"mesh_nodes": geo.meshes, "instanced_solids": geo.instances,
		"authored_triangles": geo.triangles, "collision_shapes": geo.collision_shapes,
		"nodes": _count_nodes(self), "route_points": ROUTE.size(), "areas": ZONES.size(),
		"embers": EMBER_BUDGET, "steam": STEAM_BUDGET, "lights": 4,
		"respawns": respawns, "renderer": RenderingServer.get_current_rendering_method(),
	}

func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children(): count += _count_nodes(child)
	return count

func _surface(key: String, tint: Color, scale: float, strength: float = 0.6) -> ShaderMaterial:
	var inherited := Surfaces.create_surface(key, tint, false)
	var mat := ShaderMaterial.new()
	mat.shader = OPAQUE_SHADER
	for parameter in ["tint", "albedo_map", "normal_map", "has_albedo", "has_normal", "albedo_gain", "roughness", "metallic"]:
		mat.set_shader_parameter(parameter, inherited.get_shader_parameter(parameter))
	mat.set_shader_parameter("repeat_scale", scale)
	mat.set_shader_parameter("texture_saturation", 0.10)
	mat.set_shader_parameter("texture_strength", strength)
	mat.set_shader_parameter("normal_strength", 0.13)
	return mat

func _flat(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.76
	if unshaded: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _make_materials() -> void:
	materials.deck = _surface("rough_stucco-weathered", Color("565967"), 0.34, 0.40)
	materials.deck.set_shader_parameter("normal_strength", 0.025)
	materials.metal = _surface("brushed_metal", Color("606b76"), 0.7, 0.35)
	materials.dark = _surface("metal-oxide", Color("333f48"), 0.5, 0.40)
	materials.orange = _surface("rough_stucco", Color("935838"), 0.7, 0.32)
	materials.rock = _surface("rock-moss", Color("3d424e"), 0.22, 0.58)
	materials.rock.set_shader_parameter("albedo_gain", 2.3)
	materials.gold = _flat(Color("eab56d"))
	materials.ivory = _flat(Color("818e9b"))
	materials.teal = _flat(Color("8be2dc"), true)
	materials.lamp = _flat(Color("ffbd77"), true)
	materials.rust = _flat(Color("674845"))
	var strata := ShaderMaterial.new()
	strata.shader = STRATA_SHADER
	strata.set_shader_parameter("rock_map", Library.texture("rock-moss"))
	materials.strata = strata
	var lava := ShaderMaterial.new()
	lava.shader = LAVA_SHADER
	lava.set_shader_parameter("flow_map", Library.texture("flow-field"))
	lava.set_shader_parameter("dust_map", Library.texture("dust-field"))
	materials.lava = lava

func _make_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("ash_panorama", Library.sky("ashen"))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a4b3d3")
	environment.ambient_light_energy = 0.50
	environment.ambient_light_sky_contribution = 0.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("6b5357")
	environment.fog_density = 0.0023
	environment.fog_sky_affect = 0.0
	environment.glow_enabled = false
	environment.volumetric_fog_enabled = false
	var world_env := WorldEnvironment.new()
	world_env.name = "CalderaAtmosphere"
	world_env.environment = environment
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "AshenSun"
	sun.rotation_degrees = Vector3(-32, -38, 0)
	sun.light_color = Color("ffca9a")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	_light("MoltenBounce", Vector3(5, 6, 5), Color("ff6023"), 1.8, 42)
	_light("BoreLamp", Vector3(7, 16, -31), Color("8bbfc9"), 1.5, 19)
	_light("ExtractorBounce", Vector3(23, 9, -6), Color("ff8b42"), 1.4, 24)

func _light(label: String, pos: Vector3, color: Color, energy: float, radius: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = label
	lamp.position = pos
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = radius
	lamp.shadow_enabled = false
	add_child(lamp)

func _register_connections() -> void:
	connections = [
		{"name": "SuspendedSpan", "a": Vector3(-21, 7, 21), "b": Vector3(14, 12, 0), "width": 5.2},
		{"name": "ExtractorAccess", "a": Vector3(26, 12, -14), "b": Vector3(26, 12, -29), "width": 5.4},
		{"name": "BoreFloor", "a": Vector3(26, 12, -31), "b": Vector3(-8, 12, -31), "width": 7.0},
		{"name": "RimAscent", "a": Vector3(-7, 12, -31), "b": Vector3(-23, 16, -28), "width": 5.4},
		{"name": "WestDescent", "a": Vector3(-35, 16, -21), "b": Vector3(-41, 12, -6), "width": 5.4},
		{"name": "ReturnRamp", "a": Vector3(-40, 12, -1), "b": Vector3(-31, 7, 22), "width": 5.4},
	]

func _caldera() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for level in range(6):
		var ring := PackedVector3Array()
		for i in range(80):
			var angle := TAU * float(i) / 80.0
			var jag := sin(angle * 7.0 + 0.6) * 3.0 + sin(angle * 19.0) * 1.8
			var rx := 54.0 + level * 3.6 + jag
			var rz := 43.0 + level * 3.8 + jag * 0.7
			var y := -5.0 + level * 8.2 + sin(angle * 5.0) * level * 1.2
			if level == 5: y += sin(angle * 13.0) * 4.5
			ring.append(Vector3(cos(angle) * rx + 2, y, sin(angle) * rz - 4))
		rings.append(ring)
	for level in range(5):
		for i in range(80):
			var j := (i + 1) % 80
			Geometry.quad(st, rings[level][i], rings[level + 1][i], rings[level + 1][j], rings[level][j])
	# Back slopes close the landform, rather than leaving a floating cliff ribbon.
	for i in range(80):
		var j := (i + 1) % 80
		var a := rings[5][i]
		var b := rings[5][j]
		var outer_a := Vector3(a.x * 1.8, -8, a.z * 1.8)
		var outer_b := Vector3(b.x * 1.8, -8, b.z * 1.8)
		Geometry.quad(st, b, a, outer_a, outer_b)
	st.generate_normals()
	geo.add_mesh("CarvedCalderaStrata", st.commit(), materials.strata)
	geo.cylinder("AshWastes", Vector3(0, -14, 0), 245, 12, materials.rock, 64)
	# Hexagonal column fields: seeded, material-batched, no per-frame allocations.
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC1ADE2
	for i in range(170):
		var x := rng.randf_range(-44, 48)
		var z := rng.randf_range(-47, -38)
		if x > 37: continue # Preserve a visible eastern cascade cleft.
		var top := rng.randf_range(19, 35) + sin(x * 0.14) * 4
		var radius := rng.randf_range(1.1, 2.4)
		geo.cylinder("NorthBasaltColumns", Vector3(x, (top - 5) * 0.5, z), radius, top + 5, materials.strata, 6, 0.88, Basis(Vector3.UP, rng.randf() * TAU))
	for i in range(21):
		var x := -5.5 + float(i) * 1.25
		var top := 18.6 + sin(i * 1.7) * 2.1 + sin(i * 0.5) * 0.7
		geo.cylinder("BoreFrontColumns", Vector3(x, top * 0.5, -24.7 + sin(i * 1.2) * 0.45), 1.35, top, materials.strata, 6, 0.88, Basis(Vector3.UP, i * 0.23))
	for island: Dictionary in [
		{"c": Vector3(-29, 0, 25), "top": 6.5, "r": 10.0},
		{"c": Vector3(-29, 0, -27), "top": 15.5, "r": 9.0},
		{"c": Vector3(-42, 0, -5), "top": 11.5, "r": 7.0},
		{"c": Vector3(25, 0, -10), "top": 10.4, "r": 8.0},
	]:
		for i in range(19):
			var angle := i * 2.39996
			var r: float = sqrt(float(i) / 19.0) * island.r
			var height: float = island.top - rng.randf_range(0.0, 2.2)
			var c: Vector3 = island.c + Vector3(cos(angle) * r, (height - 4) * 0.5, sin(angle) * r)
			geo.cylinder("FoundationBasalt", c, 2.6, height + 4, materials.strata, 6, 0.83)
	# Distant ash ridges make a layered skyline above the caldera lip.
	for i in range(25):
		var angle := float(i) / 25.0 * TAU
		var pos := Vector3(cos(angle) * 116, -2, sin(angle) * 104 - 4)
		geo.cylinder("DistantRidges", pos, rng.randf_range(24, 38), rng.randf_range(47, 68), materials.rock, 7, 0.015, Basis(Vector3.UP, angle))

func _lava() -> void:
	var polygon := PackedVector3Array()
	for i in range(70):
		var a := float(i) / 70.0 * TAU
		var radius := 1.0 + sin(a * 7.0) * 0.055 + sin(a * 11.0) * 0.025
		polygon.append(Vector3(4 + cos(a) * 49 * radius, 0.45, sin(a) * 40 * radius - 1))
	geo.prism("MoltenLake", polygon, 1.4, materials.lava, false)
	# A separate, sloping ribbon spills from the eastern cleft into the main lake.
	var path := [Vector3(44, 31, -44), Vector3(43, 20, -39), Vector3(42, 19, -34), Vector3(39, 6, -25), Vector3(35, 0.52, -17)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(path.size() - 1):
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		Geometry.quad(st, a + Vector3(-3, 0, 0), a + Vector3(3, 0, 0), b + Vector3(3.5, 0, 0), b + Vector3(-3.5, 0, 0))
	st.generate_normals()
	geo.add_mesh("EasternLavaCascade", st.commit(), materials.lava)
	for i in range(14):
		var a := float(i) * 2.39996
		var p := Vector3(cos(a) * (12 + i * 1.3) + 4, 0.5, sin(a) * (9 + i * 1.1))
		geo.cylinder("FloatingCrust", p, 0.8 + fmod(i * 0.73, 1.8), 0.8, materials.dark, 6, 0.7, Basis(Vector3.UP, a))

func _platform(label: String, center: Vector3, size: Vector2, chamfer: float) -> void:
	var x := size.x * 0.5
	var z := size.y * 0.5
	var polygon := PackedVector3Array([
		center + Vector3(-x + chamfer, 0, -z), center + Vector3(x - chamfer, 0, -z),
		center + Vector3(x, 0, -z + chamfer), center + Vector3(x, 0, z - chamfer),
		center + Vector3(x - chamfer, 0, z), center + Vector3(-x + chamfer, 0, z),
		center + Vector3(-x, 0, z - chamfer), center + Vector3(-x, 0, -z + chamfer),
	])
	geo.prism(label, polygon, 0.8, materials.deck)
	walk_surfaces.append({"name": label, "polygon": polygon, "slope": 0.0, "platform": true})
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		geo.beam("DeckFascia", a - Vector3.UP * 0.45, b - Vector3.UP * 0.45, 0.18, 0.5, materials.orange)
		var segments := ceili(a.distance_to(b) / 0.8)
		var start := -1
		for j in range(segments + 1):
			var blocked := j == segments
			if not blocked:
				var midpoint := a.lerp(b, (float(j) + 0.5) / segments)
				blocked = _in_gateway(midpoint)
			if not blocked and start == -1: start = j
			if blocked and start != -1:
				_rail(a.lerp(b, float(start) / segments), a.lerp(b, float(j) / segments))
				start = -1

func _in_gateway(point: Vector3) -> bool:
	for connection in connections:
		var a: Vector3 = connection.a
		var b: Vector3 = connection.b
		var p := Vector2(point.x, point.z)
		var aa := Vector2(a.x, a.z)
		var bb := Vector2(b.x, b.z)
		var t := clampf((p - aa).dot(bb - aa) / aa.distance_squared_to(bb), 0.0, 1.0)
		if (absf(point.y - a.y) < 0.1 or absf(point.y - b.y) < 0.1) and p.distance_to(aa.lerp(bb, t)) < float(connection.width) * 0.5 + 0.55:
			return true
	return false

func _profile(connection: Dictionary) -> Array[Vector3]:
	var a: Vector3 = connection.a
	var b: Vector3 = connection.b
	var side: Vector3 = Vector3(-(b - a).z, 0, (b - a).x).normalized() * connection.width * 0.5
	var lo := 0.0
	var hi := 1.0
	if not is_equal_approx(a.y, b.y):
		# Leave the entire deck footprint on the level, not just the centreline.
		for i in range(1, 45):
			var t := i / 100.0
			var start := a.lerp(b, t)
			start.y = a.y
			var end := a.lerp(b, 1.0 - t)
			end.y = b.y
			if _deck_contains(start) or _deck_contains(start + side) or _deck_contains(start - side): lo = t + 0.01
			if _deck_contains(end) or _deck_contains(end + side) or _deck_contains(end - side): hi = 1.0 - t - 0.01
	var start := a.lerp(b, lo)
	start.y = a.y
	var end := a.lerp(b, hi)
	end.y = b.y
	var points: Array[Vector3] = [a]
	if a.distance_to(start) > 0.01: points.append(start)
	points.append(end)
	if b.distance_to(end) > 0.01: points.append(b)
	return points

func connection_point(connection: Dictionary, t: float) -> Vector3:
	var points: Array[Vector3] = connection.profile
	var p: Vector3 = connection.a.lerp(connection.b, clampf(t, 0, 1))
	for i in range(points.size() - 1):
		var a := Vector2(points[i].x, points[i].z)
		var b := Vector2(points[i + 1].x, points[i + 1].z)
		var flat := Vector2(p.x, p.z)
		var fraction := (flat - a).dot(b - a) / a.distance_squared_to(b)
		if fraction >= -0.001 and fraction <= 1.001:
			p.y = lerpf(points[i].y, points[i + 1].y, clampf(fraction, 0, 1))
			return p
	return p

func _deck_contains(point: Vector3) -> bool:
	for surface in walk_surfaces:
		if not surface.get("platform", false): continue
		var poly: PackedVector3Array = surface.polygon
		if absf(point.y - poly[0].y) > 0.25: continue
		var flat := PackedVector2Array()
		for p in poly: flat.append(Vector2(p.x, p.z))
		if Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), flat): return true
	return false

func _connection_collision(profile: Array[Vector3], side: Vector3) -> void:
	for section in range(profile.size() - 1):
		var from := profile[section]
		var to := profile[section + 1]
		var level := is_equal_approx(from.y, to.y)
		# The upper landing belongs to the same convex solid as the incline.
		# Separate overlapping solids expose an internal end face at the crest:
		# capsule recovery can push against it while the incline reports a floor.
		if level:
			if section > 0 and profile[section - 1].y < from.y: continue
			if section + 2 < profile.size() and profile[section + 2].y < to.y: continue
		var overlap := (to - from).normalized() * 0.015
		var start := from - overlap
		var end := to + overlap
		if from.y > to.y: start = from
		if to.y > from.y: end = to
		var vertices := PackedVector3Array([start - side, start + side, end + side, end - side])
		if from.y > to.y and section > 0:
			var upper := profile[section - 1] + (profile[section - 1] - from).normalized() * 0.015
			vertices.append_array(PackedVector3Array([upper - side, upper + side]))
		if to.y > from.y and section + 2 < profile.size():
			var upper := profile[section + 2] + (profile[section + 2] - to).normalized() * 0.015
			vertices.append_array(PackedVector3Array([upper - side, upper + side]))
		for vertex in vertices.duplicate(): vertices.append(vertex - Vector3.UP * 0.6)
		geo.convex(vertices)

func _decks_and_route() -> void:
	_platform("TransferDeck", Vector3(-27, 7, 25), Vector2(18, 14), 3.0)
	_platform("ExtractorDeck", Vector3(22, 12, -6), Vector2(20, 21), 2.5)
	_platform("BoreEastLanding", Vector3(26, 12, -30), Vector2(11, 11), 2.0)
	_platform("BoreWestLanding", Vector3(-8, 12, -31), Vector2(9, 10), 1.5)
	_platform("RimObservationDeck", Vector3(-29, 16, -26), Vector2(17, 15), 3.0)
	_platform("CoolingTraverse", Vector3(-41, 12, -5), Vector2(11, 11), 2.0)
	for connection in connections:
		var a: Vector3 = connection.a
		var b: Vector3 = connection.b
		var delta := b - a
		var side := Vector3(-delta.z, 0, delta.x).normalized() * float(connection.width) * 0.5
		var horizontal := Vector2(delta.x, delta.z).length()
		var profile := _profile(connection)
		connection.profile = profile
		_connection_collision(profile, side)
		for section in range(profile.size() - 1):
			var from := profile[section]
			var to := profile[section + 1]
			var polygon := PackedVector3Array([from - side, from + side, to + side, to - side])
			var label: String = connection.name + str(section)
			geo.prism(label, polygon, 0.6, materials.deck, false)
			var flat_length := Vector2(to.x - from.x, to.z - from.z).length()
			walk_surfaces.append({"name": label, "polygon": polygon, "slope": rad_to_deg(atan2(absf(to.y - from.y), flat_length)), "platform": false})
			for sign_value in [-1.0, 1.0]:
				var start: Vector3 = from + side * sign_value
				var end: Vector3 = to + side * sign_value
				geo.beam("WalkwayGirders", start - Vector3.UP * 0.45, end - Vector3.UP * 0.45, 0.25, 0.55, materials.dark)
				if connection.name == "BoreFloor": continue
				var steps := maxi(1, ceili(start.distance_to(end) / 0.35))
				var run := -1
				for i in range(steps + 1):
					var inside := i == steps
					if not inside: inside = _deck_contains(start.lerp(end, (float(i) + 0.5) / steps))
					if not inside and run == -1: run = i
					if inside and run != -1:
						_rail(start.lerp(end, float(run) / steps), start.lerp(end, float(i) / steps))
						run = -1
		var count := ceili(horizontal / 3.0)
		for i in range(1, count):
			var p := connection_point(connection, float(i) / count)
			geo.beam("DeckExpansionJoints", p - side * 0.87 + Vector3.UP * 0.009, p + side * 0.87 + Vector3.UP * 0.009, 0.05, 0.025, materials.dark)

func _rail(a: Vector3, b: Vector3) -> void:
	if a.distance_to(b) < 0.15: return
	for height in [0.48, 1.12]:
		geo.beam("Handrails", a + Vector3.UP * height, b + Vector3.UP * height, 0.065, 0.075, materials.ivory)
	geo.beam("ToeGuards", a + Vector3.UP * 0.10, b + Vector3.UP * 0.10, 0.14, 0.19, materials.orange)
	var segments := maxi(1, ceili(a.distance_to(b) / 2.8))
	for i in range(segments + 1):
		var point := a.lerp(b, float(i) / segments)
		geo.beam("RailPosts", point, point + Vector3.UP * 1.23, 0.09, 0.09, materials.dark)
	# A single solid, sloping safety wall per run (not sparse post collision).
	var side := Vector3(-(b - a).z, 0, (b - a).x).normalized() * 0.095
	geo.convex(PackedVector3Array([a - side, a + side, b - side, b + side, a - side + Vector3.UP * 1.28, a + side + Vector3.UP * 1.28, b - side + Vector3.UP * 1.28, b + side + Vector3.UP * 1.28]))

func _suspension() -> void:
	var a: Vector3 = connections[0].a
	var b: Vector3 = connections[0].b
	var direction := (b - a).normalized()
	var side := Vector3(-direction.z, 0, direction.x).normalized() * 3.2
	for t in [0.12, 0.86]:
		var p := connection_point(connections[0], t)
		for sign_value in [-1.0, 1.0]:
			var foot: Vector3 = p + side * sign_value
			geo.beam("SuspensionPylons", foot - Vector3.UP * 1.5, foot + Vector3.UP * 5.5, 0.44, 0.6, materials.orange)
			geo.box("PylonCaps", foot + Vector3.UP * 5.3, Vector3(0.75, 0.4, 0.75), materials.dark)
			geo.box("PylonLamps", foot + Vector3.UP * 5.52, Vector3(0.4, 0.07, 0.4), materials.lamp)
		geo.beam("SuspensionCrossheads", p - side + Vector3.UP * 4.95, p + side + Vector3.UP * 4.95, 0.38, 0.5, materials.orange)
	for sign_value in [-1.0, 1.0]:
		var last := Vector3.ZERO
		for i in range(25):
			var t := float(i) / 24.0
			var u := clampf((t - 0.12) / 0.74, 0, 1)
			var sag := 2.8 + 2.7 * pow(absf(u - 0.5) * 2, 2.0)
			if t < 0.12: sag = lerpf(1.1, 5.5, t / 0.12)
			if t > 0.86: sag = lerpf(5.5, 1.1, (t - 0.86) / 0.14)
			var point: Vector3 = connection_point(connections[0], t) + side * sign_value + Vector3.UP * sag
			if i > 0: geo.beam("MainSuspensionCables", last, point, 0.11, 0.11, materials.dark)
			if i % 2 == 0 and t > 0.12 and t < 0.86:
				geo.beam("VerticalHangers", connection_point(connections[0], t) + side * sign_value - Vector3.UP * 0.2, point, 0.04, 0.04, materials.metal)
			last = point
	for i in range(14):
		var p := connection_point(connections[0], float(i) / 13.0)
		geo.beam("BridgeUndertruss", p - side - Vector3.UP * 0.7, p + side - Vector3.UP * 0.7, 0.18, 0.28, materials.dark)

func _gantry() -> void:
	# A recognisable A-frame extractor, with an open walk-through throat.
	for x in [15.8, 28.6]:
		geo.box("GantryFeet", Vector3(x, 12.5, -9), Vector3(2.3, 1, 3.4), materials.dark, true)
		geo.beam("GantryLegs", Vector3(x, 13, -9), Vector3(lerpf(x, 22.2, 0.18), 31, -9), 1.0, 1.45, materials.orange)
		geo.beam("GantryBackStays", Vector3(x, 12, -14), Vector3(lerpf(x, 22.2, 0.18), 29, -9), 0.34, 0.5, materials.metal)
		for y in [16, 21, 26]:
			geo.box("GantryBanding", Vector3(lerpf(x, 22.2, (y - 13.0) / 18.0 * 0.18), y, -9), Vector3(1.2, 0.42, 1.7), materials.dark)
	geo.box("ExtractorCrossbeam", Vector3(22.2, 30.5, -9), Vector3(16.5, 2.2, 3), materials.orange)
	geo.box("ExtractorCrossbeamTrim", Vector3(22.2, 29.6, -7.42), Vector3(15, 0.28, 0.12), materials.ivory)
	geo.box("CraneCab", Vector3(29, 28.5, -7.8), Vector3(3.1, 3.2, 3.5), materials.dark)
	geo.box("CraneCabGlazing", Vector3(29, 29, -6.02), Vector3(2.3, 1.6, 0.06), materials.teal)
	for x in [20.2, 24.2]:
		geo.beam("ExtractorBoom", Vector3(x, 29, -11), Vector3(x, 27, 11), 0.34, 0.6, materials.orange)
		geo.beam("ExtractorBoomTop", Vector3(x, 32.5, -11), Vector3(x, 29, 11), 0.27, 0.35, materials.metal)
		for i in range(6):
			var t := float(i) / 6.0
			var next := float(i + 1) / 6.0
			geo.beam("BoomLattice", Vector3(x, lerpf(29, 27, t), lerpf(-11, 11, t)), Vector3(x, lerpf(32.5, 29, next), lerpf(-11, 11, next)), 0.16, 0.18, materials.orange)
	for i in range(7):
		var t := float(i) / 6.0
		geo.beam("BoomCrossmembers", Vector3(20.2, lerpf(32.5, 29, t), lerpf(-11, 11, t)), Vector3(24.2, lerpf(32.5, 29, t), lerpf(-11, 11, t)), 0.16, 0.18, materials.metal)
	geo.box("HoistBlock", Vector3(22.2, 27.7, 10.5), Vector3(5.5, 1.7, 2.3), materials.dark)
	for x in [21.1, 23.3]:
		geo.beam("HoistCables", Vector3(x, 27.4, 10.5), Vector3(x, 6, 10.5), 0.065, 0.065, materials.metal)
	geo.cylinder("ExtractorBell", Vector3(22.2, 4.5, 10.5), 3.1, 5.2, materials.dark, 16, 0.48)
	geo.cylinder("ExtractorHotCollar", Vector3(22.2, 2.3, 10.5), 3.18, 0.35, materials.lamp, 16)
	geo.cylinder("ExtractorUpperCollar", Vector3(22.2, 6, 10.5), 2.25, 0.4, materials.orange, 16)
	for i in range(10):
		var a := float(i) / 10.0 * TAU
		var offset := Vector3(cos(a), 0, sin(a))
		geo.beam("ExtractorBellRibs", Vector3(22.2, 2, 10.5) + offset * 3.25, Vector3(22.2, 6.8, 10.5) + offset * 1.5, 0.18, 0.2, materials.orange)
	_text("ExtractorIdentity", "C I N D E R   /   0 7", Vector3(22.2, 30.5, -7.45), 0.032, Color("f6ddba"))
	_text("GantryMarker", "03  /  EXTRACTION", Vector3(22.2, 13.65, -15.65), 0.019, Color("d8e1df"))

func _bore() -> void:
	var cross_section := [Vector2(-3.6, 0), Vector2(-3.6, 3.3), Vector2(-2.3, 5.2), Vector2(2.3, 5.2), Vector2(3.6, 3.3), Vector2(3.6, 0)]
	for i in range(cross_section.size() - 1):
		var a: Vector2 = cross_section[i]
		var b: Vector2 = cross_section[i + 1]
		var out := Vector2(-(b - a).y, (b - a).x).normalized() * 2.2
		# Extruded, bevelled tunnel lining, with exact native convex collision.
		var polygon := PackedVector3Array([
			Vector3(-7, 12 + a.y, -31 + a.x), Vector3(21, 12 + a.y, -31 + a.x),
			Vector3(21, 12 + b.y, -31 + b.x), Vector3(-7, 12 + b.y, -31 + b.x),
		])
		var outside := PackedVector3Array()
		for p in polygon: outside.append(p + Vector3(0, out.y, out.x))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		Geometry.quad(st, polygon[0], polygon[1], polygon[2], polygon[3])
		Geometry.quad(st, outside[3], outside[2], outside[1], outside[0])
		for j in range(4): Geometry.quad(st, polygon[j], outside[j], outside[(j + 1) % 4], polygon[(j + 1) % 4])
		st.generate_normals()
		geo.add_mesh("BoreLining%d" % i, st.commit(), materials.rock)
		var shape_points := polygon.duplicate()
		shape_points.append_array(outside)
		geo.convex(shape_points)
	for x in [-7, -3, 1, 5, 9, 13, 17, 21]:
		for i in range(cross_section.size() - 1):
			var a: Vector2 = cross_section[i]
			var b: Vector2 = cross_section[i + 1]
			geo.beam("BoreArchRibs", Vector3(x, 12 + a.y, -31 + a.x), Vector3(x, 12 + b.y, -31 + b.x), 0.18, 0.20, materials.metal)
		geo.box("BoreCeilingLights", Vector3(x, 17.08, -31), Vector3(0.2, 0.06, 2.6), materials.teal)
	for z in [-34.2, -27.8]:
		geo.beam("BoreServicePipes", Vector3(-7, 14.3, z), Vector3(21, 14.3, z), 0.17, 0.17, materials.orange)
		geo.beam("BoreGuideLights", Vector3(-7, 12.26, z), Vector3(21, 12.26, z), 0.055, 0.09, materials.teal)
	for x in [-7.1, 21.1]:
		var sign_value := -1 if x < 0 else 1
		geo.box("BoreHeader", Vector3(x, 18, -31), Vector3(0.6, 1.25, 8.8), materials.dark)
		_text("BoreIdentity", "04 / BASALT BORE", Vector3(x + sign_value * 0.34, 18.05, -31), 0.025, Color("c6e5df"), sign_value * PI * 0.5)

func _cooling_array() -> void:
	for i in range(9):
		var pos := Vector3(35 + i * 0.28, 10.5, -17 + i * 3.6)
		var height := 17.0 - absf(i - 3.0) * 0.8
		var basis := Basis(Vector3.FORWARD, -0.20)
		geo.box("MassiveCoolingFins", pos, Vector3(0.62, height, 6.0), materials.dark, false, basis)
		geo.box("CoolingFinLeadingEdges", pos + Vector3(0.12, 0, 3.03), Vector3(0.65, height, 0.12), materials.orange, false, basis)
		for j in range(5):
			geo.box("CoolingFinRibs", pos + Vector3(0.39, -6 + j * 2.7, 0), Vector3(0.2, 0.22, 5.7), materials.metal, false, basis)
	geo.beam("CoolingManifold", Vector3(33.2, 7, -20), Vector3(33.2, 7, 16), 1.1, 1.1, materials.orange)
	geo.beam("CoolingFeed", Vector3(28, 8, -8), Vector3(33.2, 7, -8), 1.1, 1.1, materials.dark)
	# The western traverse has smaller, human-scale service radiator stacks.
	for i in range(5):
		geo.box("TraverseRadiators", Vector3(-44.2, 13.6, -7.8 + i * 1.45), Vector3(1.0, 3.2, 0.28), materials.dark, true)
		geo.box("RadiatorEndCaps", Vector3(-43.64, 14.8, -7.8 + i * 1.45), Vector3(0.08, 0.15, 0.35), materials.teal)

func _observation() -> void:
	for x in [-34, -24]:
		geo.beam("ObservationRoofPosts", Vector3(x, 16, -31.5), Vector3(x, 20.8, -31.5), 0.25, 0.3, materials.metal, true)
	geo.box("ObservationCanopy", Vector3(-29, 20.8, -30), Vector3(12.5, 0.35, 4.7), materials.dark)
	geo.box("ObservationCanopyStripe", Vector3(-29, 20.85, -27.61), Vector3(12.5, 0.22, 0.08), materials.orange)
	geo.box("ObservationConsole", Vector3(-34.7, 16.65, -27.7), Vector3(2.5, 1.3, 0.9), materials.dark, true)
	geo.box("ObservationConsoleScreen", Vector3(-34.7, 17.33, -27.65), Vector3(2.2, 0.05, 0.6), materials.teal)
	geo.box("ObservationBench", Vector3(-31, 16.5, -30), Vector3(3.5, 0.35, 1.0), materials.orange, true)
	_text("RimIdentity", "05   /   RIM OBSERVATORY", Vector3(-29, 19.8, -27.55), 0.018, Color("d6e4e3"))
	geo.cylinder("SurveyInstrumentBase", Vector3(-23.5, 16.7, -24.2), 0.24, 1.4, materials.ivory)
	geo.beam("SurveyScope", Vector3(-24, 17.55, -24.4), Vector3(-22.8, 17.45, -23.6), 0.23, 0.3, materials.metal)

func _dressing() -> void:
	# Transfer shelter sits behind the authored eye-level arrival view.
	geo.box("ArrivalServiceCabinet", Vector3(-32.6, 8.1, 29.6), Vector3(2, 2.2, 1.2), materials.dark, true)
	geo.box("ArrivalCabinetScreen", Vector3(-32.6, 8.45, 28.97), Vector3(1.4, 0.55, 0.06), materials.teal)
	_text("ArrivalIdentity", "01 / TRANSFER", Vector3(-26, 8.3, 31.7), 0.023, Color("e9d7c0"), PI)
	for zone: Dictionary in ZONES:
		if zone.code in ["02", "04"]: continue
		var positions := {"01": Vector3(-33, 7, 23), "03": Vector3(29, 12, 0), "05": Vector3(-36, 16, -25), "06": Vector3(-43, 12, -1)}
		var pos: Vector3 = positions[zone.code]
		geo.beam("WayfindingPosts", pos, pos + Vector3.UP * 2.0, 0.12, 0.12, materials.metal)
		geo.box("WayfindingSigns", pos + Vector3.UP * 1.75, Vector3(1.5, 0.7, 0.09), materials.dark)
		_text("Sector" + zone.code, zone.code + "  /  LOOP", pos + Vector3(0, 1.78, 0.065), 0.0075, Color("f4bc7c"))
	for i in range(8):
		var pos := Vector3(-19 + i * 6, -0.8, 28 + sin(i) * 4)
		geo.cylinder("LakeshoreBasalt", pos, 1.6 + fmod(i * 0.91, 1.8), 3.5, materials.strata, 6, 0.75)
	# Restrained route markers are flush and cannot snag the capsule.
	for connection in connections:
		if connection.name == "BoreFloor": continue
		var delta: Vector3 = connection.b - connection.a
		var side := Vector3(-delta.z, 0, delta.x).normalized()
		var count := maxi(1, int(delta.length() / 5))
		for i in range(1, count):
			var p: Vector3 = connection_point(connection, float(i) / count) + Vector3.UP * 0.016
			for sign_value in [-1.0, 1.0]:
				geo.box("RouteEdgeLights", p + side * sign_value * (connection.width * 0.5 - 0.30), Vector3(0.14, 0.025, 0.38), materials.lamp)

func _text(label: String, text: String, pos: Vector3, pixel_size: float, color: Color, yaw: float = 0.0) -> void:
	var node := Label3D.new()
	node.name = label
	node.text = text
	node.font_size = 48
	node.pixel_size = pixel_size
	node.position = pos
	node.rotation.y = yaw
	node.modulate = color
	node.outline_size = 0
	node.no_depth_test = false
	node.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	add_child(node)

func _particles() -> void:
	var ember_mat := _flat(Color("ffc077"), true)
	var ember_mesh := SphereMesh.new()
	ember_mesh.radius = 0.035
	ember_mesh.height = 0.13
	ember_mesh.radial_segments = 5
	ember_mesh.rings = 2
	ember_mesh.material = ember_mat
	for pos in [Vector3(-5, 1.2, 6), Vector3(21, 1.2, 10), Vector3(33, 1.2, -18)]:
		var particles := CPUParticles3D.new()
		particles.name = "BoundedEmbers"
		particles.position = pos
		particles.amount = EMBER_BUDGET / 3
		particles.lifetime = 5.0
		particles.preprocess = 3.0
		particles.mesh = ember_mesh
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 3.0
		particles.direction = Vector3.UP
		particles.spread = 28
		particles.gravity = Vector3(0.15, 0.15, 0.05)
		particles.initial_velocity_min = 0.4
		particles.initial_velocity_max = 1.3
		particles.scale_amount_min = 0.5
		particles.scale_amount_max = 1.4
		add_child(particles)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.71, 0.78, 0.82, 0.16), Color(0.71, 0.78, 0.82, 0.06), Color(0.71, 0.78, 0.82, 0)])
	gradient.offsets = PackedFloat32Array([0, 0.35, 1])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	texture.width = 32
	texture.height = 32
	var steam_mat := StandardMaterial3D.new()
	steam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	steam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	steam_mat.albedo_texture = texture
	steam_mat.vertex_color_use_as_albedo = true
	steam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var steam_mesh := QuadMesh.new()
	steam_mesh.size = Vector2(1.8, 1.8)
	steam_mesh.material = steam_mat
	for pos in [Vector3(33, 13, -9), Vector3(-44, 15, -5)]:
		var particles := CPUParticles3D.new()
		particles.name = "BoundedSteam"
		particles.position = pos
		particles.amount = STEAM_BUDGET / 2
		particles.lifetime = 3.8
		particles.preprocess = 2.0
		particles.mesh = steam_mesh
		particles.direction = Vector3.UP
		particles.spread = 12
		particles.gravity = Vector3(0.25, 0.02, 0)
		particles.initial_velocity_min = 0.5
		particles.initial_velocity_max = 0.9
		particles.scale_amount_min = 0.6
		particles.scale_amount_max = 1.1
		add_child(particles)
