extends SceneTree
## SYNTHETIC projection fixtures, not live source positions or gameplay evidence.
## Oracle: actual chase rig + Camera3D.unproject_position, not bearing sign math.
const Race = preload("res://sports/guidance.gd")
const Soccer = preload("res://sports/soccer_guidance.gd")
const Chase = preload("res://sports/chase.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func descriptions(point: Vector3, vehicle: Dictionary) -> Array[String]:
	var target := {"x":point.x, "z":point.z, "nx":1.0, "nz":0.0, "halfWidth":7.0}
	var race := {"gates":[target], "standings":[{"actorId":7, "nextGate":0, "finishTime":null}]}
	return [Race.describe(race, 7, vehicle), Soccer.bearing(target, vehicle)]

func run() -> void:
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	for size in [Vector2i(960, 640), Vector2i(1280, 800)]:
		viewport.size = size
		for yaw in [0.0, PI/2, PI, -PI/2, 0.7, -2.1, PI-0.001, -PI+0.001]:
			var vehicle := {"x":17.0, "y":0.0, "z":-13.0, "yaw":yaw}
			var origin := Vector3(vehicle.x, vehicle.y, vehicle.z)
			var chase := Chase.new()
			var pose := chase.follow(vehicle, 1.0/60)
			camera.position = pose.eye
			camera.look_at(pose.target)
			# Construct target fixtures in the camera basis. No atan2 or yaw-sign oracle.
			var forward := -camera.basis.z
			forward.y = 0
			forward = forward.normalized()
			for side in [-1, 1]:
				var point: Vector3 = origin + forward*25 + camera.basis.x*12*side
				var pixel := camera.unproject_position(point)
				var car_pixel := camera.unproject_position(origin)
				check(not camera.is_position_behind(point) and Rect2(Vector2.ZERO, Vector2(size)).has_point(pixel), "fixture visible")
				check(absf(pixel.x-car_pixel.x) > 50, "fixture clearly lateral")
				var expected := "Right" if pixel.x > car_pixel.x else "Left"
				for text in descriptions(point, vehicle):
					check(text.contains(expected + " · "), "%s yaw=%f projected=%s expected=%s got=%s" % [size, yaw, pixel, expected, text])
			# Thresholds are retained on both sides, including the yaw wrap seam.
			for angle in [0.0, 0.219, 0.221, 2.399, 2.401, PI]:
				for side in [-1, 1]:
					var point: Vector3 = origin + forward*cos(angle)*30 + camera.basis.x*sin(angle)*30*side
					for text in descriptions(point, vehicle):
						check(text.contains("Ahead") == (angle < 0.22), "Ahead threshold: " + text)
						check(text.contains("Behind") == (angle > 2.4), "Behind threshold: " + text)
	viewport.free()
	print("BEARING_PROJECTION_SYNTHETIC_CHECKS ", checks, " failures=", failures)
	quit(1 if failures else 0)
