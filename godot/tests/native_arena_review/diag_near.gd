extends SceneTree
## Review-lane diagnostic: list visual AABBs and collider AABBs near a point.
## Usage: godot --headless --path godot --script res://tests/native_arena_review/diag_near.gd -- --map=prism-foundry --x=-18 --y=3.6 --z=-12.5 --r=6
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var opts := {"map": "prism-foundry", "x": 0.0, "y": 0.0, "z": 0.0, "r": 5.0}
	for arg: String in args:
		for key: String in opts.keys():
			if arg.begins_with("--%s=" % key): opts[key] = float(arg.trim_prefix("--%s=" % key)) if key != "map" else arg.trim_prefix("--%s=" % key)
	var point := Vector3(opts.x, opts.y, opts.z)
	var builder: Node3D = (load("res://native_arenas/maps/%s.gd" % opts.map) as GDScript).new()
	root.add_child(builder)
	builder.build()
	print("DIAG VISUALS near ", point)
	for node: Node in builder.find_children("*", "VisualInstance3D", true, false):
		if node is MultiMeshInstance3D:
			var mn := node as MultiMeshInstance3D
			if mn.multimesh == null or mn.multimesh.mesh == null: continue
			var unit: AABB = mn.multimesh.mesh.get_aabb()
			for i in mn.multimesh.instance_count:
				var xform: Transform3D = mn.global_transform * mn.multimesh.get_instance_transform(i)
				var c: Vector3 = xform * unit.get_center()
				if c.distance_to(point) <= opts.r:
					print("  VIS multimesh ", mn.name, "#", i, " center=", c, " aabbSize=", (unit.size * xform.basis.get_scale().abs()))
		elif node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh == null: continue
			var c2: Vector3 = mi.global_transform * mi.mesh.get_aabb().get_center()
			if c2.distance_to(point) <= opts.r:
				print("  VIS mesh ", mi.name, " center=", c2, " size=", mi.mesh.get_aabb().size, " visible=", mi.is_visible_in_tree())
	print("DIAG SHAPES near ", point)
	for node: Node in builder.find_children("*", "CollisionShape3D", true, false):
		var cs := node as CollisionShape3D
		if cs.shape == null: continue
		var c3: Vector3 = cs.global_transform.origin
		if c3.distance_to(point) <= opts.r:
			var info := ""
			if cs.shape is BoxShape3D: info = "size=%s" % (cs.shape as BoxShape3D).size
			print("  SHAPE ", cs.shape.get_class(), " at ", c3, " ", info, " parent=", cs.get_parent().name)
	quit(0)
