extends RefCounted

# Native art direction using the original baked Moth pixels. Source geometry
# remains the gameplay contract; texture mapping never displaces surfaces.
#
# This file is also the application seam for the shared material language
# (`res://material_language/library.gd`): surface ROLES (floor, wall, rail,
# cover, prop, landmark, hazard) resolve to published family names here, and
# every call returns the library's shared ShaderMaterial. Nothing in this file
# invents a surface material or a texture: geometry keeps its authored colours
# as the family tint, and a role with no published family falls back to the
# pre-pass Moth surface material instead of a look-alike.
const MothSurfaces = preload("res://moth/surfaces.gd")
const Moth = preload("res://moth/library.gd")
const Atmosphere = preload("res://graphics_atmosphere/atmosphere.gd")
const MaterialLanguage = preload("res://material_language/library.gd")

# Surface roles. `family` must be one of MaterialLanguage.families(); `variant`
# must be one of MaterialLanguage.variants(family). `options` are the library's
# own bounded uniforms: tiles_per_metre is texel density (64 px tile at 0.5 =
# 32 px/m), normal_strength is the baked-bump read, lut_gain the LUT accent.
#
# Identity policy: the authored palette colour is the tint, so ALBEDO must land
# on the tint, not on the family's illustrative palette. Every role therefore
# sets albedo_gain to the reciprocal of its baked tile's mean luminance
# (measured: sand 0.44, weathered_concrete 0.40, hex_paneling 0.46,
# ice-cracked 0.48, grass 0.29, rock-moss 0.30, brushed_metal 0.25,
# metal-oxide 0.41, riveted_armor-scorched 0.44, diamond_plate 0.49,
# metal_grating 0.50, circuit_board-etch 0.31, hazard_stripes 0.44) and keeps
# texture_strength at 0.35-0.60 so the tile reads as grain and bump, not as a
# repaint. Emissive LUT accents stay off structural roles.
const ROLE_TABLE := {
	# --- ground ------------------------------------------------------------
	"floor": {"family": "regolith", "variant": "default", "options": {"tiles_per_metre": 0.5, "texture_strength": 0.55, "texture_saturation": 0.30, "albedo_gain": 1.4, "normal_strength": 0.34, "lut_gain": 0.0}},
	"floor-built": {"family": "pearl-ceramic", "variant": "cast", "options": {"tiles_per_metre": 0.5, "texture_strength": 0.40, "texture_saturation": 0.25, "albedo_gain": 1.5, "normal_strength": 0.30, "roughness": 0.86, "lut_gain": 0.0}},
	"floor-road": {"family": "hazard-industrial", "variant": "deck", "options": {"tiles_per_metre": 0.6, "texture_strength": 0.45, "texture_saturation": 0.25, "albedo_gain": 1.25, "normal_strength": 0.30, "metallic": 0.30, "lut_gain": 0.0}},
	"floor-grass": {"family": "regolith", "variant": "verdant", "options": {"tiles_per_metre": 0.8, "texture_strength": 0.45, "texture_saturation": 0.28, "albedo_gain": 2.1, "normal_strength": 0.32, "roughness": 0.90, "lut_gain": 0.0}},
	"snow": {"family": "polar-ice", "variant": "default", "options": {"tiles_per_metre": 0.26, "texture_strength": 0.30, "texture_saturation": 0.22, "albedo_gain": 8.0, "normal_strength": 0.16, "roughness": 0.88, "lut_gain": 0.0}},
	"ice": {"family": "polar-ice", "variant": "cracked", "options": {"tiles_per_metre": 0.30, "texture_strength": 0.34, "texture_saturation": 0.24, "albedo_gain": 1.25, "normal_strength": 0.26, "roughness": 0.30, "lut_gain": 0.12}},
	"sand": {"family": "regolith", "variant": "default", "options": {"tiles_per_metre": 0.5, "texture_strength": 0.58, "texture_saturation": 0.30, "albedo_gain": 1.4, "normal_strength": 0.38, "lut_gain": 0.0}},
	"rock": {"family": "regolith", "variant": "mossy", "options": {"tiles_per_metre": 0.5, "texture_strength": 0.52, "texture_saturation": 0.28, "albedo_gain": 2, "normal_strength": 0.38, "lut_gain": 0.0}},
	"ash": {"family": "regolith", "variant": "scoured", "options": {"tiles_per_metre": 0.45, "texture_strength": 0.50, "texture_saturation": 0.22, "albedo_gain": 10, "normal_strength": 0.34, "roughness": 0.94, "lut_gain": 0.0}},
	"stone": {"family": "pearl-ceramic", "variant": "cast", "options": {"tiles_per_metre": 0.5, "texture_strength": 0.38, "texture_saturation": 0.25, "albedo_gain": 1.5, "normal_strength": 0.32, "lut_gain": 0.0}},
	"dirt": {"family": "regolith", "variant": "mossy", "options": {"tiles_per_metre": 0.5, "texture_strength": 0.50, "texture_saturation": 0.28, "albedo_gain": 2, "normal_strength": 0.34, "lut_gain": 0.0}},
	# --- walls and structure ----------------------------------------------
	"wall": {"family": "pearl-ceramic", "variant": "cast", "options": {"tiles_per_metre": 0.5, "texture_strength": 0.38, "texture_saturation": 0.25, "albedo_gain": 1.5, "normal_strength": 0.30, "lut_gain": 0.0}},
	"wall-worn": {"family": "pearl-ceramic", "variant": "worn", "options": {"tiles_per_metre": 0.55, "texture_strength": 0.38, "texture_saturation": 0.25, "albedo_gain": 1.5, "normal_strength": 0.30, "lut_gain": 0.0}},
	"wall-panel": {"family": "pearl-ceramic", "variant": "polished", "options": {"tiles_per_metre": 0.5, "texture_strength": 0.42, "texture_saturation": 0.24, "albedo_gain": 1.3, "normal_strength": 0.28, "roughness": 0.32, "lut_gain": 0.05}},
	"wall-stucco": {"family": "enamel-glaze", "variant": "stucco", "options": {"tiles_per_metre": 0.5, "texture_strength": 0.40, "texture_saturation": 0.24, "albedo_gain": 1.35, "normal_strength": 0.30, "lut_gain": 0.0}},
	"wall-natural": {"family": "regolith", "variant": "mossy", "options": {"tiles_per_metre": 0.5, "texture_strength": 0.50, "texture_saturation": 0.28, "albedo_gain": 2, "normal_strength": 0.34, "lut_gain": 0.0}},
	"landmark": {"family": "pearl-ceramic", "variant": "polished", "options": {"tiles_per_metre": 0.45, "texture_strength": 0.42, "texture_saturation": 0.24, "albedo_gain": 1.3, "normal_strength": 0.30, "lut_gain": 0.05}},
	"display": {"family": "enamel-glaze", "variant": "default", "options": {"tiles_per_metre": 0.9, "texture_strength": 0.40, "texture_saturation": 0.22, "albedo_gain": 1.3, "normal_strength": 0.22, "lut_gain": 0.18}},
	# --- metal: rails, covers, machinery, props ----------------------------
	"rail": {"family": "brushed-alloy", "variant": "default", "options": {"tiles_per_metre": 1.1, "texture_strength": 0.45, "texture_saturation": 0.24, "albedo_gain": 2.4, "normal_strength": 0.34, "metallic": 0.75, "lut_gain": 0.0}},
	"cover": {"family": "brushed-alloy", "variant": "plate", "options": {"tiles_per_metre": 0.9, "texture_strength": 0.45, "texture_saturation": 0.24, "albedo_gain": 1.25, "normal_strength": 0.32, "metallic": 0.65, "lut_gain": 0.0}},
	"prop": {"family": "brushed-alloy", "variant": "default", "options": {"tiles_per_metre": 1.0, "texture_strength": 0.45, "texture_saturation": 0.24, "albedo_gain": 2.4, "normal_strength": 0.32, "metallic": 0.60, "lut_gain": 0.0}},
	"machinery": {"family": "brushed-alloy", "variant": "circuit", "options": {"tiles_per_metre": 1.0, "texture_strength": 0.45, "texture_saturation": 0.24, "albedo_gain": 2, "normal_strength": 0.30, "metallic": 0.55, "lut_gain": 0.18}},
	"grating": {"family": "brushed-alloy", "variant": "grating", "options": {"tiles_per_metre": 1.0, "texture_strength": 0.45, "texture_saturation": 0.24, "albedo_gain": 1.2, "normal_strength": 0.34, "metallic": 0.70, "lut_gain": 0.0}},
	"pipe": {"family": "oxidised-copper", "variant": "default", "options": {"tiles_per_metre": 0.7, "texture_strength": 0.48, "texture_saturation": 0.30, "albedo_gain": 1.5, "normal_strength": 0.30, "lut_gain": 0.0}},
	"pipe-scorched": {"family": "oxidised-copper", "variant": "scorched", "options": {"tiles_per_metre": 0.7, "texture_strength": 0.48, "texture_saturation": 0.30, "albedo_gain": 1.4, "normal_strength": 0.30, "metallic": 0.45, "lut_gain": 0.0}},
	"riveted": {"family": "oxidised-copper", "variant": "riveted", "options": {"tiles_per_metre": 0.8, "texture_strength": 0.48, "texture_saturation": 0.28, "albedo_gain": 1.4, "normal_strength": 0.34, "lut_gain": 0.0}},
	# --- hazard trim --------------------------------------------------------
	"hazard": {"family": "hazard-industrial", "variant": "default", "options": {"tiles_per_metre": 1.4, "texture_strength": 0.52, "texture_saturation": 0.34, "albedo_gain": 1.8, "normal_strength": 0.35, "lut_gain": 0.20}},
	"hazard-deck": {"family": "hazard-industrial", "variant": "deck", "options": {"tiles_per_metre": 1.0, "texture_strength": 0.45, "texture_saturation": 0.24, "albedo_gain": 1.25, "normal_strength": 0.34, "metallic": 0.35, "lut_gain": 0.0}},
	"hazard-grate": {"family": "hazard-industrial", "variant": "grating", "options": {"tiles_per_metre": 1.1, "texture_strength": 0.45, "texture_saturation": 0.24, "albedo_gain": 1.2, "normal_strength": 0.34, "metallic": 0.40, "lut_gain": 0.10}},
	# --- organic ------------------------------------------------------------
	"growth": {"family": "bioluminescent-membrane", "variant": "default", "options": {"tiles_per_metre": 1.0, "texture_strength": 0.50, "texture_saturation": 0.32, "albedo_gain": 1, "normal_strength": 0.30, "lut_gain": 0.30}},
	"growth-veined": {"family": "bioluminescent-membrane", "variant": "veined", "options": {"tiles_per_metre": 0.9, "texture_strength": 0.50, "texture_saturation": 0.32, "albedo_gain": 1, "normal_strength": 0.32, "lut_gain": 0.28}},
	"foliage": {"family": "regolith", "variant": "verdant", "options": {"tiles_per_metre": 0.7, "texture_strength": 0.44, "texture_saturation": 0.28, "albedo_gain": 2.1, "normal_strength": 0.30, "lut_gain": 0.0}},
}


# Block kinds that keep a map's own palette choice for the same role. Ember
# Crucible's basalt reads as scorched armour and its covers as oxidised pipe;
# the panel cities keep the mottled hex panel; the desert keeps its stucco.
const MAP_ROLE_CHOICES := {
	"sunscar-convoy": {"wall": "wall-stucco"},
	"asterion-relay": {"wall": "wall-panel", "landmark": "wall-panel", "rail": "grating"},
	"ion-speedway": {"wall": "wall-panel", "landmark": "wall-panel", "rail": "grating"},
	"monsoon-foundry": {"wall": "wall-worn"},
	"verdant-reliquary": {"wall": "wall-worn", "rock": "wall-natural"},
	"ember-crucible": {"cover": "pipe-scorched", "wall": "ash", "landmark": "riveted", "rock": "ash"},
	"nacre-engine": {"wall": "wall-panel"},
}

# Terrain keeps its source-shader DEPTH priority (the locked support-surface
# contract in moth/surface.gdshader); the material language supplies the baked
# bump that reads on each kind, at a documented, non-shimmering strength.
const TERRAIN_NORMALS := {
	"concrete": {"key": "weathered_concrete", "strength": 0.30},
	"snow": {"key": "ice", "strength": 0.20},
	"ice": {"key": "ice", "strength": 0.32},
	"grass": {"key": "grass", "strength": 0.30},
	"sand": {"key": "sand", "strength": 0.36},
	"dirt": {"key": "sand", "strength": 0.32},
	"rock": {"key": "rock", "strength": 0.40},
	"ash": {"key": "rock", "strength": 0.34},
	"metal": {"key": "metal_grating", "strength": 0.32},
	"stone": {"key": "rock", "strength": 0.34},
}

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
var roles_used: Dictionary = {}
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
	roles_used.clear()
	atmosphere.configure(map, environment, sun, Moth.sky(Atmosphere.sky_name(map)))

func surface_material(key: String, color: Color, _seams: float = 0.12) -> ShaderMaterial:
	# Kept for callers that named a pre-pass surface key directly. The key is
	# translated to a surface role and served by the material language; the
	# pre-pass Moth surface remains the fallback when no family is published.
	var role: String = KEY_ROLES.get(key, "wall")
	var material := family_surface(role, color)
	if material != null: return material
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

## One shared family material for a surface role, tinted with the caller's
## authored colour. Null means "no published family for this role": the caller
## falls back to the pre-pass material rather than a hand-rolled look-alike.
func family_surface(role: String, tint: Color, overrides: Dictionary = {}) -> Material:
	var material := role_material(role, tint, overrides, map_id)
	if material != null: roles_used[role] = ROLE_TABLE[role].family
	return material

## Static role resolution: validated against the published family list, so a
## renamed or missing family degrades to the fallback path instead of failing.
static func role_material(role: String, tint: Color, overrides: Dictionary, map_id: String) -> Material:
	if not ROLE_TABLE.has(role): return null
	var choice: Dictionary = ROLE_TABLE[role]
	if not map_id.is_empty() and MAP_ROLE_CHOICES.has(map_id) and MAP_ROLE_CHOICES[map_id].has(role):
		var chosen: String = MAP_ROLE_CHOICES[map_id][role]
		if ROLE_TABLE.has(chosen): choice = ROLE_TABLE[chosen]
	if not MaterialLanguage.families().has(str(choice.family)): return null
	var options: Dictionary = (choice.options as Dictionary).duplicate()
	if not (choice.variant as String).is_empty() and choice.variant != "default":
		options["variant"] = choice.variant
	for key: Variant in overrides: options[key] = overrides[key]
	options["tint"] = tint
	return MaterialLanguage.material(str(choice.family), options)

## Role -> family plan for the current map, for evidence and scene metadata.
func material_report() -> Dictionary:
	var plan: Dictionary = {}
	for role: String in roles_used: plan[role] = roles_used[role]
	return {"map": map_id, "roles": plan, "library": MaterialLanguage.cache_stats(), "budget": MaterialLanguage.budget()}

## Compact form for scene metadata.
func role_summary() -> Dictionary:
	var plan: Dictionary = {}
	for role: String in roles_used: plan[role] = roles_used[role]
	return {"map": map_id, "roles": plan, "library": MaterialLanguage.cache_stats()}

# Pre-pass surface keys translated to the shared role vocabulary.
const KEY_ROLES := {
	"bark": "wall-natural", "rock": "wall-natural",
	"equipment": "prop", "structure": "rail",
	"infield": "floor-grass",
	"sports-floor": "floor-grass",
	"masonry": "wall",
}

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
	# Surface roles, not block names, choose the family. A kind with no role
	# falls to the map's own masonry/wall choice, exactly like the pre-pass.
	if kind == "tree": return role_or_fallback("wall-natural", "bark", Color("544f40"))
	if kind in ["rock", "cave", "tunnel"]: return role_or_fallback("rock", "rock", wall.darkened(0.23))
	if kind in ["race-rail", "soccer-wall", "soccer-goal"]: return role_or_fallback("hazard", "equipment", accent)
	if kind in ["race-apron"]: return role_or_fallback("hazard-deck", "infield", ground)
	if kind in ["race-infield", "soccer"]: return role_or_fallback("floor-grass", "infield", ground)
	if kind in ["reactor", "relay-feed", "sluice"]: return role_or_fallback("machinery", "equipment", dark.lightened(0.12))
	if kind in ["pump", "pipe"]: return role_or_fallback("pipe", "equipment", dark.lightened(0.12))
	if kind in ["crate", "cover", "depot-wall", "base-screen"]: return role_or_fallback("cover", "equipment", dark.lightened(0.12))
	if kind in ["puma", "scout", "titan", "transport", "hornet", "launcher"]: return role_or_fallback("prop", "equipment", dark.lightened(0.18))
	if kind in ["zipline", "teleporter", "cqc", "light-mast", "race-light"]: return role_or_fallback("rail", "structure", dark.lightened(0.06))
	if kind in ["column", "pillar", "foundation"]: return role_or_fallback("landmark", "structure", dark.lightened(0.06))
	if kind in ["vehicle-road"]: return role_or_fallback("floor-road", "masonry", wall)
	if kind in ["bulkhead", "dam-buttress", "vault"]: return role_or_fallback("wall-worn", "masonry", wall)
	if kind in ["base-bastion", "base-hq", "base-wall", "wall", "partition", "building"]:
		return role_or_fallback("wall", "masonry", wall)
	return role_or_fallback("wall", "masonry", wall)

## Role first, pre-pass surface key as the fallback: one call site, no ad-hoc
## material, and a documented degradation when the library is unavailable.
func role_or_fallback(role: String, fallback_key: String, tint: Color) -> Material:
	var material := family_surface(role, tint)
	if material != null: return material
	return surface_material(fallback_key, tint)

## Composition seam for the native arenas: replace the named surface entries of
## an arena's own materials dictionary with shared family materials, keeping the
## arena's authored tint (read from its pre-pass material, never restated here)
## and its per-key option overrides. Returns {key: family} for evidence.
static func apply_roles(materials: Dictionary, roles: Dictionary, context: String) -> Dictionary:
	var plan: Dictionary = {}
	for key: String in roles:
		if not materials.has(key): continue
		var spec: Dictionary = roles[key]
		var role := str(spec.get("role", ""))
		var tint := Color.WHITE
		var existing: Material = materials[key]
		if existing is ShaderMaterial:
			var authored: Variant = (existing as ShaderMaterial).get_shader_parameter("tint")
			if authored is Color: tint = authored
		var material := role_material(role, tint, spec.get("options", {}), context)
		if material == null: continue
		materials[key] = material
		plan[key] = ROLE_TABLE[role].family
	return plan

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
		var normal_key := "weathered_concrete"
		match kind:
			"snow", "ice": texture_key = "ice-cracked"
			"grass": texture_key = "grass"
			"sand", "dirt": texture_key = "sand"
			"rock", "stone": texture_key = "rock-moss"
			"ash": texture_key = "rough_stucco-weathered"
			"metal": texture_key = "metal"
		if TERRAIN_NORMALS.has(kind): normal_key = str(TERRAIN_NORMALS[kind].key)
		var mat := MothSurfaces.create_surface(texture_key, Color.WHITE, true)
		mat.set_shader_parameter("texture_strength", 0.48)
		mat.set_shader_parameter("texture_saturation", 0.2)
		mat.set_shader_parameter("repeat_scale", 0.4)
		# Baked bump from the material language, on the surface where it reads.
		# The support-surface DEPTH priority contract in moth/surface.gdshader is
		# why terrain keeps this shader instead of the family shader.
		var normal := MaterialLanguage.normal_map(normal_key)
		if normal != null:
			mat.set_shader_parameter("normal_map", normal)
			mat.set_shader_parameter("has_normal", true)
			mat.set_shader_parameter("normal_strength", float(TERRAIN_NORMALS.get(kind, {"strength": 0.26}).strength))
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
			crown.material_override = role_or_fallback("foliage", "leaves", leaves)
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
			"marking": instances.material_override = solid_material("marking", Color("d3e9df"), 0.12)
			"accent": instances.material_override = role_or_fallback("hazard-grate", "accent", Color.WHITE)
			"skyline", "ridge": instances.material_override = solid_material("skyline", dark.lerp(Color(map.background), 0.4))
			_: instances.material_override = role_or_fallback("rail", "trim", dark)
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
