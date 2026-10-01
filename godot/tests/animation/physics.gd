extends SceneTree
const Spring = preload("res://animation/critical_spring.gd")
const Inertia = preload("res://first_person/inertia.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func integrate(steps: Array) -> Vector2:
	var spring := Spring.new()
	spring.impulse(0.6)
	for dt: float in steps: spring.advance(dt, 0.0, 18.0, 1.0)
	return Vector2(spring.value, spring.velocity)

func _initialize() -> void:
	# Compare the actual helper with the independent closed-form impulse solution.
	var duration := 0.25
	var expected := Vector2(0.6 * duration * exp(-18.0 * duration), 0.6 * (1.0 - 18.0 * duration) * exp(-18.0 * duration))
	for rate: int in [30, 60, 144]:
		var steps: Array = []
		var elapsed := 0.0
		while elapsed < duration - 0.0000001:
			var dt := minf(1.0 / rate, duration - elapsed)
			steps.append(dt)
			elapsed += dt
		check(integrate(steps).distance_to(expected) < 0.000002, "exact impulse at %d Hz" % rate)
	check(integrate([0.007,0.029,0.003,0.171,0.04]).distance_to(expected) < 0.000002, "irregular/hitch composition")
	var spring := Spring.new()
	spring.impulse(1000.0, 0.7)
	for dt: float in [0.001,0.4,2.0,10.0]:
		spring.advance(dt,0.0,22.0,0.024)
		check(is_finite(spring.value) and absf(spring.value) <= 0.024, "hitch remains bounded")
	check(spring.value == 0.0 and spring.velocity == 0.0, "exact idle settlement")
	spring.reset()
	check(spring.advance(1.0) == 0.0, "no idle drift")
	var motion := Inertia.new()
	var actor := {"x":0.0,"y":0.0,"z":0.0,"vx":0.0,"vy":0.0,"vz":0.0,"grounded":true,"health":100}
	motion.observe(actor,Basis.IDENTITY)
	actor.vx = 8.0
	motion.observe(actor,Basis.IDENTITY)
	var moving: Dictionary = motion.advance(1.0/60.0,false)
	check(moving.position.x < 0.0, "acceleration opposing inertia")
	var impulse_velocity: float = motion.lateral.velocity
	motion.observe(actor,Basis.IDENTITY)
	check(motion.lateral.velocity == impulse_velocity, "repeated snapshot cannot accumulate impulse")
	actor.grounded = false
	actor.vy = 6.0
	motion.observe(actor,Basis.IDENTITY)
	check(motion.vertical.velocity < 0.0, "source jump compression")
	actor.vy = -9.0
	motion.observe(actor,Basis.IDENTITY)
	actor.grounded = true
	actor.vy = 0.0
	motion.observe(actor,Basis.IDENTITY)
	check(motion.vertical.velocity >= -0.7 and motion.vertical.velocity < 0.0, "landing impulse capped")
	actor.x = 100.0
	motion.observe(actor,Basis.IDENTITY)
	check(motion.lateral.value == 0.0 and motion.vertical.velocity == 0.0, "teleport resets")
	actor.grounded = false
	actor.vy = 5.0
	motion.observe(actor,Basis.IDENTITY,true)
	check(motion.vertical.velocity == 0.0, "flight never claims jump/landing")
	motion.look(Vector2(0.4,0.2))
	var quiet: Dictionary = motion.advance(1.0/60.0,true)
	check(quiet.position == Vector3.ZERO and quiet.rotation == Vector3.ZERO, "reduced motion suppresses secondary offsets")
	motion.reset()
	check(motion.look_x.value == 0.0 and motion.look_x.velocity == 0.0 and not motion.sampled, "restart drains history")
	print("ANIMATION_PHYSICS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
