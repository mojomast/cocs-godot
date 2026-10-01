extends SceneTree
## Native replay of source-produced wire states, plus actual recipe colliders.
const Director = preload("res://campaign/interlude_director.gd")
const Model = preload("res://campaign/model.gd")
const Terrain = preload("res://campaign/terrain.gd")
const Widgets = preload("res://campaign/story_widgets.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var source := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixtures="): source = arg.trim_prefix("--fixtures=")
	assert(not source.is_empty())
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string(source))
	assert(fixtures.size() == 8)
	var director := Director.new()
	root.add_child(director)
	var widgets := Widgets.new()
	root.add_child(widgets)
	var world: Node3D
	var map_id := ""
	for fixture: Dictionary in fixtures:
		if fixture.mapId != map_id:
			if is_instance_valid(world): world.free()
			world = Terrain.new()
			root.add_child(world)
			assert(world.build(fixture.mapId))
			map_id = fixture.mapId
			assert(world.recipe.geometryHash == fixture.geometryHash)
			var colliders: Node = world.get_node("AuthoritativeBlocks")
			assert(colliders.get_child_count() == world.recipe.arena.blocks.size())
			for i: int in world.recipe.arena.blocks.size():
				var block: Dictionary = world.recipe.arena.blocks[i]
				if not str(block.id).begins_with("interlude-"): continue
				var collider: CollisionShape3D = colliders.get_child(i)
				assert(collider.shape.size.is_equal_approx(Vector3(block.w, block.h, block.d)))
				assert(collider.position.is_equal_approx(Vector3(block.x, block.h*0.5, block.z)))
			for route: Dictionary in world.recipe.routes:
				if not str(route.id).begins_with("interlude-"): continue
				for p: Dictionary in route.points: assert(absf(world.height_at(p.x,p.z)-float(p.y)) < 0.001)
		for state: Dictionary in [fixture.before,fixture.linked,fixture.after]:
			var model := Model.new()
			if not model.apply(state):
				printerr("WORKSHOP_MODEL_ERROR ",model.error," ",JSON.stringify(state.interludes))
				quit(1)
				return
			director.apply(state.interludes, map_id)
			widgets.observe(state.story,true,state.interludes)
			assert(director.workshops.size() == 2)
			for beat: Dictionary in state.interludes.beats:
				var node: Node3D = director.workshops[beat.id]
				assert(node.get_meta("stage") == int(beat.stage))
				assert(node.get_meta("lamps").size() == 2)
				assert(node.get_meta("wires").size() == beat.cable.size()-1)
				assert(node.find_children("*","CollisionObject3D",true,false).is_empty(), "Moving workshop ornaments cannot invent geometry")
				if beat.completed:
					assert(node.get_meta("title").text.contains("RESTORED"))
					for panel: MeshInstance3D in node.get_meta("panels"): assert(panel.material_override.emission_enabled)
		assert(widgets.caption.text == "%s: %s" % [fixture.after.interludes.feedback.speaker,fixture.after.interludes.feedback.text])
		var bad: Dictionary = fixture.after.interludes.duplicate(true)
		bad.beats[0].a.x = INF
		assert(not Model.valid_interludes(bad))
		print("CAMPAIGN_INTERLUDE_NATIVE_OK ",map_id," ",fixture.id)
	widgets.observe({},false)
	assert(not widgets.prompt.visible and not widgets.caption.visible)
	world.free()
	widgets.free()
	director.free()
	quit()
