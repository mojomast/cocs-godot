extends SceneTree
const Robot = preload("res://campaign/robot_visual.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func actual_cost(node: Node) -> Dictionary:
	var result := {"draws":0, "triangles":0}
	for child: Node in node.get_children():
		if child is MeshInstance3D and child.is_visible_in_tree():
			for surface: int in range(child.mesh.get_surface_count()):
				var arrays: Array = child.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				result.draws += 1
				result.triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
		var nested: Dictionary = actual_cost(child)
		result.draws += nested.draws
		result.triangles += nested.triangles
	return result

func visible_bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first: bool = true
	for mesh: Node in node.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree(): continue
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	return result

func run() -> void:
	var leg_counts := [4, 2, 3, 4, 2, 6]
	for id: String in Robot.IDS:
		var robot := Robot.new()
		robot.automatic_animation = false
		root.add_child(robot)
		var actor := {"id":9, "npcModel":id, "health":100, "shots":0, "vx":3.0, "vz":0.0, "npcProfile":{"scale":1.6}}
		robot.configure(actor)
		check(robot.rigs[0].legs.size() == leg_counts[Robot.IDS.find(id)], id + " anatomy")
		check(is_equal_approx(robot.feet.position.y, -0.9) and is_equal_approx(robot.feet.scale.x, 1.6), "scale around feet")
		actor.vx = 0.0
		# Reproduce the real presentation transform: source y is FEET, root y+0.9.
		# Recount actual rendered geometry, not merely the decorative feet marker.
		for terrain_y: float in [-4.25, 7.5, 31.0]:
			for source_scale: float in [1.0, 1.6, 2.2]:
				actor.npcProfile.scale = source_scale
				actor.y = terrain_y
				robot.position = Vector3(12, float(actor.y) + 0.9, -8)
				robot.apply_actor(actor)
				for level: int in range(3):
					robot.set_lod(level)
					check(absf(visible_bounds(robot).position.y - terrain_y) < 0.001, id + " rendered soles match nonzero terrain at every scale/LOD")
		actor.npcProfile.scale = 1.0
		robot.position = Vector3(0, 0.9, 0)
		robot.apply_actor(actor)
		robot.set_lod(0)
		print(id, " rest dimensions=", visible_bounds(robot).size)
		var previous: int = 1000000
		for level: int in range(3):
			robot.set_lod(level)
			var cost: Dictionary = robot.visible_cost()
			var measured: Dictionary = actual_cost(robot)
			check(cost.draws == measured.draws and cost.triangles == measured.triangles, id + " every visible assembly accounted")
			check(cost.triangles < previous and cost.draws <= 18, id + " authored LOD budget")
			previous = cost.triangles
			print(id, " LOD", level, " ", cost)
		robot.set_lod(0)
		actor.vx = 3.0
		robot.apply_actor(actor)
		robot.advance(0.2)
		var phase: float = robot.gait_phase
		robot.reset_pose()
		for frame: int in range(12): robot.advance(1.0 / 60.0)
		check(absf(robot.gait_phase - phase) < 0.0001, "gait consumes all dt")
		var before: float = robot.rigs[0].legs[0].rotation.x
		robot.advance(0.1)
		check(absf(robot.rigs[0].legs[0].rotation.x - before) > 0.001, "articulation moves")
		actor.shots = 1
		robot.apply_actor(actor)
		check(robot.recoil == 1.0, "source shot recoil")
		robot.advance(0.3)
		check(robot.recoil < 0.04, "recoil recovery")
		actor.artilleryWindup = 0.6
		actor.npcArtillery = {"telegraph":1.2}
		robot.apply_actor(actor)
		check(is_equal_approx(robot.tell_strength, 0.65), "source role anticipation")
		actor.erase("artilleryWindup")
		robot.apply_actor(actor)
		check(robot.tell_strength == 0 and robot.recoil >= 0.7, "role cradle settles")
		actor.health = 0
		robot.apply_actor(actor)
		robot.advance(0.65)
		check(robot.rigs[0].body.rotation.z > 0.2, "source death collapse")
		actor.health = 100
		robot.apply_actor(actor)
		check(robot.death_elapsed == 0, "respawn clears death")
		robot.apply_actor(actor, 9)
		check(robot.visible_cost().draws == 0, "hidden cost is zero")
		robot.free()
	print("CAMPAIGN_ROBOTS_OK" if failures == 0 else "CAMPAIGN_ROBOTS_FAILED", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
