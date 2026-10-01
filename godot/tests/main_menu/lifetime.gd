extends SceneTree
## Reproduces menu scene removal while the real replay terrain is still being built.
const Stage = preload("res://ui/attract/demo.gd")
var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
	print(("PASS " if ok else "FAIL ") + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for chapter: int in 3:
		var scene := Node.new()
		root.add_child(scene)
		var stage := Stage.new()
		scene.add_child(stage)
		stage.start()
		check(stage.building and stage.world != null and not stage.scene_ready,
			"chapter %d begins a real incremental terrain build" % chapter)
		for step: int in range(chapter): stage._step_terrain()
		check(stage.building and stage.build_surface_index < stage.build_recipe.arena.terrain.surfaces.size(),
			"chapter %d remains part-built at removal" % chapter)
		var old_stage: WeakRef = weakref(stage)
		root.remove_child(scene)
		scene.queue_free()
		var replacement := Node.new()
		root.add_child(replacement)
		current_scene = replacement
		for _tick: int in 4: await process_frame
		check(old_stage.get_ref() == null and root.find_children("*", "WorldEnvironment", true, false).is_empty(),
			"chapter %d teardown frees the partial world with no deferred resumption" % chapter)
		current_scene = null
		root.remove_child(replacement)
		replacement.free()
	print("MENU_ATTRACT_LIFETIME_OK" if not failed else "MENU_ATTRACT_LIFETIME_FAILED")
	quit(1 if failed else 0)
