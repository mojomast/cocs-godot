extends SceneTree
## Run after the shared import/render session is available. This exercises the
## composition-owned rig with the same style entry point as inspection.
const Style = preload("res://identity_maps/style.gd")
const Rig = preload("res://native_arenas/identity_environment.gd")
const WeatherLook = preload("res://ambience/weather_look.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func run() -> void:
	for id: String in ["lacuna-court", "vermilion-fold", "nacre-engine"]:
		var stage := Node3D.new()
		root.add_child(stage)
		var rig := Rig.new()
		stage.add_child(rig)
		check(rig.build({"id": id, "palette": ["a4a8ac", "b7b0a0", "202c59", "ad7045"]}), id + " build")
		var reference := WorldEnvironment.new()
		var key := DirectionalLight3D.new()
		Style.configure_environment(id, reference, key)
		var actual := rig.world_environment.environment
		var expected := reference.environment
		check(stage.find_children("*", "WorldEnvironment", true, false).size() == 1, id + " duplicate environment")
		check(stage.find_children("*", "DirectionalLight3D", true, false).size() == 1, id + " duplicate sun")
		check(actual.tonemap_mode == expected.tonemap_mode and actual.tonemap_exposure == expected.tonemap_exposure, id + " tonemap")
		check(actual.background_mode == expected.background_mode and actual.background_energy_multiplier == expected.background_energy_multiplier, id + " background")
		check(actual.ambient_light_source == expected.ambient_light_source and actual.ambient_light_color == expected.ambient_light_color and actual.ambient_light_energy == expected.ambient_light_energy, id + " fill")
		check(actual.fog_enabled == expected.fog_enabled and actual.fog_light_color == expected.fog_light_color and actual.fog_density == expected.fog_density, id + " fog")
		check(actual.sky.sky_material is ShaderMaterial and (actual.sky.sky_material as ShaderMaterial).shader == (expected.sky.sky_material as ShaderMaterial).shader, id + " panorama shader")
		var actual_sky := actual.sky.sky_material as ShaderMaterial
		var expected_sky := expected.sky.sky_material as ShaderMaterial
		for uniform: String in ["zenith", "horizon", "ground", "panorama", "panorama_strength", "panorama_rotation", "sun_direction", "disk_strength"]:
			check(actual_sky.get_shader_parameter(uniform) == expected_sky.get_shader_parameter(uniform), id + " sky " + uniform)
		check(rig.sun.rotation_degrees == key.rotation_degrees and rig.sun.light_color == key.light_color and rig.sun.light_energy == key.light_energy and rig.sun.shadow_enabled == key.shadow_enabled, id + " key")
		var original := actual
		var look := WeatherLook.new()
		look.bind(stage, rig.world_environment, rig.sun)
		look.apply("storm", 0.0, true)
		check(rig.world_environment.environment != original, id + " weather lease")
		look.clear()
		check(rig.world_environment.environment == original and rig.sun.light_energy == key.light_energy, id + " weather restore")
		var owned_environment := rig.world_environment
		var owned_sun := rig.sun
		stage.free()
		check(not is_instance_valid(owned_environment) and not is_instance_valid(owned_sun), id + " return Home cleanup")
		reference.free()
		key.free()
	for id: String in ["canopy-divide", "basalt-reach"]:
		var rig := Rig.new()
		root.add_child(rig)
		check(rig.build({"id": id, "palette": ["a4a8ac", "b7b0a0", "202c59", "ad7045"]}), id + " build")
		check(rig.world_environment.environment.sky.sky_material is ProceduralSkyMaterial, id + " native sky")
		check(rig.world_environment.environment.tonemap_mode == Environment.TONE_MAPPER_LINEAR, id + " native tonemap")
		check(rig.world_environment.environment.ambient_light_color == Color("bdcdd4") and is_equal_approx(rig.world_environment.environment.ambient_light_energy,0.48), id + " native fill")
		check(is_equal_approx(rig.sun.light_energy,1.15) and rig.sun.rotation_degrees.is_equal_approx(Vector3(-46, -34, 0)), id + " native sun")
		rig.free()
	print("IDENTITY_ENVIRONMENT_PARITY_OK")
	quit(1 if failures > 0 else 0)
