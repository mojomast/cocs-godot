extends SceneTree
## Verifies the exported source third-person weapon catalog: file provenance,
## imported triangle/draw counts, the shared six-channel detail kit, the pinned
## pre-detail grip anchors and bounds.
##
## `PINNED_ANCHORS` below are the chassis-derived fallback coordinates from the
## pre-detail export (`godot/source_operators/generated/world_weapons/manifest.json`
## at commit 84dbae73, preserved in
## `port/native-weapon-detail-world/anchors-before.json`). They are the values
## `HandGrips.align` was accepted against, so detail must keep them within the
## lane's 1e-4 contract; the fixture comparison in grips.gd proves the solved
## contacts.
const WorldWeapons = preload("res://source_operators/generated/world_weapons/catalog.gd")
const PINNED_ANCHORS: Array = [
	{"Muzzle":[0.0,0.01,-0.85],"WeaponGripLeft":[-0.11000000000000001,-0.09000000000000001,-0.22559999999999997],"WeaponGripRight":[0.0,-0.15500000000000003,-0.035]},
	{"Muzzle":[0.0,0.0,-0.76],"WeaponGripLeft":[-0.155,-0.13,-0.264],"WeaponGripRight":[0.0,-0.195,-0.035]},
	{"Muzzle":[0.0,0.025,-1.04],"WeaponGripLeft":[-0.11499999999999999,-0.07,-0.26880000000000004],"WeaponGripRight":[0.0,-0.135,-0.035]},
	{"Muzzle":[0.0,0.03,-0.82],"WeaponGripLeft":[-0.185,-0.06,-0.20159999999999997],"WeaponGripRight":[0.0,-0.125,-0.035]},
	{"Muzzle":[0.0,0.0,-0.77],"WeaponGripLeft":[-0.135,-0.115,-0.2208],"WeaponGripRight":[0.0,-0.18,-0.035]},
	{"Muzzle":[0.0,0.04,-0.93],"WeaponGripLeft":[-0.14,-0.07,-0.2064],"WeaponGripRight":[0.0,-0.135,-0.035]},
	{"Muzzle":[0.0,0.0,-0.99],"WeaponGripLeft":[-0.13,-0.105,-0.24],"WeaponGripRight":[0.0,-0.16999999999999998,-0.035]},
	{"Muzzle":[0.0,0.0,-0.99],"WeaponGripLeft":[-0.16,-0.125,-0.2448],"WeaponGripRight":[0.0,-0.19,-0.035]},
	{"Muzzle":[0.0,0.02,-0.84],"WeaponGripLeft":[-0.1,-0.06999999999999999,-0.2592],"WeaponGripRight":[0.0,-0.135,-0.035]},
	{"Muzzle":[0.0,0.05,-0.835],"WeaponGripLeft":[-0.10500000000000001,-0.045,-0.16799999999999998],"WeaponGripRight":[0.0,-0.11,-0.035]},
]
const MIN_TRIANGLES := 1200
const MAX_TRIANGLES := 2500
const MAX_BATCHES := 4
const CHANNELS: Array = ["receiver","feed","muzzle","stock","sight","accent"]
const ZONES: Array = ["mount","sight","ejection","feed","heat","muzzle","stock","grip","signature"]
var failures: Array[String] = []
var max_anchor_error: float = 0.0
var max_pinned_anchor_error: float = 0.0
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
	var identities: Dictionary = {}
	var detail_triangles: int = 0
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
		check(triangles >= MIN_TRIANGLES and triangles <= MAX_TRIANGLES,"%s detail triangle budget %d outside [%d,%d]" % [weapon.name,triangles,MIN_TRIANGLES,MAX_TRIANGLES])
		check(meshes.size() == int(weapon.draws),"%s material batches %d != %d" % [weapon.name,meshes.size(),int(weapon.draws)])
		check(meshes.size() >= 3 and meshes.size() <= MAX_BATCHES,"%s batch budget %d outside [3,%d]" % [weapon.name,meshes.size(),MAX_BATCHES])
		# Shared six-channel identity: every channel answered, every weapon distinct.
		check(weapon.has("detail"),str(weapon.name)+" carries detail metadata")
		var detail: Dictionary = weapon.get("detail",{})
		var identity: Dictionary = detail.get("identity",{})
		var signature: PackedStringArray = PackedStringArray()
		for channel: String in CHANNELS:
			check(identity.has(channel) and not str(identity[channel]).is_empty(),"%s identity channel %s present" % [weapon.name,channel])
			signature.append(str(identity.get(channel,"")))
		check(not str(identity.get("signature","")).is_empty(),str(weapon.name)+" signature greeble motif present")
		check(signature.size() == CHANNELS.size() and not identities.has(signature) if signature.size() == CHANNELS.size() else false,"%s identity is unique across the ten weapons" % weapon.name)
		identities[signature] = weapon.name
		var zones: Dictionary = detail.get("zones",{})
		var zone_total: int = 0
		for zone: String in ZONES:
			check(int(zones.get(zone,0)) > 0,"%s detail zone %s carries geometry" % [weapon.name,zone])
			zone_total += int(zones.get(zone,0))
		check(zone_total == int(detail.get("triangles",-1)),"%s detail zone sum %d != %d" % [weapon.name,zone_total,int(detail.get("triangles",-1))])
		detail_triangles += int(detail.get("triangles",0))
		for anchor_name: String in weapon.anchors:
			var node: Node3D = instance.find_child(anchor_name,true,false) as Node3D
			check(node != null,"%s %s anchor exists" % [weapon.name,anchor_name])
			if node == null: continue
			var expected: Array = weapon.anchors[anchor_name]
			var error: float = node.position.distance_to(Vector3(expected[0],expected[1],expected[2]))
			max_anchor_error = maxf(max_anchor_error,error)
			check(error < 0.000001,"%s %s chassis anchor %.8f" % [weapon.name,anchor_name,error])
			var pinned: Array = PINNED_ANCHORS[int(weapon.id)][anchor_name]
			var pinned_error: float = node.position.distance_to(Vector3(pinned[0],pinned[1],pinned[2]))
			max_pinned_anchor_error = maxf(max_pinned_anchor_error,pinned_error)
			check(pinned_error < 0.0001,"%s %s moved %.8f from the pre-detail contact" % [weapon.name,anchor_name,pinned_error])
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
	check(identities.size() == 10,"All ten weapon identities are distinct")
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == base_nodes,"Weapon catalog releases all imported nodes")
	var report: Dictionary = {"passed":failures.is_empty(),"weapons":checked,"detailTriangles":detail_triangles,"maximumAnchorError":max_anchor_error,"maximumPinnedAnchorDrift":max_pinned_anchor_error,"maximumBoundsError":max_bounds_error,"failures":failures}
	var evidence: String = OS.get_environment("OPERATOR_EVIDENCE")
	if not evidence.is_empty():
		FileAccess.open(evidence.path_join("weapons.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
