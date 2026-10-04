extends RefCounted
## New source-only fixtures. World-space vertices; every collider transform identity.
const GROUPS := ["inclined-landing-rejections","positive-step-admission"]
static func cases(group: String) -> Array:
	var result: Array = []
	for radius: float in [.35,.42]:
		for degrees: float in [-45.0,45.0]:
			result.append({"id":str(radius)+":"+str(degrees),"radius":radius,"yaw":deg_to_rad(degrees),
				"incline":47.0 if group==GROUPS[0] else 0.0,"start":-1.0,"goal":1.0,"maxResponses":240})
	return result

static func rotated(point: Vector3, yaw: float) -> Vector3:
	return Vector3(cos(yaw)*point.x+sin(yaw)*point.z,point.y,-sin(yaw)*point.x+cos(yaw)*point.z)

static func make(parent: Node, spec: Dictionary) -> Dictionary:
	var world := Node3D.new()
	parent.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20,1,20)
	floor_shape.shape = floor_box
	floor_shape.position.y = -.5
	floor_body.add_child(floor_shape)
	floor_body.name = "AdmissionBaseFloor"
	world.add_child(floor_body)
	var top := StaticBody3D.new()
	top.name = "InclinedLanding" if spec.incline>0.0 else "PositiveTread"
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	var back_y: float = .15+3.0*tan(deg_to_rad(float(spec.incline)))
	var a := rotated(Vector3(-2,.15,0),spec.yaw)
	var b := rotated(Vector3(-2,back_y,3),spec.yaw)
	var c := rotated(Vector3(2,back_y,3),spec.yaw)
	var d := rotated(Vector3(2,.15,0),spec.yaw)
	var faces := PackedVector3Array([a,b,c,a,c,d])
	shape.set_faces(faces)
	shape.backface_collision = true
	collision.shape = shape
	top.add_child(collision)
	world.add_child(top)
	return {"world":world,"top":top,"shape":shape,"faces":faces,"direction":rotated(Vector3(0,0,1),spec.yaw),
		"normal":(b-a).cross(c-a).normalized(),"start":rotated(Vector3(0,.05,spec.start),spec.yaw),
		"goal":rotated(Vector3(0,.15,spec.goal),spec.yaw),"topRid":top.get_rid(),"topShapeIndex":0}
