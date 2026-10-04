extends RefCounted
## Actual static native collider fixtures; no canned PhysicsServer results.
static func cases() -> Array:
	return ["ceiling-up","overhang-forward","height-025","height-030","height-031","height-guard",
		"narrow-width","narrow-depth","hole","pit","lateral","no-input","airborne","jumping","tilted-body","transformed-parent","moving-floor"]

static func box(world: Node3D, at: Vector3, size: Vector3, label: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body

static func rectangle(x0: float,x1: float,z0: float,z1: float,y: float) -> PackedVector3Array:
	var a := Vector3(x0,y,z0)
	var b := Vector3(x0,y,z1)
	var c := Vector3(x1,y,z1)
	var d := Vector3(x1,y,z0)
	return PackedVector3Array([a,b,c,a,c,d])

static func scene(id: String) -> Dictionary:
	var world := Node3D.new()
	var floor_body := box(world,Vector3(0,-.5,0),Vector3(20,1,20),"ControlFloor")
	var h := .15
	if id=="height-025": h = .25
	if id=="height-030": h = .3
	if id=="height-031": h = .31
	if id=="height-guard": h = .24995
	if id=="pit":
		floor_body.position.z = -5.1
		(floor_body.get_child(0).shape as BoxShape3D).size.z = 10.0
	else:
		var width := .2 if id=="narrow-width" else 4.0
		var depth := .12 if id=="narrow-depth" else .5
		if id=="hole":
			var body := StaticBody3D.new()
			body.name = "HoledTread"
			var collision := CollisionShape3D.new()
			var shape := ConcavePolygonShape3D.new()
			var faces := rectangle(-2,2,0,.1,h)
			faces.append_array(rectangle(-2,2,.3,.5,h))
			faces.append_array(rectangle(-2,-.1,.1,.3,h))
			faces.append_array(rectangle(.1,2,.1,.3,h))
			shape.set_faces(faces)
			shape.backface_collision = true
			collision.shape = shape
			body.add_child(collision)
			world.add_child(body)
		else: box(world,Vector3(0,h*.5,depth*.5),Vector3(width,h,depth),"ControlTread")
	if id=="ceiling-up": box(world,Vector3(0,1.95,-1.05),Vector3(4,.1,1.9),"LowCeiling")
	if id=="overhang-forward": box(world,Vector3(0,1.83,.56),Vector3(4,.1,.88),"ForwardOverhang")
	if id=="moving-floor": floor_body.constant_linear_velocity = Vector3(.1,0,0)
	var reasons: Array = ["not_low_riser_band","strict_surface_rise_limit"]
	match id:
		"ceiling-up": reasons = ["up_blocked_or_lateral_recovery"]
		"overhang-forward": reasons = ["raised_path_blocked"]
		"narrow-width","narrow-depth": reasons = ["unsupported_or_narrow_landing"]
		"hole": reasons = ["no_continuous_flat_landing"]
		"pit": reasons = ["no_bounded_riser","no_flat_static_base_support"]
		"lateral": reasons = ["lateral_wall_or_corner","multiple_obstacles"]
		"no-input": reasons = ["no_input"]
		"airborne","jumping": reasons = ["not_stationary_grounded_intent"]
		"tilted-body": reasons = ["non_yaw_rotation"]
		"transformed-parent": reasons = ["transformed_parent"]
		"moving-floor": reasons = ["moving_platform","no_flat_static_base_support"]
	return {"world":world,"reasons":reasons}
