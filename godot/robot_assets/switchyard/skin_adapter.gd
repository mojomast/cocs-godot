extends RefCounted
## Explicit local cosmetic selection, after RobotVisual.configure(). Never changes
## npcModel, source state, sockets, skeleton pivots, material overrides or collision.
const SKINS := {"needle_surveyor":"skirmisher", "caisson_guard":"bulwark", "kiln_tender":"mortar"}
const DIRECTORY := "res://robot_assets/switchyard/generated/"

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
		replacements.append([batch, meshes[key]])
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
	visual.remove_meta("switchyard_skin")
