extends RefCounted
## Compatibility-renderer art direction, independent of the Moth asset loader.
## One controller per viewer. Call after the existing surface style's configure.

const SKY_SHADER = preload("res://graphics_atmosphere/horizon.gdshader")
const GROUND_SHADER = preload("res://graphics_atmosphere/distant_ground.gdshader")
const MaterialLanguage = preload("res://material_language/library.gd")

# Source identities are explicit; biome alone misclassifies the orbital relay.
# Colors: zenith / horizon / lower hemisphere / key / ambient fill.
const PROFILES := {
	"meridian-exchange": {
		"sky": "nebula", "colors": ["545779", "b6a49c", "525760", "ffe0bd", "c5d5e5"],
		"texture": 0.22, "veil": 0.08, "rotation": 0.12, "disk": 0.75,
		"key": 0.72, "fill": 0.66, "pitch": -32.0, "yaw": -32.0, "fog": 0.00065,
	},
	"verdant-reliquary": {
		"sky": "frost", "colors": ["689caa", "bdcfc2", "56665e", "fff0d0", "d4e3d8"],
		"texture": 0.0, "veil": 0.18, "rotation": 0.0, "disk": 0.85,
		"key": 0.82, "fill": 0.68, "pitch": -48.0, "yaw": -38.0, "fog": 0.0008,
	},
	"ember-crucible": {
		"sky": "ember", "colors": ["291f32", "78544e", "392c31", "ffc18d", "c6c5df"],
		"texture": 0.66, "veil": 0.0, "rotation": 0.20, "disk": 0.0,
		"key": 0.62, "fill": 0.72, "pitch": -38.0, "yaw": -25.0, "fog": 0.0009,
	},
	"tidal-citadel": {
		"sky": "frost", "colors": ["648aa8", "c2d8df", "556d7b", "e4f1ff", "d3e4ec"],
		"texture": 0.10, "veil": 0.12, "rotation": 0.36, "disk": 0.65,
		"key": 0.78, "fill": 0.66, "pitch": -44.0, "yaw": -30.0, "fog": 0.0006,
	},
	"sunscar-convoy": {
		"sky": "ashen", "colors": ["927c7c", "c6a17f", "76624f", "ffddb0", "e0d8c9"],
		"texture": 0.10, "veil": 0.10, "rotation": 0.55, "disk": 0.8,
		"key": 0.82, "fill": 0.66, "pitch": -36.0, "yaw": -38.0, "fog": 0.00055,
	},
	"asterion-relay": {
		"sky": "void", "colors": ["111b32", "52657f", "29364b", "cadcff", "c3d4f2"],
		"texture": 0.82, "veil": 0.0, "rotation": 0.08, "disk": 0.0,
		"key": 0.70, "fill": 0.76, "pitch": -42.0, "yaw": -32.0, "fog": 0.00035,
	},
	"monsoon-foundry": {
		"sky": "ashen", "colors": ["688780", "a7bfb5", "53675f", "e2e9d7", "d0e0dd"],
		"texture": 0.0, "veil": 0.22, "rotation": 0.0, "disk": 0.12,
		"key": 0.66, "fill": 0.78, "pitch": -54.0, "yaw": -30.0, "fog": 0.00085,
	},
	"ion-speedway": {
		"sky": "void", "colors": ["121e35", "4d6b80", "283b4a", "cde8ff", "bfdaec"],
		"texture": 0.68, "veil": 0.0, "rotation": 0.38, "disk": 0.0,
		"key": 0.78, "fill": 0.78, "pitch": -52.0, "yaw": -32.0, "fog": 0.0003,
	},
	"aurora-stadium": {
		"sky": "nebula", "colors": ["24344e", "607f8f", "304552", "e1efff", "cce4e9"],
		"texture": 0.48, "veil": 0.0, "rotation": 0.62, "disk": 0.0,
		"key": 0.82, "fill": 0.80, "pitch": -60.0, "yaw": -32.0, "fog": 0.0003,
	},
}

var sky_material := ShaderMaterial.new()
var ground_material := ShaderMaterial.new()
var sky := Sky.new()
var env := Environment.new()
var current_id := ""

func _init() -> void:
	sky_material.shader = SKY_SHADER
	ground_material.shader = GROUND_SHADER
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# Linear display keeps the already-muted native materials readable in GL.
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = false
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.ssr_enabled = false

static func profile(map: Dictionary) -> Dictionary:
	# Unknown metadata has a stable finite fallback; it cannot invent a map ID.
	return PROFILES.get(str(map.get("id", "")), PROFILES["meridian-exchange"]).duplicate(true)

static func sky_name(map: Dictionary) -> String:
	return str(profile(map).sky)

func configure(map: Dictionary, environment: WorldEnvironment, sun: DirectionalLight3D, sky_texture: Texture2D = null) -> void:
	var p := profile(map)
	current_id = str(map.get("id", ""))
	var colors: Array = p.colors
	for pair: Array in [["zenith", 0], ["horizon", 1], ["ground", 2], ["sun_color", 3]]:
		sky_material.set_shader_parameter(pair[0], Color(colors[pair[1]]))
	sky_material.set_shader_parameter("panorama", sky_texture)
	sky_material.set_shader_parameter("has_panorama", sky_texture != null and p.texture > 0.0)
	sky_material.set_shader_parameter("panorama_strength", p.texture)
	sky_material.set_shader_parameter("panorama_rotation", p.rotation)
	sky_material.set_shader_parameter("veil_strength", p.veil)
	sky_material.set_shader_parameter("disk_strength", p.disk)
	env.ambient_light_color = Color(colors[4])
	env.ambient_light_energy = p.fill
	env.fog_light_color = Color(colors[1])
	env.fog_density = p.fog
	environment.environment = env
	sun.rotation_degrees = Vector3(p.pitch, p.yaw, 0.0)
	sun.light_color = Color(colors[3])
	sun.light_energy = p.key
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.1
	sun.shadow_normal_bias = 1.0
	sky_material.set_shader_parameter("sun_direction", sun.basis.z.normalized())
	ground_material.set_shader_parameter("ground", Color(colors[2]).darkened(0.18))
	ground_material.set_shader_parameter("horizon", Color(colors[1]))
	# The material language's derived data bucket is the only texture this
	# controller binds: distant ground grain that fades out with the sky blend.
	var grain := MaterialLanguage.derived("data--sand")
	ground_material.set_shader_parameter("grain_map", grain)
	ground_material.set_shader_parameter("has_grain", grain != null)
	var bounds: Dictionary = map.get("bounds", {})
	var extent := 100.0
	for key: String in ["minX", "maxX", "minZ", "maxZ"]:
		var value: Variant = bounds.get(key, 0.0)
		if (value is float or value is int) and is_finite(float(value)):
			extent = maxf(extent, minf(absf(float(value)), 250.0))
	ground_material.set_shader_parameter("fade_begin", extent + 20.0)
	ground_material.set_shader_parameter("fade_end", extent + 360.0)

func decorate(world: Node3D) -> void:
	# Bounded migration of baseline-only scenery. No authored meshes, collision,
	# terrain, labels, trim or objectives are inspected or modified here.
	var detail := world.get_node_or_null("NativeWorldDetail")
	if detail == null: return
	var backdrop := detail.get_node_or_null("DistantGround") as MeshInstance3D
	if backdrop != null: backdrop.material_override = ground_material
	for name: String in ["SkylineDetails", "RidgeDetails"]:
		var silhouette := detail.get_node_or_null(name) as MultiMeshInstance3D
		if silhouette != null: silhouette.visible = false

func clear(environment: WorldEnvironment) -> void:
	# Do not detach a replacement environment installed by another owner.
	if environment.environment == env: environment.environment = null
	sky_material.set_shader_parameter("panorama", null)
	sky_material.set_shader_parameter("has_panorama", false)
	current_id = ""
