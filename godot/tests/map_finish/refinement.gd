extends "res://tests/map_finish/proof.gd"
## Source-prepared comparison harness; requires an explicit exclusive native grant.
## External rejected profile is an immutable git-show snapshot, never copied over
## production files. Uses current production binder (including font exclusion).

func _run() -> void:
	var args := {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var pair := arg.trim_prefix("--").split("=", true, 1)
			args[pair[0]] = pair[1]
	var id: String = args.get("map", "gravemill-foundry")
	var directory: String = args.get("proof-dir", "")
	var rejected_path: String = args.get("rejected-profile", "")
	if not Profile.IDENTITIES.has(id) or directory.is_empty() or not FileAccess.file_exists(rejected_path):
		print("REFINEMENT_FAIL requires accepted --map, --proof-dir and --rejected-profile")
		quit(1)
		return
	var refined_path := "res://multiplayer_worlds/dressing/profiles/" + id + ".json"
	var rejected: Variant = JSON.parse_string(FileAccess.get_file_as_string(rejected_path))
	var refined: Variant = JSON.parse_string(FileAccess.get_file_as_string(refined_path))
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/" + id + ".json"))
	if not raw is Dictionary:
		quit(1)
		return
	for profile: Variant in [rejected, refined]:
		_check(Profile.validate(profile, id, raw.geometryHash).is_empty(), "profile schema")
	if not _failures.is_empty():
		print("REFINEMENT_FAIL ", _failures)
		quit(1)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	var world := Map.new()
	stage.add_child(world)
	_check(world.build(raw), "map build")
	if not _failures.is_empty():
		print("REFINEMENT_FAIL ", _failures)
		quit(1)
		return
	Binder.cleanup(world)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.far = 2000
	camera.fov = float(args.get("fov", "75"))
	var origin := _coordinates(args.get("camera", "-84,13.65,13.24"))
	var target := _coordinates(args.get("target", "-84,14.3,17.64"))
	var motion := _coordinates(args.get("motion", "0,0,0"))
	var frames := clampi(int(args.get("frames", "1")), 1, 120)
	var clock := float(args.get("clock", "12"))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = _coordinates(args.get("sun", "-48,-30,0"))
	sun.light_energy = 1.0
	stage.add_child(sun)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("627985")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a0adb5")
	env.ambient_light_energy = 0.68
	environment.environment = env
	stage.add_child(environment)
	DirAccess.make_dir_recursive_absolute(directory)
	var reports := {}
	for variant: String in ["flat", "rejected", "refined"]:
		Binder.cleanup(world)
		if variant != "flat":
			# Proof-only alternate input through the production prepare/collect/detail
			# methods. This does not introduce an external-profile runtime interface.
			var binder := Binder.new()
			binder.name = "NewMapDressing"
			binder.set_meta(Binder.OWNER, true)
			binder._profile = rejected if variant == "rejected" else refined
			binder._diagnostics = {"errors": [], "matched": [], "unmatched": [], "unused_selectors": [], "preserved": [], "resources": []}
			world.add_child(binder)
			binder._prepare(world)
			binder._collect(world.get_node("BlenderArtNoGameplayCollision"))
			binder.set_detail(Binder.Detail.FULL)
			binder.set_clock_for_capture(clock)
			reports[variant] = binder.diagnostics()
			_check(binder._diagnostics.errors.is_empty() and binder._diagnostics.unmatched.is_empty(), variant + " resources/coverage")
		for frame in frames:
			var delta := motion * float(frame) / float(maxi(frames - 1, 1))
			camera.position = origin + delta
			camera.look_at(target + delta)
			await process_frame
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var path := directory.path_join(id + "-" + variant + "-%03d.png" % frame)
			_check(not FileAccess.file_exists(path), "refuse to overwrite " + path)
			if not FileAccess.file_exists(path): _check(root.get_texture().get_image().save_png(path) == OK, "capture " + path)
	Binder.cleanup(world)
	var result := {"map": id, "camera": str(origin), "target": str(target), "motion": str(motion), "frames": frames, "sun": str(sun.rotation_degrees), "clock": clock, "fov": camera.fov, "viewport": str(root.size), "rejected_sha256": FileAccess.get_sha256(rejected_path), "refined_sha256": FileAccess.get_sha256(refined_path), "reports": reports, "failures": _failures, "note": "Matched source-profile variants; inspect images. No GPU timing or visual acceptance inferred."}
	var file := FileAccess.open(directory.path_join(id + "-refinement.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result, "  "))
	print("REFINEMENT_PROOF ", JSON.stringify(result))
	quit(0 if _failures.is_empty() else 1)
