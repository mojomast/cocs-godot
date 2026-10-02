extends SceneTree
const State = preload("res://mode_expansion/state.gd")
const Scene = preload("res://mode_expansion/demo.tscn")

func _initialize() -> void:
	var projection := State.new()
	var actors := [{"id":0,"name":"Crown zero","x":1,"y":2,"z":3,"juggernautShield":125},{"id":1,"name":"Hunter","x":9,"y":0,"z":4,"health":260,"team":1}]
	var state := {"config":{"mode":"juggernaut"},"actors":actors,"objectives":{"juggernautId":0,"points":{"0":3.5}},"over":true,"winner":0}
	projection.apply(state, 0)
	assert(projection.text.contains("3.5") and projection.text.contains("Crown zero wins"))
	assert(projection.markers.size() == 1 and projection.markers[0].x == 1)
	state.objectives.juggernautId = 1
	projection.apply(state, 0)
	assert(projection.markers.size() == 1 and projection.markers[0].x == 9)
	state.config.mode = "arsenal"
	state.objectives = null
	projection.apply(state, 0)
	assert(projection.markers.is_empty() and projection.text.contains("All ten weapons"))
	state.config.mode = "team-elimination"
	state.objectives = {"lives":{"0":2,"1":0}}
	projection.apply(state, 0)
	assert(projection.text.contains("Red 2 / Blue 0") and projection.text.contains("Red team wins"))
	state.config.mode = "vip-escort"
	state.objectives = {"vipId":1,"escortTeam":0,"defenderTeam":1,"progress":2.5,"captureSeconds":4,"extract":{"x":20,"y":0,"z":30}}
	state.winner = 1
	projection.apply(state, 0)
	assert(projection.markers.size() == 2 and projection.text.contains("2.5 / 4.0s") and projection.text.contains("Blue team wins"))
	state.objectives.vipDead = true
	projection.apply(state, 0)
	assert(projection.markers.size() == 1 and projection.markers[0].id == "extract")
	# Parse the full scene dependency closure without constructing an unattached
	# session, whose composition intentionally parents its nodes in _ready().
	assert(Scene.get_state().get_node_count() == 3)
	print("MODE_NATIVE_CONTRACTS_OK four_modes=true zero_winner=true crown_transfer=true stale_markers_cleared=true vip_death=true scene_composition=true")
	quit()
