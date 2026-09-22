extends SceneTree

const Atmosphere = preload("res://graphics_atmosphere/atmosphere.gd")
const Catalog = preload("res://world/catalog.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func finite(value: Variant) -> bool:
	if value is float: return is_finite(value)
	if value is Color: return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
	if value is Vector3: return value.is_finite()
	if value is Dictionary:
		for item: Variant in value.values():
			if not finite(item): return false
	if value is Array:
		for item: Variant in value:
			if not finite(item): return false
	return true

func freeze(value: Variant) -> void:
	if value is Dictionary:
		for item: Variant in value.values(): freeze(item)
		value.make_read_only()
	elif value is Array:
		for item: Variant in value: freeze(item)
		value.make_read_only()

func verify() -> void:
	var catalog := Catalog.new()
	check(catalog.open(), "catalog open")
	check(catalog.entries.size() == 9, "nine source IDs")
	check(Atmosphere.PROFILES.size() == 9, "nine atmosphere profiles")
	var controller := Atmosphere.new()
	var environment := WorldEnvironment.new()
	var sun := DirectionalLight3D.new()
	root.add_child(environment)
	root.add_child(sun)
	var resource_ids := [controller.env.get_instance_id(), controller.sky.get_instance_id(), controller.sky_material.get_instance_id(), controller.ground_material.get_instance_id()]
	var snapshots := {}
	var maps := {}
	for id: String in catalog.entries:
		check(Atmosphere.PROFILES.has(id), "explicit profile " + id)
		var map: Dictionary = catalog.resolve_map(id)
		snapshots[id] = JSON.stringify(map)
		freeze(map)
		maps[id] = map
	var previous_texture: WeakRef
	for cycle in range(12):
		for id: String in maps:
			var map: Dictionary = maps[id]
			var image := Image.create(4, 2, false, Image.FORMAT_RGBA8)
			image.fill(Color(0.2, 0.3, 0.4))
			var texture := ImageTexture.create_from_image(image)
			controller.configure(map, environment, sun, texture)
			check(previous_texture == null or previous_texture.get_ref() == null, "prior texture released " + id)
			previous_texture = weakref(texture)
			texture = null
			check(environment.environment == controller.env, "environment ownership " + id)
			check(finite(Atmosphere.profile(map)), "finite profile " + id)
			check(finite(sun.rotation) and finite(sun.light_color), "finite light " + id)
			check(finite(controller.sky_material.get_shader_parameter("sun_direction")), "finite direction " + id)
			check(controller.env.ambient_light_energy >= 0.65, "shadow fill readability " + id)
			# At 100m even the smokiest profile transmits >91% of scene radiance.
			check(exp(-controller.env.fog_density * 100.0) > 0.91, "objective fog budget " + id)
			check(not controller.env.glow_enabled and not controller.env.ssao_enabled and not controller.env.volumetric_fog_enabled, "Compatibility features " + id)
			check(JSON.stringify(map) == snapshots[id], "read-only source map " + id)
		await process_frame
	check(resource_ids == [controller.env.get_instance_id(), controller.sky.get_instance_id(), controller.sky_material.get_instance_id(), controller.ground_material.get_instance_id()], "resource identities stable across 108 switches")
	controller.configure({"id": "unknown", "bounds": {"minX": NAN, "maxZ": INF}}, environment, sun)
	check(previous_texture.get_ref() == null, "null panorama releases prior texture")
	check(controller.sky_material.get_shader_parameter("panorama") == null, "no panorama retained on fallback")
	check(finite(controller.ground_material.get_shader_parameter("fade_begin")), "nonfinite bounds guarded")
	check(Atmosphere.sky_name({}) == "nebula", "unknown metadata fallback")
	var edited := Atmosphere.profile({})
	edited.colors[0] = "ffffff"
	check(Atmosphere.profile({}).colors[0] == "545779", "profile copies cannot mutate palette")
	# The bounded backdrop hook must leave authored geometry and tree ownership intact.
	var world := Node3D.new()
	root.add_child(world)
	var detail := Node3D.new()
	detail.name = "NativeWorldDetail"
	world.add_child(detail)
	var backdrop := MeshInstance3D.new()
	backdrop.name = "DistantGround"
	backdrop.mesh = PlaneMesh.new()
	backdrop.position.y = -4.0
	detail.add_child(backdrop)
	var silhouette := MultiMeshInstance3D.new()
	silhouette.name = "SkylineDetails"
	detail.add_child(silhouette)
	var objective := MeshInstance3D.new()
	objective.name = "Objective"
	objective.position = Vector3(1, 2, 3)
	detail.add_child(objective)
	for cycle in range(24): controller.decorate(world)
	check(detail.get_child_count() == 3 and backdrop.position.y == -4.0, "decoration adds no nodes or displacement")
	check(not silhouette.visible and objective.visible and objective.position == Vector3(1, 2, 3), "only old scenic silhouette hidden")
	var replacement := Environment.new()
	environment.environment = replacement
	controller.clear(environment)
	check(environment.environment == replacement, "clear respects replacement owner")
	controller.configure(maps["meridian-exchange"], environment, sun)
	controller.clear(environment)
	check(environment.environment == null, "clear detaches owned environment")
	var weak_environment: WeakRef = weakref(controller.env)
	world.free()
	controller = null
	check(weak_environment.get_ref() == null, "controller resources released")
	environment.free()
	sun.free()
	await process_frame
	print("ATMOSPHERE_VERIFY maps=9 switches=108 finite=true immutable=true stable_resources=true texture_release=true failures=", failures)
	quit(0 if failures == 0 else 1)
