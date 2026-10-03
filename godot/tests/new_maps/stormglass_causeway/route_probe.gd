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
	var contacts:=0
	for edge: Array in data.arena.race.boundary.values():
		for i in range(edge.size()):
			var a:=Vector3(edge[i].x,0,edge[i].z)
			var b:=Vector3(edge[(i+1)%edge.size()].x,0,edge[(i+1)%edge.size()].z)
			var p: Vector3=(a+b)/2
			var midpoint:=Vector3((line[i].x+line[(i+1)%line.size()].x)/2,0,(line[i].z+line[(i+1)%line.size()].z)/2)
			var normal: Vector3=(b-a).cross(Vector3.UP).normalized()
			if normal.dot(p-midpoint)<0: normal=-normal
			for radius in [.42,2.0838665984]:
				var body:=CharacterBody3D.new()
				var shape:=CollisionShape3D.new()
				var cylinder:=CylinderShape3D.new()
				cylinder.radius=radius
				cylinder.height=1.7
				shape.shape=cylinder
				body.add_child(shape)
				world.add_child(body)
				body.position=p-normal*6+Vector3.UP*.86
				for step in range(120): body.move_and_collide(normal*.15)
				var gap: float=(p-body.position).dot(normal)
				assert(gap>=radius-.03 and gap<radius+.15,"Native body barrier mismatch: "+str(gap))
				body.free()
				contacts+=1
			var shot:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p-normal*4+Vector3.UP,p+normal*4+Vector3.UP))
			assert(not shot.is_empty(),"Barrier shot leak")
	var report:={"accepted":false,"supportSamples":samples,"ceilings":6,"sustainedBodyContacts":contacts,"wallShots":42,"geometryHash":data.geometryHash}
	var out:=OS.get_environment("ASSET_STAGE_EVIDENCE")
	if not out.is_empty():
		var file:=FileAccess.open(out.path_join("collision.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  "))
	print("STORMGLASS_ROUTE_PROBE ",JSON.stringify(report))
	quit(0)
