extends SceneTree
const Gate = preload("res://combined_arms/controls.gd")
const Lease = preload("res://combined_arms/lease.gd")
const CameraRig = preload("res://combined_arms/camera.gd")
const Fleet = preload("res://combined_arms/fleet.gd")
const Bridge = preload("res://vehicles/session_bridge.gd")
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
	var s: Dictionary = JSON.parse_string('{"config":{"mode":"combined-arms"},"actors":[{"id":0,"team":1,"health":100,"dead":0,"vehicleId":"p","vehicleSeat":"driver","vehicleSeatIndex":0,"x":0,"y":7,"z":0}],"vehicles":[{"id":"p","kind":"puma","driver":0,"gunner":null,"passengers":[],"health":300,"respawnTimer":0,"x":0,"y":7,"z":0}]}')
	var a := Lease.actor_for(s, 0)
	var v := Lease.vehicle_for(s, a)
	check(not v.is_empty() and Lease.permitted(s, a, v, 0), "float actor zero driver lease")
	check(Lease.actor_for(s, -1).is_empty(), "unassigned is not actor zero")
	s.vehicles[0].driver = 1.0
	check(Lease.vehicle_for(s, a).is_empty(), "wrong driver rejected")
	check(not Lease.permitted(s, a, {}, 0), "no infantry fallback on broken lease")
	s.vehicles[0].driver = 0.0
	check(not Lease.permitted(s, a, v, 0.5), "stale lease rejected")
	s.config.mode = "ctf"
	check(Lease.permitted(s, a, v, 0), "same lease works in source CTF vehicle mode")
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
	for kind: String in ["puma", "hornet", "titan", "scout", "transport"]:
		var count: int = Lease.PASSENGERS[kind]
		var record := {"id":kind, "kind":kind, "driver":0, "gunner":null, "passengers":[], "health":100, "respawnTimer":0}
		var driver := {"id":0, "health":100, "dead":0, "vehicleId":kind, "vehicleSeat":"driver", "vehicleSeatIndex":0}
		var fixture := {"actors":[driver], "vehicles":[record], "config":{"mode":"combined-arms"}}
		check(not Lease.vehicle_for(fixture, driver).is_empty(), kind + " driver 0")
		if kind != "scout":
			record.gunner = 0
			check(Lease.vehicle_for(fixture, driver).is_empty(), kind + " duplicate role claim rejected")
			record.driver = null
			driver.vehicleSeat = "gunner"
			check(not Lease.vehicle_for(fixture, driver).is_empty(), kind + " gunner 0")
			record.gunner = null
		else:
			record.driver = null
			record.gunner = 0
			driver.vehicleSeat = "gunner"
			check(Lease.vehicle_for(fixture, driver).is_empty(), "scout gunner cannot lease")
		record.gunner = null
		driver.vehicleSeat = "passenger"
		for index: int in range(count):
			record.passengers = []
			for ignored in range(index + 1): record.passengers.append(null)
			record.passengers[index] = 0
			driver.vehicleSeatIndex = index
			check(not Lease.vehicle_for(fixture, driver).is_empty(), "%s passenger %d" % [kind, index])
			driver.vehicleSeatIndex = index + 1
			check(Lease.vehicle_for(fixture, driver).is_empty(), "%s wrong passenger index" % kind)
	var bridge := Bridge.new()
	var mounted_state := {"actors":[{"id":0,"health":100,"dead":0,"vehicleId":"hornet","vehicleSeat":"driver","vehicleSeatIndex":0}], "vehicles":[{"id":"hornet","kind":"hornet","driver":0,"gunner":null,"passengers":[],"health":240,"respawnTimer":0}]}
	bridge.observe(mounted_state, 0)
	check(bridge.eligible(0, 0, true, false) and not bridge.eligible(0, 0.5, true, false), "shared bridge freshness")
	check(bridge.adapt({"x":0.4,"z":0.8,"jump":true,"fire":true}, true).jump, "first flight ascent edge")
	check(not bridge.adapt({"x":0.4,"z":0.8,"jump":true,"fire":true}, true).jump, "held jump never emits synthetic climb")
	check(not bridge.adapt({"x":0.4,"z":0.8,"jump":false}, true).jump and bridge.adapt({"jump":true}, true).jump, "released jump permits a fresh rising edge")
	check(bridge.adapt({"x":0.4,"z":0.8,"jump":false}, false).x == 0, "focus release neutralizes axes")
	var passenger_actor := {"id":0,"health":100,"dead":0,"vehicleId":"transport","vehicleSeat":"passenger","vehicleSeatIndex":3}
	var passenger_vehicle := {"id":"transport","kind":"transport","driver":1,"gunner":null,"passengers":[null,null,null,0],"health":300,"respawnTimer":0}
	var passenger_state := {"actors":[passenger_actor],"vehicles":[passenger_vehicle]}
	bridge.observe(passenger_state, 0)
	check(bridge.eligible(0, 0.49, true, false) and not bridge.eligible(0, 0.5, true, false), "passenger lease obeys source snapshot staleness boundary")
	var personal := bridge.adapt({"x":1.0,"z":-1.0,"jump":true,"fire":true,"reload":true,"weapon":"rifle"}, true)
	check(personal.x == 0 and personal.z == 0 and not personal.jump and personal.fire and personal.reload and personal.weapon == "rifle", "passenger keeps personal input but cannot steer hull")
	bridge.observe(mounted_state, 0)
	check(bridge.adapt({"x":1.0,"fire":true}, false).x == 0 and not bridge.adapt({"fire":true}, false).fire, "focus loss clears passenger personal actions")
	mounted_state.vehicles[0].driver = null
	bridge.observe(mounted_state, 0)
	check(not bridge.eligible(0, 0, true, false) and not bridge.adapt({"fire":true,"x":1.0}, true).fire, "broken seat lease cannot fire")
	var g := Gate.new()
	tap(g, KEY_ENTER)
	key(g, KEY_F, true)
	check(g.command(0, 0, true, false).melee, "fresh infantry F requests a kick")
	check(not g.command(0, 0, true, false).melee, "held F never repeats")
	key(g, KEY_F, false)
	tap(g, KEY_F)
	check(g.command(0, 0, true, false).melee, "release then press permits next kick")
	tap(g, KEY_F)
	check(not g.command(0, 0, true, true).melee, "driving suppresses kick")
	key(g, KEY_W, true)
	key(g, KEY_D, true)
	for yaw in [0.0, PI/2, PI, -PI/2]:
		var p := g.command(yaw, 0, true, true)
		check(is_equal_approx(-p.x*sin(yaw)-p.z*cos(yaw), 1), "exact source throttle projection")
		check(is_equal_approx(-p.x*cos(yaw)+p.z*sin(yaw), -1), "source D negative-right steer projection")
	var diagonal := g.command(PI/4, 0, true, true)
	check(is_equal_approx(diagonal.x, -sqrt(2.0)) and is_zero_approx(diagonal.z), "source web keeps full W+D axes without native normalization")
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
