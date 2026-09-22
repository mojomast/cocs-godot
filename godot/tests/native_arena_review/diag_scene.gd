extends SceneTree
## Review-lane diagnostic: dump map scene children and the nearest visual to a point.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var map := "prism-foundry"
	var point := Vector3(-18, 3.6, -12.5)
	for arg: String in args:
		if arg.begins_with("--map="): map = arg.trim_prefix("--map=")
		if arg.begins_with("--x="): point.x = float(arg.trim_prefix("--x="))
		if arg.begins_with("--y="): point.y = float(arg.trim_prefix("--y="))
		if arg.begins_with("--z="): point.z = float(arg.trim_prefix("--z="))
	var builder: Node3D = (load("res://native_arenas/maps/%s.gd" % map) as GDScript).new()
	root.add_child(builder)
	builder.build()
	await process_frame
	print("DIAG children of ", builder.name)
	for child: Node in builder.get_children():
		var extra := ""
		if child is MultiMeshInstance3D:
			var mm := (child as MultiMeshInstance3D).multimesh
			extra = " instances=%d totalChildren=%d" % [mm.instance_count if mm else -1, child.get_child_count()]
		print("  ", child.get_class(), " ", child.name, extra, " visible=", (child as CanvasItem).visible if child is CanvasItem else "")
	var best := {}
	var visuals := builder.find_children("*", "VisualInstance3D", true, false)
	print("DIAG visual count ", visuals.size())
	for node: Node in visuals:
		var center := Vector3.INF
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			center = node.global_transform * (node as MeshInstance3D).mesh.get_aabb().get_center()
		elif node is MultiMeshInstance3D:
			var mn := node as MultiMeshInstance3D
			if mn.multimesh == null or mn.multimesh.mesh == null: continue
			var best_d := INF
			for i in mn.multimesh.instance_count:
				var c: Vector3 = (mn.global_transform * mn.multimesh.get_instance_transform(i)) * mn.multimesh.mesh.get_aabb().get_center()
				if c.distance_to(point) < best_d: best_d = c.distance_to(point)
			center = Vector3(best_d, 0, 0)
		if node is MultiMeshInstance3D:
			print("  MULTIMESH ", node.name, " nearestInstanceDist=", center.x)
		elif center.distance_to(point) < 40.0:
			print("  MESH ", node.name, " dist=", "%.2f" % center.distance_to(point))
	quit(0)
