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
		for slot: Dictionary in red._slots:
			originals.append((slot.mesh.mesh.surface_get_material(slot.surface) as StandardMaterial3D).albedo_color)
			material_ids.append(slot.applied.get_instance_id())
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
