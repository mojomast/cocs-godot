extends Node3D
## Documented shared environment for identity maps.
##
## identity_maps/map.gd is a geometry/collision builder: it deliberately ships
## no lights and no WorldEnvironment. This composition-owned layer installs
## exactly one DirectionalLight3D and one WorldEnvironment per identity-map
## session, so a session always has one sun and one sky. The native builders
## keep their own authored atmosphere, so all six Deathmatch maps have exactly
## one environment each. Colors come from the validated recipe palette.
const FALLBACK := ["a4a8ac", "b7b0a0", "202c59", "ad7045"]
var sun := DirectionalLight3D.new()
var world_environment := WorldEnvironment.new()
var built := false

static func palette_color(palette: Array, index: int, fallback: String) -> Color:
	if index < palette.size() and palette[index] is String:
		var value := str(palette[index])
		if Color.html_is_valid(value): return Color(value)
	return Color(fallback)

func build(recipe: Dictionary) -> bool:
	if built: return true
	built = true
	var palette: Array = recipe.get("palette", [])
	var floor_color := palette_color(palette, 0, FALLBACK[0])
	var shell := palette_color(palette, 1, FALLBACK[1])
	var cut := palette_color(palette, 2, FALLBACK[2])
	var accent := palette_color(palette, 3, FALLBACK[3])
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = cut.lerp(Color.BLACK, 0.45)
	sky_material.sky_horizon_color = shell.lerp(floor_color, 0.35)
	sky_material.ground_bottom_color = cut.darkened(0.45)
	sky_material.ground_horizon_color = shell.darkened(0.2)
	sky_material.sun_angle_max = 12.0
	sky_material.sun_curve = 0.2
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_light_color = shell
	environment.fog_light_energy = 1.0
	environment.fog_density = 0.0007
	environment.fog_sky_affect = 0.0
	environment.volumetric_fog_enabled = false
	environment.glow_enabled = false
	environment.ssao_enabled = false
	environment.ssil_enabled = false
	environment.ssr_enabled = false
	world_environment.environment = environment
	sun.rotation_degrees = Vector3(-46.0, -34.0, 0.0)
	sun.light_color = accent.lerp(Color.WHITE, 0.55)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.1
	sun.shadow_normal_bias = 1.0
	name = "IdentityEnvironment"
	add_child(sun)
	add_child(world_environment)
	return true
