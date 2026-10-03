extends SceneTree
const Motion = preload("res://source_operators/motion_math.gd")
const Ground = preload("res://source_operators/ground_contact.gd")
const Robot = preload("res://campaign/robot_visual.gd")
const Operator = preload("res://source_operators/operator_visual.gd")
const Puppy = preload("res://campaign/puppy_visual.gd")
const Gesture = preload("res://campaign/story_gesture.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void:
	call_deferred("run")

func actor(id: String) -> Dictionary:
	return {"id":1,"npcModel":id,"health":100,"vx":1.2,"vz":-1.6,"grounded":true,"yaw":0.0,"bodyYaw":0.0}

func run() -> void:
	# Exact spring semigroup: a hitch equals the same elapsed time subdivided.
	for fps: int in [30,60,144]:
		var result := Vector2(0.3,1.7)
		for frame in fps: result = Motion.spring(result.x,result.y,0.8,18,1.0/fps)
		var exact := Motion.spring(0.3,1.7,0.8,18,1.0)
		check(result.distance_to(exact)<0.00001,"Spring rate invariance %d"%fps)
	# Support portion has exactly zero lift, constant travel, and continuous swing.
	for frame in 100:
		var phase := TAU*float(frame)/100
		var contact := Motion.contact(phase,0.9,0.08)
		check(contact.y>=0 and contact.y<=0.08001,"Bounded lift")
		if frame<62: check(contact.y==0,"Stance height")
	check(Motion.contact(TAU-0.00001,0.9,0.08).distance_to(Motion.contact(0,0.9,0.08))<0.00001,"Cycle continuity")
	var upper := Vector3(0.2,-0.3,0.1); var lower := Vector3(0.1,-0.25,-0.1)
	for target: Vector3 in [Vector3(0.2,-0.45,0.1),Vector3(-0.1,-0.4,-0.15),Vector3(0.15,-0.35,0.25)]:
		var solved := Motion.two_link(upper,lower,target,upper)
		var endpoint: Vector3 = solved[0]*(upper+solved[1]*lower)
		check(endpoint.distance_to(target)<0.00001,"Rigid two-link grounded target")
	for model: String in Robot.IDS:
		var poses: Array[Transform3D] = []
		for fps: int in [30,60,144]:
			var robot := Robot.new()
			robot.automatic_animation=false; robot.automatic_lod=false
			root.add_child(robot)
			var state := actor(model)
			robot.configure(state)
			for frame in fps: robot.advance(1.0/fps)
			poses.append(robot.rigs[0].legs[0].transform)
			# All living damage geometry stays within the rest sensor/chassis hull
			# plus 0.06m at the same source pitch. Test all mesh vertices, not AABBs.
			state.vx=0.0; state.vz=0.0
			robot.apply_actor(state); robot.reset_pose()
			var rests: Dictionary = {}
			for assembly: String in ["ArmorAndVents","SensorHousing"]:
				var mesh: MeshInstance3D = robot.rigs[0].body.get_node(assembly) if assembly=="ArmorAndVents" else robot.rigs[0].turret.get_node(assembly)
				rests[assembly]=mesh.global_transform*mesh.get_aabb()
			state.vx=3.5; state.pitch=0.0; state.campaignAttackWindup=0.8
			robot.apply_actor(state); robot.hit_reaction=1.0; robot.kick()
			for frame in fps:
				robot.advance(1.0/fps)
				for assembly: String in rests:
					var mesh: MeshInstance3D = robot.rigs[0].body.get_node(assembly) if assembly=="ArmorAndVents" else robot.rigs[0].turret.get_node(assembly)
					var hull: AABB = rests[assembly].grow(0.059)
					for vertex: Vector3 in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
						check(hull.has_point(mesh.global_transform*vertex),"Live %s %s containment"%[model,assembly])
			check(robot.stride_weight<0.00001,"Windup plants %s"%model)
			var planted: Transform3D = robot.rigs[0].legs[-1].transform
			robot.advance(0); robot.advance(NAN)
			check(robot.rigs[0].legs[-1].transform==planted,"Pause/invalid dt stable")
			for frame in fps: robot.advance(1.0/fps)
			check(robot.rigs[0].legs[-1].transform.origin==planted.origin,"Stationary hip anchor")
			state.health=0; robot.apply_actor(state); robot.advance(1.0)
			check(not robot.visible and not robot.wants_death_pose(),"Finite death lifetime")
			state.health=100; robot.apply_actor(state)
			check(robot.death_elapsed==0 and robot.stride_weight==0,"Respawn resets inertia")
			robot.free()
		for i in [1,2]:
			var difference := poses[i].basis.get_rotation_quaternion().angle_to(poses[0].basis.get_rotation_quaternion())
			print("RATE_POSE ",model," fps=",[30,60,144][i]," radians=",difference)
			check(difference<0.002,"Robot pose %s frame rate"%model)
	var puppy := Puppy.new(); puppy.automatic_animation=false; root.add_child(puppy)
	puppy.set_pose("idle"); puppy.advance(1)
	var foot := puppy.paws[0].global_position
	for frame in 144: puppy.advance(1.0/144); check(puppy.paws[0].global_position.distance_to(foot)<0.000001,"Idle paw locked")
	puppy.pet(); puppy.set_pose("sit")
	for frame in 180:
		puppy.advance(1.0/60)
		for paw: Node3D in puppy.paws:
			check((paw.global_transform*Vector3(0,-0.13,0)).y>=-0.01,"Patch sit sole above plane")
	puppy.free()
	var operator := Operator.new(); operator.automatic_animation=false; root.add_child(operator)
	var state := {"id":1,"character":"chatgpt","health":100,"weapon":0,"vx":0.0,"vz":0.0,"grounded":true}
	operator.configure(state); operator.advance(0.1)
	var foot_start: Transform3D = operator.nodes.footL.global_transform
	for frame in 60: operator.advance(1.0/60)
	check(operator.nodes.footL.global_transform.origin.distance_to(foot_start.origin)<0.0001,"Operator idle feet stable")
	state.grounded=false; state.vy=-6.0; operator.apply_actor(state); operator.advance(0.1)
	state.grounded=true; operator.apply_actor(state); operator.advance(0.25)
	check(absf(operator.locomotion.landing)<0.14,"Bounded hitch landing")
	operator.reset_pose(); check(operator.locomotion.landing==0 and operator.handling_weight==Vector3.ZERO,"Operator respawn reset")
	state.reloading=true; state.reloadTimer=0.5; state.reloadDuration=1.0
	operator.apply_actor(state); operator.advance(0.2)
	check(operator.handling_weight.x>0.9 and operator.grip_error.R<0.03,"Reload service keeps right-hand grip")
	operator.free()
	var operator_feet: Array[Vector3] = []
	var rate_paths: Array = []
	for fps: int in [30,60,144]:
		var visual := Operator.new(); visual.automatic_animation=false; root.add_child(visual)
		visual.configure({"id":1,"character":"claude","health":100,"weapon":0})
		var previous := Vector3.ZERO
		var maximum_jump := 0.0
		var path: Array[Vector3] = []
		for frame in fps*3:
			var section: int = frame/(fps/2)
			var moving := section in [1,2,3]
			var snapshot := {"id":1,"character":"claude","health":100,"weapon":0,"grounded":section!=3,"vy":-4.0,"vx":3.0 if section==2 else 0.0,"vz":-3.0 if moving and section!=2 else 0.0,"crouching":section==5,"ads":section>=4}
			visual.apply_actor(snapshot); visual.advance(1.0/fps)
			var current: Vector3 = visual.nodes.footL.global_position
			check(current.is_finite(),"Operator transition ankle finite")
			for side: String in ["L","R"]:
				var contact: Dictionary = visual.locomotion.contacts[side]
				check((contact.ankle as Vector3).distance_to(contact.hip)<=float(visual.rig.anatomy[side].length)+0.005,"Ankle remains inside measured authored leg reach")
				check(not contact.planted,"Coordinate-free no-floor fixture cannot fabricate support")
				check(visual.grip_error.has(side),"Transition grip sample exists")
				check(float(visual.grip_error[side])-float(visual.grip_clamp.get("clamped"+side,0))<=0.003,"Transition hand matches measured grip reach")
			if frame>0: maximum_jump=maxf(maximum_jump,current.distance_to(previous))
			previous=current
			if (frame+1)%(fps/2)==0: path.append(current)
		operator_feet.append(previous)
		rate_paths.append(path)
		print("OPERATOR_TRANSITION fps=",fps," maximum_adjacent_foot_metres=",maximum_jump)
		visual.free()
	# Compare the same six physical times, rather than imposing the discarded
	# shortened-stride implementation's 3.8 m/s swing-speed cap.
	for i in [1,2]:
		check(rate_paths[i].size()==6,"Six transition-time samples required")
		for sample in 6: check(rate_paths[i][sample].distance_to(rate_paths[0][sample])<0.03,"Transition ankle paths converge within 3 cm across render rates")
	for i in [1,2]: check(operator_feet[i].distance_to(operator_feet[0])<0.005,"Operator final terrain-foot rate invariance")
	var gesture := Gesture.new(); gesture.select("wave"); gesture.advance(0.9)
	var before: Dictionary = gesture.sample(); gesture.select("work")
	check(gesture.sample()==before,"Interrupted gesture exact pose continuity")
	# Native static surface sampling, including bounded ledges and missing floor.
	var body := StaticBody3D.new(); var collision := CollisionShape3D.new(); var box := BoxShape3D.new()
	box.size=Vector3(2,0.1,2); collision.shape=box; body.add_child(collision); body.position=Vector3(10,0.07,0)
	root.add_child(body)
	await physics_frame
	check(absf(Ground.offset(body,Vector3(10,0,0),0)-0.12)<0.001,"Terrain surface height")
	check(Ground.offset(body,Vector3(20,0,0),0)==0,"Missing terrain retains source plane")
	for model: String in Robot.IDS:
		var visual := Robot.new(); visual.automatic_animation=false; visual.automatic_lod=false
		root.add_child(visual); visual.position=Vector3(10,0.9,0)
		var snapshot := actor(model); snapshot.vx=0; snapshot.vz=0
		visual.configure(snapshot)
		for frame in 60: visual.advance(1.0/60)
		var rig: Dictionary = visual.rigs[0]
		for i in rig.legs.size():
			var endpoint: Vector3 = rig.knees[i].to_global(rig.ends[i])
			check(absf(endpoint.y-0.21)<0.002,"Articulated %s foot reaches sampled raised terrain"%model)
		check(visual.position==Vector3(10,0.9,0),"Terrain fitting never moves root")
		visual.free()
	var terrain_operator := Operator.new(); terrain_operator.automatic_animation=false; root.add_child(terrain_operator)
	terrain_operator.position=Vector3(20,0.9,0)
	terrain_operator.configure({"id":1,"character":"chatgpt","health":100,"grounded":true,"vx":0.0,"vz":0.0})
	for frame in 60: terrain_operator.advance(1.0/60)
	var flat_foot: float = terrain_operator.nodes.footL.global_position.y
	terrain_operator.position.x=10
	for frame in 60: terrain_operator.advance(1.0/60)
	check(absf(terrain_operator.nodes.footL.global_position.y-flat_foot-0.12)<0.003,"Operator ankle follows sampled terrain height")
	check(terrain_operator.position==Vector3(10,0.9,0),"Operator terrain fitting never moves root")
	terrain_operator.free()
	body.free()
	print("ACTOR_ANIMATION_OK checks=",checks," failures=",failures)
	quit(1 if failures else 0)
