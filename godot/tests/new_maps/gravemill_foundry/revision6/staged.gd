extends RefCounted
## Explicit test-only integration. Never registers/publishes R6 in the catalog.
const WorldMap = preload("res://multiplayer_worlds/map.gd")
const Binder = preload("res://multiplayer_worlds/dressing/binder.gd")
const Schema = preload("res://tests/new_maps/gravemill_foundry/revision6/profile_schema.gd")
const DIR := "res://tests/new_maps/gravemill_foundry/revision6/"
const ART := "res://multiplayer_worlds/art/revisions/gravemill-foundry-r6.glb"
const AUTHORITY := "res://multiplayer_worlds/generated/revisions/gravemill-foundry-r5.json"

static func read_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func make_world(parent: Node) -> Node3D:
	var data := read_json(AUTHORITY)
	var identity := read_json(DIR + "art-identity.json")
	assert(identity.visualRevision == 6 and identity.geometryHash == data.geometryHash)
	assert(identity.artHash is String and identity.artHash.length() == 64)
	assert(FileAccess.get_sha256(ART) == identity.artHash)
	var lineage := read_json(DIR + "profile-lineage.json")
	assert(data.geometryHash == lineage.candidateGeometryHash)
	assert(FileAccess.get_sha256(DIR + "profile.json") == lineage.candidateProfileSha256)
	assert(FileAccess.get_sha256(DIR + "profile_schema.gd") == lineage.candidateSchemaSha256)
	var profile := read_json(DIR + "profile.json")
	assert(Schema.validate(profile, data.id, data.geometryHash).is_empty())
	assert(not Schema.validate(profile, data.id, lineage.acceptedGeometryHash).is_empty())
	var world := WorldMap.new()
	parent.add_child(world)
	assert(world.build(data))
	Binder.cleanup(world)
	var original := world.get_node("BlenderArtNoGameplayCollision")
	world.remove_child(original)
	original.free()
	var art: Node3D = load(ART).instantiate()
	art.name = "BlenderArtNoGameplayCollision"
	world.add_child(art)
	for mesh_node: Node in art.find_children("*","MeshInstance3D",true,false):
		for surface in mesh_node.mesh.get_surface_count():
			var original_material: StandardMaterial3D = mesh_node.mesh.surface_get_material(surface)
			var filtered: StandardMaterial3D = original_material.duplicate()
			filtered.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mesh_node.set_surface_override_material(surface,filtered)
	var binder := Binder.new()
	binder.name = "ExactR6StagedDressing"
	binder.set_meta(Binder.OWNER, true)
	binder._profile = profile
	binder._diagnostics = {"map_id":data.id,"geometryHash":data.geometryHash,"status":"staged", "errors":[],"matched":[],"unmatched":[],"unused_selectors":[],"preserved":[],"resources":[],"surfaces":0,"panels":0,"signs":0,"motes":0}
	world.add_child(binder)
	binder._prepare(world)
	binder._collect(art)
	assert(binder._diagnostics.errors.is_empty() and binder._diagnostics.unmatched.is_empty())
	assert(binder._diagnostics.preserved.size() == 18)
	binder.set_detail(Binder.Detail.FULL)
	world.set_meta("staged_dressing",binder.diagnostics())
	var lights := read_json(DIR+"lights.json")
	assert(lights.geometryHash==data.geometryHash and lights.lights.size()==4)
	assert(FileAccess.get_sha256("res://multiplayer_worlds/art/worlds/gravemill-foundry.glb")==lights.acceptedArtSha256)
	for entry: Dictionary in lights.lights:
		var light := OmniLight3D.new()
		light.name = entry.id
		light.position = Vector3(entry.position[0],entry.position[1],entry.position[2])
		light.light_color = Color(entry.color)
		light.light_energy = entry.energy
		light.omni_range = entry.range
		light.shadow_enabled = false
		world.add_child(light)
	world.set_meta("visualRevision", 6)
	world.set_meta("artHash", identity.artHash)
	return world

static func emission(world: Node) -> Dictionary:
	var result := {}
	for node: Node in world.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null: continue
		for index in node.mesh.get_surface_count():
			var base: Material = node.mesh.surface_get_material(index)
			if base == null or base.resource_name != "GM / orange": continue
			var active: StandardMaterial3D = node.get_active_material(index)
			assert(active.emission_enabled)
			result = {"color":active.emission,"energy":active.emission_energy_multiplier,"albedo":active.albedo_color,"roughness":active.roughness,"texture":active.emission_texture,"operator":active.emission_operator}
	assert(not result.is_empty())
	return result
