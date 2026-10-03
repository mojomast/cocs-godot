extends SceneTree
const Stage = preload("res://tests/new_maps/gravemill_foundry/revision5/staged.gd")

func _initialize() -> void:
	call_deferred("run")
	create_timer(120).timeout.connect(func() -> void: push_error("R5 physics timeout"); quit(2))

func run() -> void:
	var world := Stage.make_world(root)
	var probes := Stage.read_json(Stage.DIR + "probes.json")
	assert(world.geometry_hash == probes.geometryHash)
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = .41
	capsule.height = 1.7
	var errors: Array = []
	var checked := 0
	var seam_support: Array = []
	for p: Dictionary in probes.points:
		var origin := Vector3(p.x,p.y,p.z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin+Vector3.UP*.5,origin-Vector3.UP*.3))
		if hit.is_empty():
			# Float32 triangle seams can miss an infinitesimal centre ray. A
			# finite .41 m capsule needs support across its footprint instead.
			var neighboring := 0
			for offset: Vector3 in [Vector3(.005,0,0),Vector3(-.005,0,0),Vector3(0,0,.005),Vector3(0,0,-.005)]:
				var adjacent := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin+offset+Vector3.UP*.5,origin+offset-Vector3.UP*.3))
				if not adjacent.is_empty() and absf(float(adjacent.position.y)-float(p.y))<.08:
					neighboring += 1
					hit = adjacent
			if neighboring < 4: hit = {}
			else: seam_support.append({"id":p.id,"offsetMetres":.005,"supportedNeighbors":neighboring})
		if hit.is_empty() or absf(float(hit.position.y)-float(p.y))>.08:
			errors.append({"id":p.id,"kind":"ground","point":p,"hit":str(hit)})
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY,origin+Vector3.UP*.9)
		var contacts := space.intersect_shape(query,8)
		if not contacts.is_empty():
			var names: Array = []
			for contact: Dictionary in contacts: names.append(str(contact.collider.name))
			errors.append({"id":p.id,"kind":"capsule","point":p,"contacts":names})
		checked += 1
	var rays: Array = []
	for p: Dictionary in probes.rays:
		var o := Vector3(p.origin[0],p.origin[1],p.origin[2])
		var d := Vector3(p.direction[0],p.direction[1],p.direction[2])
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(o,o+d*float(p.max)))
		var distance: float = o.distance_to(hit.position) if not hit.is_empty() else float(p.max)
		if absf(distance-float(p.authority))>.04: errors.append({"id":p.id,"kind":"ray","distance":distance,"source":p.authority})
		rays.append({"id":p.id,"distance":distance})
	var report := {"geometryHash":world.geometry_hash,"godot":Engine.get_version_info(),"finiteCapsules":checked,"expected":probes.points.size(),"radius":.41,"height":1.7,"seamFootprintSupport":seam_support,"rays":rays,"errors":errors,"scope":"staged native route/nav/spawn/team/objective clearance; six-mode hosted journeys pending"}
	var file := FileAccess.open(Stage.DIR+"physics-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	print("R5_NATIVE_PHYSICS ",JSON.stringify(report))
	world.free()
	quit(0 if errors.is_empty() and checked==probes.points.size() else 1)
