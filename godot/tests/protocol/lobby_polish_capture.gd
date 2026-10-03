extends SceneTree
## Real controls and routed keyboard focus; controlled advertised-room records.
const RoomBrowser = preload("res://social/room_browser.gd")
var failures := 0
var output := ""

func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for frame in 3: await process_frame
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func room_rows() -> Array:
	return [
		{"roomId":"AB12","name":"Alpha","mapId":"meridian-exchange","players":2,"started":false,"config":{"mode":"teamdeathmatch"}},
		{"roomId":"CD34","name":"Bravo","mapId":"verdant-reliquary","players":1,"started":true,"config":{"mode":"deathmatch"}},
		{"roomId":"EF56","name":"Echo","mapId":"meridian-exchange","players":3,"started":false,"config":{"mode":"deathmatch"}}]

func save_frame(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-out="): output=arg.trim_prefix("--evidence-out=")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(760,520)
	root.content_scale_factor=1.5
	var margin := MarginContainer.new()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	var browser := RoomBrowser.new()
	margin.add_child(browser)
	browser.sync(true)
	browser.accept(room_rows())
	browser.rebuild()
	await settle()
	browser.search.grab_focus()
	await save_frame("rooms-keyboard-focus")
	browser.search.text="no-such-room"
	browser.rebuild()
	await save_frame("filtered-empty")
	# Same ordinary recovery path in both candidates: clear the focused query.
	browser.search.grab_focus()
	browser.search.select_all()
	var erase := InputEventKey.new()
	erase.physical_keycode=KEY_BACKSPACE
	erase.keycode=KEY_BACKSPACE
	erase.pressed=true
	Input.parse_input_event(erase)
	erase=erase.duplicate()
	erase.pressed=false
	Input.parse_input_event(erase)
	await settle()
	browser.rebuild()
	check(browser.search.text.is_empty(),"routed Backspace clears selected query")
	await save_frame("recovered-rooms")
	browser.accept([])
	browser.rebuild()
	await save_frame("server-empty")
	margin.free()
	print("LOBBY_POLISH_CAPTURE ",JSON.stringify({"failures":failures,"scope":"real controls; synthetic advertised-room records; UI150 760x520"}))
	quit(0 if failures==0 else 1)
