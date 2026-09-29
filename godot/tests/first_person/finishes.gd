extends SceneTree
const Rig = preload("res://first_person/rig.gd")
const Catalog = preload("res://first_person/generated/finishes.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func actor(id: int, weapon_id: int, finish_id: Variant) -> Dictionary:
	return {"id":id, "weapon":weapon_id, "health":100, "finish":finish_id}

func matches(rig: Node, palette: Dictionary) -> bool:
	for slot: Dictionary in rig.finish.slots:
		var material: StandardMaterial3D = slot.material
		var expected: Color = slot.base
		if not palette.is_empty():
			var source: Array = palette.linear[slot.role]
			expected = Color(source[0],source[1],source[2])
		if not material.albedo_color.is_equal_approx(expected): return false
		if slot.role == "glow":
			var emission: Color = expected if not palette.is_empty() else slot.emission
			if not material.emission.is_equal_approx(emission): return false
	return not rig.finish.slots.is_empty()

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	var rig := Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	var second := Rig.new()
	root.add_child(second)
	second.attach_to(camera)
	second.set_process(false)
	var stock := actor(7, 0, null)
	rig.apply_actor(stock, true)
	second.apply_actor(stock, true)
	check(matches(rig, {}), "imported stock materials preserved")
	var role_set: Dictionary = {}
	var material_ids: Array[int] = []
	var imported: Array[Color] = []
	for slot: Dictionary in rig.finish.slots:
		imported.append(slot.base)
		role_set[slot.role] = true
		material_ids.append((slot.material as Material).get_instance_id())
	check(role_set.size() == 3 and role_set.has("dark") and role_set.has("light") and role_set.has("glow"), "all source roles bound")
	for key: String in Catalog.PALETTES:
		var snapshot := actor(7, 0, key)
		var frozen := snapshot.duplicate(true)
		rig.apply_actor(snapshot, true)
		check(matches(rig, Catalog.PALETTES[key]), "source role palette " + key)
		check(snapshot == frozen, "snapshot unmodified " + key)
		check(matches(second, {}), "other rig remains stock " + key)
		var writes: int = rig.finish.write_count
		var original_instance := rig.weapon.get_instance_id()
		for i: int in 200: rig.apply_actor(snapshot, true)
		check(rig.finish.write_count == writes and rig.weapon.get_instance_id() == original_instance,
			"identical snapshots do not rebuild or allocate " + key)
	for value: Variant in [null, "future-finish", 5, {}, []]:
		rig.apply_actor(actor(7, 0, "finish-ion"), true)
		rig.apply_actor(actor(7, 0, value), true)
		check(matches(rig, {}), "null, malformed or unknown restores stock: " + str(value))
	var after_ids: Array[int] = []
	for slot: Dictionary in rig.finish.slots: after_ids.append((slot.material as Material).get_instance_id())
	check(after_ids == material_ids, "finish swaps reuse the same bounded material resources")
	rig.apply_actor({"id":7,"weapon":0,"health":100}, true)
	check(matches(rig, {}), "missing finish restores stock")
	for id: int in 10:
		rig.apply_actor(actor(7, id, "finish-ember"), true)
		check(matches(rig, Catalog.PALETTES["finish-ember"]), "weapon switch role coverage %d" % id)
		var roles: Dictionary = {}
		for slot: Dictionary in rig.finish.slots: roles[slot.role] = true
		check(roles.size() == 3, "all source roles populated on weapon %d" % id)
		rig.apply_actor(actor(7, id, null), true)
		check(matches(rig, {}), "weapon switch restores stock %d" % id)
	rig.apply_actor(actor(7, 0, "finish-toxic"), true)
	for hidden: Dictionary in [{"id":7,"weapon":0,"health":0}, {"id":7,"weapon":0,"health":100,"vehicleId":4},
		{"id":7,"weapon":0,"health":100,"spectating":true}]:
		rig.apply_actor(hidden, true)
		check(matches(rig, {}), "hidden state clears finish")
		rig.apply_actor(actor(7, 0, "finish-toxic"), true)
	rig.apply_actor(actor(8, 0, null), true)
	check(matches(rig, {}), "actor switch clears old finish")
	rig.apply_actor(actor(8, 0, "finish-ion"), true)
	rig.reset()
	check(matches(rig, {}), "disconnect/reset clears finish")
	rig.apply_actor(actor(9, 0, "finish-crimson"), true)
	check(matches(rig, Catalog.PALETTES["finish-crimson"]), "reconnect uses new snapshot")
	rig.apply_actor(actor(9, 0, null), true)
	check(matches(rig, {}), "next match stock source snapshot")
	check(rig.finish.slots.size() == imported.size(), "material slot count bounded")
	rig.free()
	second.free()
	camera.free()
	print("FIRST_PERSON_FINISHES ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
