extends SceneTree
const Model = preload("res://horde/model.gd")
const Demo = preload("res://horde/demo.gd")
var count := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void:
	var m := Model.new()
	m.apply({})
	check(m.state.is_empty(), "missing state cleared")
	m.apply({"singleplayer":{"kind":"campaign"}})
	check(m.state.is_empty(), "campaign rejected")
	var raw: Dictionary = JSON.parse_string('{"singleplayer":{"kind":"horde","wave":1,"waveTarget":10,"lives":3,"score":0,"enemiesAlive":3,"enemiesTotal":3,"waveTimer":2.1,"phase":"intermission","winner":null}}')
	m.apply(raw)
	check("NEXT WAVE IN 3s" in m.text, "authoritative fractional timer")
	check("LIVES 3" in m.text, "JSON number display")
	m.apply(raw, true)
	check(m.state.is_empty() and "stalled" in m.text, "stale clears old state")
	raw.singleplayer.phase = "won"
	raw.singleplayer.winner = 0.0
	raw.over = true
	m.apply(raw)
	check("VICTORY" in m.text and "Enter" in m.text, "winner zero and results")
	raw.singleplayer.phase = "lost"
	raw.singleplayer.lives = 0.0
	m.apply(raw)
	check("DEFEAT" in m.text and "LIVES 0" in m.text, "loss projection")
	m.clear()
	check(m.state.is_empty() and not "DEFEAT" in m.text, "round cleanup")
	raw.singleplayer.phase = "wave"
	raw.singleplayer.wave = 2.0
	m.apply(raw)
	check("WAVE 2 / 10" in m.text, "wave changes follow snapshot only")
	var d := Demo.new()
	var seen: Array = []
	d.client.events.connect(func(items: Array) -> void: seen.append_array(items))
	d.client.decode_text('{"type":"events","items":[{"id":1,"type":"horde-wave"}]}')
	d.client.decode_text('{"type":"events","items":[{"id":1,"type":"horde-wave"}]}')
	check(seen.size() == 1, "inherited transport deduplicates events")
	d.client.reset_round()
	d.client.decode_text('{"type":"events","items":[{"id":1,"type":"horde-wave"}]}')
	check(seen.size() == 2, "event identity resets next round")
	var a := {"id":0.0,"x":1.0,"y":0.0,"z":2.0,"yaw":0.0,"pitch":0.0,"health":100.0,"dead":0.0}
	var enemy := a.duplicate(true)
	enemy.id = 1.0
	enemy.isNpc = true
	enemy.npcType = "husk"
	d.presentation.apply_state({"actors":[a,enemy]},0)
	d.apply_horde({"actors":[a,enemy],"singleplayer":{"kind":"horde","phase":"wave","wave":2.0}})
	check(d.presentation.local_actor.id == 0, "actor zero retained")
	check(d.presentation.actors[1].has_node("HordeRole"), "received enemy role label")
	d.presentation.apply_state({"actors":[a]},0)
	check(d.presentation.actors.size()==1, "absent enemy removed")
	d.on_started({})
	check(d.presentation.actors.is_empty() and d.horde.state.is_empty() and d.latest.is_empty(), "full round cleanup")
	# Detached components are not owned by the scene until _ready; free explicitly.
	for node: Node in [d.camera,d.sun,d.environment,d.label,d.selector,d.combat_label,d.pickups,d.presentation,d.combat,d.client,d.horde_label]: node.free()
	d.free()
	print("HORDE_TESTS checks=",count," failures=",failures)
	quit(0 if failures == 0 else 1)
