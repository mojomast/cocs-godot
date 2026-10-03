extends SceneTree
const Biome = preload("res://biomes/map.gd")
const Visual = preload("res://source_operators/operator_visual.gd")
var failures: Array[String] = []
var queries := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr(message)

func run() -> void:
	for id: String in ["canopy-divide","basalt-reach"]:
		var map := Biome.new()
		root.add_child(map)
		check(map.build(id),id+" build")
		await physics_frame
		await physics_frame
		for route: Dictionary in map.recipe.routes:
			for p: Dictionary in route.points:
				var from := Vector3(p.x,50,p.z)
				var query := PhysicsRayQueryParameters3D.create(from,Vector3(p.x,-5,p.z))
				var hit: Dictionary = map.get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty(),id+" missing native support")
				if not hit.is_empty(): check(absf(hit.position.y-p.y)<0.025,id+" native/source floor disagreement: "+str(p))
				queries += 1
		check(map.foliage_batches <= 2 and map.plant_count > 100,id+" foliage batching")
		map.free()
		await physics_frame
	var visual := Visual.new()
	root.add_child(visual)
	visual.automatic_animation = false
	visual.configure({"id":2,"character":"claude","health":100,"vx":3.5,"vz":0.0,"grounded":true,"weapon":0})
	check(visual.armor_details.size() >= 30,"articulated armor detail missing")
	# Maps above are freed: this is explicitly the coordinate-free treadmill
	# lane, not a world-plant measurement. Abduction need not yaw the whole leg.
	var min_x := INF
	var max_x := -INF
	for i in 120:
		visual.advance(1.0/60)
		for side: String in ["L","R"]:
			var ankle: Vector3 = visual.nodes["foot"+side].global_position
			check(ankle.is_finite(),"strafe ankle must stay finite")
			check(visual.source.is_ancestor_of(visual.nodes["foot"+side]),"ankle must belong to imported source hierarchy")
			check(not visual.locomotion.contacts[side].planted,"no-world treadmill cannot claim a ground plant")
			check(visual.grip_error.has(side),"grip measurement missing")
			check(float(visual.grip_error[side])-float(visual.grip_clamp.get("clamped"+side,0))<0.003,"directional gait breaks weapon grip beyond authored reach clamp")
		if i>=60:
			min_x=minf(min_x,visual.nodes.footL.global_position.x)
			max_x=maxf(max_x,visual.nodes.footL.global_position.x)
	check(max_x-min_x>0.08,"strafe must displace ankle along lateral travel by >8 cm")
	visual.apply_actor({"id":2,"character":"claude","health":100,"vx":0.0,"vz":0.0,"vy":-8.0,"grounded":false,"weapon":0})
	visual.advance(1.0/60)
	visual.apply_actor({"id":2,"character":"claude","health":100,"vx":0.0,"vz":0.0,"grounded":true,"weapon":0})
	visual.advance(1.0/60)
	check(visual.locomotion.landing < 0,"landing has no weight response")
	for i in 180: visual.advance(1.0/60)
	check(absf(visual.locomotion.landing)<0.001,"landing spring does not settle")
	var standing_head: float = visual.nodes.head.global_position.y
	var standing_foot: float = visual.nodes.footL.global_position.y
	visual.apply_actor({"id":2,"character":"claude","health":100,"vx":0.0,"vz":0.0,"grounded":true,"crouching":true,"weapon":0})
	for i in 90: visual.advance(1.0/60)
	check(standing_head-visual.nodes.head.global_position.y > 0.2,"crouch does not lower the silhouette")
	check(absf(standing_foot-visual.nodes.footL.global_position.y)<0.045,"crouch IK loses foot contact")
	visual.select_distance(30)
	check(visual.armor_details.all(func(m: MeshInstance3D) -> bool: return not m.visible),"far armor LOD")
	visual.reset_pose()
	check(visual.locomotion.distance_phase==0 and visual.locomotion.landing==0,"locomotion reset")
	visual.apply_actor({"id":2,"character":"claude","health":100,"vx":10.0,"vz":0.0,"vehicleId":1,"grounded":true,"weapon":0})
	for i in 30: visual.advance(1.0/60)
	check(visual.locomotion.distance_phase==0,"mounted vehicle velocity triggers walking")
	visual.free()
	print(JSON.stringify({"gate":"biome-model-animation","floor_queries":queries,"failures":failures,"passed":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
