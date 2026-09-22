extends SceneTree
## Low-health threshold boundaries, recovery scaling, heartbeat and F9 Low gating.
const Director = preload("res://player_fx/director.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("PLAYER_FX_LOW_HEALTH: " + message)

func actor(health: float, extra: Dictionary = {}) -> Dictionary:
	var value := {"id": 0, "x": 0, "y": 0, "z": 0, "health": health, "dead": 0}
	value.merge(extra, true)
	return value

func state_with(health: float, extra: Dictionary = {}) -> Dictionary:
	return {"time": 1.0, "actors": [actor(health, extra), {"id": 1, "x": 0, "y": 0, "z": -5, "health": 100, "dead": 0}]}

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	var director: Node = Director.new()
	root.add_child(director)
	director.configure(camera)

	# Documented threshold: strictly below 35% of the public max health.
	director.apply_state(state_with(36.0), 0)
	check(director.low_health == 0.0, "above threshold is quiet")
	director.apply_state(state_with(35.0), 0)
	check(director.low_health == 0.0, "exact threshold boundary is quiet")
	director.apply_state(state_with(34.9), 0)
	check(director.low_health > 0.0 and director.low_health < 0.01, "just below threshold starts scaling")
	director.apply_state(state_with(17.5), 0)
	check(absf(director.low_health - 0.5) < 0.001, "halfway below threshold is half strength")
	director.apply_state(state_with(1.0), 0)
	check(director.low_health > 0.9, "critical health approaches full strength")

	# maxHealth from the public actor drives the ratio.
	director.apply_state({"time": 1.0, "actors": [actor(70.0, {"maxHealth": 200.0})]}, 0)
	check(absf(director.low_health - 0.0) < 0.001, "public maxHealth above threshold stays quiet")
	director.apply_state({"time": 1.0, "actors": [actor(35.0, {"maxHealth": 200.0})]}, 0)
	check(director.low_health > 0.0, "public maxHealth scales the threshold")
	director.apply_state({"time": 1.0, "actors": [actor(10.0, {"maxHealth": 200.0})]}, 0)
	check(director.low_health > 0.0 and director.low_health < 0.9, "same absolute health is milder at larger maxHealth")

	# Recovery scales off, death clears the state cue.
	director.apply_state(state_with(100.0), 0)
	check(director.low_health == 0.0, "recovery clears the tint")
	director.apply_state(state_with(10.0), 0)
	check(director.low_health > 0.0, "damage re-arms the tint")
	director.apply_state(state_with(0.0), 0)
	check(director.low_health == 0.0 and not director.alive, "death uses the death cue instead of low health")

	# Heartbeat: present at High/Extreme, absent at F9 Low.
	director.apply_state(state_with(10.0), 0)
	check(director.low_health > 0.0 and director.alive, "low health re-armed for the heartbeat check")
	var beats := 0
	var low_hearts := 0
	director.set_quality(1)
	for step in range(60):
		director.advance(1.0 / 60.0)
		if director.model().heartbeat > 0.0: beats += 1
	check(beats > 0, "heartbeat pulses while low")
	check(float(director.model().heartbeat) >= 0.0 and float(director.model().heartbeat) <= 1.0, "heartbeat stays bounded")
	director.set_quality(0)
	for step in range(60):
		director.advance(1.0 / 60.0)
		if director.model().heartbeat > 0.0: low_hearts += 1
	check(low_hearts == 0 and float(director.model().heartbeat) == 0.0, "F9 Low disables the heartbeat pulse")
	check(director.low_health > 0.0, "F9 Low keeps the bounded static tint strength")
	director.set_quality(2)
	director.advance(0.05)
	check(director.model().heartbeat >= 0.0, "Extreme restores the heartbeat path")

	# Focus/round drain clears the cue until fresh authority arrives.
	director.clear_transient()
	check(director.low_health == 0.0 and not director.have_actor, "drain clears low health without a fresh frame")
	director.clear_round()
	check(director.low_health == 0.0 and director.local_id == -1, "round drain clears low health and identity")

	director.free()
	camera.free()
	if failures.is_empty():
		print("PLAYER_FX_LOW_HEALTH_OK checks=", checks)
	else:
		print("PLAYER_FX_LOW_HEALTH_FAIL ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
