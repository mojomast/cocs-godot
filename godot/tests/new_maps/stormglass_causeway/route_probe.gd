extends SceneTree
## Explicit engine grant required. This is a geometry probe, not hosted play.
const MapBuilder = preload("res://multiplayer_worlds/map.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/stormglass-causeway.json"))
	if not ResourceLoader.exists("res://multiplayer_worlds/art/worlds/stormglass-causeway.glb"):
		push_error("Stormglass Blender export/import required")
		quit(2)
		return
	var world := Node3D.new()
	root.add_child(world)
	var geometry := MapBuilder.new()
	world.add_child(geometry)
	assert(geometry.build(data))
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var samples := 0
	var line: Array = data.arena.race.centerline
	for i in range(line.size()):
		var a: Dictionary = line[i]
		var b: Dictionary = line[(i+1)%line.size()]
		for step in range(21):
			var p := Vector3(lerpf(a.x,b.x,step/20.0),0,lerpf(a.z,b.z,step/20.0))
			var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*2,p-Vector3.UP)
			var hit := space.intersect_ray(query)
			assert(not hit.is_empty(),"Missing road support")
			assert(absf(hit.position.y)<0.001,"Road floor mismatch")
			samples += 1
	for i in [1,4,5,6,14,18]:
		var a: Dictionary = line[i]
		var b: Dictionary = line[(i+1)%line.size()]
		var p := Vector3((a.x+b.x)/2,1,(a.z+b.z)/2)
		var query := PhysicsRayQueryParameters3D.create(p,p+Vector3.UP*30)
		query.hit_back_faces = true
		var hit := space.intersect_ray(query)
		assert(not hit.is_empty(),"Missing overhead collision")
		assert(hit.position.y>=7 and hit.position.y<=17)
	print("STORMGLASS_ROUTE_PROBE ",JSON.stringify({"supportSamples":samples,"ceilings":6,"geometryHash":data.geometryHash}))
	quit(0)
