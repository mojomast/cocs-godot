extends RefCounted

# Native art direction using the original baked Moth pixels. Source geometry
# remains the gameplay contract; texture mapping never displaces surfaces.
const MothSurfaces = preload("res://moth/surfaces.gd")
const Moth = preload("res://moth/library.gd")
const Atmosphere = preload("res://graphics_atmosphere/atmosphere.gd")
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

var wall: Color
var dark: Color
var leaves: Color
var accent: Color
var ground: Color
var materials: Dictionary = {}
var detail_batches: Dictionary = {}
var map_id: String
var atmosphere := Atmosphere.new()

func configure(map: Dictionary, environment: WorldEnvironment, sun: DirectionalLight3D) -> void:
	map_id = map.id
	var palette: Array = PALETTES[map_id]
	wall = Color(palette[0]).darkened(0.22)
	dark = Color(palette[1])
	leaves = Color(palette[2]).darkened(0.18)
	accent = Color(map.color)
	ground = Color(map.floorColor)
	materials.clear()
	detail_batches.clear()
	atmosphere.configure(map, environment, sun, Moth.sky(Atmosphere.sky_name(map)))

func surface_material(key: String, color: Color, _seams: float = 0.12) -> ShaderMaterial:
	if not materials.has(key):
		var texture_key := "weathered_concrete-worn"
		match key:
			"bark", "rock": texture_key = "rock-moss"
			"equipment": texture_key = "riveted_armor-scorched" if map_id == "ember-crucible" else "metal"
			"structure": texture_key = "brushed_metal"
			"infield": texture_key = "grass"
			"masonry":
				if map_id == "sunscar-convoy": texture_key = "rough_stucco"
				elif map_id in ["asterion-relay", "ion-speedway"]: texture_key = "hex_paneling-mottle"
		var mat := MothSurfaces.create_surface(texture_key, color)
		mat.set_shader_parameter("texture_strength", 0.5)
		mat.set_shader_parameter("texture_saturation", 0.25)
		mat.set_shader_parameter("repeat_scale", 0.35)
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

func terrain_material(kind: String = "concrete") -> Material:
	var key := "terrain/" + kind
	if not materials.has(key):
		var texture_key := "weathered_concrete"
		match kind:
			"snow", "ice": texture_key = "ice-cracked"
			"grass": texture_key = "grass"
			"sand", "dirt": texture_key = "sand"
			"rock", "stone": texture_key = "rock-moss"
			"ash": texture_key = "rough_stucco-weathered"
			"metal": texture_key = "metal"
		var mat := MothSurfaces.create_surface(texture_key, Color.WHITE, true)
		mat.set_shader_parameter("texture_strength", 0.48)
		mat.set_shader_parameter("texture_saturation", 0.2)
		mat.set_shader_parameter("repeat_scale", 0.4)
		materials[key] = mat
	return materials[key]

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
	atmosphere.decorate(parent)

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
