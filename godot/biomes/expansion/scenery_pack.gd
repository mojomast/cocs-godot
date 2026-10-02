extends Node3D
## Additive visuals only. Never mutates host geometry, collision or materials.
const CATALOG := "res://biomes/expansion/catalog.json"
const ART := "res://biomes/expansion/art/"
var loaded_assets: Array[String] = []
var reduced := false
var recipe_hash := ""
var last_build := {"status":"empty", "code":"cleared", "path":""}
var _installed: Array[Node3D] = []

func clear() -> void:
	for child: Node3D in _installed:
		if is_instance_valid(child):
			if child.get_parent() == self: remove_child(child)
			child.free()
	_installed.clear()
	loaded_assets.clear()
	recipe_hash = ""
	last_build = {"status":"empty", "code":"cleared", "path":""}

func _fail(pending: Array[Node3D], required: bool, code: String, path: String) -> bool:
	for instance: Node3D in pending:
		if is_instance_valid(instance): instance.free()
	last_build = {"status":"failed" if required else "fallback", "code":code, "path":path}
	if required: _report_failure(code, path)
	return false

func _report_failure(code: String, path: String) -> void:
	push_error("Biome4 " + code + ": " + path)

# Narrow overrides let the grant-only lifecycle fixture inject invalid resources.
func _exists(path: String) -> bool: return ResourceLoader.exists(path)
func _load(path: String) -> Resource: return ResourceLoader.load(path)

func build(host: Node3D, require_assets := false) -> bool:
	clear()
	var pending: Array[Node3D] = []
	var selected: Array[String] = []
	if not FileAccess.file_exists(CATALOG): return _fail(pending, require_assets, "missing_catalog", CATALOG)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not parsed is Dictionary or not parsed.get("chapters") is Dictionary:
		return _fail(pending, require_assets, "invalid_catalog", CATALOG)
	var catalog: Dictionary = parsed
	if str(catalog.get("recipeSha256", "")).length() != 64: return _fail(pending, require_assets, "invalid_recipe_hash", CATALOG)
	var recipe: Variant = host.get("recipe")
	if not recipe is Dictionary: return _fail(pending, require_assets, "invalid_host_recipe", "host")
	var id := str(recipe.get("id", ""))
	if not catalog.chapters.has(id): return _fail(pending, require_assets, "unknown_chapter", id)
	if not catalog.chapters[id] is Dictionary: return _fail(pending, require_assets, "invalid_chapter", id)
	var chapter: Dictionary = catalog.chapters[id]
	var source := "res://campaign/generated/" + id + ".json"
	if not FileAccess.file_exists(source): return _fail(pending, require_assets, "missing_chapter", source)
	if str(recipe.get("geometryHash", "")) != str(chapter.get("geometryHash", "")) or FileAccess.get_sha256(source) != str(chapter.get("recipeSha256", "")):
		return _fail(pending, require_assets, "chapter_identity_mismatch", source)
	if not chapter.get("placements") is Array or chapter.placements.size() != 3:
		return _fail(pending, require_assets, "invalid_placement_count", id)
	for entry: Variant in chapter.placements:
		if not entry is Dictionary: return _fail(pending, require_assets, "invalid_placement", id)
		var placement: Dictionary = entry
		var asset := str(placement.get("asset", ""))
		if asset.is_empty() or "/" in asset or ".." in asset or asset in selected:
			return _fail(pending, require_assets, "invalid_asset_id", asset)
		if not valid_vector(placement.get("origin")) or not valid_vector(placement.get("scale"), true):
			return _fail(pending, require_assets, "invalid_transform", asset)
		for lod: int in 2:
			var path := ART + asset + "-%d.glb" % lod
			if not _exists(path): return _fail(pending, require_assets, "missing_import", path)
			var resource: Resource = _load(path)
			if resource == null: return _fail(pending, require_assets, "load_failed", path)
			if not resource is PackedScene: return _fail(pending, require_assets, "not_packed_scene", path)
			if not (resource as PackedScene).can_instantiate(): return _fail(pending, require_assets, "empty_scene", path)
			var node: Node = (resource as PackedScene).instantiate()
			if not node is Node3D:
				if node != null: node.free()
				return _fail(pending, require_assets, "wrong_root_type", path)
			var instance := node as Node3D
			pending.append(instance)
			var problem := visual_problem(instance)
			if not problem.is_empty(): return _fail(pending, require_assets, problem, path)
			if mesh_count(instance) == 0: return _fail(pending, require_assets, "no_meshes", path)
			instance.name = asset + "_LOD%d" % lod
			instance.set_meta("biome4_lod", lod)
			instance.set_meta("reviewed_block", str(placement.block))
			instance.position = vector(placement.origin)
			instance.scale = vector(placement.scale)
			# Instance-owned material copies protect cached GLBs and sibling packs
			# from downstream per-instance tint/wet overrides. Textures stay shared.
			private_materials(instance)
		selected.append(asset)
	# The only publish boundary: all six trees have passed every check.
	for instance: Node3D in pending: add_child(instance)
	_installed.assign(pending)
	loaded_assets.assign(selected)
	recipe_hash = str(catalog.recipeSha256)
	set_reduced_detail(reduced)
	last_build = {"status":"installed", "code":"ok", "path":id, "instances":6}
	return true

static func valid_vector(value: Variant, positive := false) -> bool:
	if not value is Array or value.size() != 3: return false
	for component: Variant in value:
		if not (component is float or component is int) or not is_finite(float(component)): return false
		if positive and float(component) <= 0: return false
	return true

static func vector(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

static func visual_only(node: Node) -> bool:
	return visual_problem(node).is_empty()

static func visual_problem(node: Node) -> String:
	if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D: return "collision:" + str(node.name)
	if not node is Node3D: return "non_spatial_node:" + str(node.name)
	if node.get_script() != null: return "scripted_node:" + str(node.name)
	if node.get_class() not in ["Node3D", "MeshInstance3D"]: return "non_visual_class:" + node.get_class()
	if not (node as Node3D).transform.is_finite(): return "nonfinite_transform:" + str(node.name)
	if absf((node as Node3D).transform.basis.determinant()) < 0.000001: return "singular_transform:" + str(node.name)
	if node is MeshInstance3D and (node.mesh == null or node.mesh.get_surface_count() == 0): return "empty_mesh:" + str(node.name)
	for child: Node in node.get_children():
		var problem := visual_problem(child)
		if not problem.is_empty(): return problem
	return ""

static func mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children(): count += mesh_count(child)
	return count

static func private_materials(node: Node) -> void:
	if node is MeshInstance3D:
		if node.material_override != null: node.material_override = node.material_override.duplicate()
		if node.material_overlay != null: node.material_overlay = node.material_overlay.duplicate()
		for surface: int in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(surface)
			if material != null: node.set_surface_override_material(surface, material.duplicate())
	for child: Node in node.get_children(): private_materials(child)

func set_reduced_detail(value: bool) -> void:
	reduced = value
	for child: Node3D in _installed:
		if not is_instance_valid(child): continue
		var lod := int(child.get_meta("biome4_lod"))
		child.visible = not reduced or lod == 1
		set_ranges(child, lod)

func set_ranges(node: Node, lod: int) -> void:
	if node is GeometryInstance3D:
		node.visibility_range_begin = 85.0 if lod == 1 and not reduced else 0.0
		node.visibility_range_end = 85.0 if lod == 0 else 0.0
	for child: Node in node.get_children(): set_ranges(child, lod)
