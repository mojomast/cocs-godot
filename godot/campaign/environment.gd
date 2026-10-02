extends Node3D
## Geometry-only campaign worlds own one persistent daylight composition.
## This node owns the persistent sky/light baseline. The weather adapter may
## lease a cloned Environment and modulate the sun, restoring both at teardown.
const DAYLIGHT := {
	"rootfall-verge":["789cb2", "becbc6"],
	"siltwake-crossing":["829caf", "d9b89c"],
	"emberline-ascent":["748ba3", "bec5cc"],
	"crown-array":["7e9fb8", "cbd6ce"],
}
var map_id := ""
var sun := DirectionalLight3D.new()
var world_environment := WorldEnvironment.new()

func _init() -> void:
	name = "CampaignEnvironment"
	sun.name = "DaylightSun"
	world_environment.name = "DaylightSky"
	add_child(sun)
	add_child(world_environment)

func build(recipe: Dictionary) -> bool:
	var id := str(recipe.get("id", ""))
	if id not in DAYLIGHT: return false
	if not map_id.is_empty(): return map_id == id
	var palette: Variant = recipe.get("palette")
	if not palette is Array or palette.size() < 4: return false
	for index: int in [0, 3]:
		if not palette[index] is String or not Color.html_is_valid(palette[index]): return false
	var ground := Color(palette[0])
	var stone := Color(palette[3])
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(DAYLIGHT[id][0])
	sky_material.sky_horizon_color = Color(DAYLIGHT[id][1]).lerp(stone, 0.15)
	sky_material.ground_bottom_color = ground.lerp(Color("9bb8bb"), 0.25)
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.sun_angle_max = 12.0
	sky_material.sun_curve = 0.2
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	var daylight := Environment.new()
	daylight.background_mode = Environment.BG_SKY
	daylight.sky = sky
	# Same explicit daylight fill used by the original biome identity composition;
	# it does not depend on sky radiance warm-up or on a live authority connection.
	daylight.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	daylight.ambient_light_color = Color("cfddd8")
	daylight.ambient_light_energy = 0.48
	daylight.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	daylight.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	daylight.tonemap_exposure = 1.0
	daylight.fog_enabled = true
	daylight.fog_light_color = sky_material.sky_horizon_color
	daylight.fog_density = 0.0007
	daylight.fog_sky_affect = 0.0
	daylight.volumetric_fog_enabled = false
	daylight.glow_enabled = false
	daylight.ssao_enabled = false
	daylight.ssil_enabled = false
	daylight.ssr_enabled = false
	world_environment.environment = daylight
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_color = Color("fff0d7")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.1
	sun.shadow_normal_bias = 1.0
	map_id = id
	return true
