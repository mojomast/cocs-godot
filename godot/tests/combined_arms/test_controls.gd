extends SceneTree
const Gate = preload("res://combined_arms/controls.gd")
const Lease = preload("res://combined_arms/lease.gd")
const CameraRig = preload("res://combined_arms/camera.gd")
const Fleet = preload("res://combined_arms/fleet.gd")
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error(message)
func key(g, code: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	g.accept(e, true)
func tap(g, code: int) -> void:
	key(g, code, true)
	key(g, code, false)
func _initialize() -> void:
	# JSON parser represents integral IDs as floats; zero is a valid owner.
	var s: Dictionary = JSON.parse_string('{"config":{"mode":"combined-arms"},"actors":[{"id":0,"team":1,"health":100,"dead":0,"vehicleId":"p","vehicleSeat":"driver","x":0,"y":7,"z":0}],"vehicles":[{"id":"p","kind":"puma","driver":0,"gunner":null,"passengers":[],"health":300,"respawnTimer":0,"x":0,"y":7,"z":0}]}')
	var a := Lease.actor_for(s, 0)
	var v := Lease.vehicle_for(s, a)
	check(not v.is_empty() and Lease.permitted(s, a, v, 0), "float actor zero driver lease")
	check(Lease.actor_for(s, -1).is_empty(), "unassigned is not actor zero")
	s.vehicles[0].driver = 1.0
	check(Lease.vehicle_for(s, a).is_empty(), "wrong driver rejected")
	check(not Lease.permitted(s, a, {}, 0), "no infantry fallback on broken lease")
	s.vehicles[0].driver = 0.0
	check(not Lease.permitted(s, a, v, 0.5), "stale lease rejected")
	s.config.mode = "puma-race"
	check(not Lease.permitted(s, a, v, 0), "sports mode rejected")
	s.config.mode = "combined-arms"
	a.health = 0
	check(Lease.vehicle_for(s, a).is_empty(), "death revokes lease")
	a.health = 100
	a.vehicleId = null
	a.vehicleSeat = null
	s.vehicles[0].driver = null
	check(not Lease.nearby(s, a).is_empty(), "source has no team entry lock")
	check(Lease.vehicle_for(s, a).is_empty(), "proximity grants no lease")
	s.vehicles[0].respawnTimer = 1
	check(Lease.nearby(s, a).is_empty(), "respawning chassis not enterable")
	var g := Gate.new()
	tap(g, KEY_ENTER)
	key(g, KEY_W, true)
	key(g, KEY_D, true)
	for yaw in [0.0, PI/2, PI, -PI/2]:
		var p := g.command(yaw, 0, true, true)
		check(is_equal_approx(-p.x*sin(yaw)-p.z*cos(yaw), 1), "exact source throttle projection")
		check(is_equal_approx(-p.x*cos(yaw)+p.z*sin(yaw), 1), "exact source steer projection")
	var diagonal := g.command(PI/4, 0, true, true)
	check(absf(diagonal.x) <= 1 and absf(diagonal.z) <= 1, "wire axes remain within source parser bounds")
	check(is_equal_approx(-diagonal.x*sin(PI/4)-diagonal.z*cos(PI/4), -diagonal.x*cos(PI/4)+diagonal.z*sin(PI/4)), "diagonal retains throttle/steer ratio after wire fit")
	tap(g, KEY_E)
	check(g.command(0, 0, true, true).interact, "tap survives until packet")
	check(not g.command(0, 0, true, true).interact, "interact consumed once")
	g.release()
	tap(g, KEY_ENTER)
	check(g.command(0, 0, true, false).z == 0, "seat transition clears held controls")
	key(g, KEY_W, true)
	check(g.command(0, 0, true, false).z == 0, "held key cannot masquerade as fresh press")
	key(g, KEY_W, false)
	key(g, KEY_W, true)
	check(g.command(0, 0, true, false).z == -1, "fresh infantry movement")
	g.command(0, 0, false, false)
	check(not g.engaged, "stale release latch")
	key(g, KEY_W, false)
	tap(g, KEY_ENTER)
	tap(g, KEY_E)
	g.focus(false)
	check(not g.command(0, 0, true, false).interact, "focus loss clears queued interact")
	g.focus(true)
	check(not g.engaged, "focus return does not auto-capture")
	tap(g, KEY_ENTER)
	tap(g, KEY_ESCAPE)
	check(not g.engaged, "escape releases")
	var cam := CameraRig.new()
	check(is_equal_approx(cam.infantry(a, 0, 0).eye.y, 8.45), "infantry source Y preserved")
	check(cam.follow({"x":0,"y":7,"z":0,"yaw":0}, 0.1).eye.y == 12, "vehicle source Y preserved")
	cam.reset()
	check(not cam.seeded, "camera lease reset")
	var fleet := Fleet.new()
	root.add_child(fleet)
	var roster: Array = []
	for kind in ["puma", "titan", "scout", "transport", "hornet"]:
		roster.append({"id":kind,"kind":kind,"x":12.5,"y":7.25,"z":-3,"vx":0,"vz":0,"yaw":0.2,"pitchBody":0.1,"roll":0.15,"turretYaw":0.3,"health":300,"respawnTimer":0})
	check(fleet.apply_state({"vehicles":roster}), "all five source chassis render")
	for v2: Dictionary in roster:
		check(fleet.vehicle_node(v2.id).position.is_equal_approx(Vector3(12.5,7.25,-3)), "exact full source root for "+v2.kind)
	check(fleet.nodes.size()+fleet.secondary.size() == 5, "bounded stable vehicle identity")
	var original := fleet.vehicle_node("titan")
	fleet.apply_state({"vehicles":roster})
	check(fleet.vehicle_node("titan") == original, "snapshot reuses chassis node")
	check(not fleet.apply_state({"vehicles":[{"id":"bad","kind":"titan"}]}), "malformed secondary rejected atomically")
	check(fleet.vehicle_node("titan") == original, "invalid snapshot preserves previous roster")
	fleet.apply_state({"vehicles":[]})
	check(fleet.nodes.is_empty() and fleet.secondary.is_empty(), "missing roster prunes all vehicle leases")
	fleet.clear_round()
	fleet.free()
	print("COMBINED_SYNTHETIC_CHECKS ", checks)
	quit(1 if failed else 0)
