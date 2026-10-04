extends RefCounted
## Dedicated rise-derived, world-baked geometry. No original fixture edits.
static func cases() -> Array:
	var rows: Array = []
	for pair: Array in [[.35,.15],[.42,.15],[.42,.18],[.42,.20]]:
		for yaw: float in [-45.0,45.0]: rows.append({"radius":pair[0],"rise":pair[1],"yawDegrees":yaw})
	return rows
static func direction(s: Dictionary) -> Vector3:
	return Vector3(sin(deg_to_rad(s.yawDegrees)),0,cos(deg_to_rad(s.yawDegrees)))
static func vertices(s: Dictionary) -> PackedVector3Array:
	var d := direction(s);var right := Vector3(d.z,0,-d.x)
	var a := right*-2.0+Vector3.UP*float(s.rise)
	var b := a+d*3.0;var c := right*2.0+Vector3.UP*float(s.rise)+d*3.0;var e := right*2.0+Vector3.UP*float(s.rise)
	return PackedVector3Array([a,b,c,a,c,e])
static func make(parent: Node, s: Dictionary) -> Dictionary:
	var world := Node3D.new();parent.add_child(world)
	var base := StaticBody3D.new();base.name = "BaselineBase";world.add_child(base)
	var box := BoxShape3D.new();box.size = Vector3(20,1,20)
	var floor_shape := CollisionShape3D.new();floor_shape.shape = box;floor_shape.position.y = -.5;base.add_child(floor_shape)
	var top := StaticBody3D.new();top.name = "BaselineTarget";world.add_child(top)
	var mesh := ConcavePolygonShape3D.new();mesh.set_faces(vertices(s));mesh.backface_collision = true
	var top_shape := CollisionShape3D.new();top_shape.shape = mesh;top.add_child(top_shape)
	return {"world":world,"base":base,"target":top}
static func certificate(f: Dictionary) -> Dictionary:
	var result := {}
	for role: String in ["base","target"]:
		var body: StaticBody3D = f[role];var collider: CollisionShape3D = body.get_child(0);var shape: Shape3D = collider.shape
		var row := {"rid":body.get_rid(),"shapeRid":shape.get_rid(),"shape":0,"path":str(body.get_path()),"type":shape.get_class(),"transform":body.global_transform,"offset":collider.transform,"layer":body.collision_layer,"mask":body.collision_mask,"velocity":body.constant_linear_velocity,"angularVelocity":body.constant_angular_velocity}
		if role=="base": row.size = (shape as BoxShape3D).size
		else:
			var mesh := shape as ConcavePolygonShape3D;var faces := mesh.get_faces();var bounds := AABB(faces[0],Vector3.ZERO)
			for point: Vector3 in faces: bounds = bounds.expand(point)
			row.faces = faces;row.backface = mesh.backface_collision;row.plane = faces[0].y;row.aabb = {"position":bounds.position,"size":bounds.size}
		result[role] = row
	return result
