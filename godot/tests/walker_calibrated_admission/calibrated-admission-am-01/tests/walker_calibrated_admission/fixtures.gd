extends RefCounted
## New positive geometry only. Original inclined geometry executes unchanged.
const Original = preload("res://tests/walker_admission/fixtures_v4.gd")
static func cases(group: String) -> Array:
	var rows := Original.cases(group)
	if group=="positive-step-admission":
		for spec: Dictionary in rows: spec.rise = .15 if spec.radius==.35 else .18
	return rows
static func make(parent: Node,spec: Dictionary) -> Dictionary:
	if spec.incline>0: return Original.make(parent,spec)
	var world := Node3D.new();parent.add_child(world)
	var floor_body := StaticBody3D.new();var floor_shape := CollisionShape3D.new();var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20,1,20);floor_shape.shape = floor_box;floor_shape.position.y = -.5
	floor_body.add_child(floor_shape);floor_body.name = "AdmissionBaseFloor";world.add_child(floor_body)
	var top := StaticBody3D.new();top.name = "PositiveTread"
	var collision := CollisionShape3D.new();var shape := ConcavePolygonShape3D.new()
	var a := Original.rotated(Vector3(-2,spec.rise,0),spec.yaw)
	var b := Original.rotated(Vector3(-2,spec.rise,3),spec.yaw)
	var c := Original.rotated(Vector3(2,spec.rise,3),spec.yaw)
	var d := Original.rotated(Vector3(2,spec.rise,0),spec.yaw)
	var faces := PackedVector3Array([a,b,c,a,c,d]);shape.set_faces(faces);shape.backface_collision = true
	collision.shape = shape;top.add_child(collision);world.add_child(top)
	return {"world":world,"top":top,"shape":shape,"faces":faces,"direction":Original.rotated(Vector3(0,0,1),spec.yaw),"normal":(b-a).cross(c-a).normalized(),"start":Original.rotated(Vector3(0,.05,spec.start),spec.yaw),"goal":Original.rotated(Vector3(0,spec.rise,spec.goal),spec.yaw),"topRid":top.get_rid(),"topShapeIndex":0}
