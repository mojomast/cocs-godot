extends RefCounted
## Exact test-only integration, based on reviewed R5 staging. No catalog writes.
const WorldMap = preload("res://multiplayer_worlds/map.gd")
const Binder = preload("res://multiplayer_worlds/dressing/binder.gd")
const Schema = preload("res://tests/new_maps/botanical_correction/x-03/parallax-observatory/profile_schema.gd")
const Catalog = preload("res://multiplayer_worlds/catalog.gd")
const DIR := "res://tests/new_maps/botanical_correction/x-03/parallax-observatory/"

static func read_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(value is Dictionary, "Missing/invalid staged JSON: " + path)
	return value

static func map_id() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			var id := arg.trim_prefix("--map=")
			assert(Schema.IDENTITIES.has(id), "Unknown staged map")
			return id
	assert(false, "Explicit --map required")
	return ""

static func directory(id: String) -> String:
	assert(id == "parallax-observatory")
	return DIR

static func manifest(id: String) -> Dictionary:
	var result := read_json(directory(id) + "manifest.json")
	assert(result.status == "artifacts-verified-native-pending")
	assert(result.map == id and result.geometryHash == Schema.IDENTITIES[id])
	for path: String in result.files:
		assert(FileAccess.get_sha256(path) == result.files[path], "Stale staged bytes: " + path)
	assert(FileAccess.get_sha256(result.source.acceptedAuthority) == result.source.acceptedAuthoritySha256)
	assert(FileAccess.get_sha256(result.source.acceptedArt) == result.source.acceptedArtSha256)
	assert(result.modes == Catalog.MODES[id])
	return result

static func make_world(parent: Node, id: String, candidate: bool = true) -> Node3D:
	var receipt := manifest(id)
	var data := read_json(directory(id) + "authority.json" if candidate else receipt.source.acceptedAuthority)
	assert(data.geometryHash == (Schema.IDENTITIES[id] if candidate else receipt.source.acceptedGeometryHash))
	var world := WorldMap.new()
	parent.add_child(world)
	assert(world.build(data))
	if candidate:
		var import_options := ConfigFile.new()
		assert(import_options.load(directory(id)+"candidate.glb.import")==OK)
		assert(import_options.get_value("params","meshes/force_disable_compression",false)==true)
		assert(import_options.get_value("params","meshes/generate_lods",true)==false)
		Binder.cleanup(world)
		var old := world.get_node_or_null("BlenderArtNoGameplayCollision")
		assert(old != null, "Accepted runtime baseline art required")
		# Preserve only actual inherited light nodes. Never retain old dishes,
		# floors, domes, full geometry or a second copy of legacy labels.
		for light: Node3D in old.find_children("*", "Light3D", true, false):
			var inherited: Node3D = light.duplicate()
			for child: Node in inherited.get_children(): child.free()
			world.add_child(inherited)
			inherited.global_transform = light.global_transform
		old.free()
		# Vesper's production loader draws authority surfaces for its older art.
		# This complete new GLB already includes them. Keep every collider.
		for child: Node in world.get_children():
			if child is MeshInstance3D: child.free()
		var packed: PackedScene = load(directory(id) + "candidate.glb")
		assert(packed != null)
		var art: Node3D = packed.instantiate()
		art.name = "BlenderArtNoGameplayCollision"
		world.add_child(art)
		assert(art.find_children("*", "CollisionObject3D", true, false).is_empty())
		var profile := read_json(directory(id) + "profile.json")
		assert(Schema.validate(profile, id, data.geometryHash).is_empty())
		assert(not Schema.validate(profile, id, receipt.source.acceptedGeometryHash).is_empty())
		assert(not Schema.validate(profile, id, "arbitrary").is_empty())
		for node: MeshInstance3D in art.find_children("*", "MeshInstance3D", true, false):
			assert(node.material_override == null)
			for index in node.mesh.get_surface_count():
				var material: Material = node.mesh.surface_get_material(index)
				assert(material is StandardMaterial3D)
				var owned: StandardMaterial3D = material.duplicate()
				owned.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				node.set_surface_override_material(index, owned)
		var binder := Binder.new()
		binder.name = "ExactBotanicalStagedDressing"
		binder.set_meta(Binder.OWNER, true)
		binder._profile = profile
		binder._diagnostics = {"map_id":id,"geometryHash":data.geometryHash,"status":"staged","errors":[],"matched":[],"unmatched":[],"unused_selectors":[],"preserved":[],"resources":[],"surfaces":0,"panels":0,"signs":0,"motes":0}
		world.add_child(binder)
		binder._prepare(world)
		binder._collect(art)
		assert(binder._diagnostics.errors.is_empty() and binder._diagnostics.unmatched.is_empty())
		assert(binder._diagnostics.preserved.size() == profile.preserve_materials.size())
		binder.set_detail(Binder.Detail.FULL)
		assert(binder._diagnostics.errors.is_empty())
		world.set_meta("staged_dressing", binder.diagnostics())
	# These are the actual production presentation.gd interior-light parameters.
	# Keep this same policy in before/after worlds, not per-camera adjustments.
	if id == "parallax-observatory":
		for roof: Dictionary in data.arena.get("overhead", []):
			var light := OmniLight3D.new()
			light.position = Vector3(roof.x, roof.minY - .45, roof.z)
			light.light_color = Color("ffdda3")
			light.light_energy = 1.2
			light.omni_range = 20
			light.shadow_enabled = false
			world.add_child(light)
	# Weather owns presentation only. The real WorldMap colliders remain intact
	# as siblings; traversing 27k Helix collider nodes would exceed its visual
	# service's 16k node cap. Every displayed mesh/panel/light is in this subtree.
	var presentation_root := Node3D.new()
	presentation_root.name = "StagedPresentation"
	world.add_child(presentation_root)
	for child: Node in world.get_children():
		if child.name == "BlenderArtNoGameplayCollision" or child is GeometryInstance3D or child is Light3D or child.get_meta(Binder.OWNER,false):
			child.reparent(presentation_root)
	return world

static func visual_root(world: Node3D) -> Node3D:
	return world.get_node("StagedPresentation")

static func art_root(world: Node3D) -> Node3D:
	return visual_root(world).get_node("BlenderArtNoGameplayCollision")

static func snapshot(world: Node3D) -> Array:
	var result: Array = []
	var art := art_root(world)
	for node: MeshInstance3D in art.find_children("*", "MeshInstance3D", true, false):
		for index in node.mesh.get_surface_count():
			result.append({"node":node,"index":index,"source":node.mesh.surface_get_material(index),"active":node.get_active_material(index),"fields":fields(node.get_active_material(index))})
	return result

static func fields(material: Material) -> Dictionary:
	if not material is StandardMaterial3D: return {"resource":material}
	var result := {}
	for key: String in ["albedo_color","albedo_texture","metallic","roughness","metallic_texture","roughness_texture","normal_enabled","normal_scale","normal_texture","transparency","cull_mode","emission_enabled","emission","emission_texture","emission_energy_multiplier","texture_filter"]:
		result[key] = material.get(key)
	return result

static func restored(rows: Array) -> void:
	for row: Dictionary in rows:
		assert(row.node.mesh.surface_get_material(row.index) == row.source)
		assert(row.node.get_active_material(row.index) == row.active)
		assert(fields(row.active) == row.fields)

static func presentation(id: String, environment: WorldEnvironment, sun: DirectionalLight3D) -> void:
	sun.rotation_degrees = Vector3(-44,-30,0)
	sun.light_energy = .6 if id == "parallax-observatory" else 1.25
	sun.shadow_enabled = true
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("46566f" if id == "parallax-observatory" else "627985")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("bac7dc" if id == "parallax-observatory" else "a0adb5")
	settings.ambient_light_energy = .45 if id == "parallax-observatory" else .68
	environment.environment = settings
