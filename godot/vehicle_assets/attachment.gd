extends RefCounted
## Optional visual-only adapter. Installation is atomic across all three LODs.
## No generated asset is required to retain the existing procedural fleet.
const PIVOTS := {"puma":Vector3(0, 1.1, -0.95), "titan":Vector3(0, 1.5, -0.72), "scout":Vector3(0, 0.79, 0.04)}

static func meshes(node: Node, found: Dictionary) -> bool:
	if node is MeshInstance3D:
		if found.has(str(node.name)) or node.mesh == null: return false
		found[str(node.name)] = node
	elif not node is Node3D:
		return false
	# GLBs must be rigid visual assemblies, never imported collision/authority.
	if node is CollisionObject3D or node is CollisionShape3D: return false
	for child: Node in node.get_children():
		if not meshes(child, found): return false
	return true

static func install(host: Node3D, kind: String) -> bool:
	if not PIVOTS.has(kind): return false
	if host.has_meta("authored_vehicle"): return true
	var targets: Dictionary = {"body":host, "turret":host.turret}
	for i in host.wheels.size(): targets["wheel_%d" % i] = host.wheels[i]
	var staged: Array[Node3D] = []
	var collected: Array[Dictionary] = []
	for lod in 3:
		var path := "res://vehicle_assets/generated/%s-lod%d.glb" % [kind, lod]
		if not ResourceLoader.exists(path):
			for root: Node3D in staged: root.free()
			return false
		var scene := load(path) as PackedScene
		if scene == null:
			for root: Node3D in staged: root.free()
			return false
		var root := scene.instantiate() as Node3D
		if root == null:
			for prior: Node3D in staged: prior.free()
			return false
		staged.append(root)
		var found: Dictionary = {}
		var valid := meshes(root, found) and found.size() == targets.size()
		for key: String in targets: valid = valid and found.has(key)
		if not valid:
			for prior: Node3D in staged: prior.free()
			return false
		collected.append(found)
	# Replace only procedural visual children; keep native pivots/roll ownership.
	for target: Node3D in targets.values():
		for child: Node in target.get_children():
			if child is MeshInstance3D: child.visible = false
	var accents: Array[Dictionary] = []
	var clones: Dictionary = {}
	for lod in 3:
		for key: String in targets:
			var mesh: MeshInstance3D = collected[lod][key]
			# Imported meshes still belong to the staged PackedScene root. Drop
			# that owner before reparenting, then assign the persistent host owner;
			# freeing the staged root must not retain a foreign scene owner.
			mesh.owner = null
			mesh.get_parent().remove_child(mesh)
			targets[key].add_child(mesh)
			mesh.owner = host
			mesh.transform = Transform3D.IDENTITY
			mesh.visibility_range_begin = [0.0, 24.0, 65.0][lod]
			mesh.visibility_range_end = [24.0, 65.0, 0.0][lod]
			mesh.visibility_range_begin_margin = 0.0
			mesh.visibility_range_end_margin = 0.0
			# Per-instance StandardMaterial3D clones retain weather channel support.
			for surface in mesh.mesh.get_surface_count():
				var original := mesh.mesh.surface_get_material(surface)
				if original == null: continue
				var channel := original.resource_name
				if not clones.has(channel): clones[channel] = original.duplicate()
				var material: Material = clones[channel]
				mesh.set_surface_override_material(surface, material)
				if channel == "team_accent": accents.append({"node":weakref(mesh), "surface":surface, "base":material})
		staged[lod].free()
	host.set_meta("authored_vehicle", kind)
	host.set_meta("vehicle_accents", accents)
	return true

static func set_team(host: Node3D, color: Color) -> void:
	for binding: Dictionary in host.get_meta("vehicle_accents", []):
		# Update retained dry original and whichever weather clone currently owns
		# the surface. Roughness, metallic, wet texture and channel stay untouched.
		if binding.base is StandardMaterial3D: binding.base.albedo_color = color
		var node: MeshInstance3D = binding.node.get_ref()
		if is_instance_valid(node):
			var active := node.get_active_material(int(binding.surface))
			if active is StandardMaterial3D: active.albedo_color = color

static func apply_source_pose(host: Node3D, state: Dictionary) -> void:
	if not host.has_meta("authored_vehicle"): return
	var kind: String = host.get_meta("authored_vehicle")
	# Source muzzles ignore visual hull pitch/roll and orbit the vehicle origin.
	# Preserve native turret mount coordinates in the authored attachment-local mesh.
	var yaw_basis := Basis(Vector3.UP, float(state.yaw) + float(state.turretYaw))
	var source_turret := Transform3D(yaw_basis, host.position + yaw_basis * PIVOTS[kind])
	# Keep the native turret pivot at the source-relative yaw. Only authored
	# geometry needs the upright, world-space muzzle orbit under hull pitch/roll.
	# Synthetic fleet controls also pose a vehicle before adding it to the tree.
	# global_transform is unavailable there; compose the same local chain instead.
	var turret_transform: Transform3D = host.turret.global_transform if host.turret.is_inside_tree() else host.transform * host.turret.transform
	var visual_pose: Transform3D = turret_transform.affine_inverse() * source_turret
	for child: Node in host.turret.get_children():
		if child is MeshInstance3D and child.visible: child.transform = visual_pose
