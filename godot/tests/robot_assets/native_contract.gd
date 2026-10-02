extends SceneTree
## Post-grant: headless import first; then run this script with the pinned engine.
const Robot = preload("res://campaign/robot_visual.gd")
const Adapter = preload("res://robot_assets/switchyard/skin_adapter.gd")
const Campaign = preload("res://campaign/demo.gd")
const Horde = preload("res://horde/demo.gd")
const Terrain = preload("res://campaign/terrain.gd")
var failures: Array[String] = []
var checks := 0
var results: Array[Dictionary] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value and message not in failures: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	for skin: String in Adapter.SKINS:
		var robot := Robot.new()
		robot.automatic_animation = false
		robot.automatic_lod = false
		root.add_child(robot)
		var actor := {"id":22,"npcModel":Adapter.SKINS[skin],"health":100,"armor":10,"grounded":true,"vx":0.0,"vz":0.0,"shots":0,"yaw":0.0,"pitch":0.0}
		robot.configure(actor)
		var original_mesh: Mesh = robot.batches[0].mesh
		var original: Dictionary = actor.duplicate(true)
		check(Adapter.install(robot, skin), skin + " real complete GLB required")
		check(robot.armor_material.albedo_texture != null, "Moth texture survives override")
		check(robot.optic_material.albedo_texture != null, "live optic texture")
		check(robot.armor_material.vertex_color_use_as_albedo, "palette multiplied")
		check(not robot.armor_material.normal_enabled, "coating no forced normal map")
		for batch: MeshInstance3D in robot.batches:
			var arrays := batch.mesh.surface_get_arrays(0)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			check(not colors.is_empty(), "imported COLOR_0 exists")
			var colored := false
			for color: Color in colors:
				if color.r < .8 or color.g < .8 or color.b < .8: colored = true; break
			check(colored, "COLOR_0 carries palette instead of exporter white placeholder")
		var soles: Array[float] = []
		for knee: Node3D in robot.rigs[0].knees:
			var mesh: MeshInstance3D = knee.get_child(0)
			var low := INF
			for point: Vector3 in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				low = minf(low, mesh.to_global(point).y - robot.feet.global_position.y)
			soles.append(low)
			check(absf(low) < 0.035, "imported neutral sole contact " + skin)
		results.append({"skin":skin,"neutralSoles":soles})
		check(actor == original, "installation cannot mutate actor")
		check(robot.feet.position == Vector3(0,-0.9,0), "feet anchor")
		for level: int in range(3):
			robot.set_lod(level)
			for phase: String in ["idle","walk","attack","react","death"]:
				robot.reset_pose()
				actor.health = 0 if phase == "death" else 100
				actor.vz = -1.5 if phase == "walk" else 0.0
				actor.campaignAttackWindup = 1.0 if phase == "attack" else 0.0
				robot.apply_actor(actor)
				if phase == "react": robot.hit_reaction = 1
				for frame: int in range(25):
					robot.advance(1.0/30.0)
					check(robot.position == Vector3.ZERO, "animation never moves authority root")
					for batch: MeshInstance3D in robot.batches:
						check(batch.global_transform.origin.is_finite(), "finite pose")
						check(batch.mesh.get_aabb().size.is_finite(), "finite bounds")
				if phase == "death": check(not robot.wants_death_pose(), "corpse teardown at .8 seconds")
		Adapter.restore(robot)
		check(robot.batches[0].mesh == original_mesh, "original skin restored")
		Adapter.install_role(robot)
		robot.configure({"id":22,"npcModel":"sentinel","health":100})
		check(not robot.has_meta("switchyard_skin") and robot.armor_material.albedo_texture == null, "unmapped identity restores stock finish")
		robot.configure({"id":22,"npcModel":Adapter.SKINS[skin],"health":100})
		check(robot.get_meta("switchyard_skin", "") == skin, "respawn identity reapplies selected pack")
		Adapter.select_stock(robot)
		check(not robot.get_meta("switchyard_enabled") and not robot.has_meta("switchyard_skin"), "explicit stock selection")
		robot.free()
	for script: GDScript in [Campaign, Horde]:
		var host: Node = script.new()
		for role: String in Adapter.ROLE_SKIN:
			var actor := {"id":32, "isNpc":true, "npcModel":role, "health":100}
			var visual: Node3D = host.create_visual(actor, -1) if script == Campaign else host.create_horde_visual(actor, -1)
			check(visual.get_meta("switchyard_skin", "") == Adapter.ROLE_SKIN[role], "production factory " + role)
			visual.free()
		# Constructors own unattached presentation helpers; free them explicitly in
		# this factory-only probe, as _ready()/session teardown is not entered.
		for property: Dictionary in host.get_property_list():
			if property.type == TYPE_OBJECT and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var value: Variant = host.get(property.name)
				if is_instance_valid(value) and value is Node and value.get_parent() == null: value.free()
		host.free()
	var terrain := Terrain.new()
	root.add_child(terrain)
	check(terrain.build("emberline-ascent"), "production Emberline build")
	var workshop: Node3D = terrain.get_node("SwitchyardWorkshop")
	check(workshop.installed.size() == 6, "six production prop mounts")
	check(workshop.find_children("*", "CollisionObject3D", true, false).is_empty(), "no new collision objects")
	var first: Array = workshop.installed.duplicate(true)
	workshop.build(terrain)
	check(workshop.installed == first and workshop.get_child_count() == 6, "mount rebuild is deterministic without duplicates")
	results.append({"workshop":first})
	terrain.free()
	for message: String in failures: push_error(message)
	var report := {"failures":failures,"checks":checks,"skins":Adapter.SKINS.size(),"results":results}
	var directory := OS.get_environment("ASSET_STAGE_EVIDENCE")
	if not directory.is_empty():
		var file := FileAccess.open(directory.path_join("native.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  "))
	print("SWITCHYARD_NATIVE ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
