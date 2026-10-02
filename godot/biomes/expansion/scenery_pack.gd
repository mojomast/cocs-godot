extends Node3D
## Explicit additive architecture. Existing frames, facade collision, landmarks,
## workshop controls and material resources retain their original ownership.
const CATALOG := "res://biomes/expansion/catalog.json"
const ART := "res://biomes/expansion/art/"
var loaded_assets: Array[String] = []
var reduced := false
var recipe_hash := ""

func clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	loaded_assets.clear()
	recipe_hash = ""

func build(host: Node3D, require_assets := false) -> bool:
	clear()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var id := str(host.recipe.id)
	if not catalog.chapters.has(id): return false
	var chapter: Dictionary = catalog.chapters[id]
	if str(host.recipe.geometryHash) != str(chapter.geometryHash) or FileAccess.get_sha256("res://campaign/generated/" + id + ".json") != str(chapter.recipeSha256):
		push_error("Biome4 requires reviewed chapter bounds: " + id)
		return false
	# Atomic chapter load: never publish one LOD or half an architectural group.
	for placement: Dictionary in chapter.placements:
		for lod: int in 2:
			if not ResourceLoader.exists(ART + str(placement.asset) + "-%d.glb" % lod):
				if require_assets: push_error("Biome4 asset has not been built: " + str(placement.asset))
				return false
	var pending: Array[Node3D] = []
	for placement: Dictionary in chapter.placements:
		for lod: int in 2:
			var scene: PackedScene = load(ART + str(placement.asset) + "-%d.glb" % lod)
			var instance: Node3D = scene.instantiate()
			if not visual_only(instance):
				instance.free()
				for other: Node3D in pending: other.free()
				push_error("Biome4 export contains collision")
				return false
			instance.name = str(placement.asset) + "_LOD%d" % lod
			instance.set_meta("biome4_lod", lod)
			instance.set_meta("reviewed_block", str(placement.block))
			instance.position = vector(placement.origin)
			instance.scale = vector(placement.scale)
			pending.append(instance)
		loaded_assets.append(str(placement.asset))
	for instance: Node3D in pending: add_child(instance)
	recipe_hash = str(catalog.recipeSha256)
	set_reduced_detail(reduced)
	return true

static func vector(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

static func visual_only(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D: return false
	for child: Node in node.get_children():
		if not visual_only(child): return false
	return true

func set_reduced_detail(value: bool) -> void:
	reduced = value
	for child: Node3D in get_children():
		var lod := int(child.get_meta("biome4_lod"))
		child.visible = not reduced or lod == 1
		set_ranges(child, lod)

func set_ranges(node: Node, lod: int) -> void:
	if node is GeometryInstance3D:
		node.visibility_range_begin = 85.0 if lod == 1 and not reduced else 0.0
		node.visibility_range_end = 85.0 if lod == 0 else 0.0
	for child: Node in node.get_children(): set_ranges(child, lod)
