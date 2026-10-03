extends SceneTree
const Gate = preload("res://sports/controls.gd")
const Chase = preload("res://sports/chase.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func key(g, code: int, down: bool, eligible: bool = true) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = down
	g.accept(e, eligible)
func _initialize() -> void:
	var g := Gate.new()
	key(g, KEY_W, true)
	check(g.packet(0, true).z == 0, "must engage")
	key(g, KEY_ENTER, true, false)
	check(not g.engaged, "countdown blocks engage")
	for yaw in [0.0, PI/2, PI, -PI/2]:
		key(g, KEY_ENTER, true)
		# Engagement suppresses physical holds; each case starts with real releases.
		key(g, KEY_W, false)
		key(g, KEY_D, false)
		key(g, KEY_W, true)
		key(g, KEY_D, true)
		var p: Dictionary = g.packet(yaw, true)
		check(is_equal_approx(-p.x*sin(yaw)-p.z*cos(yaw), 1.0), "throttle inverse")
		check(is_equal_approx(-p.x*cos(yaw)+p.z*sin(yaw), -1.0), "source D negative-right steer")
	key(g, KEY_SPACE, true)
	key(g, KEY_SHIFT, true)
	key(g, KEY_R, true)
	check(g.packet(0, true).jump and g.packet(0, true).sprint and g.packet(0, true).interact, "source actions")
	g.focus(false)
	check(not g.engaged and g.packet(0, true).z == 0, "focus loss neutral")
	key(g, KEY_ENTER, true)
	check(not g.engaged, "unfocused cannot engage")
	g.focus(true)
	check(not g.engaged, "focus does not resume")
	key(g, KEY_ENTER, true)
	check(g.packet(0, true).z == 0, "held keys cleared")
	key(g, KEY_W, true)
	g.packet(0, false)
	check(not g.engaged and g.packet(0, true).z == 0, "stale/missing authority latches release")
	key(g, KEY_ENTER, true)
	key(g, KEY_ESCAPE, true)
	check(not g.engaged, "escape releases")
	var c := Chase.new()
	var v := {"x":0.0,"y":0.0,"z":0.0,"yaw":0.0,"vx":0,"vz":-6}
	var rear: Vector3 = c.follow(v, 0.1).eye
	check(rear.is_finite() and rear.z < -1.0 and rear.y > 1.0 and absf(rear.x)<0.01, "+Z reverse keeps camera behind and above chassis")
	c.reset()
	v.yaw = PI/2
	var lateral: Vector3 = c.follow(v, 0.1).eye
	check(lateral.distance_to(Basis(Vector3.UP,PI/2)*rear)<0.001, "+X heading rotates chase offset with chassis")
	v.x = 100.0
	check(c.follow(v, 0.01).eye.distance_to(lateral+Vector3(100,0,0))<0.001, "teleport preserves chase offset without interpolating across map")
	c.reset()
	check(not c.seeded, "round cleanup")
	var demo = preload("res://sports/demo.gd").new()
	demo.on_started({})
	check(demo.age == 0 and demo.phase == "active", "start grants first snapshot timeout budget")
	check(not demo.eligible(), "start alone never grants authority")
	demo.net.actor_id = 0
	demo.vehicle = {"driver":0,"health":300,"respawnTimer":0}
	demo.actor = {"health":100,"dead":0}
	demo.state = {"race":{"phase":"racing"}}
	check(demo.eligible(), "owned fresh driving state")
	demo.age = 0.6
	check(not demo.eligible(), "stale authority blocks")
	demo.age = 0
	demo.vehicle.driver = 1
	check(not demo.eligible(), "ownership loss blocks")
	demo.on_started({})
	check(demo.vehicle.is_empty() and not demo.chase.seeded and not demo.controls.engaged, "round reset clears controls and camera")
	# These helpers are constructed before entering a scene; explicitly free them.
	demo.net.free()
	demo.fleet.free()
	demo.ball.free()
	demo.hud.free()
	demo.world.camera.free()
	demo.world.label.free()
	demo.world.selector.free()
	demo.world.environment.free()
	demo.world.sun.free()
	demo.world.free()
	demo.free()
	print("SPORTS_SYNTHETIC_CHECKS ", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
