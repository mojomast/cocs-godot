extends SceneTree
## Candidate-only production MapBuilder probe. Does not register a mode or map.
const Builder = preload("res://multiplayer_worlds/map.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var id := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): id = arg.trim_prefix("--map=")
	assert(id in ["abyssal-pressureworks","vesper-viaduct","stormglass-causeway"])
	assert(ResourceLoader.exists("res://multiplayer_worlds/art/worlds/"+id+".glb"),"Real candidate GLB required")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/"+id+".json"))
	assert(data.arena.modeBindings.is_empty(),"Candidate probe must not grant admission")
	var world := Builder.new()
	root.add_child(world)
	assert(world.build(data))
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	for spawn: Dictionary in data.spawnPoints:
		var feet := Vector3(spawn.x,spawn.y,spawn.z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.15,feet-Vector3.UP*.15))
		assert(not hit.is_empty() and absf(hit.position.y-feet.y)<.001,"Source/native spawn support")
	if id == "abyssal-pressureworks":
		for probe: Array in [
			[Vector3(-110,8,-68),Vector3(-120,8,-68),true],
			[Vector3(-85,8,-68),Vector3(-71,8,-68),false],
			[Vector3(-94,9,-84),Vector3(-94,9,-99),false],
			[Vector3(-94,8,-68),Vector3(-94,38,-68),true]]:
			var query := PhysicsRayQueryParameters3D.create(probe[0],probe[1])
			query.hit_back_faces = true
			assert((not space.intersect_ray(query).is_empty()) == bool(probe[2]),"Source/native shell/portal/window/ceiling")
	print("ASSET_MAP_PROBE ",id," ",data.geometryHash," spawns=",data.spawnPoints.size())
	world.free()
	await process_frame
	quit()
