extends SceneTree
const Wet = preload("res://ambience/wet_surface.gd")
const Look = preload("res://ambience/weather_look.gd")
const Contact = preload("res://ambience/rain_contact.gd")
const Weather = preload("res://ambience/weather_service.gd")

class OracleContact extends "res://ambience/rain_contact.gd":
	func _support(position: Vector3) -> Dictionary:
		queries += 1
		return {"position":Vector3(position.x, 2.0 if position.x > 5.0 else 0.0, position.z), "normal":Vector3.UP}

func _initialize() -> void:
	call_deferred("verify")
	create_timer(60).timeout.connect(func() -> void: push_error("Spatial weather watchdog"); quit(1))

func near(a: float, b: float) -> void:
	assert(absf(a-b) < 0.00002, "%s != %s" % [a,b])

func verify() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/world_weather/spatial_source.json"))
	for row: Dictionary in source.textures:
		var bytes := Wet.pixels(int(row.seed))
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(bytes)
		assert(hash.finish().hex_encode() == row.sha256, "full source texture byte parity")
	var contact := OracleContact.new()
	root.add_child(contact)
	contact.begin_tick()
	for i in 20:
		assert(contact.schedule(Vector3(1,5,3),Vector3(2,-10,1),Color("cfe0ef"),0.0) == source.schedules[i])
	assert(contact.slots.size() == 3 and contact.queries == 6)
	var slot: Dictionary = contact.slots[0]
	for i in 3: near(slot.position[i], source.contact.position[i])
	near(slot.born, source.contact.delay)
	for i in 3: near(slot.color[i], source.contact.color[i])
	# Source RipplePool spends one update step at the delay crossing; native is
	# timestamp-driven. Compare identical effect ages, not that frame artifact.
	for i in range(1,5):
		var value := Contact.envelope(float(i)*0.1)
		near(value.x, source.replay[i].scale)
		near(value.y, source.replay[i].opacity)
	contact.update(0.49,Vector3.ZERO)
	assert(contact.visible_count == 0)
	contact.update(0.6,Vector3.ZERO)
	assert(contact.visible_count == 3)
	contact.update(0.6,Vector3(100,0,0))
	near((contact.mesh.get_instance_transform(0).origin+contact.global_position).x,2.0)
	for tick in 100:
		contact.begin_tick()
		for i in 44: contact.schedule(Vector3(1,5,3),Vector3(2,-10,1),Color.WHITE,float(tick))
		assert(contact.slots.size() <= 18 and contact.queries <= 6)
	contact.clear()
	assert(contact.slots.is_empty() and contact.mesh.visible_instance_count == 0)
	contact.free()
	await verify_materials()
	await verify_support()
	await verify_lifecycle()
	print("WORLD_WEATHER_SPATIAL_OK texture_bytes=196608 contact_limit=18 query_limit=6")
	quit()

func verify_materials() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	world.add_child(environment)
	var original := StandardMaterial3D.new()
	var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.2,0.4,0.6))
	var texture := ImageTexture.create_from_image(image)
	original.roughness_texture = texture
	original.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	var meshes: Array[MeshInstance3D] = []
	for i in 3:
		var node := MeshInstance3D.new()
		node.mesh = BoxMesh.new()
		node.material_override = original
		world.add_child(node)
		meshes.append(node)
	var shader_nodes: Array[MeshInstance3D] = []
	var originals: Array[ShaderMaterial] = []
	for path: String in Wet.TARGETS:
		var mat := ShaderMaterial.new()
		mat.shader = load(path)
		originals.append(mat)
		var node := MeshInstance3D.new()
		node.mesh = BoxMesh.new()
		node.material_override = mat
		world.add_child(node)
		shader_nodes.append(node)
	var look := Look.new()
	for cycle in 12:
		look.bind(world,environment,null,7)
		look.apply("storm",0.0,true)
		assert(look.diagnostics().materials == 4)
		assert(look.diagnostics().wet_textures == 1 and look.diagnostics().wet_shader_variants == 3)
		assert(meshes[0].material_override == meshes[1].material_override)
		assert(meshes[0].material_override.roughness_texture != texture)
		assert(original.roughness_texture == texture and original.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE)
		for i in 3:
			assert(shader_nodes[i].material_override.shader != originals[i].shader)
			assert(shader_nodes[i].material_override.get_shader_parameter("weather_has_roughness") == true)
			assert(not originals[i].shader.code.contains("weather_has_roughness"))
		look.apply("clear",0.0,true)
		assert(meshes[0].material_override.roughness_texture == texture)
		assert(meshes[0].material_override.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE)
		look.clear()
		assert(look.diagnostics().wet_textures == 0 and look.diagnostics().wet_shader_variants == 0)
		assert(meshes[0].material_override == original)
	world.free()
	await process_frame

func verify_support() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10,1,10)
	shape.shape = box
	body.position.y = 1.5
	body.add_child(shape)
	world.add_child(body)
	var contact := Contact.new()
	root.add_child(contact)
	contact.bind(world)
	await physics_frame
	await physics_frame
	var hit := contact._support(Vector3(0,5,0))
	assert(not hit.is_empty())
	near(hit.position.y,2.0)
	assert(contact._support(Vector3(20,5,20)).is_empty(), "no guessed floor outside support")
	body.rotation.z = 0.2
	await physics_frame
	await physics_frame
	contact.begin_tick()
	hit = contact._support(Vector3(0,5,0))
	assert(hit.normal.y > 0.9 and absf(hit.normal.x) > 0.1)
	world.free()
	assert(contact._support(Vector3(0,5,0)).is_empty(), "freed map cannot retain contact queries")
	contact.free()

func verify_lifecycle() -> void:
	var weather := Weather.new()
	root.add_child(weather)
	var camera := Camera3D.new()
	root.add_child(camera)
	weather.bind({"id":"spatial-lifecycle"},camera)
	weather.apply_snapshot({"time":2.0,"singleplayer":{"weather":"rain"}})
	weather.set_native_weather_suppressed(true)
	weather.apply_settings({"mute":true})
	weather.tick(0.1)
	var serial: int = weather.contacts.serial
	weather.tick(0.1)
	assert(weather.contacts.serial == serial, "same authority time cannot emit again")
	for settings: Dictionary in [{"weather_quality":0},{"weather_quality":100,"reduced_motion":true},{"reduced_motion":false,"weather_enabled":false}]:
		weather.apply_settings(settings)
		assert(weather.contacts.slots.is_empty())
	weather.apply_settings({"weather_enabled":true,"weather_quality":100})
	weather.set_focus(false)
	assert(weather.contacts.slots.is_empty())
	weather.reset_transients()
	assert(weather.contacts.serial == 0)
	weather.free()
	camera.free()
	await process_frame
