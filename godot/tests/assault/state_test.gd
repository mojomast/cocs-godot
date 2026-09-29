extends SceneTree
## Bounded logic-only suite; run after the integration lead grants Godot execution.
const State = preload("res://assault/state.gd")

func fixture(count: int = 3) -> Dictionary:
	var zones: Array = []
	for index in range(count):
		zones.append({"id":"sector-%d" % index, "x":index*10, "y":2, "z":-3, "radius":3.5, "owner":null, "captureTeam":null, "progress":0, "captureSeconds":6})
	return {"config":{"mode":"assault"}, "objectives":{"kind":"assault", "active":0, "attacker":0, "defender":1, "breached":false, "winner":null, "zones":zones}}

func _init() -> void:
	var model := State.new()
	for count in [1, 3, 9]:
		var frame := fixture(count)
		assert(model.apply_state(frame)) # No contested property on the source wire.
		assert(model.active_sector().id == "sector-0")
		frame.objectives.zones[0].progress = 88
		assert(model.active_sector().progress == 0) # Own immutable snapshot copy.
	var frame := fixture()
	frame.objectives.active = 1
	frame.objectives.zones[1].progress = 37.5
	assert(model.apply_state(frame))
	assert(model.active_sector().id == "sector-1")
	assert(model.active_sector().progress == 37.5)
	assert("DEFEND" in model.text(1, false))
	assert("0.6" in model.text(0, false))
	for field in ["active", "winner", "breached", "attacker", "defender", "zones"]:
		var invalid := fixture()
		invalid.objectives.erase(field)
		assert(not model.apply_state(invalid))
		assert(model.objective.is_empty())
	for field in ["id", "x", "y", "z", "radius", "owner", "captureTeam", "progress", "captureSeconds"]:
		var invalid := fixture()
		invalid.objectives.zones[0].erase(field)
		assert(not model.apply_state(invalid))
		assert(model.active_sector().is_empty())
	for progress in [-1, 101, INF, NAN, "40"]:
		var invalid := fixture()
		invalid.objectives.zones[0].progress = progress
		assert(not model.apply_state(invalid))
	for count in [0, 10]: assert(not model.apply_state(fixture(count)))
	for active in [-1, 4, 0.5, "0"]:
		var invalid := fixture()
		invalid.objectives.active = active
		assert(not model.apply_state(invalid))
	for owner in [2, -1, "0", false]:
		var invalid := fixture()
		invalid.objectives.zones[0].owner = owner
		assert(not model.apply_state(invalid))
	var duplicate := fixture()
	duplicate.objectives.zones[1].id = duplicate.objectives.zones[0].id
	assert(not model.apply_state(duplicate))
	frame = fixture()
	frame.objectives.active = 3
	frame.objectives.breached = true
	# A breach or a 100% sector must never synthesize a winner locally.
	assert(model.apply_state(frame))
	assert(model.active_sector().is_empty())
	assert("No winner reported" in model.text(0, true))
	frame.objectives.winner = 0
	assert(model.apply_state(frame))
	assert("Attackers win" in model.text(0, true))
	frame = fixture()
	frame.objectives.winner = 1
	assert(model.apply_state(frame))
	assert("Defenders win" in model.text(1, true))
	model.clear_round()
	assert(model.objective.is_empty())
	assert(model.active_sector().is_empty())
	print("ASSAULT_STATE_OK")
	quit()
