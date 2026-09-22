extends SceneTree
## Verifies the exported source third-person weapon catalog: file provenance,
## imported triangle/draw counts, actual chassis-derived grip anchors and bounds.
const WorldWeapons = preload("res://source_operators/generated/world_weapons/catalog.gd")
var failures: Array[String] = []
var max_anchor_error: float = 0.0
var max_bounds_error: float = 0.0
var checked: int = 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr(message)

func sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()

func run() -> void:
	var base_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for weapon: Dictionary in WorldWeapons.WEAPONS:
		var path: String = "res://source_operators/generated/world_weapons/" + str(weapon.file)
		check(ResourceLoader.exists(path),"%s exists" % path)
		if not ResourceLoader.exists(path): continue
		check(sha256(FileAccess.get_file_as_bytes(path)) == str(weapon.sha256),str(weapon.name)+" source provenance sha256")
		var packed: PackedScene = load(path)
		check(packed != null,str(weapon.name)+" imports")
		if packed == null: continue
		var instance: Node3D = packed.instantiate()
		var meshes: Array[MeshInstance3D] = []
		var stack: Array[Node] = [instance]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is MeshInstance3D: meshes.append(node)
			for child: Node in node.get_children(): stack.append(child)
		var triangles: int = 0
		for mesh: MeshInstance3D in meshes:
			check(mesh.mesh.get_surface_count() == 1,str(weapon.name)+" one material surface per batch")
			for surface: int in range(mesh.mesh.get_surface_count()):
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				triangles += int(arrays[Mesh.ARRAY_INDEX].size()/3)
		check(triangles == int(weapon.triangles),"%s source triangles %d != %d" % [weapon.name,triangles,int(weapon.triangles)])
		check(meshes.size() == int(weapon.draws),"%s material batches %d != %d" % [weapon.name,meshes.size(),int(weapon.draws)])
		for anchor_name: String in weapon.anchors:
			var node: Node3D = instance.find_child(anchor_name,true,false) as Node3D
			check(node != null,"%s %s anchor exists" % [weapon.name,anchor_name])
			if node == null: continue
			var expected: Array = weapon.anchors[anchor_name]
			var error: float = node.position.distance_to(Vector3(expected[0],expected[1],expected[2]))
			max_anchor_error = maxf(max_anchor_error,error)
			check(error < 0.000001,"%s %s chassis anchor %.8f" % [weapon.name,anchor_name,error])
		var bounds := AABB()
		var first: bool = true
		for mesh: MeshInstance3D in meshes:
			var box: AABB = mesh.transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var expected_min: Array = weapon.bounds[0]
		var expected_max: Array = weapon.bounds[1]
		var error: float = maxf(bounds.position.distance_to(Vector3(expected_min[0],expected_min[1],expected_min[2])),bounds.end.distance_to(Vector3(expected_max[0],expected_max[1],expected_max[2])))
		max_bounds_error = maxf(max_bounds_error,error)
		check(error < 0.0001,"%s source bounds %.8f" % [weapon.name,error])
		instance.free()
		checked += 1
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == base_nodes,"Weapon catalog releases all imported nodes")
	var report: Dictionary = {"passed":failures.is_empty(),"weapons":checked,"maximumAnchorError":max_anchor_error,"maximumBoundsError":max_bounds_error,"failures":failures}
	var evidence: String = OS.get_environment("OPERATOR_EVIDENCE")
	if not evidence.is_empty():
		FileAccess.open(evidence.path_join("weapons.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
