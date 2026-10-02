extends SceneTree
const Model = preload("res://career/challenges_model.gd")

func _initialize() -> void:
	var row := {"id":"source-row", "label":"Play 3 matches", "target":3, "progress":2, "reward":90, "done":false}
	assert(Model.rows([row]).size() == 1)
	assert(Model.rows([row, row]).is_empty())
	for bad: Variant in [-1, 1.5, true, "90"]:
		var malformed := row.duplicate()
		malformed.reward = bad
		assert(Model.rows([malformed]).is_empty())
	assert(Model.project({}).is_empty())
	assert(Model.award({"version":1,"gained":0,"completed":[]}) == {"gained":0,"completed":[]})
	assert(Model.award({"version":1,"gained":90,"completed":[{"id":"source-row","label":"Play 3 matches","reward":90}]}).completed.size() == 1)
	assert(load("res://tests/mode_expansion/challenges_live.tscn") != null)
	print("CHALLENGE_NATIVE_CONTRACTS_OK")
	quit()
