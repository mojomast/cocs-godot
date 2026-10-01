extends SceneTree
## Live reviewed-art contract. The canonical source exporter has independent
## provenance tests; this exercises the shipping model substitution itself.
const Rig = preload("res://first_person/rig.gd")
const Visual = preload("res://source_operators/operator_visual.gd")
const Catalog = preload("res://first_person/generated/catalog.gd")
var failures: Array[String] = []
var metrics: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func art_meshes(model: Node3D) -> Array[MeshInstance3D]:
	var list: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D"):
		if mesh.has_meta("blender_art"): list.append(mesh)
	return list

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	var rig := Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	var visual := Visual.new()
	root.add_child(visual)
	var other := Visual.new()
	root.add_child(other)
	for id: int in range(10):
		var actor := {"id":7,"weapon":id,"health":100,"character":"claude","team":2}
		rig.apply_actor(actor,true)
		visual.apply_actor({"id":8,"weapon":id,"health":100,"character":"claude","team":2})
		var source_meshes := 0
		for mesh: MeshInstance3D in rig.weapon.find_children("*", "MeshInstance3D"):
			if not mesh.has_meta("blender_art"):
				source_meshes += 1
				check(not mesh.visible,"canonical mesh hidden %d" % id)
		var fp := art_meshes(rig.weapon)
		var world := art_meshes(visual.world_weapon)
		check(source_meshes == 8,"source assembly still eight batches %d" % id)
		check(fp.size() >= 8 and fp.size() <= 16,"first-person art installed %d" % id)
		check(world.size() >= 8 and world.size() <= 16,"world art installed %d" % id)
		check(rig.get_muzzle_count() == Catalog.WEAPONS[id].muzzles.size(),"muzzles unchanged %d" % id)
		for anchor: String in ["SightRear","SightFront","GripRight","GripSupport","GripReload","Muzzle0"]:
			check(rig.anchors.has(anchor) and rig.anchors[anchor] != null,"anchor %s %d" % [anchor,id])
		check(visual.world_weapon.find_child("WeaponGripLeft",true,false) != null,"world left grip %d" % id)
		check(visual.world_weapon.find_child("WeaponGripRight",true,false) != null,"world right grip %d" % id)
		var feed := rig.parts["feed"] as Node3D
		var painted_feed: MeshInstance3D = null
		for mesh: MeshInstance3D in fp:
			if str(mesh.name).begins_with("feed-"):
				painted_feed = mesh
				break
		check(painted_feed != null and feed.is_ancestor_of(painted_feed),"feed art follows moving source pivot %d" % id)
		var old_position: Vector3 = painted_feed.global_position if painted_feed != null else Vector3.ZERO
		feed.position.y -= .04
		if painted_feed != null: check(painted_feed.global_position.distance_to(old_position) > .039,"feed animates %d" % id)
		feed.transform = rig.rest["feed"]
		rig.apply_actor(actor.merged({"finish":"finish-ion"}),true)
		visual.apply_actor({"id":8,"weapon":id,"health":100,"character":"claude","team":2,"finish":"finish-ion"})
		check(not rig.finish.slots.is_empty(),"finish slots %d" % id)
		check(rig.finish.active == "finish-ion","finish binding active %d" % id)
		check(visual.weapon_finish.active == "finish-ion","world finish binding active %d" % id)
		other.apply_actor({"id":9,"weapon":id,"health":100,"character":"claude","team":2})
		check(other.weapon_finish.slots.size() == visual.weapon_finish.slots.size(),"matching finish slot layouts %d" % id)
		for slot: int in mini(other.weapon_finish.slots.size(), visual.weapon_finish.slots.size()):
			check(other.weapon_finish.slots[slot].material != visual.weapon_finish.slots[slot].material,"private tint material %d/%d" % [id,slot])
			check(other.weapon_finish.slots[slot].material.albedo_color == other.weapon_finish.slots[slot].base,"other actor retains stock color %d/%d" % [id,slot])
		metrics.append({"id":id,"firstPerson":fp.size(),"world":world.size(),"source":source_meshes,"finishSlots":rig.finish.slots.size(),"worldFinishSlots":visual.weapon_finish.slots.size()})
		await process_frame
	visual.free()
	other.free()
	rig.free()
	camera.free()
	await process_frame
	print("BLENDER_WEAPON_ART ",JSON.stringify({"passed":failures.is_empty(),"weapons":metrics,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
