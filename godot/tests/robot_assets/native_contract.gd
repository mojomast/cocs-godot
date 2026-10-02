extends SceneTree
## Post-grant: headless import first; then run this script with the pinned engine.
const Robot = preload("res://campaign/robot_visual.gd")
const Adapter = preload("res://robot_assets/switchyard/skin_adapter.gd")
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _initialize() -> void:
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
		robot.free()
	for message: String in failures: push_error(message)
	print("SWITCHYARD_NATIVE ", JSON.stringify({"failures":failures,"skins":Adapter.SKINS.size()}))
	quit(0 if failures.is_empty() else 1)
