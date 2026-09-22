extends SceneTree
## Death and respawn cues: elimination once per death, materialization matched
## to the genuine spawn-protection pool, and results/restart drains.
const Director = preload("res://player_fx/director.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("PLAYER_FX_LIFECYCLE: " + message)

func state(health: float, dead: float, protection: float = 0.0) -> Dictionary:
	return {"time": 1.0, "actors": [
		{"id": 0, "x": 0, "y": 0, "z": 0, "health": health, "dead": dead, "protection": protection},
		{"id": 1, "x": 0, "y": 0, "z": -8, "health": 100, "dead": 0}]}

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	var director: Node = Director.new()
	root.add_child(director)
	director.configure(camera)

	director.apply_state(state(100.0, 0.0), 0)
	check(director.alive and director.death_remaining == 0.0, "healthy local actor has no death cue")

	# Elimination fires exactly once per death transition.
	director.apply_state(state(0.0, 1.0), 0)
	check(director.death_remaining > 0.0 and int(director.counters.death) == 1, "death transition starts the elimination cue")
	director.apply_state(state(0.0, 1.0), 0)
	director.apply_state(state(0.0, 1.0), 0)
	check(int(director.counters.death) == 1, "held death never replays the elimination cue")
	director.advance(2.0)
	check(director.death_remaining == 0.0, "elimination cue expires")

	# Respawn without a genuine protection window shows no materialization.
	director.apply_state(state(100.0, 0.0, 0.0), 0)
	check(director.alive and director.materialize_remaining == 0.0 and int(director.counters.respawn) == 0, "unprotected respawn has no materialize cue")

	# Death again, then a protected respawn mirrors the authoritative seconds.
	director.apply_state(state(0.0, 1.0), 0)
	check(int(director.counters.death) == 2, "second death cues again")
	director.apply_state(state(100.0, 0.0, 2.0), 0)
	check(int(director.counters.respawn) == 1, "protected respawn counted once")
	check(is_equal_approx(director.materialize_window, 2.0) and is_equal_approx(director.materialize_remaining, 2.0), "materialize matches the genuine protection pool")
	var model: Dictionary = director.model()
	check(absf(float(model.materialize) - 1.0) < 0.001, "materialize starts at full strength")
	director.advance(1.0)
	director.apply_state(state(100.0, 0.0, 1.0), 0)
	check(absf(director.materialize_remaining - 1.0) < 0.01, "materialize mirrors the live pool countdown")
	director.apply_state(state(100.0, 0.0, 0.0), 0)
	check(director.materialize_remaining == 0.0 and director.materialize_window == 0.0, "materialize ends exactly with protection")
	var held: int = director.counters.respawn
	director.apply_state(state(100.0, 0.0, 0.0), 0)
	check(int(director.counters.respawn) == held, "steady alive frames never re-arm materialize")

	# First sight of a protected local actor (round start) is genuine, uncounted.
	director.clear_round()
	director.apply_state(state(100.0, 0.0, 3.0), 0)
	check(director.materialize_remaining > 0.0 and int(director.counters.respawn) == 0, "round-start protection materializes without a respawn count")
	director.advance(0.5)
	check(director.materialize_remaining > 0.0, "protection window is not cut short by the cue timer")

	# Results and restart drain both cues; stale events cannot replay.
	director.apply_state(state(0.0, 1.0), 0)
	check(director.death_remaining > 0.0, "death cue armed before drain")
	director.apply_state({"over": true}, 0)
	check(director.death_remaining == 0.0 and director.materialize_remaining == 0.0 and not director.alive, "results drain death and respawn cues")
	director.apply_state(state(100.0, 0.0), 0)
	director.apply_events([{"id": 40, "type": "damage", "actor": 0, "source": 1, "amount": 90}], 0)
	check(int(director.counters.damage) == 1, "fresh round accepts the event once")
	director.clear_round()
	check(director.local_id == -1 and director.damage_remaining == 0.0, "round restart drains cue state")
	director.apply_state(state(100.0, 0.0), 0)
	director.apply_events([{"id": 40, "type": "damage", "actor": 0, "source": 1, "amount": 90}], 0)
	check(int(director.counters.damage) == 1, "restart accepts a reused public ID once, not twice")

	director.free()
	camera.free()
	if failures.is_empty():
		print("PLAYER_FX_LIFECYCLE_OK checks=", checks)
	else:
		print("PLAYER_FX_LIFECYCLE_FAIL ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
