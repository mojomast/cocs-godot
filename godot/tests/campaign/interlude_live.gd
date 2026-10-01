extends SceneTree
## Normal movement/E controls over the real campaign WebSocket client. Only the
## initial checkpoint is supplied by the trusted authority test seam.
const Client = preload("res://campaign/client.gd")
const Terrain = preload("res://campaign/terrain.gd")
const Model = preload("res://campaign/model.gd")
const Director = preload("res://campaign/interlude_director.gd")
const Widgets = preload("res://campaign/story_widgets.gd")
var client: Node
var state: Dictionary = {}
var model := Model.new()
var director: Node3D
var widgets: Control
var beat_id := ""
var started := Time.get_ticks_msec()

func _initialize() -> void:
	call_deferred("run")

func _process(_dt: float) -> bool:
	if Time.get_ticks_msec()-started > 90000:
		printerr("INTERLUDE_LIVE_TIMEOUT ",beat_id); quit(1)
	return false

func receive(frame: Dictionary) -> void:
	state = frame.state
	if not model.apply(state.campaign):
		printerr(model.error); quit(1); return
	director.apply(state.campaign.interludes,state.mapId)
	widgets.observe(state.campaign.story,true,state.campaign.interludes)

func control(value: Dictionary) -> void:
	while client.send_controls(value) == ERR_BUSY:
		await create_timer(0.017).timeout
	await create_timer(0.017).timeout

func walk(points: Array) -> void:
	for p: Dictionary in points:
		while true:
			var a: Dictionary = state.actors[0]
			var delta := Vector2(float(p.x)-float(a.x),float(p.z)-float(a.z))
			if delta.length() < 0.6: break
			delta = delta.normalized()
			await control({"x":delta.x,"z":delta.y})
	await control({})

func pulse(yaw: float = 0) -> void:
	await control({})
	await control({"interact":true,"yaw":yaw})
	await control({})
	await create_timer(0.2).timeout

func current() -> Dictionary:
	for beat: Dictionary in state.campaign.interludes.beats:
		if beat.id == beat_id: return beat
	return {}

func run() -> void:
	var endpoint := ""
	var map_id := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg.begins_with("--map="): map_id = arg.trim_prefix("--map=")
		if arg.begins_with("--beat="): beat_id = arg.trim_prefix("--beat=")
	var world := Terrain.new()
	root.add_child(world)
	assert(world.build(map_id))
	director = Director.new(); root.add_child(director)
	widgets = Widgets.new(); root.add_child(widgets)
	client = Client.new(); root.add_child(client)
	client.snapshot.connect(receive)
	client.connection_error.connect(func(message: String) -> void: printerr(message); quit(1))
	assert(client.connect_server(endpoint,{map_id:{"modes":["campaign"],"geometryHash":world.recipe.geometryHash}},map_id) == OK)
	while client.peer.get_ready_state() != WebSocketPeer.STATE_OPEN: await process_frame
	assert(client.create_room() == OK)
	assert(client.send_frame({"type":"start"}) == OK)
	while state.is_empty(): await process_frame
	var route: Array = []
	for r: Dictionary in world.recipe.routes:
		if r.id == "interlude-"+beat_id+"-a": route = r.points
	await walk(route)
	var beat := current()
	var actor: Dictionary = state.actors[0]
	await pulse(atan2(-(float(beat.b.x)-float(actor.x)),-(float(beat.b.z)-float(actor.z))))
	if beat.family == "link":
		assert(int(current().stage) == 1)
		await walk(beat.cable)
		await pulse()
	assert(current().completed, "Authority accepted native movement and fresh E")
	assert(widgets.caption.visible and not widgets.caption.text.is_empty())
	assert(director.workshops[beat_id].get_meta("title").text.contains("RESTORED"))
	var choice: Variant = current().choice
	await pulse()
	assert(current().completed and current().choice == choice)
	print("INTERLUDE_LIVE_NATIVE_OK ",map_id," ",beat_id," controls=",client.input_seq," feedback=",widgets.caption.text)
	client.disconnect_server()
	world.free(); widgets.free(); director.free(); client.free()
	quit()
