extends SceneTree
## Review-lane diagnostic: dump batched multimesh instance transforms.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var map := "prism-foundry"
	var prefix := "warm"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): map = arg.trim_prefix("--map=")
		if arg.begins_with("--batch="): prefix = arg.trim_prefix("--batch=")
	var builder: Node3D = (load("res://native_arenas/maps/%s.gd" % map) as GDScript).new()
	root.add_child(builder)
	builder.build()
	await process_frame
	for node: Node in builder.find_children("*", "MultiMeshInstance3D", true, false):
		var mn := node as MultiMeshInstance3D
		if not String(mn.name).contains(prefix): continue
		print("DIAG ", mn.name, " count=", mn.multimesh.instance_count, " global=", mn.global_transform)
		for i in mini(8, mn.multimesh.instance_count):
			var t := mn.multimesh.get_instance_transform(i)
			print("   instance ", i, " origin=", t.origin, " basisScale=", t.basis.get_scale())
	quit(0)
