extends RefCounted
## Source-observed motion -> bounded cosmetic weapon offsets. Never camera/aim.
const Spring = preload("res://animation/critical_spring.gd")
var lateral := Spring.new()
var forward := Spring.new()
var vertical := Spring.new()
var sprint := Spring.new()
var look_x := Spring.new()
var look_y := Spring.new()
var strafe := Spring.new()
var strafe_target := 0.0
var previous := Vector3.ZERO
var position := Vector3.ZERO
var grounded := true
var sampled := false
var sprinting := false
var flying := false
var health := 0.0

func reset() -> void:
	for spring in [lateral, forward, vertical, sprint, look_x, look_y, strafe]: spring.reset()
	sampled = false
	sprinting = false
	flying = false
	grounded = true
	strafe_target = 0.0
	health = 0.0

func observe(actor: Dictionary, camera_basis: Basis, flight_mode: bool = false) -> void:
	var next := Vector3(float(actor.get("vx", 0.0)), float(actor.get("vy", 0.0)), float(actor.get("vz", 0.0)))
	var at := Vector3(float(actor.get("x", 0.0)), float(actor.get("y", 0.0)), float(actor.get("z", 0.0)))
	if not next.is_finite() or not at.is_finite(): reset(); return
	var floor_now: bool = actor.get("grounded", true) != false
	var flight_now: bool = flight_mode
	if sampled and (at.distance_to(position) > 4.0 or flight_now != flying): reset()
	var hp := float(actor.get("health", 0.0))
	if sampled and not flight_now:
		# Differences in observed velocity are impulses, not frame-count forces.
		var change := camera_basis.inverse() * (next - previous)
		lateral.impulse(clampf(-change.x * 0.035, -0.28, 0.28), 0.6)
		forward.impulse(clampf(-change.z * 0.025, -0.24, 0.24), 0.5)
		if grounded and not floor_now and next.y > 1.0: vertical.impulse(-0.22, 0.7)
		if not grounded and floor_now: vertical.impulse(-clampf(absf(previous.y) * 0.07, 0.12, 0.65), 0.7)
		if hp < health: lateral.impulse(0.15, 0.6); vertical.impulse(-0.18, 0.7)
	previous = next
	position = at
	grounded = floor_now
	health = hp
	flying = flight_now
	sprinting = actor.get("sprinting", false) == true and floor_now and not flying
	# The source velocity, not raw input, follows real braking and collision.
	# Weapon-only lean leaves camera aim and gameplay collision untouched.
	var local_velocity := camera_basis.inverse() * next
	strafe_target = clampf(-local_velocity.x / 9.0, -1.0, 1.0) if floor_now and not flight_now else 0.0
	sampled = true

func look(radians: Vector2) -> void:
	look_x.impulse(-radians.x * 3.0, 0.7)
	look_y.impulse(-radians.y * 3.0, 0.6)

func advance(delta: float, reduced: bool) -> Dictionary:
	var quiet := 0.0 if reduced else 1.0
	var x := lateral.advance(delta, 0.0, 18.0, 0.018) * quiet
	var z := forward.advance(delta, 0.0, 18.0, 0.014) * quiet
	var y := vertical.advance(delta, 0.0, 22.0, 0.024) * quiet
	var run := sprint.advance(delta, 1.0 if sprinting else 0.0, 20.0, 1.0) * quiet
	var lean := strafe.advance(delta, strafe_target, 12.0, 1.0) * quiet
	return {"position":Vector3(x + lean * 0.009, y - run * 0.028, z), "rotation":Vector3(-y * 0.7 + run * 0.055 + look_y.advance(delta, 0.0, 22.0, 0.02) * quiet, look_x.advance(delta, 0.0, 22.0, 0.025) * quiet, -x * 0.9 - lean * 0.014)}
