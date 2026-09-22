extends SceneTree
const Manager = preload("res://combat_particles/manager.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	var failed := false
	for id: String in ["cinder-array", "aurora-basin"]:
		var script: GDScript = load("res://%s/map.gd" % id.replace("-", "_"))
		var map: Node3D = script.new()
		root.add_child(map)
		map.build()
		var manager := Manager.new()
		root.add_child(manager)
		if manager._native_collision_root(root, id) != map:
			failed = true
			push_error("Native string-ID discovery must select map subtree, not whole session")
		var result: Dictionary = manager.configure(camera, {"id": id, "bounds": manager._native_bounds(id), "collision_root": map})
		if not result.ok or result.collision_shapes < 20 or result.solid_cells < 20 or result.unsupported_collision_shapes != 0 or manager.budget != 131072:
			failed = true
			push_error("Native collision/High budget contract: " + str(result))
		manager.set_active(true, false)
		if manager.snapshot().active_emitters != 4:
			failed = true
			push_error("Offline native weather activation")
		print("COMBAT_PARTICLES_NATIVE ", JSON.stringify(manager.snapshot()))
		manager.reset()
		manager.free()
		map.free()
	camera.free()
	quit(1 if failed else 0)
