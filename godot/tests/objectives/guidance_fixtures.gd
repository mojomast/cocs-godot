extends SceneTree
const Guidance = preload("res://objectives/guidance.gd")
const Renderer = preload("res://objectives/renderer.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.rotation_order = EULER_ORDER_YXZ
	# Synthetic targets, independent oracle: actual Camera3D projection.
	for size: Vector2i in [Vector2i(960,640), Vector2i(1280,800)]:
		root.size = size
		await process_frame
		for yaw_deg: int in range(-180, 181, 30):
			for pitch_deg: int in [-50, -20, 0, 20, 50]:
				camera.rotation = Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0)
				camera.position = Vector3(12, 8, -7)
				for side: int in [-1, 1]:
					var target := camera.to_global(Vector3(side * 9, 0, -10))
					var projected := camera.unproject_position(target)
					var label := Guidance.bearing(camera, target)
					check(not camera.is_position_behind(target) and ((projected.x > size.x / 2.0) == (side == 1)), "projection oracle")
					check(label == ("Right" if projected.x > size.x / 2.0 else "Left"), "bearing matches screen at yaw %s pitch %s" % [yaw_deg, pitch_deg])
				check(Guidance.bearing(camera, camera.global_position - camera.global_basis.z * 20) == "Ahead", "forward -Z")
				check(Guidance.bearing(camera, camera.global_position + camera.global_basis.z * 20) == "Behind", "behind +Z")
	check(Guidance.bearing(null, Vector3.ZERO) == "Direction unknown", "no camera")
	camera.rotation = Vector3.ZERO
	camera.position = Vector3.ZERO
	var objective := {"attacker":0,"defender":1,"payload":{"position":{"x":0,"y":0,"z":0},"radius":4.5,"contested":false,"pushing":null}}
	var actor := {"x":4.5,"y":5.0,"z":0.0,"health":100}
	var data := Guidance.sample(objective, actor)
	check(Guidance.approach(data,camera,true).contains("Inside 4.5"), "inclusive horizontal and vertical boundaries")
	actor.x = 4.501
	check(Guidance.approach(Guidance.sample(objective,actor),camera,true).contains("Get within 4.5"), "outside radius")
	actor.x = 0
	actor.y = 5.001
	check(Guidance.approach(Guidance.sample(objective,actor),camera,true).contains("Different height"), "height not 3D sphere")
	actor.y = 0
	actor.health = 0
	check(Guidance.approach(Guidance.sample(objective,actor),camera,true).contains("Dead"), "dead cannot escort")
	actor.health = 100
	check(Guidance.approach(Guidance.sample(objective,actor),camera,false).contains("Controls released"), "release not local pushing promise")
	actor.erase("health")
	check(Guidance.approach(Guidance.sample(objective,actor),camera,true).contains("Life state unknown"), "missing health")
	objective.payload.radius = NAN
	check(Guidance.approach(Guidance.sample(objective,actor),camera,true).contains("Range unknown"), "no radius fallback")
	actor.x = INF
	check(Guidance.approach(Guidance.sample(objective,actor),camera,true).contains("unavailable"), "nonfinite position")
	objective.payload.position = null
	check(Guidance.approach(Guidance.sample(objective,{}),camera,true).contains("unavailable"), "missing position")
	objective.payload.contested = true
	check(Guidance.status(objective) == "CONTESTED", "contest priority")
	objective.payload.delivered = true
	objective.payload.pushing = 1
	check(Guidance.status(objective) == "DELIVERED", "delivery priority over stale pushing/contest")
	objective.payload.delivered = false
	objective.payload.contested = false
	objective.payload.pushing = 8
	check(Guidance.status(objective) == "UNKNOWN", "invalid pushing team")
	objective.payload.pushing = 0
	objective.attacker = null
	check(Guidance.status(objective) == "UNKNOWN", "unknown team roles")
	objective.payload.erase("pushing")
	objective.payload.progress = 100
	objective.payload.checkpointsReached = 3
	check(Guidance.status(objective) == "UNKNOWN", "100 percent/count never imply delivered")
	objective.defender = 1
	objective.payload.pushing = 1
	objective.payload.distance = 0
	objective.payload.checkpointsReached = 0.5
	objective.zones = []
	check(Guidance.status(objective) == "ROLLING BACK", "malformed checkpoint index cannot imply bank or index empty zones")
	var renderer := Renderer.new()
	root.add_child(renderer)
	var archive: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../port/native-payload-guidance/snapshots.json"))
	for entry: Dictionary in archive.samples:
		var before := JSON.stringify(entry.state)
		renderer.apply_state(entry.state, 0)
		check(Guidance.status(entry.state.objectives) == entry.status, "actual archived state " + entry.status)
		check(renderer.hud_model.title.contains("ROLLING BACK: CHECKPOINT LIMIT" if entry.status == "HOLDING CHECKPOINT" else entry.status), "actual renderer " + entry.status)
		check(renderer.hud_model.detail.begins_with("Route "), "route distinct from cart range")
		check(JSON.stringify(entry.state) == before, "snapshot immutable")
		var defender_state: Dictionary = entry.state.duplicate(true)
		defender_state.actors[0].team = 1
		renderer.apply_state(defender_state,0)
		if entry.status == "IDLE": check(renderer.hud_model.hint.contains("block attackers"), "defender first action")
		if entry.status.begins_with("PUSHING"): check(renderer.hud_model.hint.contains("contest"), "defender contests attacker push")
	renderer.apply_state({}, 0)
	check(renderer.guidance_model.is_empty(), "missing state clears guidance")
	renderer.free()
	camera.free()
	print("GUIDANCE_FIXTURES checks=",checks," failures=",failures," geometry=synthetic snapshot_states=archived")
	quit(1 if failures else 0)
