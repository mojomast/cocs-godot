extends SceneTree
## Damage-direction cues: camera-relative bearing math, environmental fallback,
## immunity/self/environment cases, public-ID dedup, expiry and round drain.
const Director = preload("res://player_fx/director.gd")
const Client = preload("res://net/client.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("PLAYER_FX_DIRECTION: " + message)

func actor(id: int, x: float, y: float, z: float, extra: Dictionary = {}) -> Dictionary:
	var value := {"id": id, "x": x, "y": y, "z": z, "health": 100, "dead": 0}
	value.merge(extra, true)
	return value

func _initialize() -> void: call_deferred("run")

func run() -> void:
	# Camera-relative bearing: 0 ahead, positive right, negative left, PI behind.
	var identity := Basis.IDENTITY
	check(is_zero_approx(Director.bearing_angle(identity, Vector3.ZERO, Vector3(0, 0, -10))), "ahead is zero")
	check(is_equal_approx(Director.bearing_angle(identity, Vector3.ZERO, Vector3(10, 0, 0)), PI * 0.5), "right is +90")
	check(is_equal_approx(Director.bearing_angle(identity, Vector3.ZERO, Vector3(-10, 0, 0)), -PI * 0.5), "left is -90")
	check(is_equal_approx(absf(Director.bearing_angle(identity, Vector3.ZERO, Vector3(0, 0, 10))), PI), "behind is PI")
	check(is_zero_approx(Director.bearing_angle(identity, Vector3.ZERO, Vector3(0, 5, -10))), "elevation does not bend the edge bearing")
	var turned := Basis(Vector3.UP, -PI * 0.5)
	check(is_equal_approx(Director.bearing_angle(turned, Vector3.ZERO, Vector3(0, 0, -10)), -PI * 0.5), "turned camera keeps world-true bearing")
	check(is_equal_approx(Director.edge_direction(0.0).x, 0.0) and is_equal_approx(Director.edge_direction(0.0).y, -1.0), "edge direction zero points up")
	check(Director.edge_direction(PI * 0.5).distance_to(Vector2.RIGHT) < 0.0001, "edge direction +90 points right")

	var camera := Camera3D.new()
	root.add_child(camera)
	var director: Node = Director.new()
	root.add_child(director)
	director.configure(camera)
	var state := {"time": 1.0, "actors": [actor(0, 0, 0, 0), actor(1, 0, 0, -10)]}
	director.apply_state(state, 0)
	director.apply_events([{"id": 10, "type": "damage", "actor": 0, "source": 1, "amount": 12}], 0)
	check(director.damage_remaining > 0.0 and int(director.counters.damage) == 1, "actor damage starts the directional cue")
	director.advance(0.016)
	var model: Dictionary = director.model()
	check(model.direction and model.direction_known, "known bearing after processing")
	check(absf(float(model.direction_angle)) < 0.0001, "bearing resolves ahead for the public attacker position")

	# The bearing follows the attacker's latest public position.
	state.actors[1].x = 10.0
	state.actors[1].z = 0.0
	director.apply_state(state, 0)
	director.advance(0.016)
	check(absf(float(director.model().direction_angle) - PI * 0.5) < 0.0001, "bearing tracks the moved public attacker")

	# Environmental damage: neutral pulse, never an invented bearing.
	director.apply_events([{"id": 11, "type": "damage", "actor": 0, "source": null, "amount": 8}], 0)
	director.advance(0.016)
	check(director.damage_environmental and not director.model().direction_known, "environmental damage degrades to neutral")
	check(int(director.counters.environmental) == 1, "environmental cue counted once")
	check(director.model().direction_environment, "neutral pulse flag exposed")
	director.apply_events([{"id": 12, "type": "damage", "actor": 0, "source": 0, "amount": 8}], 0)
	check(int(director.counters.environmental) == 2 and not director.model().direction_known, "self damage is not a directional threat")

	# Unknown attacker identity is also neutral rather than guessed.
	director.apply_events([{"id": 13, "type": "damage", "actor": 0, "source": 7, "amount": 8}], 0)
	director.advance(0.016)
	check(director.damage_environmental and not director.model().direction_known, "absent attacker position is neutral")

	# Only local damage counts; other actors never drive the local cue.
	var damage_before: int = director.counters.damage
	director.apply_events([{"id": 14, "type": "damage", "actor": 1, "source": 0, "amount": 30}], 0)
	check(int(director.counters.damage) == damage_before, "remote damage does not cue the local overlay")

	# Public-ID dedup and event window.
	director.apply_events([{"id": 15, "type": "damage", "actor": 0, "source": 1, "amount": 10}], 0)
	director.apply_events([{"id": 15, "type": "damage", "actor": 0, "source": 1, "amount": 10}], 0)
	check(int(director.counters.damage) == damage_before + 1 and int(director.counters.dedup) == 1, "duplicate public IDs are consumed once")

	# Expiry.
	director.advance(1.0)
	check(director.damage_remaining == 0.0 and not director.model().direction, "direction cue expires")

	# Round boundaries drain and permit a fresh round's reused IDs once.
	director.apply_state({"over": true}, 0)
	check(director.damage_remaining == 0.0 and director.seen.is_empty(), "results drain direction history")
	director.apply_state(state, 0)
	director.apply_events([{"id": 15, "type": "damage", "actor": 0, "source": 1, "amount": 10}], 0)
	check(int(director.counters.damage) == 1, "fresh round accepts a reused public ID once")

	# Identity change drains held cues through clear_round.
	director.clear_round()
	check(director.local_id == -1 and director.damage_remaining == 0.0, "clear_round drains identity and cues")

	director.free()
	camera.free()
	if failures.is_empty():
		print("PLAYER_FX_DIRECTION_OK checks=", checks)
	else:
		print("PLAYER_FX_DIRECTION_FAIL ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
