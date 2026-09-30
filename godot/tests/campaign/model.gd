extends SceneTree
const Model = preload("res://campaign/model.gd")

func _initialize() -> void:
	var model := Model.new()
	var marker := {"x":1,"y":2,"z":3,"radius":4}
	var state := {"id":"quiet-relay", "mapId":"rootfall-verge", "title":"Rootfall Verge", "objective":"Recover archive", "detail":"Follow the signal", "phase":"playing", "checkpoint":0, "marker":marker, "transmission":{"speaker":"ECHO","text":"Help."}, "nextMapId":"siltwake-crossing"}
	assert(model.apply(state) and model.playing() and model.action().is_empty())
	state.phase = "dead"
	state.marker = null
	assert(model.apply(state) and not model.playing() and model.action() == "retry")
	state.phase = "playing"
	state.marker = marker
	state.checkpoint = 1
	assert(model.apply(state) and model.checkpoint_notice.contains("1"))
	state.phase = "level-complete"
	state.marker = null
	assert(model.apply(state) and model.action() == "continue")
	state.phase = "campaign-complete"
	assert(model.apply(state) and model.action().is_empty())
	state.mapId = "old-deferred-map"
	assert(not model.apply(state))
	assert(model.state.mapId == "rootfall-verge", "invalid state cannot replace current chapter")
	print("CAMPAIGN_MODEL_OK")
	quit()
