extends SceneTree
## Native ResourceLoader/skin/curve proof only; not visual/art acceptance.
const IDS := ["chatgpt", "claude", "grok", "meta", "gemini", "deepseek", "mistral", "kimi", "qwen"]
const STATES := ["idle", "walk_f", "walk_b", "crouch", "jump_rise", "jump_apex", "jump_fall", "land", "dash_f", "dash_b", "guard_hi", "guard_lo", "hit_hi", "hit_lo", "hit_air", "block_hi", "block_lo", "knockdown", "wakeup", "throw_tech", "win", "lose"]
var failures: Array = []
var checks: Array = []

func _initialize() -> void:
	call_deferred("run")

func expect(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func nodes(node: Node, kind: String) -> Array:
	var found: Array = [node] if node.is_class(kind) else []
	for child in node.get_children():
		found.append_array(nodes(child, kind))
	return found

func finite_transform(transform: Transform3D) -> bool:
	return transform.origin.is_finite() and transform.basis.x.is_finite() and transform.basis.y.is_finite() and transform.basis.z.is_finite()

func run() -> void:
	var roster: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/roster.json"))
	if not roster is Dictionary:
		failures.append("roster unavailable")
		finish()
		return
	for oid in IDS:
		var path: String = "res://fighting/assets/operators/" + oid + ".glb"
		var scene: Variant = load(path)
		if not scene is PackedScene:
			failures.append(oid + " native GLB PackedScene load")
			continue
		var body: Node = scene.instantiate()
		root.add_child(body)
		var skeletons := nodes(body, "Skeleton3D")
		var players := nodes(body, "AnimationPlayer")
		var meshes := nodes(body, "MeshInstance3D")
		expect(not skeletons.is_empty(), oid + " native skeletons")
		var skinned := 0
		for mesh in meshes:
			if mesh.mesh != null and mesh.skin != null and mesh.skin.get_bind_count() > 0:
				skinned += 1
		expect(skinned > 0, oid + " native body skins")
		var available: Array = []
		for player in players:
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			for clip in player.get_animation_list():
				available.append(str(clip))
				var animation: Animation = player.get_animation(clip)
				expect(animation.length > 0 and is_finite(animation.length), oid + ":" + clip + " finite duration")
				for track in animation.get_track_count():
					expect(animation.track_get_type(track) != Animation.TYPE_METHOD, oid + ":" + clip + " no gameplay method callbacks")
				player.play(clip)
				for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
					player.seek(animation.length * fraction, true)
					player.advance(0.0)
					for skeleton in skeletons:
						for bone in skeleton.get_bone_count():
							expect(finite_transform(skeleton.get_bone_rest(bone)), oid + " finite native bone rest")
							expect(finite_transform(skeleton.get_bone_global_pose(bone)), oid + ":" + clip + " finite native pose")
		checks.append({"id": oid, "native_meshes": meshes.size(), "skinned_meshes": skinned, "skeletons": skeletons.size(), "animation_names": available})
		body.free()
	var visual: Variant = load("res://fighting/visuals/fighter_visual.gd")
	expect(visual != null, "fighter visual native class load")
	if visual != null:
		for oid in IDS:
			var instance: Variant = visual.new()
			root.add_child(instance)
			expect(instance.configure(oid), oid + " real visual configure")
			var configured_players := nodes(instance, "AnimationPlayer")
			var configured_skeletons := nodes(instance, "Skeleton3D")
			var resolved := {}
			for player in configured_players:
				player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				for qualified in player.get_animation_list():
					var clip: String = str(qualified).get_file()
					if not player.has_animation(qualified):
						continue
					var animation: Animation = player.get_animation(qualified)
					expect(animation != null and animation.length > 0, oid + " resolved library resource " + qualified)
					resolved[clip] = str(qualified)
					player.play(qualified)
					for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
						player.seek(animation.length * fraction, true)
						player.advance(0.0)
						for skeleton in configured_skeletons:
							for bone in skeleton.get_bone_count():
								expect(finite_transform(skeleton.get_bone_global_pose(bone)), oid + ":" + qualified + " configured finite native pose")
			for required in STATES:
				expect(resolved.has(required), oid + " resolved state clip " + required)
			for operator in roster.operators:
				if operator.id == oid:
					for move in operator.moves.values():
						expect(resolved.has(move.animation), oid + " resolved data clip " + move.animation)
				for mid in operator.moves:
					var move: Dictionary = operator.moves[mid]
					if move.has("throw") or move.get("counter", {}).get("strike", false):
						var victim_clip: String = "victim_" + operator.id + "_" + mid
						expect(resolved.has(victim_clip), oid + " resolved paired alias " + victim_clip)
			checks.append({"id": oid + "-configured-libraries", "resolved": resolved, "contact_anatomy": "unrun per mesh/socket"})
			instance.reset()
			instance.free()
	finish()

func finish() -> void:
	var report := {"status": "passed" if failures.is_empty() else "failed", "checks": checks, "failures": failures, "unrun": [],
		"art_acceptance": "unrun", "contact_anatomy": "unrun", "capture": "unrun"}
	var output := OS.get_environment("FIGHTING_ACCEPTANCE_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	if failures.is_empty():
		print("FIGHTING_ACCEPTANCE_ASSETS_OK")
	quit(0 if failures.is_empty() else 1)
