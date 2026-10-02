extends SceneTree
## Native, asset-free assertions against the real adapter's pure seek function.
## Prepared only: integration worker owns execution under the combined grant.
const Visual = preload("res://fighting/visuals/fighter_visual.gd")


func _initialize() -> void:
	var visual := Visual.new()
	var data := {"seek_keys": [[0, 0], [6, 0.28], [18, 0.68], [29, 0.82], [38, 1.0]], "loop": false}
	var phase := {"actor": 0, "target": 1, "move_id": "throw_f", "caught_move_frame": 30,
		"damage_frame": 40, "release_frame": 41, "end_frame": 42, "frame": 30}
	var fighter := {"id": 0, "animation": "throw_f", "state": "throw", "animation_frame": 30, "pair_phase": phase}
	var previous := 0.28
	for frame: int in range(30, 43):
		phase["frame"] = frame
		fighter["animation_frame"] = frame
		var value: float = visual._presentation_seconds(fighter, data)
		assert(value >= previous)
		var victim := fighter.duplicate(true)
		victim["id"] = 1
		victim["animation"] = "victim_meta_throw_f"
		assert(is_equal_approx(value, visual._presentation_seconds(victim, data)))
		if frame >= 41:
			var recovery := fighter.duplicate(true)
			recovery["pair_phase"] = {}
			recovery["animation_pair_phase"] = phase.duplicate(true)
			assert(is_equal_approx(value, visual._presentation_seconds(recovery, data)))
		previous = value
	phase["frame"] = 41
	fighter["animation_frame"] = 41
	assert(is_equal_approx(visual._presentation_seconds(fighter, data), 0.82))
	phase["frame"] = 30
	fighter["animation_frame"] = 30
	assert(is_equal_approx(visual._presentation_seconds(fighter, data), 0.28))
	phase["damage_frame"] = 30
	assert(visual._presentation_seconds(fighter, data) == -1.0)
	fighter["state"] = "throw_tech"
	fighter["animation"] = "throw_tech"
	fighter["animation_frame"] = 3
	assert(is_equal_approx(visual._presentation_seconds(fighter, {"seek_keys": [[0, 0], [60, 1]], "loop": false}), 0.05))
	visual.free()
	print("PAIR_SEEK_NATIVE_PASS")
	quit(0)
