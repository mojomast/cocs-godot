extends SceneTree
const Stage = preload("res://tests/new_maps/gravemill_foundry/revision7/staged.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := Stage.make_world(root)
	var probes := Stage.read_json(Stage.DIR+"probes.json")
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var rays: Array = []
	for p: Dictionary in probes.rays:
		var o := Vector3(p.origin[0],p.origin[1],p.origin[2])
		var d := Vector3(p.direction[0],p.direction[1],p.direction[2])
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(o,o+d*float(p.max)))
		var distance: float = o.distance_to(hit.position) if not hit.is_empty() else float(p.max)
		assert(absf(distance-float(p.authority))<.04)
		rays.append({"id":p.id,"distance":distance,"expected":p.authority})
	var report := {"geometryHash":world.geometry_hash,"artHash":FileAccess.get_sha256(Stage.ART),"rays":rays,"godot":Engine.get_version_info(),"scope":"Eight fresh native targeted R7-stage rays; previous R5 capsule report remains prior same-geometry evidence, not rerun here"}
	var file := FileAccess.open(Stage.DIR+"rays-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	print("R7_NATIVE_RAYS ",rays.size())
	world.free()
	quit()
