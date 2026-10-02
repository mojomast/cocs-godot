extends SceneTree
const Look = preload("res://ambience/weather_look.gd")
const Profile = preload("res://ambience/weather_profile.gd")
const Weather = preload("res://ambience/weather_service.gd")

func _initialize() -> void:
	call_deferred("verify")
	create_timer(30).timeout.connect(func() -> void: push_error("Weather unit watchdog"); quit(1))

func near(actual: float, expected: float) -> void:
	assert(absf(actual - expected) < 0.00002, "actual=%s expected=%s" % [actual, expected])

func color_near(actual: Color, expected: Array) -> void:
	near(actual.r, expected[0])
	near(actual.g, expected[1])
	near(actual.b, expected[2])

func verify() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/world_weather/source.json"))
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	root.add_child(environment)
	var baseline := Environment.new()
	baseline.fog_light_color = Color(data.base.fog)
	baseline.fog_density = data.base.density
	baseline.tonemap_exposure = data.base.exposure
	baseline.ambient_light_color = Color(data.base.fillColor)
	baseline.ambient_light_energy = data.base.fill
	environment.environment = baseline
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(data.base.keyColor)
	sun.light_energy = data.base.key
	root.add_child(sun)
	var mat := StandardMaterial3D.new()
	mat.roughness = data.base.roughness
	mat.metallic = data.base.metallic
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.material_override = mat
	world.add_child(mesh)
	var second := MeshInstance3D.new()
	second.mesh = mesh.mesh
	second.material_override = mat
	world.add_child(second)
	var original_transform := mesh.transform
	var look := Look.new()
	look.bind(world, environment, sun)
	assert(look.diagnostics().materials == 1, "shared material must clone only once")
	assert(mesh.material_override == second.material_override and mesh.material_override != mat)
	for row: Dictionary in data.looks:
		look.apply(row.kind, 0.0, true)
		near(look.wetness, row.wetness)
		near(environment.environment.fog_density, row.density)
		near(environment.environment.tonemap_exposure, row.exposure)
		near(environment.environment.ambient_light_energy, row.fill)
		near(sun.light_energy, row.key)
		color_near(environment.environment.fog_light_color, row.fog)
		color_near(environment.environment.ambient_light_color, row.fillColor)
		color_near(sun.light_color, row.keyColor)
		near(mesh.material_override.roughness, row.roughness)
		near(mesh.material_override.metallic, row.metallic)
		near(mat.roughness, data.base.roughness)
		assert(mesh.transform == original_transform)
	look.apply("clear", 0.0, true)
	for row: Dictionary in data.replay:
		look.apply(row.kind, row.delta)
		near(look.wetness, row.wetness)
	for row: Dictionary in data.phases:
		assert(Profile.time_at({"id":"linear-oracle", "background":row.background, "timeOfDay":false}, 0) == row.expected)
	for row: Dictionary in data.sheen:
		var actual := Profile.wet_sheen(row.value)
		for key: String in row.expected: near(actual[key], row.expected[key])
	look.clear()
	assert(mesh.material_override == mat and second.material_override == mat)
	assert(environment.environment == baseline)
	near(sun.light_energy, data.base.key)
	# Existing shader material path, exact restoration of inherited surfaces,
	# and replacement-owner safety at map transitions.
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = preload("res://material_language/family.gdshader")
	shader_mat.set_shader_parameter("roughness", 0.8)
	var shader_mesh := MeshInstance3D.new()
	shader_mesh.mesh = BoxMesh.new()
	shader_mesh.mesh.surface_set_material(0, shader_mat)
	world.add_child(shader_mesh)
	look.bind(world, environment, sun)
	look.apply("storm", 0.0, true)
	var wet_shader := shader_mesh.get_surface_override_material(0) as ShaderMaterial
	assert(wet_shader != null and wet_shader != shader_mat)
	near(wet_shader.get_shader_parameter("roughness"), 0.8 * (1.0 - 0.22 * 0.55))
	near(wet_shader.get_shader_parameter("metallic"), 0.22 * 0.3)
	assert(shader_mat.get_shader_parameter("metallic") == null, "shader-declared defaults must not be written to the original")
	near(shader_mat.get_shader_parameter("roughness"), 0.8)
	var replacement := Environment.new()
	environment.environment = replacement
	sun.light_energy = 0.123
	look.clear()
	assert(environment.environment == replacement)
	near(sun.light_energy, 0.123)
	assert(shader_mesh.get_surface_override_material(0) == null)
	environment.environment = baseline
	sun.light_energy = data.base.key
	sun.light_color = Color(data.base.keyColor)
	# Production service: authoritative clock, frozen/stale feed, rewind, settings.
	var service := Weather.new()
	root.add_child(service)
	service.apply_settings({"mute":true})
	service.bind({"id":"world-weather-test", "sky":"day"}, null)
	service.bind_presentation(world, environment, sun)
	service.apply_snapshot({"time":1.0, "singleplayer":{"weather":"storm"}})
	service.tick(0.1)
	var wet: float = service.look.wetness
	service.tick(0.1)
	near(service.look.wetness, wet)
	service.set_focus(false)
	service.apply_snapshot({"time":1.25, "singleplayer":{"weather":"rain"}})
	service.tick(0.1)
	near(service.look.wetness, wet)
	service.apply_settings({"weather_enabled":false})
	near(service.look.wetness, 0.0)
	service.apply_settings({"weather_enabled":true, "reduced_motion":true})
	near(service.look.wetness, 0.0)
	service.apply_settings({"reduced_motion":false, "weather_quality":0})
	service.set_focus(true)
	service.tick(0.1)
	near(service.look.wetness, 0.0)
	service.apply_settings({"weather_quality":100})
	service.apply_snapshot({"time":0.0, "singleplayer":{"weather":"snow"}})
	service.tick(0.1)
	near(service.look.wetness, 0.05)
	service.bind({"id":"next-map", "sky":"day"}, null)
	assert(environment.environment == baseline and mesh.material_override == mat)
	service.free()
	# Finite-pool contract under unique-material pressure.
	for index in 270:
		var extra := MeshInstance3D.new()
		extra.mesh = mesh.mesh
		extra.material_override = StandardMaterial3D.new()
		world.add_child(extra)
	look.bind(world, environment, sun)
	assert(look.diagnostics().materials == Look.MATERIAL_CAP)
	assert(look.diagnostics().capped)
	look.apply("storm", 0.0, true)
	assert(look.diagnostics().uniform_writes == Look.MATERIAL_CAP * 2)
	look.clear()
	world.free()
	environment.free()
	sun.free()
	var owner := Node3D.new()
	root.add_child(owner)
	var owned_environment := WorldEnvironment.new()
	owned_environment.environment = Environment.new()
	owner.add_child(owned_environment)
	var owned_sun := DirectionalLight3D.new()
	owner.add_child(owned_sun)
	var ground_mesh := MeshInstance3D.new()
	ground_mesh.mesh = PlaneMesh.new()
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = preload("res://campaign/materials/ground.gdshader")
	ground_mesh.material_override = ground_mat
	owner.add_child(ground_mesh)
	var freed_environment := WorldEnvironment.new()
	var freed_sun := DirectionalLight3D.new()
	freed_environment.free()
	freed_sun.free()
	var av = preload("res://audio/av_service.gd").new()
	root.add_child(av)
	av.apply_settings({"mute":true})
	av.bind_session(owner, null, {"id":"map-owned"}, "campaign", 1)
	av.weather.bind_presentation(owner, freed_environment, freed_sun)
	av.apply_snapshot({"time":1.0,"singleplayer":{"weather":"storm"}}, -1, true)
	av.tick(0.1)
	assert(av.weather.look.wetness > 0.0, "mute must not freeze visuals")
	assert(owned_environment.environment == av.weather.look._owned)
	near(ground_mesh.material_override.get_shader_parameter("weather_wetness"), av.weather.look.wetness)
	assert(ground_mat.get_shader_parameter("weather_wetness") == null, "shader default stays unset on original")
	av.free()
	assert(ground_mesh.material_override == ground_mat, "campaign ground restored exactly")
	owner.free()
	print("WORLD_WEATHER_NATIVE_OK source_looks=6 replay_steps=60 lifecycle=pass")
	quit()
