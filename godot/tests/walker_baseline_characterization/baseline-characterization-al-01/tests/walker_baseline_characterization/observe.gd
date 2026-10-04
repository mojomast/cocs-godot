extends RefCounted
const Walker = preload("res://exploration/walker.gd")
## Only ordinary state and one downward observational support query per response.
static func encode(v: Variant) -> Variant:
	if v is Vector3: return [v.x,v.y,v.z]
	if v is Vector2: return [v.x,v.y]
	if v is RID: return v.get_id()
	if v is Transform3D: return {"origin":encode(v.origin),"basis":[encode(v.basis.x),encode(v.basis.y),encode(v.basis.z)]}
	if v is Dictionary:
		var d := {}
		for k: Variant in v: d[str(k)] = encode(v[k])
		return d
	if v is Array or v is PackedVector3Array:
		var a: Array = []
		for x: Variant in v: a.append(encode(x))
		return a
	return v
static func state(b: CharacterBody3D) -> Dictionary:
	return {"transform":b.global_transform,"velocity":b.velocity,"grounded":b.is_on_floor(),"floorNormal":b.get_floor_normal(),"onWall":b.is_on_wall(),"onCeiling":b.is_on_ceiling(),"platformVelocity":b.get_platform_velocity(),"platformAngularVelocity":b.get_platform_angular_velocity(),"slideCount":b.get_slide_collision_count(),"lastMotion":b.get_last_motion(),"parentDelta":b.get_position_delta(),"realVelocity":b.get_real_velocity(),"resetCount":b.get("reset_count")}
static func parameters(b: CharacterBody3D) -> Dictionary:
	var collider: CollisionShape3D = b.get_child(0);var shape: CapsuleShape3D = collider.shape
	var data: Dictionary = PhysicsServer3D.shape_get_data(shape.get_rid());var exceptions: Array = []
	for other: PhysicsBody3D in b.get_collision_exceptions(): exceptions.append(other.get_rid())
	return {"radius":data.radius,"height":data.height,"bodyRid":b.get_rid(),"shapeRid":shape.get_rid(),"offset":collider.transform,"margin":b.safe_margin,"snap":b.floor_snap_length,"floorAngle":b.floor_max_angle,"walk":Walker.WALK_SPEED,"sprint":Walker.SPRINT_SPEED,"gravity":Walker.GRAVITY,"jump":Walker.JUMP_SPEED,"layer":b.collision_layer,"mask":b.collision_mask,"up":b.up_direction,"motionMode":b.motion_mode,"maxSlides":b.max_slides,"wallMinSlideAngle":b.wall_min_slide_angle,"platformFloorLayers":b.platform_floor_layers,"platformWallLayers":b.platform_wall_layers,"platformOnLeave":b.platform_on_leave,"floorStopOnSlope":b.floor_stop_on_slope,"floorConstantSpeed":b.floor_constant_speed,"floorBlockOnWall":b.floor_block_on_wall,"slideOnCeiling":b.slide_on_ceiling,"exceptions":exceptions}
static func support(b: CharacterBody3D) -> Dictionary:
	var before := state(b);var p := PhysicsTestMotionParameters3D.new()
	p.from = b.global_transform;p.motion = -Vector3.UP*(b.safe_margin+.0001);p.margin = b.safe_margin;p.max_collisions = 32;p.recovery_as_collision = true;p.collide_separation_ray = true
	var result := PhysicsTestMotionResult3D.new();var hit := PhysicsServer3D.body_test_motion(b.get_rid(),p,result)
	var contacts: Array = []
	for i in result.get_collision_count():
		var object: Object = result.get_collider(i)
		contacts.append({"rid":result.get_collider_rid(i),"path":str(object.get_path()) if object is Node else "","shape":result.get_collider_shape(i),"localShape":result.get_collision_local_shape(i),"point":result.get_collision_point(i),"normal":result.get_collision_normal(i),"velocity":result.get_collider_velocity(i),"depth":result.get_collision_depth(i)})
	return {"before":before,"after":state(b),"bodyRid":b.get_rid(),"from":p.from,"motion":p.motion,"margin":p.margin,"maxCollisions":p.max_collisions,"recoveryAsCollision":p.recovery_as_collision,"collideSeparationRay":p.collide_separation_ray,"excludeBodies":p.exclude_bodies,"excludeObjects":p.exclude_objects,"hit":hit,"safeFraction":result.get_collision_safe_fraction(),"unsafeFraction":result.get_collision_unsafe_fraction(),"travel":result.get_travel(),"remainder":result.get_remainder(),"count":result.get_collision_count(),"contacts":contacts}
static func slides(b: CharacterBody3D) -> Array:
	var rows: Array = []
	for i in b.get_slide_collision_count():
		var hit := b.get_slide_collision(i)
		for j in hit.get_collision_count():
			var object: Object = hit.get_collider(j)
			var local: Object = hit.get_local_shape(j)
			rows.append({"slideIndex":i,"contactIndex":j,"rid":hit.get_collider_rid(j),"path":str(object.get_path()) if object is Node else "","shape":hit.get_collider_shape_index(j),"localShape":0 if local==b.get_child(0) else -1,"point":hit.get_position(j),"normal":hit.get_normal(j),"velocity":hit.get_collider_velocity(j),"depth":hit.get_depth(),"travel":hit.get_travel(),"remainder":hit.get_remainder()})
	return rows
