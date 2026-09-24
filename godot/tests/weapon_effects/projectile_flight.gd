extends SceneTree
## Projectile presentation contract: authoritative samples always snap exactly,
## the bounded visual lead smooths the flight between samples at both cadences,
## bounces and teleports reset the exhaust ribbon, and the muzzle-origin blend
## and occlusion checks are unchanged. No collision, hit or damage is invented.
const Projectiles = preload("res://world/projectiles.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func rocket(id: int, pos: Vector3, dir: Vector3, weapon: int = 1) -> Dictionary:
	return {"id":id,"owner":0,"weapon":weapon,"pos":{"x":pos.x,"y":pos.y,"z":pos.z},"dir":{"x":dir.x,"y":dir.y,"z":dir.z}}

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var projectiles := Projectiles.new()
	world.add_child(projectiles)
	projectiles.set_process(false)
	projectiles.configure_occlusion(func(_from: Vector3, _to: Vector3) -> bool: return false)
	# 1. A fresh sample is seated exactly and a second sample snaps cleanly.
	projectiles.apply_state({"time":0.0,"rockets":[rocket(7, Vector3(0,2,0), Vector3.FORWARD)]})
	var node: MeshInstance3D = projectiles.markers[7]
	check(node.position == Vector3(0,2,0), "first sample seated exactly")
	check(node.get_child_count() == 1, "exhaust ribbon is a marker child, not a new scene node")
	projectiles.apply_state({"time":0.05,"rockets":[rocket(7, Vector3(0,2,-1.1), Vector3.FORWARD)]})
	check(node.position == Vector3(0,2,-1.1), "second sample snaps exactly to authority")
	# 2. Between samples the presentation leads by the measured velocity, capped.
	projectiles._process(0.05)
	var lead: float = -1.1 - node.position.z
	check(lead > 0.0 and lead <= Projectiles.EXTRAPOLATE_MAX_METERS + 0.0001, "bounded visual lead between samples (%.4f m)" % lead)
	check(absf(projectiles.flight[7].velocity.z + 22.0) < 2.0, "velocity estimate follows the sample delta")
	# A stale sample cannot keep flying forever: the lead saturates in time.
	for frame: int in 30: projectiles._process(1.0 / 60.0)
	check(absf((-1.1 - node.position.z) - 22.0 * Projectiles.EXTRAPOLATE_MAX) < 0.0001, "dead reckoning saturates instead of running away")
	check(not projectiles.flight[7].trail.is_empty(), "moving projectile grows an exhaust ribbon")
	# 3. A bounce reverses the velocity and restarts the ribbon.
	projectiles.apply_state({"time":0.10,"rockets":[rocket(7, Vector3(0,2,-2.2), Vector3.FORWARD)]})
	projectiles._process(1.0 / 60.0)
	projectiles.apply_state({"time":0.15,"rockets":[rocket(7, Vector3(0,2,-1.95), Vector3.BACK)]})
	check(projectiles.flight[7].trail.is_empty(), "reversal clears the exhaust ribbon")
	check(projectiles.flight[7].velocity.z > 0.0, "bounce continues in the new direction")
	# 4. A teleport resets instead of drawing a ribbon across the jump.
	projectiles.apply_state({"time":0.20,"rockets":[rocket(7, Vector3(0,2,8.0), Vector3.FORWARD)]})
	check(node.position == Vector3(0,2,8.0), "teleport sample snaps exactly")
	check(projectiles.flight[7].trail.is_empty(), "teleport clears the exhaust ribbon")
	projectiles.apply_state({"time":0.25,"rockets":[rocket(99, Vector3(50,2,0), Vector3.FORWARD)]})
	check(projectiles.markers.has(99) and not projectiles.markers.has(7), "new id allocates and retires cleanly")
	check(projectiles.get_child_count() == projectiles.markers.size(), "one direct child per live projectile")
	check(projectiles.flight[99].trail.is_empty(), "fresh projectile starts with an empty ribbon")
	# 4. 60 Hz cadence: 60 real samples track and stay smooth.
	projectiles.clear_round()
	for step: int in 60:
		var time := 2.0 + step * (1.0 / 60.0)
		projectiles.apply_state({"time":time,"rockets":[rocket(5, Vector3(0,2,-step * 0.4), Vector3.FORWARD)]})
		projectiles._process(1.0 / 60.0)
	var settled: MeshInstance3D = projectiles.markers[5]
	check(absf(settled.position.z + 23.6) <= Projectiles.EXTRAPOLATE_MAX_METERS + 0.0001, "60 Hz flight stays inside the visual cap")
	# 5. Muzzle-origin blend: accepted launch blends from the muzzle, then snaps.
	projectiles.clear_round()
	var launch := {"id":1,"type":"launch","actor":0,"weapon":1,"time":3.0,"pos":{"x":0,"y":2,"z":-1.0}}
	projectiles.cache_launch(launch, {"position":Vector3(0.2,1.8,-0.4)}, 0)
	projectiles.apply_state({"time":3.0,"rockets":[rocket(0, Vector3(0,2,-1.0), Vector3.FORWARD)]})
	check(not projectiles.launch_origins.is_empty(), "known-clear launch origin accepted")
	projectiles._process(0.06)
	var blended: Vector3 = projectiles.markers[0].position
	check(blended.z > -1.0 and blended.z < -0.4, "launch still blends from the muzzle origin")
	projectiles._process(0.2)
	check(projectiles.markers[0].position == Vector3(0,2,-1.0), "launch blend snaps to authority after its window")
	# 6. A blocked launch is never cached.
	projectiles.clear_round()
	projectiles.configure_occlusion(func(_from: Vector3, _to: Vector3) -> bool: return true)
	projectiles.cache_launch(launch, {"position":Vector3(0.2,1.8,-0.4)}, 0)
	check(projectiles.launch_origins.is_empty(), "blocked launch origin fails closed")
	# 7. Saturation and round reset stay bounded.
	projectiles.configure_occlusion(func(_from: Vector3, _to: Vector3) -> bool: return false)
	var many: Array = []
	for id: int in range(400): many.append(rocket(id, Vector3.ZERO, Vector3.FORWARD))
	projectiles.apply_state({"time":4.0,"rockets":many})
	check(projectiles.markers.size() == Projectiles.MAX_PROJECTILES, "projectile pool bounded")
	check(projectiles.get_child_count() == Projectiles.MAX_PROJECTILES, "no extra scene nodes under saturation")
	for frame: int in 10: projectiles._process(1.0 / 60.0)
	projectiles.clear_round()
	check(projectiles.markers.is_empty() and projectiles.flight.is_empty() and projectiles.get_child_count() == 0, "round reset frees every marker and ribbon")
	projectiles.free()
	world.free()
	print("WEAPON_EFFECTS_PROJECTILE_FLIGHT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
