extends SceneTree
const Stage = preload("res://tests/new_maps/botanical_correction/x-03/helix-conservatory/staged.gd")

func _initialize() -> void:
	call_deferred("run")
	create_timer(170).timeout.connect(func() -> void: push_error("Botanical physics timeout"); quit(2))

func run() -> void:
	var id := Stage.map_id()
	var receipt := Stage.manifest(id)
	var world := Stage.make_world(root, id)
	var probes := Stage.read_json(Stage.directory(id) + "probes.json")
	assert(world.geometry_hash == probes.geometryHash)
	# Actual imported GLB ray target, test layer 2 only. Gameplay remains JSON
	# layer 1; these transient shapes never participate in capsule clearance.
	var visual := StaticBody3D.new()
	visual.collision_layer = 2
	visual.collision_mask = 0
	visual.name = "TestOnlyActualImportedGLBRays"
	world.add_child(visual)
	var art := Stage.art_root(world)
	for node: MeshInstance3D in art.find_children("*", "MeshInstance3D", true, false):
		var points := PackedVector3Array()
		for point: Vector3 in node.mesh.get_faces(): points.append(world.global_transform.affine_inverse() * node.global_transform * point)
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(points)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		visual.add_child(collision)
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = .41
	capsule.height = 1.7
	var errors: Array = []
	var checked := 0
	var seams: Array = []
	var groups := {}
	for p: Dictionary in probes.points:
		var origin := Vector3(p.x,p.y,p.z)
		assert(origin.is_finite())
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin+Vector3.UP*.5,origin-Vector3.UP*.3,1))
		if hit.is_empty():
			var adjacent_count := 0
			# Diagonal footprint corners avoid leaving two retry rays on the
			# same cardinal seam (authored trig coordinates can be ~1e-15).
			for offset: Vector3 in [Vector3(.005,0,.005),Vector3(-.005,0,.005),Vector3(.005,0,-.005),Vector3(-.005,0,-.005)]:
				var adjacent := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin+offset+Vector3.UP*.5,origin+offset-Vector3.UP*.3,1))
				if not adjacent.is_empty() and absf(float(adjacent.position.y)-float(p.y))<.08:
					adjacent_count += 1
					hit = adjacent
			if adjacent_count != 4: hit = {}
			else: seams.append({"id":p.id,"offsetMetres":.005,"neighbors":4})
		if hit.is_empty() or absf(float(hit.position.y)-float(p.y))>.08:
			errors.append({"id":p.id,"kind":"ground","expected":p.y,"hit":str(hit)})
			continue
		capsule.radius = .42 if str(p.kind).begins_with("successor-") else .41
		capsule.height = 1.8 if str(p.kind).begins_with("successor-") else 1.7
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.collision_mask = 1
		query.transform = Transform3D(Basis.IDENTITY,origin+Vector3.UP*(capsule.height/2.0+.05))
		var contacts := space.intersect_shape(query,8)
		if not contacts.is_empty(): errors.append({"id":p.id,"kind":"finite-capsule","contacts":str(contacts)})
		checked += 1
		groups[p.kind] = int(groups.get(p.kind,0))+1
	var rays: Array = []
	for p: Dictionary in probes.rays:
		var origin := Vector3(p.origin[0],p.origin[1],p.origin[2])
		var direction := Vector3(p.direction[0],p.direction[1],p.direction[2])
		assert(origin.is_finite() and direction.is_finite() and absf(direction.length()-1)<.00001)
		var distances: Array = []
		for mask in [1,2]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*float(p.max),mask))
			distances.append(origin.distance_to(hit.position) if not hit.is_empty() else float(p.max))
		if absf(distances[0]-float(p.authority))>.0001 or absf(distances[1]-float(p.glb))>.0001 or absf(distances[0]-distances[1])>.04:
			errors.append({"id":p.id,"kind":"actual-imported-GLB-vs-authority","native":distances,"source":p})
		rays.append({"id":p.id,"nativeAuthority":distances[0],"nativeGLB":distances[1]})
	var mode_support: Array = []
	for mode: String in receipt.modes:
		assert(groups.get("spawns",0)>0 and groups.get("objectives",0)>0)
		if mode in ["teamdeathmatch","ctf"]: assert(groups.get("teamSpawns",0)>0)
		if mode == "ctf": assert(groups.get("flags",0)>0)
		mode_support.append({"mode":mode,"scope":"shared native spawn/team/objective support only","hostedJourney":"pending"})
	var report := {"geometryHash":world.geometry_hash,"glbSha256":receipt.glbSha256,"manifestSha256":FileAccess.get_sha256(Stage.directory(id)+"manifest.json"),"godot":Engine.get_version_info(),"finiteCapsules":checked,"expected":probes.points.size(),"groups":groups,"seamSupport":seams,"rays":rays,"modeSupport":mode_support,"errors":errors,"scope":"native finite capsule/static ray probes; movement dynamics and hosted modes pending"}
	assert(not FileAccess.file_exists(Stage.directory(id)+"physics-report.json"), "Receipt exists; use a new attempt")
	var file := FileAccess.open(Stage.directory(id)+"physics-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	print("BOTANICAL_PHYSICS ",id," checked=",checked," errors=",errors.size())
	world.free()
	quit(0 if errors.is_empty() and checked==probes.points.size() else 1)
