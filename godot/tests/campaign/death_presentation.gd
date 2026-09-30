extends SceneTree
## Integration: real robot/source visuals through the shared actor presenter.
const Presentation = preload("res://world/presentation.gd")
const Robot = preload("res://campaign/robot_visual.gd")
const Source = preload("res://source_operators/operator_visual.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr(message)

func actor(id: int, robot: bool = true) -> Dictionary:
	var value := {"id":id, "character":"claude", "team":1, "x":1.0, "y":2.0, "z":3.0,
		"yaw":0.0, "pitch":0.0, "health":100, "dead":0.0, "shots":0, "weapon":0,
		"vx":0.0, "vz":0.0, "ammo":[30], "eyeHeight":1.45}
	if robot: value.npcModel = "scrapper"
	return value

func visual_factory(value: Dictionary, local_id: int) -> Node3D:
	if value.get("npcModel") in Robot.IDS:
		var visual := Robot.new()
		visual.automatic_animation = false
		visual.configure(value, local_id)
		return visual
	return Source.new()

func run() -> void:
	var view := Presentation.new()
	view.actor_visual_factory = visual_factory
	root.add_child(view)
	var remote := actor(1)
	var fallback := actor(2, false)
	var local := actor(9)
	view.apply_state({"actors":[remote, fallback, local]}, 9)
	var robot: Node3D = view.actors[1]
	var local_robot: Node3D = view.actors[9]
	check(robot.visible and not robot.wants_death_pose(), "Healthy remote robot is visible without death opt-in")
	check(local_robot.local_id == 9 and not local_robot.visible, "One-argument apply_actor preserves assigned local identity")
	check(robot.position.is_equal_approx(Vector3(1, 2.9, 3)), "Death seam retains authoritative feet-to-root transform")
	for value: Dictionary in [remote, fallback, local]:
		value.health = 0
		value.dead = 2.5
	view.apply_state({"actors":[remote, fallback, local]}, 9)
	check(robot.visible and robot.wants_death_pose(), "First dead snapshot shows remote robot collapse")
	check(not view.actors[2].visible, "Source fallback still hides immediately on death")
	check(not local_robot.visible and not view.lifecycle.can_control(), "Cosmetic death pose never shows local body or enables controls")
	var rig: Dictionary = robot.rigs[robot.lod_level]
	var start_height: float = rig.body.position.y
	robot.advance(0.65)
	check(robot.visible and rig.body.position.y < start_height - 0.3, "Visible robot reaches its actual collapse pose")
	view.apply_state({"actors":[remote, fallback, local]}, 9)
	check(robot.visible and is_equal_approx(robot.death_elapsed, 0.65), "Repeated dead snapshots do not reset collapse clock")
	robot.advance(0.16)
	check(not robot.visible and not robot.wants_death_pose(), "Corpse expires without waiting for another snapshot")
	view.apply_state({"actors":[remote, fallback, local]}, 9)
	check(not robot.visible, "Later snapshots cannot resurrect an expired cosmetic corpse")
	remote.health = 100
	remote.dead = 0
	view.apply_state({"actors":[remote, fallback, local]}, 9)
	check(robot.visible and is_zero_approx(robot.death_elapsed), "Healthy authoritative actor resets death pose")
	remote.health = 0
	remote.dead = 2.5
	view.apply_state({"actors":[remote, fallback, local]}, 9)
	check(robot.visible and robot.wants_death_pose(), "A later death gets its own bounded collapse")
	view.apply_state({"actors":[fallback, local]}, 9)
	check(not is_instance_valid(robot), "Authority removal still retires corpse immediately")
	view.clear_round()
	view.free()
	# No factory means the historical source route, even with npcModel on the wire.
	var source_view := Presentation.new()
	root.add_child(source_view)
	source_view.apply_state({"actors":[remote]}, 9)
	check(source_view.actors[1].get_script() == Source and not source_view.actors[1].visible, "Default route keeps source visual and immediate death hiding")
	source_view.clear_round()
	source_view.free()
	print("CAMPAIGN_DEATH_PRESENTATION_OK" if failures.is_empty() else "CAMPAIGN_DEATH_PRESENTATION_FAILED")
	quit(0 if failures.is_empty() else 1)
