extends RefCounted
## Exact JSON/art binding only. No Binder/Weather lifecycle acceptance claim.
const WorldMap = preload("res://multiplayer_worlds/map.gd")
const Binder = preload("res://multiplayer_worlds/dressing/binder.gd")
const IDENTITIES := {
	"accepted": {"authoritySha256":"0f7f8a0aa5bd8ff1bd8b5098fa0c9e3a63fa770cc748407ae2a0db29ca484a0c", "geometryHash":"db20ce1fec59678ac3b7086be40b1dbac25fdaf9b576d284a1db448dcd9ebd22", "recipeHash":"6886cf86c360f24fdcd5e39762d7c978e89a1438b11e19a92b8de4ab563f3561", "artSha256":"51a5b5768e5eb66bc0941652ea47436a5db4f75a282bd23e72bf007091b022d2", "triangles":54964,"meshInstances":11,"surfaces":11,"materials":["asphalt","brick","cobbles","glass","iron","letter","plaster","quay","sandstone","slate","water"]},
	"candidate": {"authoritySha256":"397cedc8f5583a229bb3f65ed94d9a8c74c30fd4132b57bd4e754299a47c67ec", "geometryHash":"fd8e7134c8933e908336d7b0409c66bdc90f4adc03fcfc6e596d5b4579f1c740", "recipeHash":"f22b863cab4caec974602b81548b11e7fd60e221d441e136c47c35df144220e2", "artSha256":"f859d49cc1b462b4a88e351d915518c49940ce24a7b8c2047c2d8f94f419e1db", "triangles":64311,"meshInstances":29,"surfaces":29,"materials":["asphalt","brick","cobbles","glass","iron","letter","plaster","quay","sandstone","slate","vesper.awning","vesper.brick-era","vesper.coping","vesper.quay","vesper.slate","vesper.stall","water"]}
}

static func read_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(value is Dictionary,"Required binding JSON missing/invalid: "+path)
	return value

static func imported_art(path: String, expected: Dictionary) -> Dictionary:
	assert(FileAccess.file_exists(path) and FileAccess.get_sha256(path)==expected.artSha256,"Selected GLB missing/changed")
	assert(ResourceLoader.exists(path),"Selected GLB is not actually imported")
	var packed: PackedScene = ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
	assert(packed != null and packed.resource_path==path,"Wrong loaded resource path")
	var art: Node3D = packed.instantiate()
	assert(art != null and art.scene_file_path==path)
	assert(not art is CollisionObject3D and art.find_children("*","CollisionObject3D",true,false).is_empty(),"Art must not add gameplay collisions")
	var meshes: Array = art.find_children("*","MeshInstance3D",true,false)
	if art is MeshInstance3D: meshes.push_front(art)
	assert(not meshes.is_empty(),"Imported art world is empty")
	var triangles := 0
	var surfaces := 0
	var materials := {}
	for node: MeshInstance3D in meshes:
		assert(node.mesh != null and node.material_override==null)
		var faces := node.mesh.get_faces()
		assert(faces.size()>0 and faces.size()%3==0)
		triangles += faces.size()/3
		for point: Vector3 in faces: assert(point.is_finite())
		for index in node.mesh.get_surface_count():
			surfaces += 1
			assert((node.mesh.surface_get_format(index)&Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)==0,"Actual imported mesh still compressed")
			assert(node.get_surface_override_material(index)==null)
			var material: Material = node.mesh.surface_get_material(index)
			assert(material != null)
			materials[material.resource_name] = true
			var arrays := node.mesh.surface_get_arrays(index)
			var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
			if uv != null:
				assert(uv is PackedVector2Array)
				for point: Vector2 in uv: assert(point.is_finite())
	var names: Array = materials.keys()
	names.sort()
	assert(meshes.size()==int(expected.meshInstances) and surfaces==int(expected.surfaces))
	assert(triangles==int(expected.triangles) and names==expected.materials,"Imported triangle/material identity differs")
	return {"art":art,"readback":{"loadedResourcePath":packed.resource_path,"instanceScenePath":art.scene_file_path,
		"artSha256":FileAccess.get_sha256(path),"meshInstances":meshes.size(),"surfaces":surfaces,"triangles":triangles,"materials":names,"nonempty":true}}

static func make_world(parent: Node, directory: String, config: Dictionary, selected: String) -> Dictionary:
	assert(IDENTITIES.has(selected))
	var policy := read_json(directory+"import-policy.json")
	var bindings := {}
	for variant: String in ["accepted","candidate"]:
		var expected: Dictionary = IDENTITIES[variant]
		var configured: Dictionary = config.variants[variant]
		for key: String in expected: assert(configured[key]==expected[key],"Unreviewed binding field: "+key)
		var authority_path := directory+variant+".json"
		var art_path := directory+variant+".glb"
		assert(configured.authorityPath==authority_path and configured.artPath==art_path,"Variant path substitution")
		assert(FileAccess.get_sha256(authority_path)==expected.authoritySha256)
		var data := read_json(authority_path)
		assert(data.id=="vesper-viaduct" and data.geometryHash==expected.geometryHash and data.get("recipeHash")==expected.recipeHash,"Authority/recipe substitution")
		var options := ConfigFile.new()
		assert(options.load(art_path+".import")==OK,"Actual Godot import sidecar required")
		assert(options.get_value("deps","source_file","")==art_path)
		var uid: String = options.get_value("remap","uid","")
		var imported_path: String = options.get_value("remap","path","")
		assert(uid.begins_with("uid://") and uid==policy.variants[variant].uid)
		assert(ResourceUID.id_to_text(ResourceLoader.get_resource_uid(art_path))==uid,"Loaded resource UID differs from retained import UID")
		assert(FileAccess.get_sha256(art_path+".import")==policy.variants[variant].afterSha256)
		assert(options.get_value("params","meshes/force_disable_compression",false)==true)
		assert(options.get_value("params","meshes/generate_lods",true)==false)
		assert(imported_path.begins_with("res://.godot/imported/") and FileAccess.file_exists(imported_path))
		var probe := imported_art(art_path,expected)
		bindings[variant] = probe.readback
		bindings[variant].merge({"authorityPath":authority_path,"authoritySha256":FileAccess.get_sha256(authority_path),
			"geometryHash":data.geometryHash,"recipeHash":data.recipeHash,"importUid":uid,"importSidecarSha256":FileAccess.get_sha256(art_path+".import"),
			"importedResourcePath":imported_path,"importedResourceSha256":FileAccess.get_sha256(imported_path),"compressionDisabled":true,"lodsDisabled":true,"runtimeArtReady":true})
		probe.art.free()
	var selected_data := read_json(directory+selected+".json")
	var world := WorldMap.new()
	parent.add_child(world)
	assert(world.build(selected_data))
	assert(world.geometry_hash==IDENTITIES[selected].geometryHash)
	# WorldMap's default path is shared between variants. It is never evidence
	# of the selected art. Remove it and its Binder before explicit instantiation.
	Binder.cleanup(world)
	var old := world.get_node_or_null("BlenderArtNoGameplayCollision")
	if old != null: old.free()
	if selected=="candidate":
		for child: Node in world.get_children():
			if child is MeshInstance3D: child.free()
	var loaded := imported_art(directory+selected+".glb",IDENTITIES[selected])
	loaded.art.name = "ExactDiagnosticArt"
	world.add_child(loaded.art)
	assert(world.get_node_or_null("BlenderArtNoGameplayCollision")==null)
	assert(loaded.art.get_parent()==world and loaded.art.scene_file_path==bindings[selected].loadedResourcePath)
	return {"world":world,"receipt":{"bindingReady":true,"bothVariantsRuntimeVerified":true,"variants":bindings,
		"selectedVariant":selected,"runtimeGeometryHash":world.geometry_hash,"selectedLoadedResourcePath":loaded.art.scene_file_path,
		"scope":"exact JSON/art walk diagnostic only; Binder cleaned, no Weather or presentation lifecycle acceptance"}}
