extends SceneTree
## Prepared native harness; run only under the exclusive native grant.
## godot --path godot --script res://tests/map_finish/proof.gd --
##   --map=helix-conservatory --proof-dir=/absolute/evidence
## Optional --camera=x,y,z --target=x,y,z for authored district closeups.
const Binder = preload("res://multiplayer_worlds/dressing/binder.gd")
const Profile = preload("res://multiplayer_worlds/dressing/profile.gd")
const Map = preload("res://multiplayer_worlds/map.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, reason: String) -> void:
	if not condition: _failures.append(reason)

func _run() -> void:
	var args := {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var pair := arg.trim_prefix("--").split("=", true, 1)
			args[pair[0]] = pair[1]
	var id: String = args.get("map", "helix-conservatory")
	if not Profile.IDENTITIES.has(id):
		print("DRESSING_PROOF_FAIL unsupported map")
		quit(1)
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer_worlds/generated/" + id + ".json"))
	if not raw is Dictionary:
		print("DRESSING_PROOF_FAIL missing authority input")
		quit(1)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	var world := Map.new()
	stage.add_child(world)
	_check(world.build(raw), "map build")
	var hash: String = raw.geometryHash
	var initial := Binder.apply(world, id, hash)
	_check(initial.status == "ready", "profile/resource/selector coverage: " + str(initial))
	Binder.set_root_detail(world, Binder.Detail.OFF)
	var originals: Array[Dictionary] = []
	_snapshot(world.get_node_or_null("BlenderArtNoGameplayCollision"), originals)
	var profile_path := "res://multiplayer_worlds/dressing/profiles/" + id + ".json"
	var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile_path)) if FileAccess.file_exists(profile_path) else null
	if p is Dictionary:
		_negative_cases(p, id, hash)
		_verify_mounts(world, p)
	var owned_max := 0
	for iteration in 3:
		for level in [Binder.Detail.OFF, Binder.Detail.LOW, Binder.Detail.FULL]:
			Binder.set_root_detail(world, level)
			var owned := 0
			for child: Node in world.get_children():
				if child.get_meta(Binder.OWNER, false):
					owned += 1
					var d: Dictionary = child.diagnostics()
					_check(d.errors.is_empty(), "detail errors " + str(d.errors))
					_check(d.motes <= 96 and d.panels <= 96 and d.signs <= 24, "bounded counts")
					if level == Binder.Detail.OFF: _check(child.get_child_count() == 0 and d.surfaces == 0, "Off release")
					if level == Binder.Detail.LOW: _check(d.motes == 0, "Low motes")
			owned_max = maxi(owned_max, owned)
		Binder.apply(world, id, hash)
	_check(owned_max == 1, "idempotent owned root")
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.far = 2000
	camera.fov = float(args.get("fov", "75"))
	camera.position = _coordinates(args.get("camera", "55,35,55"))
	camera.look_at(_coordinates(args.get("target", "0,3,0")))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
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
	var directory: String = args.get("proof-dir", "")
	if directory != "":
		DirAccess.make_dir_recursive_absolute(directory)
		for level in [Binder.Detail.OFF, Binder.Detail.LOW, Binder.Detail.FULL]:
			Binder.set_root_detail(world, level)
			for child: Node in world.get_children():
				if child.get_meta(Binder.OWNER, false): child.set_clock_for_capture(float(args.get("clock", "12")))
			await process_frame
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var path := directory.path_join(id + "-" + str(level) + ".png")
			_check(root.get_texture().get_image().save_png(path) == OK, "capture " + path)
	var frame_usec: Array[int] = []
	var previous := Time.get_ticks_usec()
	for i in 60:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_usec.append(now - previous)
		previous = now
	Binder.cleanup(world)
	_check(world.get_node_or_null("NewMapDressing") == null, "cleanup")
	for original: Dictionary in originals:
		_check(original.node.mesh.surface_get_material(original.index) == original.material, "immutable mesh surface")
		_check(original.node.get_surface_override_material(original.index) == original.override, "restored original override")
	var reloaded := Binder.apply(world, id, hash)
	_check(reloaded.status == "ready", "reload coverage")
	var result := {"map": id, "initial": initial, "reloaded": reloaded, "failures": _failures, "owned_max": owned_max, "frame_usec": frame_usec, "renderer": RenderingServer.get_video_adapter_name(), "rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"), "camera": str(camera.position), "fov": camera.fov, "viewport": str(root.size), "clock": float(args.get("clock", "12")), "evidence_note": "frame cadence is not a GPU FPS measurement; images require human route/district review"}
	if directory != "":
		var file := FileAccess.open(directory.path_join(id + "-diagnostics.json"), FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result, "  "))
	print("DRESSING_PROOF ", JSON.stringify(result))
	quit(0 if _failures.is_empty() else 1)

func _negative_cases(p: Dictionary, id: String, hash: String) -> void:
	_check(Profile.validate(p, id, hash).is_empty(), "valid native schema")
	for patch: Dictionary in [{"version": 2}, {"geometry_hash": "bad"}, {"unknown": 1}, {"budgets": {"material_variants": {}, "panels": 999, "signs": -1, "motes": 1.5}}, {"panels": [{"id": "a", "texture": "invented", "position": [0, 0, 0], "rotation_degrees": [0, 0, 0], "size": [1, 1], "tint": "ffffff"}]}, {"materials": [{"source": "a", "family": "invented", "options": {"typo": 1}}]}, {"pockets": [{"id": "a", "kind": "invented", "position": [0, 0, 0], "size": [1, 1, 1], "color": "ffffff", "count": 999}]}]:
		var bad := p.duplicate(true)
		bad.merge(patch, true)
		_check(not Profile.validate(bad, id, hash).is_empty(), "negative schema case " + str(patch))

func _verify_mounts(world: Node3D, p: Dictionary) -> void:
	# Proof-only triangle scan, never in the production frame or load path.
	var faces: Array[Vector3] = []
	var art := world.get_node_or_null("BlenderArtNoGameplayCollision")
	if art == null: return
	_faces(art, world, faces)
	for group: String in ["panels", "signs"]:
		for entry: Dictionary in p[group]:
			var basis := Basis.from_euler(Vector3(entry.rotation_degrees[0], entry.rotation_degrees[1], entry.rotation_degrees[2]) * PI / 180.0)
			var center := Vector3(entry.position[0], entry.position[1], entry.position[2])
			for x: float in [-0.5, 0.0, 0.5]:
				for y: float in [-0.5, 0.0, 0.5]:
					var point := center + basis * Vector3(x * entry.size[0], y * entry.size[1], 0)
					var mounted := false
					for index in range(0, faces.size(), 3):
						var hit: Variant = Geometry3D.ray_intersects_triangle(point, -basis.z, faces[index], faces[index + 1], faces[index + 2])
						if hit is Vector3 and point.distance_to(hit) >= 0.004 and point.distance_to(hit) <= 0.101:
							mounted = true
							break
					_check(mounted, "unmounted face sample: " + entry.id + " " + str(point))

func _faces(node: Node, world: Node3D, faces: Array[Vector3]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var transform: Transform3D = world.global_transform.affine_inverse() * node.global_transform
		for point: Vector3 in node.mesh.get_faces(): faces.append(transform * point)
	for child: Node in node.get_children(): _faces(child, world, faces)

func _coordinates(text: String) -> Vector3:
	var v := text.split(",")
	return Vector3(float(v[0]), float(v[1]), float(v[2]))

func _snapshot(node: Node, result: Array[Dictionary]) -> void:
	if node == null: return
	if node is MeshInstance3D and node.mesh != null:
		for index in node.mesh.get_surface_count():
			result.append({"node": node, "index": index, "material": node.mesh.surface_get_material(index), "override": node.get_surface_override_material(index)})
	for child: Node in node.get_children(): _snapshot(child, result)
