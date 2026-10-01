extends Node3D
## Non-colliding Blender facades fitted entirely inside authoritative recipe blocks.
const PATH := "res://campaign/art/structures/"
const CELL := 48.0
var placements := 0
var batches := 0
var _sources: Dictionary = {}

static func style_for(map_index: int, id: String) -> String:
	if map_index == 0: return "relay" if id.contains("Fallen relay") or id.contains("gate") else "outpost"
	if map_index == 1: return "abutment" if id.begins_with("bridgeworks") else "pump"
	if map_index == 2: return "uplink" if id.begins_with("basalt") else "refinery"
	return "receiver" if id.begins_with("crown") else "gate"

func build(host: Node3D) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	placements = 0
	batches = 0
	var groups: Dictionary = {}
	for block: Dictionary in host.recipe.arena.blocks:
		if block.material == "rock": continue
		var style := style_for(int(host.recipe.campaign.index), str(block.id))
		var ground: float = host.height_at(float(block.x), float(block.z))
		var exposed := minf(float(block.h) - float(block.baseY), maxf(1.0, float(block.h) - ground + 0.35))
		var segments := maxi(1, ceili(exposed / 5.0))
		for segment: int in segments:
			var y0: float = float(block.h) - exposed + exposed * segment / segments
			var height: float = exposed / segments
			var at := Vector3(float(block.x), y0, float(block.z))
			var scale := Vector3(float(block.w), height, float(block.d))
			var cell := Vector2i(floori(at.x / CELL), floori(at.z / CELL))
			for lod: int in 2:
				var key := "%s/%d/%d/%d" % [style, lod, cell.x, cell.y]
				if not groups.has(key): groups[key] = {"style":style, "lod":lod, "origin":Vector3(cell.x*CELL, 0, cell.y*CELL), "transforms":[]}
				groups[key].transforms.append(Transform3D(Basis.from_scale(scale), at - groups[key].origin))
			placements += 1
	for group: Dictionary in groups.values():
		_batch(group)

func _batch(group: Dictionary) -> void:
	var source_key := "%s-%d" % [group.style, group.lod]
	if not _sources.has(source_key):
		var scene: PackedScene = load(PATH + source_key + ".glb")
		var instance := scene.instantiate()
		var meshes: Array = []
		_collect_meshes(instance, Transform3D.IDENTITY, meshes)
		_sources[source_key] = meshes
		instance.free()
	for part: Dictionary in _sources[source_key]:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = part.mesh
		multi.instance_count = group.transforms.size()
		var bounds := AABB()
		for i: int in group.transforms.size():
			var transform: Transform3D = group.transforms[i] * part.transform
			multi.set_instance_transform(i, transform)
			var box: AABB = transform * part.mesh.get_aabb()
			bounds = box if i == 0 else bounds.merge(box)
		multi.custom_aabb = bounds.grow(0.05)
		var node := MultiMeshInstance3D.new()
		node.name = "Structure_%s_LOD%d" % [group.style, group.lod]
		node.position = group.origin
		node.multimesh = multi
		if int(group.lod) == 0:
			node.visibility_range_end = 100.0
			node.visibility_range_end_margin = 12.0
		else:
			node.visibility_range_begin = 100.0
			node.visibility_range_begin_margin = 12.0
		add_child(node)
		batches += 1

func _collect_meshes(node: Node, transform: Transform3D, result: Array) -> void:
	if node is Node3D: transform = transform * node.transform
	if node is MeshInstance3D:
		result.append({"mesh":node.mesh, "transform":transform})
	for child: Node in node.get_children(): _collect_meshes(child, transform, result)
