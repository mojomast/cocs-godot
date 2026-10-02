extends RefCounted
## Explicit local cosmetic selection, after RobotVisual.configure(). Never changes
## npcModel, source state, sockets, skeleton pivots or collision.
const SKINS := {"needle_surveyor":"skirmisher", "caisson_guard":"bulwark", "kiln_tender":"mortar"}
const DIRECTORY := "res://robot_assets/switchyard/generated/"
const ROLE_SKIN := {"skirmisher":"needle_surveyor", "bulwark":"caisson_guard", "mortar":"kiln_tender"}

static func install_role(visual: Node3D) -> bool:
	# Fixed role mapping, never random actor assignment. Missing art retains stock.
	visual.set_meta("switchyard_enabled", true)
	if not ROLE_SKIN.has(visual.get("model_id")):
		restore(visual)
		return false
	return install(visual, str(ROLE_SKIN.get(visual.get("model_id"), "")))

static func select_stock(visual: Node3D) -> void:
	visual.set_meta("switchyard_enabled", false)
	restore(visual)

static func install(visual: Node3D, skin: String) -> bool:
	if not SKINS.has(skin) or visual.get("model_id") != SKINS[skin]: return false
	var path := DIRECTORY + skin + ".glb"
	if not ResourceLoader.exists(path): return false
	var packed := load(path) as PackedScene
	if packed == null: return false
	var scene := packed.instantiate()
	var meshes: Dictionary = {}
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		meshes[str(node.name)] = (node as MeshInstance3D).mesh
	scene.free()
	var replacements: Array = []
	for batch: MeshInstance3D in visual.get("batches"):
		var parent: Node3D = batch.get_parent()
		var assembly := str(parent.name)
		if batch.name == "Optics": assembly = "Optics"
		elif assembly == "Knee": assembly = "Shin" + str(parent.get_parent().name).trim_prefix("Hip")
		elif assembly == "WeaponCradle": assembly = "Weapon"
		elif assembly == "ShieldArm": assembly = "Shield"
		var band: Node = parent
		while band != visual and not str(band.name).begins_with("LOD"):
			band = band.get_parent()
		var key := str(band.name).replace("LOD", "L") + "_" + assembly
		# Validate complete coverage before changing any visible mesh.
		if not meshes.has(key): return false
		var material := (meshes[key] as Mesh).surface_get_material(0) as StandardMaterial3D
		if material == null or material.albedo_texture == null: return false
		replacements.append([batch, meshes[key]])
	# Keep the live optic/shield material objects: RobotVisual animates their
	# emission on every source update. Carry the imported Moth texture into those
	# overrides rather than silently hiding it under the old flat material.
	for material: StandardMaterial3D in [visual.get("armor_material"), visual.get("optic_material"), visual.get("shield_material")]:
		if not material.has_meta("switchyard_original_texture"):
			material.set_meta("switchyard_original_texture", {"texture":material.albedo_texture})
		var imported := (replacements[0][1] as Mesh).surface_get_material(0) as StandardMaterial3D
		material.albedo_texture = imported.albedo_texture
		material.vertex_color_use_as_albedo = true
		material.normal_enabled = false # Reviewed coating role has geometry normals.
	for pair: Array in replacements:
		var batch: MeshInstance3D = pair[0]
		if not batch.has_meta("switchyard_original"):
			batch.set_meta("switchyard_original", batch.mesh)
			batch.set_meta("switchyard_original_triangles", batch.get_meta("triangles", 0))
		batch.mesh = pair[1]
		var triangles := 0
		for surface: int in range(batch.mesh.get_surface_count()):
			var arrays := batch.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += (indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
		batch.set_meta("triangles", triangles)
	visual.set_meta("switchyard_skin", skin)
	return true

static func restore(visual: Node3D) -> void:
	for batch: MeshInstance3D in visual.get("batches"):
		if batch.has_meta("switchyard_original"):
			batch.mesh = batch.get_meta("switchyard_original")
			batch.set_meta("triangles", batch.get_meta("switchyard_original_triangles"))
	for material: StandardMaterial3D in [visual.get("armor_material"), visual.get("optic_material"), visual.get("shield_material")]:
		if material.has_meta("switchyard_original_texture"):
			material.albedo_texture = material.get_meta("switchyard_original_texture").texture
	if visual.has_meta("switchyard_skin"): visual.remove_meta("switchyard_skin")
