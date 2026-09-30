extends Node3D
## Snapshot presentation only. No colliders, input handling, or story progression.
const Puppy = preload("res://campaign/puppy_visual.gd")
const Operator = preload("res://source_operators/operator_visual.gd")
var actors: Dictionary = {}
var last_serial: Dictionary = {}
var story: Dictionary = {}
var chapter := ""

func clear_round() -> void:
	for actor: Node3D in actors.values(): actor.queue_free()
	actors.clear()
	last_serial.clear()
	story.clear()
	chapter = ""

func apply(value: Dictionary, map_id: String) -> void:
	if chapter != map_id:
		clear_round()
		chapter = map_id
	story = value
	var present := {}
	for entity: Dictionary in value.get("entities", []):
		if not entity.get("active", false): continue
		var id: String = entity.id
		present[id] = true
		var visual: Node3D = actors.get(id)
		var created := visual == null
		if created:
			visual = Puppy.new() if entity.kind == "puppy" else Operator.new()
			visual.name = "Story_" + id.validate_node_name()
			add_child(visual)
			actors[id] = visual
			if entity.kind == "operator":
				visual.call("apply_actor", {"character":entity.get("character", "chatgpt"), "team":"blue", "id":-10, "health":100})
				visual.set("automatic_animation", false)
				var nodes: Dictionary = visual.get("nodes")
				if nodes.has("weapon"): nodes.weapon.hide()
		var goal := Vector3(float(entity.x), float(entity.y), float(entity.z))
		if not visual.has_meta("story_placed"):
			visual.position = goal
			visual.set_meta("story_placed", true)
		else:
			var distance := visual.position.distance_to(goal)
			# An authority cut to a distant staging point is not a visible teleport.
			if distance > 8:
				visual.hide()
				visual.position = goal
				visual.set_meta("story_reveal", 0.35)
			else:
				visual.position = goal if distance < 0.3 else visual.position.move_toward(goal, 0.3)
		visual.rotation.y = float(entity.yaw)
		var serial: int = int(entity.get("reactionSerial", 0))
		if not created and last_serial.has(id) and serial > int(last_serial[id]) and entity.kind == "puppy": visual.call("pet")
		last_serial[id] = maxi(serial, int(last_serial.get(id, serial)))
		if entity.kind == "puppy": visual.call("set_pose", str(entity.pose))
		else:
			var pose: String = str(entity.pose)
			visual.set("snapshot", {"yaw":float(entity.yaw), "bodyYaw":float(entity.yaw), "vx":sin(float(entity.yaw)) * 1.4 if pose == "walk" else 0.0, "vz":-cos(float(entity.yaw)) * 1.4 if pose == "walk" else 0.0, "grounded":true, "ads":pose == "point", "crouching":pose == "work"})
			visual.set_meta("story_pose", pose)
	for id: String in actors.keys():
		if present.has(id): continue
		actors[id].queue_free()
		actors.erase(id)
		# Keep serial baseline for temporarily inactive entities in this chapter.

func _process(dt: float) -> void:
	var camera := get_viewport().get_camera_3d()
	for id: String in actors:
		var visual: Node3D = actors[id]
		if camera:
			var distance := visual.global_position.distance_to(camera.global_position)
			var reveal := maxf(0, float(visual.get_meta("story_reveal", 0.0)) - dt)
			visual.set_meta("story_reveal", reveal)
			visual.visible = distance < 90 and reveal <= 0
			visual.call("select_distance", distance)
		if visual is Operator:
			visual.call("advance", dt)
			var nodes: Dictionary = visual.get("nodes")
			var arm: Node3D = nodes.get("armR")
			if arm == null: continue
			match str(visual.get_meta("story_pose", "idle")):
				"wave": arm.rotation.z = -0.75 + sin(Time.get_ticks_msec() * 0.006) * 0.26
				"point": arm.rotation.x = -0.5
				_: pass
