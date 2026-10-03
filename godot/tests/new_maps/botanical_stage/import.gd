extends SceneTree
const Stage = preload("res://tests/new_maps/botanical_stage/staged.gd")
const Weather = preload("res://ambience/weather_service.gd")

func _initialize() -> void:
	call_deferred("run")
	create_timer(110).timeout.connect(func() -> void: push_error("Botanical import probe timeout"); quit(2))

func run() -> void:
	var version := Engine.get_version_info()
	assert(version.major == 4 and version.minor == 5 and version.patch == 2)
	var id := Stage.map_id()
	var receipt := Stage.manifest(id)
	var world := Stage.make_world(root,id)
	var originals := Stage.snapshot(world)
	assert(not originals.is_empty())
	var expected_pixels := Stage.read_json(Stage.directory(id)+"expected-pixels.json")
	var verified_pixels := {}
	for row: Dictionary in originals:
		var material: StandardMaterial3D = row.active
		var selector: String = row.source.resource_name
		if verified_pixels.has(selector): continue
		var channels: Dictionary = expected_pixels[selector]
		for channel: String in channels:
			var texture: Texture2D = material.get(channel+"_texture")
			assert(texture != null)
			var image := texture.get_image()
			if image.is_compressed(): assert(image.decompress()==OK)
			image.clear_mipmaps()
			image.convert(Image.FORMAT_RGBA8)
			assert(image.get_width()==int(channels[channel].width) and image.get_height()==int(channels[channel].height))
			var digest := HashingContext.new()
			digest.start(HashingContext.HASH_SHA256)
			digest.update(image.get_data())
			assert(digest.finish().hex_encode()==channels[channel].rgba8Sha256,"Imported pixel mismatch: "+selector+"/"+channel)
		verified_pixels[selector] = channels
	var proof := Stage.read_json(Stage.directory(id)+"geometry-proof.json")
	var triangles := 0
	for node: MeshInstance3D in Stage.art_root(world).find_children("*","MeshInstance3D",true,false):
		var faces := node.mesh.get_faces()
		triangles += faces.size()/3
		for point: Vector3 in faces: assert(point.is_finite())
	assert(triangles == int(proof.evaluatedExportTriangles))
	var visual := Stage.visual_root(world)
	for level in [Stage.Binder.Detail.OFF,Stage.Binder.Detail.LOW,Stage.Binder.Detail.FULL]:
		Stage.Binder.set_root_detail(visual,level)
		Stage.restored(originals)
	var profile := Stage.read_json(Stage.directory(id)+"profile.json")
	for patch: Dictionary in [{"geometry_hash":"arbitrary"},{"unknown":true},{"budgets":{"material_variants":99,"panels":999,"signs":0,"motes":0}}]:
		var invalid := profile.duplicate(true)
		invalid.merge(patch,true)
		assert(not Stage.Schema.validate(invalid,id,receipt.geometryHash).is_empty())
	var environment := WorldEnvironment.new()
	var sun := DirectionalLight3D.new()
	root.add_child(environment)
	root.add_child(sun)
	Stage.presentation(id,environment,sun)
	var camera := Camera3D.new()
	root.add_child(camera)
	var weather := Weather.new()
	root.add_child(weather)
	weather.apply_settings({"mute":true})
	var data := Stage.read_json(Stage.directory(id)+"authority.json")
	weather.bind(data.arena,camera,"playing",int(data.arena.get("seed",0)))
	weather.bind_presentation(visual,environment,sun)
	assert(not weather.look.diagnostics().capped)
	weather.set_native_weather_suppressed(true)
	weather.apply_snapshot({"time":12.0})
	weather.tick(.05)
	var weather_report: Dictionary = weather.look.diagnostics()
	weather.look.clear()
	Stage.restored(originals)
	var report := {"geometryHash":receipt.geometryHash,"glbSha256":receipt.glbSha256,"manifestSha256":FileAccess.get_sha256(Stage.directory(id)+"manifest.json"),"godot":version,"triangles":triangles,"materials":proof.usedMaterials,"importedPixelEvidence":verified_pixels,"materialInstancesRestored":originals.size(),"weatherLook":weather_report,"dressing":world.get_meta("staged_dressing"),"scope":"actual imported GLB/schema/Binder/Weather lifecycle; rendering and hosted play are separate pending gates"}
	var file := FileAccess.open(Stage.directory(id)+"import-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	print("BOTANICAL_IMPORT ",JSON.stringify(report))
	quit()
