extends SceneTree
const SportsControls = preload("res://sports/controls.gd")
const ArmsControls = preload("res://combined_arms/controls.gd")
const Chase = preload("res://sports/chase.gd")
const LocalSettings = preload("res://ui/local_settings.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL vehicle view: ", label)

func press(code: int, down: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	return event

func vehicle(yaw: float = 0.0) -> Dictionary:
	return {"x":0.0, "y":0.0, "z":0.0, "yaw":yaw, "kind":"puma"}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(LocalSettings.normalize({}).vehicle_view == "third", "legacy settings default to chase")
	check(LocalSettings.normalize({"vehicle_view":"first"}).vehicle_view == "first", "first-person preference survives normalization")
	check(LocalSettings.normalize({"vehicle_view":"sideways"}).vehicle_view == "third", "invalid view rejected")
	# game/race.mjs and game/soccer.mjs project x/z against actor yaw
	# heading - PI. Their positive throttle advances +Z at heading zero.
	for controls in [SportsControls.new(), ArmsControls.new()]:
		controls.accept(press(KEY_ENTER), true)
		controls.accept(press(KEY_W), true)
		var p: Dictionary = controls.command(-PI, 0, true, true) if controls is ArmsControls else controls.packet(-PI, true)
		check(absf(float(p.x)) < 0.001 and is_equal_approx(float(p.z), 1.0), "W advances source +Z")
		controls.accept(press(KEY_W, false), true)
		controls.accept(press(KEY_D), true)
		p = controls.command(-PI, 0, true, true) if controls is ArmsControls else controls.packet(-PI, true)
		check(is_equal_approx(float(p.x), -1.0), "D projects to screen right and negative chassis steer")
		controls.accept(press(KEY_D, false), true)
		controls.accept(press(KEY_W), true)
		controls.accept(press(KEY_D), true)
		p = controls.command(-PI, 0, true, true) if controls is ArmsControls else controls.packet(-PI, true)
		check(is_equal_approx(float(p.x), -1.0) and is_equal_approx(float(p.z), 1.0), "W+D retain full independent source axes")
		controls.accept(press(KEY_W, false), true)
		controls.accept(press(KEY_D, false), true)
		controls.accept(press(KEY_S), true)
		p = controls.command(-PI, 0, true, true) if controls is ArmsControls else controls.packet(-PI, true)
		check(is_equal_approx(float(p.z), -1.0), "S reverses source throttle")
		controls.release()
		check(is_zero_approx(float(controls.packet(-PI, false).x)), "released controls neutral")
	var chase := Chase.new()
	var start := chase.follow(vehicle(), 1.0 / 60.0)
	check(start.eye.z < -8.0 and start.target.z > 0, "chase behind +Z nose")
	var coarse := Vector3.ZERO
	var fine := Vector3.ZERO
	var coarse_speed := Vector3.ZERO
	var fine_speed := Vector3.ZERO
	for i in 30:
		var step := Chase.spring(coarse, coarse_speed, Vector3(10, 0, 0), 1.0 / 30.0, 12.0)
		coarse = step[0]
		coarse_speed = step[1]
	for i in 120:
		var step := Chase.spring(fine, fine_speed, Vector3(10, 0, 0), 1.0 / 120.0, 12.0)
		fine = step[0]
		fine_speed = step[1]
	check(coarse.distance_to(fine) < 0.0001, "critically damped follow independent of render dt")
	var v := vehicle(PI - 0.03)
	chase.follow(v, 1.0 / 60.0)
	v.yaw = -PI + 0.03
	var before: float = chase.heading
	chase.follow(v, 1.0 / 60.0)
	check(absf(wrapf(chase.heading - before, -PI, PI)) < 0.2, "yaw wrap takes short arc")
	chase.reset_motion()
	var after := chase.follow(v, 1.0 / 60.0)
	check(after.eye.distance_to(Vector3(0, 5, 9)) < 0.5, "reset discards spring velocity")
	chase.toggle_view()
	var cockpit := chase.follow(vehicle(), 1.0 / 60.0, -PI)
	check(cockpit.eye.y > 1.4 and cockpit.eye.z > 0.9 and cockpit.target.z > cockpit.eye.z, "puma cockpit forward and clear of hood")
	var scout := chase.follow({"x":0.0,"y":0.0,"z":0.0,"yaw":0.0,"kind":"scout"}, 1.0 / 60.0, -PI, 0, "driver", 0, true)
	check(scout.eye.y < cockpit.eye.y and scout.eye.z < cockpit.eye.z, "scout seat profile")
	chase.toggle_view()
	chase.boxes = [AABB(Vector3(-2, 0, -5), Vector3(4, 8, 1))]
	chase.cells = {Vector2i(0, -1):[0], Vector2i(-1, -1):[0]}
	chase.follow(vehicle(), 1.0 / 60.0)
	check(chase.obstructed and chase.eye.z > -5, "chase boom pulls ahead of wall")
	print("VEHICLE VIEWS failures=", failures)
	quit(1 if failures else 0)
