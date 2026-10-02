extends SceneTree
## Grant-gated native test. Run only after content/import/package closure exists.
const Binder = preload("res://source_operators/moth_finish/binder.gd")
const Catalog = preload("res://source_operators/generated/catalog.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for id: String in Catalog.OPERATORS:
		var packed := load("res://source_operators/generated/%s.glb" % id) as PackedScene
		var first := packed.instantiate() as Node3D
		var second := packed.instantiate() as Node3D
		root.add_child(first)
		root.add_child(second)
		var red := Binder.new()
		var blue := Binder.new()
		assert(red.bind(first,id).installed, "first binding missing: " + id)
		assert(blue.bind(second,id).installed, "second binding missing: " + id)
		assert(not red._team.is_empty(), "declared team armor has no finish binding: " + id)
		var originals: Array[Color] = []
		var material_ids: Array[int] = []
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://source_operators/moth_finish/manifest.json"))
		for slot: Dictionary in red._slots:
			var original := slot.mesh.mesh.surface_get_material(slot.surface) as StandardMaterial3D
			var applied := slot.applied as StandardMaterial3D
			var finish: Dictionary = manifest.finishes[slot.coverage.finish]
			originals.append(original.albedo_color)
			material_ids.append(slot.applied.get_instance_id())
			assert(applied.albedo_color == original.albedo_color, "initial tint/palette changed")
			assert(applied.albedo_texture == red._textures[finish.albedo])
			assert(is_equal_approx(applied.metallic, float(finish.metallic)))
			if finish.has("roughness"):
				assert(is_equal_approx(applied.roughness, float(finish.roughness_gain)), "absolute roughness texture multiplied by original scalar")
				assert(applied.roughness_texture == red._textures[finish.roughness])
				assert(applied.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED)
			assert(applied.normal_enabled == finish.has("normal"), "omitted rubber normal was invented")
			if finish.has("normal"):
				assert(applied.normal_texture == red._textures[finish.normal])
				assert(is_equal_approx(applied.normal_scale, float(finish.normal_strength)))
			for property: String in ["resource_name", "transparency", "cull_mode", "vertex_color_use_as_albedo", "vertex_color_is_srgb", "uv1_scale", "uv1_offset", "render_priority", "emission_enabled", "emission", "emission_energy_multiplier", "texture_filter"]:
				assert(applied.get(property) == original.get(property), "render trait dropped: " + property)
		red.set_team_color(Color.RED)
		blue.set_team_color(Color.BLUE)
		for iteration in 200:
			red.set_team_color(Color.GREEN if iteration % 2 == 0 else Color.RED)
		for slot: Dictionary in blue._team: assert(slot.applied.albedo_color == Color.BLUE)
		for index in red._slots.size():
			var slot: Dictionary = red._slots[index]
			assert(slot.applied.get_instance_id() == material_ids[index], "team update allocated material")
			assert(slot.mesh.mesh.surface_get_material(slot.surface).albedo_color == originals[index], "shared source mutated")
		var count := red._slots.size()
		assert(red.bind(first,id).installed)
		assert(red._slots.size() == count, "rebinding accumulated slots")
		var slots := red._slots.duplicate()
		red.clear()
		red.clear()
		for slot: Dictionary in slots: assert(slot.mesh.get_surface_override_material(slot.surface) == slot.original)
		blue.clear()
		first.free()
		second.free()
	var invalid := Binder.new()
	invalid.report = {"errors":[]}
	assert(not invalid._validate({"version":99}, {"version":1}, "meta"))
	print("OPERATOR_FINISH_LIFECYCLE_OK all nine / team isolation / 200 updates / rebind / double clear")
	quit()
