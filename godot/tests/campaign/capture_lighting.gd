extends SceneTree
## The capture census must exclude actual separate worlds, never named nodes.
const Capture = preload("res://tests/campaign/live_capture.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var main_environment := WorldEnvironment.new()
	scene.add_child(main_environment)
	scene.add_child(DirectionalLight3D.new())
	var separate := SubViewport.new()
	separate.own_world_3d = true
	scene.add_child(separate)
	separate.add_child(WorldEnvironment.new())
	separate.add_child(DirectionalLight3D.new())
	separate.add_child(DirectionalLight3D.new())
	await process_frame
	var census := Capture.world_lights(root, scene.get_world_3d())
	assert(census.environments.size() == 1 and census.suns.size() == 1)
	assert(census.separateWorlds.size() == 3 and census.unresolved.is_empty())
	for excluded: Dictionary in census.separateWorlds:
		assert(excluded.worldID != scene.get_world_3d().get_instance_id() and excluded.ownWorld)
	# A SubViewport sharing the game world cannot hide extra scene lighting.
	var shared := SubViewport.new()
	shared.own_world_3d = false
	scene.add_child(shared)
	var duplicate := DirectionalLight3D.new()
	duplicate.name = "FirstPerson" # naming alone provides no exemption
	shared.add_child(duplicate)
	await process_frame
	census = Capture.world_lights(root, scene.get_world_3d())
	assert(census.suns.size() == 2 and census.suns.has(duplicate))
	# A second root-world environment is also detected, even outside scene's map.
	var extra_environment := WorldEnvironment.new()
	root.add_child(extra_environment)
	census = Capture.world_lights(root, scene.get_world_3d())
	assert(census.environments.size() == 2 and census.environments.has(extra_environment))
	extra_environment.free()
	scene.free()
	print("CAMPAIGN_CAPTURE_LIGHTING_OK")
	quit()
