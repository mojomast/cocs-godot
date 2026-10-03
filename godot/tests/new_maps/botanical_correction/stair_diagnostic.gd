extends SceneTree
## Additive failure investigation; never upgrades a failed physics receipt.
var stage: Script
var directory: String

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): directory = arg.trim_prefix("--stage=")
	assert(directory.begins_with("res://tests/new_maps/botanical_correction/"))
	stage = load(directory + "staged.gd")
	call_deferred("run")
	create_timer(110).timeout.connect(func() -> void: quit(2))

func run() -> void:
	var id: String = stage.map_id()
	assert(id == "vesper-viaduct")
	var receipt: Dictionary = stage.manifest(id)
	var probes: Dictionary = stage.read_json(directory + "probes.json")
	var failure: Dictionary = stage.read_json(directory + "physics-report.json")
	var failed := {}
	for error: Dictionary in failure.errors: failed[error.id] = true
	var capsule := CapsuleShape3D.new()
	capsule.radius = .41
	capsule.height = 1.7
	var records: Array = []
	for candidate: bool in [false, true]:
		var holder := Node3D.new()
		root.add_child(holder)
		var world: Node3D = stage.make_world(holder, id, candidate)
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		for p: Dictionary in probes.points:
			if not failed.has(p.id): continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.collision_mask = 1
			query.transform = Transform3D(Basis.IDENTITY, Vector3(p.x,p.y+.9,p.z))
			var contacts: Array = []
			for hit: Dictionary in space.intersect_shape(query, 32): contacts.append(str(hit.collider.name))
			records.append({"id":p.id,"candidate":candidate,"foot":[p.x,p.y,p.z],"contacts":contacts})
		holder.queue_free()
		await process_frame
	var path := directory + "stair-diagnostic.json"
	assert(not FileAccess.file_exists(path))
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"manifestSha256":FileAccess.get_sha256(directory+"manifest.json"),"glbSha256":receipt.glbSha256,"records":records,"scope":"unchanged-position accepted/candidate static overlap comparison; no waiver, height lift or controller traversal claim"},"\t")+"\n")
	file.close()
	quit(0)
