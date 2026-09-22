extends RefCounted

# Native, texture-free art direction. Source geometry remains the gameplay contract.
# Palette order: masonry, dark metal, vegetation, horizon, sun.
const PALETTES := {
	"meridian-exchange": ["a9b6b5", "34444f", "44796d", "d2a997", "ffdbb5"],
	"verdant-reliquary": ["a6ad87", "46534c", "42764d", "b1cbb4", "fff0cc"],
	"ember-crucible": ["88746c", "393c46", "514b45", "9e625b", "ffb67e"],
	"tidal-citadel": ["8da9b9", "394f66", "648a92", "c3e0e9", "e2f3ff"],
	"sunscar-convoy": ["c6a579", "635247", "918464", "e1b58a", "ffdfb3"],
	"asterion-relay": ["8994af", "353d59", "4c5875", "566681", "bccfff"],
	"monsoon-foundry": ["8baba0", "374e50", "39624d", "adc6be", "d9e7d1"],
	"ion-speedway": ["78919f", "293746", "456171", "526c89", "c9dfff"],
	"aurora-stadium": ["a0b8c9", "34445f", "30695e", "586d8b", "d6e6ff"],
}

# World-space seams give large surfaces scale without textures, UV assumptions,
# external assets, time-dependent effects, or Forward+-only features.
const SURFACE_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float seams = 0.12;
uniform bool vertex_tint = false;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	vec3 n = abs(world_normal);
	vec2 p = n.y > 0.65 ? world_position.xz : (n.x > n.z ? world_position.zy : world_position.xy);
	vec2 tile = p / 3.0;
	vec2 edge = min(fract(tile), 1.0 - fract(tile));
	vec2 aa = max(fwidth(tile), vec2(0.001));
	vec2 line = 1.0 - smoothstep(vec2(0.006), vec2(0.006) + aa, edge);
	float joint = max(line.x, line.y);
	float variation = fract(sin(dot(floor(tile), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 base = tint.rgb * (vertex_tint ? COLOR.rgb : vec3(1.0));
	ALBEDO = base * (0.97 + variation * 0.06) * (1.0 - joint * seams);
	ROUGHNESS = 0.87;
	SPECULAR = 0.22;
	// Presentation-only depth priority for coplanar authored support surfaces.
	// No vertex displacement: collision/support coordinates stay exact.
	DEPTH = FRAGCOORD.z - (vertex_tint ? UV.x * 0.000001 : 0.0);
}
"""

var wall: Color
var dark: Color
var leaves: Color
var accent: Color
var ground: Color
var shader := Shader.new()
var materials: Dictionary = {}
var detail_batches: Dictionary = {}
var map_id: String
var sky_material := ProceduralSkyMaterial.new()
var sky := Sky.new()
var env := Environment.new()

func configure(map: Dictionary, environment: WorldEnvironment, sun: DirectionalLight3D) -> void:
	map_id = map.id
	var palette: Array = PALETTES[map_id]
	wall = Color(palette[0]).darkened(0.22)
	dark = Color(palette[1])
	leaves = Color(palette[2]).darkened(0.18)
	accent = Color(map.color)
	ground = Color(map.floorColor)
	if shader.code.is_empty(): shader.code = SURFACE_SHADER
	materials.clear()
	detail_batches.clear()
	var horizon := Color(palette[3])
	var night: bool = map.sky == "night"
	sky_material.sky_top_color = Color(map.background).lightened(0.06)
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon
	sky_material.ground_bottom_color = horizon.darkened(0.25)
	sky_material.sky_curve = 0.18
	sky_material.sun_angle_max = 4.0
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = horizon.lerp(Color.WHITE, 0.4)
	env.ambient_light_energy = 0.5
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = horizon
	env.fog_light_energy = 0.65
	env.fog_density = 0.0025 if night else 0.002
	env.fog_sky_affect = 0.12
	environment.environment = env
	sun.rotation_degrees = Vector3(-32 if map.sky == "dusk" else -48, -32, 0)
	sun.light_color = Color(palette[4])
	sun.light_energy = 0.35 if night else 0.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.1
	sun.shadow_normal_bias = 1.0

func surface_material(key: String, color: Color, seams: float = 0.12) -> ShaderMaterial:
	if not materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("tint", color)
		mat.set_shader_parameter("seams", seams)
		materials[key] = mat
	return materials[key]

func solid_material(key: String, color: Color, emission: float = 0.0) -> StandardMaterial3D:
	if not materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.8
		if emission > 0:
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = emission
		materials[key] = mat
	return materials[key]

func block_material(block: Dictionary) -> Material:
	var kind: String = block.get("kind", "building")
	if kind in ["tree"]: return surface_material("bark", Color("544f40"), 0.02)
	if kind in ["rock", "cave", "tunnel"]: return surface_material("rock", wall.darkened(0.23), 0.02)
	if kind in ["cover", "crate", "reactor", "pump", "sluice", "relay-feed"]:
		return surface_material("equipment", dark.lightened(0.12), 0.22)
	if kind in ["race-infield", "race-apron"]: return surface_material("infield", ground, 0.04)
	if kind in ["column", "pillar", "foundation", "light-mast"]:
		return surface_material("structure", dark.lightened(0.06))
	return surface_material("masonry", wall)

func terrain_color(triangle: Dictionary) -> Color:
	var kind: String = triangle.get("material", "concrete")
	var surface: String = triangle.get("surfaceId", "")
	if "ceiling" in surface: return dark.lightened(0.1)
	match kind:
		"snow": return Color("9dafb8")
		"ice": return Color("558b9e")
		"grass": return leaves
		"sand": return ground
		"dirt": return ground.lerp(Color("78694f"), 0.45)
		"ash", "rock": return ground.darkened(0.18)
		"metal": return dark.lightened(0.18)
		"stone": return wall.darkened(0.17)
	return ground

func terrain_material() -> Material:
	var mat := surface_material("terrain", Color.WHITE, 0.10)
	mat.set_shader_parameter("vertex_tint", true)
	return mat

func detail_box(key: String, pos: Vector3, size: Vector3, rotation: float = 0.0) -> void:
	if not detail_batches.has(key): detail_batches[key] = []
	detail_batches[key].append(Transform3D(Basis(Vector3.UP, rotation).scaled_local(size), pos))

func decorate(map: Dictionary, parent: Node3D) -> void:
	var detail := Node3D.new()
	detail.name = "NativeWorldDetail"
	parent.add_child(detail)
	# Scenic backdrop is below/outside the authored bounds, never playable support.
	var backdrop := MeshInstance3D.new()
	backdrop.name = "DistantGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1800, 1800)
	backdrop.mesh = plane
	backdrop.position.y = -4.0
	backdrop.material_override = solid_material("backdrop", ground.darkened(0.48))
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	detail.add_child(backdrop)
	var bounds: Dictionary = map.bounds
	var radius: float = maxf(maxf(absf(bounds.minX), bounds.maxX), maxf(absf(bounds.minZ), bounds.maxZ)) + 75.0
	for i in range(28):
		var angle := i * TAU / 28.0 + sin(i * 9.0) * 0.035
		var height := 15.0 + fmod(i * 17.0, 29.0)
		var distance := radius + sin(i * 13.0) * 24.0
		var natural: bool = map.get("biome", "") in ["forest", "snow", "canyon", "volcanic"]
		detail_box("ridge" if natural else "skyline", Vector3(cos(angle) * distance, height / 2.0 - 4.0, sin(angle) * distance), Vector3(50 if natural else 14 + i % 3 * 6, height, 45 if natural else 12 + i % 4 * 4), angle)
	# Surface-mounted trim stays within each solid segment's span: never bridge doors.
	for b: Dictionary in map.get("blocks", []):
		var kind: String = b.get("kind", "")
		var pos := Vector3(b.x, b.h - 0.16, b.z)
		if kind in ["building", "partition", "base-wall", "base-hq", "base-bastion", "wall"]:
			detail_box("trim", pos, Vector3(b.w + 0.035, 0.22, b.d + 0.035))
			detail_box("trim", Vector3(b.x, 0.25, b.z), Vector3(b.w + 0.03, 0.5, b.d + 0.03))
			if b.h > 4.0 and minf(b.w, b.d) < 1.5 and maxf(b.w, b.d) > 3.5:
				var along_x: bool = b.w > b.d
				var span: float = maxf(b.w, b.d)
				var count := int(span / 2.8)
				for i in range(count):
					var offset: float = (i - (count - 1) * 0.5) * 2.8
					var window_pos := Vector3(b.x + (offset if along_x else 0.0), b.h - 1.3, b.z + (0.0 if along_x else offset))
					var size := Vector3(1.35, 0.55, b.d + 0.045) if along_x else Vector3(b.w + 0.045, 0.55, 1.35)
					detail_box("window", window_pos, size)
		elif kind in ["cover", "crate", "reactor", "pump", "race-rail", "soccer-wall", "soccer-goal"]:
			detail_box("accent", pos, Vector3(b.w + 0.025, 0.12, b.d + 0.025))
		elif kind == "tree":
			var crown := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.2
			mesh.bottom_radius = 1.8
			mesh.height = 3.8
			mesh.radial_segments = 7
			crown.mesh = mesh
			crown.material_override = solid_material("leaves", leaves)
			crown.position = Vector3(b.x, maxf(4.8, b.h + 1.9), b.z)
			detail.add_child(crown)
	for landmark: Dictionary in map.get("landmarks", []):
		var sign := Label3D.new()
		sign.text = landmark.label
		sign.position = Vector3(landmark.x, landmark.y + 0.5, landmark.z)
		sign.font_size = 48
		sign.pixel_size = 0.014
		sign.modulate = accent.lightened(0.35)
		sign.outline_modulate = dark.darkened(0.65)
		sign.outline_size = 12
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.no_depth_test = false
		# Navigational landmarks should not fill the view when walking past them.
		sign.visibility_range_begin = 10
		sign.visibility_range_end = 120
		detail.add_child(sign)
	if map.has("race"): decorate_sport(map.race)
	for key: String in detail_batches:
		var instances := MultiMeshInstance3D.new()
		instances.name = key.capitalize() + "Details"
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		multimesh.mesh = mesh
		if key == "ridge":
			var ridge := CylinderMesh.new()
			ridge.top_radius = 0.0
			ridge.bottom_radius = 0.5
			ridge.height = 1.0
			ridge.radial_segments = 5
			multimesh.mesh = ridge
		multimesh.instance_count = detail_batches[key].size()
		for i in range(multimesh.instance_count): multimesh.set_instance_transform(i, detail_batches[key][i])
		instances.multimesh = multimesh
		match key:
			"window": instances.material_override = solid_material("window", accent.lerp(Color("ffdcad"), 0.55), 0.35)
			"accent": instances.material_override = solid_material("accent", accent, 0.12)
			"marking": instances.material_override = solid_material("marking", Color("d3e9df"), 0.12)
			"skyline", "ridge": instances.material_override = solid_material("skyline", dark.lerp(Color(map.background), 0.4))
			_: instances.material_override = solid_material("trim", dark)
		instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		detail.add_child(instances)

func line(a: Vector3, b: Vector3, width: float, key: String = "marking") -> void:
	var delta := b - a
	detail_box(key, (a + b) * 0.5, Vector3(width, 0.025, delta.length()), atan2(delta.x, delta.z))

func decorate_sport(race: Dictionary) -> void:
	# Authored layout markings only. No vehicle, gate trigger, ball or mode logic.
	if race.get("kind", "race") == "soccer":
		var p: Dictionary = race.pitch
		var a := Vector3(p.minX, 0.03, p.minZ)
		var b := Vector3(p.maxX, 0.03, p.maxZ)
		line(a, Vector3(b.x, a.y, a.z), 0.18)
		line(b, Vector3(a.x, b.y, b.z), 0.18)
		line(a, Vector3(a.x, a.y, b.z), 0.18)
		line(b, Vector3(b.x, b.y, a.z), 0.18)
		line(Vector3(0, 0.03, a.z), Vector3(0, 0.03, b.z), 0.18)
		for i in range(48):
			var angle := TAU * i / 48.0
			var next := TAU * (i + 1) / 48.0
			line(Vector3(cos(angle) * 8, 0.03, sin(angle) * 8), Vector3(cos(next) * 8, 0.03, sin(next) * 8), 0.16)
	else:
		var points: Array = race.get("centerline", [])
		for i in range(points.size()):
			var a: Dictionary = points[i]
			var b: Dictionary = points[(i + 1) % points.size()]
			var start := Vector3(a.x, 0.03, a.z)
			var end := Vector3(b.x, 0.03, b.z)
			var count := maxi(1, int(start.distance_to(end) / 7.0))
			for j in range(count):
				line(start.lerp(end, float(j) / count), start.lerp(end, (j + 0.45) / count), 0.22)
