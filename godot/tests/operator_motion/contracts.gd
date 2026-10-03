extends SceneTree
## Native integration gate. SOURCE PREPARED; requires an assigned engine slot.
const Visual = preload("res://source_operators/operator_visual.gd")
const Catalog = preload("res://source_operators/generated/catalog.gd")
const Ground = preload("res://source_operators/ground_contact.gd")
var failures: Array[String] = []
var measurements: Array[Dictionary] = []

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):
		failures.append(message)
		printerr(message)

func actor_at(identity: String, point: Vector3, velocity: Vector2) -> Dictionary:
	return {"id":2,"character":identity,"health":100,"weapon":0,"x":point.x,"y":point.y-0.9,"z":point.z,"vx":velocity.x,"vy":0.0,"vz":velocity.y,"grounded":true,"yaw":0.0,"bodyYaw":0.0,"moveSpeed":8.0}

func drive(visual: Node3D, actor: Dictionary, dt: float) -> void:
	visual.apply_actor(actor)
	visual.position = Vector3(actor.x,actor.y+0.9,actor.z)
	visual.rotation.y = actor.bodyYaw
	var authoritative := actor.duplicate(true)
	var transform_before := visual.transform
	visual.advance(dt)
	check(visual.transform.is_equal_approx(transform_before),"presentation moved the actor transform")
	check(actor == authoritative,"presentation mutated authoritative snapshot")

func run() -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(500,0.2,500)
	collision.shape = box
	floor.add_child(collision)
	floor.position.y = -0.1
	root.add_child(floor)
	await physics_frame
	await physics_frame
	for identity: String in Catalog.OPERATORS:
		var visual := Visual.new()
		root.add_child(visual)
		visual.automatic_animation = false
		visual.configure(actor_at(identity,Vector3(0,0.9,0),Vector2.ZERO))
		for side: String in ["L","R"]:
			for prefix: String in ["legUpper","legLower","foot"]:
				check(visual.nodes.has(prefix+side) and visual.source.is_ancestor_of(visual.nodes[prefix+side]),identity+" imported pivot membership "+prefix+side)
			check(absf(float(visual.rig.anatomy[side].length)-0.69)<0.0001,identity+" thigh+shin must include translated intermediate pivots")
		for hz: int in [30,60,144]:
			for speed: float in [1.0,2.0,4.0,8.0,11.0]:
				for direction: Vector2 in [Vector2(0,-1),Vector2(0,1),Vector2(1,0),Vector2(-1,-1).normalized()]:
					visual.reset_pose()
					var point := Vector3(0,0.9,0)
					var previous: Dictionary = {}
					var drift := 0.0
					var error := 0.0
					var grip := 0.0
					var samples := 0
					for frame in hz*2:
						var dt := 1.0/hz
						point += Vector3(direction.x,0,direction.y)*speed*dt
						var actor := actor_at(identity,point,direction*speed)
						drive(visual,actor,dt)
						for side: String in ["L","R"]:
							var contact: Dictionary = visual.locomotion.contacts[side]
							check((contact.ankle as Vector3).is_finite() and (contact.knee as Vector3).is_finite(),identity+" finite native leg pose")
							check(visual.grip_error.has(side),identity+" missing actual grip sample")
							if frame > hz and contact.planted:
								error = maxf(error,float(contact.error))
								if previous.has(side) and previous[side].planted and (previous[side].target as Vector3).is_equal_approx(contact.target):
									drift = maxf(drift,(previous[side].ankle as Vector3).distance_to(contact.ankle))
									samples += 1
							previous[side] = contact.duplicate()
							grip = maxf(grip,float(visual.grip_error.get(side,0))-float(visual.grip_clamp.get("clamped"+side,0)))
					var label := "%s/%d/%s/%s" % [identity,hz,speed,direction]
					check(samples > 0,label+" no measured planted interval")
					check(drift <= 0.01,label+" stance drift > 1 cm")
					check(error <= 0.015,label+" stance target residual > 1.5 cm")
					check(grip <= 0.003,label+" hand placement differs from measured reach clamp")
					measurements.append({"case":label,"stanceDrift":drift,"contactError":error,"gripResidual":grip,"samples":samples})
		var a := actor_at(identity,Vector3(0,0.9,0),Vector2.ZERO)
		drive(visual,a,1.0/60)
		for frame in 90:
			a.bodyYaw = float(frame)/90*PI
			a.yaw = a.bodyYaw
			drive(visual,a,1.0/60)
		check(absf(visual.locomotion.turn)>0.001,identity+" turn has no lag/weight response")
		a.grounded = false; a.vy = -8.0; a.y = 2.0
		drive(visual,a,1.0/60)
		var air_phase: float = visual.locomotion.distance_phase
		for frame in 40:
			a.x += 0.05
			drive(visual,a,1.0/60)
		check(is_equal_approx(visual.locomotion.distance_phase,air_phase),identity+" walks in air")
		check(not visual.locomotion.contacts.L.planted and not visual.locomotion.contacts.R.planted,identity+" air foot lock")
		a.grounded = true; a.y = 0.0; a.vy = 0.0
		drive(visual,a,1.0/60)
		check(visual.locomotion.landing < 0,identity+" missing landing compression")
		for frame in 120: drive(visual,a,1.0/60)
		check(absf(visual.locomotion.landing)<0.001,identity+" landing failed to recover")
		var head_y: float = visual.nodes.head.global_position.y
		a.crouching = true
		for frame in 90: drive(visual,a,1.0/60)
		check(head_y-visual.nodes.head.global_position.y > 0.2,identity+" crouch lost body height")
		check(float(visual.locomotion.contacts.L.error)<0.015,identity+" crouch lost contact")
		a.x += 30.0
		drive(visual,a,1.0/60)
		check(visual.locomotion.distance_phase == 0.0,identity+" teleport advanced stride")
		check(visual.locomotion.landing == 0.0,identity+" teleport retained landing impulse")
		visual.seek_pose(a,4.0)
		var first: Dictionary = visual._capture_pose()
		visual.kick(1.0)
		for frame in 33: visual.advance(1.0/30)
		visual.seek_pose(a,4.0)
		var second: Dictionary = visual._capture_pose()
		for joint: String in first:
			check((first[joint] as Transform3D).is_equal_approx(second[joint]),identity+" seek leaked state: "+joint)
		a.vehicleId = 9; a.vx = 11.0
		for frame in 30:
			a.x += 0.1
			drive(visual,a,1.0/60)
		check(visual.locomotion.distance_phase == 0.0,identity+" mounted actor walks")
		a.erase("vehicleId")
		a.crouching = false; a.vx = 2.0
		for frame in 20:
			a.x += 0.2
			drive(visual,a,0.1)
			check(visual.nodes.footL.global_position.is_finite(),identity+" hitch produced invalid foot")
		var paused: Dictionary = visual._capture_pose()
		visual.advance(0.0); visual.advance(NAN)
		var after_pause: Dictionary = visual._capture_pose()
		for joint: String in paused:
			check((paused[joint] as Transform3D).is_equal_approx(after_pause[joint]),identity+" invalid dt altered pose")
		visual.advance(0.5)
		check(visual.locomotion.distance_phase == 0.0,identity+" long pause retained stale stride")
		visual.free()
	floor.free()
	await physics_frame
	var unsupported := Visual.new()
	root.add_child(unsupported)
	unsupported.automatic_animation = false
	var sample := actor_at("chatgpt",Vector3(0,0.9,0),Vector2(0,-2))
	drive(unsupported,sample,1.0/60)
	check(Ground.sample(unsupported,Vector3.ZERO,0).is_empty(),"missing terrain fabricated support")
	check(not unsupported.locomotion.contacts.L.planted and not unsupported.locomotion.contacts.R.planted,"unsupported foot lock")
	unsupported.free()
	print(JSON.stringify({"gate":"operator-motion-native","passed":failures.is_empty(),"failures":failures,"measurements":measurements}))
	quit(0 if failures.is_empty() else 1)
