extends SceneTree
const Outcome = preload("res://audio/outcome.gd")

func _initialize() -> void:
	var teams := {"over":true, "winner":0, "actors":[{"id":4,"team":0},{"id":5,"team":1}]}
	assert(Outcome.resolve(teams, "cocs", 4) == "victory")
	assert(Outcome.resolve(teams, "puma-soccer", 5) == "defeat")
	assert(Outcome.resolve(teams, "cocs", -1) == "neutral")
	assert(Outcome.resolve({"over":true,"actors":teams.actors}, "ctf", 5) == "neutral", "unknown winner cannot become defeat")
	assert(Outcome.resolve({"over":true,"race":{"winnerId":5},"actors":teams.actors}, "puma-race", 5) == "victory")
	assert(Outcome.resolve({"over":true,"race":{"winnerId":5},"actors":teams.actors}, "puma-race", -1) == "neutral")
	assert(Outcome.resolve({"over":true,"singleplayer":{"winner":0},"actors":teams.actors}, "horde", 4) == "victory")
	assert(Outcome.resolve({"over":true,"singleplayer":{"winner":1},"actors":teams.actors}, "horde", 4) == "defeat")
	assert(Outcome.resolve({"over":true,"winner":null,"actors":[{"id":4,"frags":3},{"id":5,"frags":3}]}, "deathmatch", 4) == "victory", "ties share FFA award")
	print("AUDIO_OUTCOME_OK")
	quit()
