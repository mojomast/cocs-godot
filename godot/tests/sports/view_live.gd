extends SceneTree
## Ordinary public Puma race client, physical routed keys, unmodified authority.
var session: Node
var output := ""
var failures: Array[String] = []
var observations: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr(message)

func key(code: int, down: bool) -> void:
	var input := InputEventKey.new()
	input.physical_keycode=code
	input.pressed=down
	Input.parse_input_event(input)

func tap(code: int) -> void:
	key(code,true)
	key(code,false)

func wait_for(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec()+roundi(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	return false

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
	observations.append({"stage":name,"vehicle":session.vehicle.duplicate(true),"camera":str(session.world.camera.global_transform),"first":session.chase.first_person})

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-out="): output=arg.trim_prefix("--evidence-out=")
	DirAccess.make_dir_recursive_absolute(output)
	if "--compact" in OS.get_cmdline_user_args():
		root.size=Vector2i(760,520)
		var settings := preload("res://ui/settings_access.gd").service()
		settings.set_value("ui_scale",150,false)
	change_scene_to_file("res://multiplayer_worlds/sports_demo.tscn")
	await scene_changed
	session=current_scene
	if not await wait_for(func() -> bool: return session.eligible(),20):
		check(false,"public race receives eligible source vehicle: phase=%s error=%s state=%s"%[session.phase,session.error,session.state])
		finish()
		return
	tap(KEY_ENTER)
	await process_frame
	check(session.controls.engaged,"ordinary Enter engages driving")
	for first: bool in [false,true]:
		if session.chase.first_person!=first: tap(KEY_F4)
		await create_timer(0.3).timeout
		check(session.chase.first_person==first,"F4 selects requested view")
		var before: Dictionary=session.vehicle.duplicate(true)
		key(KEY_W,true)
		await create_timer(0.8).timeout
		key(KEY_W,false)
		var delta := Vector2(float(session.vehicle.x)-float(before.x),float(session.vehicle.z)-float(before.z))
		var forward := Vector2(sin(float(before.yaw)),cos(float(before.yaw)))
		check(delta.dot(forward)>0.1,"ordinary W advances source chassis forward")
		await capture("first-drive" if first else "third-drive")
		var yaw_before: float=session.vehicle.yaw
		key(KEY_W,true); key(KEY_D,true)
		await create_timer(0.7).timeout
		key(KEY_D,false); key(KEY_W,false)
		check(absf(wrapf(float(session.vehicle.yaw)-yaw_before,-PI,PI))>0.02,"ordinary D turns chassis while driving")
		await capture("first-turn" if first else "third-turn")
	tap(KEY_ESCAPE)
	await process_frame
	check(not session.controls.engaged,"Escape drains ordinary driving holds")
	if await wait_for(func() -> bool: return session.phase=="results",70):
		await capture("public-results")
		check(session.hud.result_panel.visible,"shared result panel visible")
		check(root.get_visible_rect().encloses(session.hud.result_panel.get_global_rect()),"shared result panel fits actual logical viewport")
		tap(KEY_F5)
		if await wait_for(func() -> bool: return session.phase=="active" and session.eligible(),10):
			check(not session.controls.engaged,"restart drains driving latch")
			check(session.audiovisual.service.music.orchestra.player.stream!=null,"restart restores persistent music stream")
			check(session.audiovisual.service.music.outcome.is_empty(),"restart removes prior outcome")
			await capture("public-restart")
		else: check(false,"ordinary F5 begins next confirmed source round")
	else: check(false,"ordinary source timer reaches public results")
	change_scene_to_file("res://ui/main_menu.tscn")
	await scene_changed
	await create_timer(0.3).timeout
	finish()

func finish() -> void:
	var report := {"passed":failures.is_empty(),"failures":failures,"observations":observations,"classification":"public Puma race ordinary input; no mount/demount in this route"}
	FileAccess.open(output.path_join("native.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("VEHICLE_VIEW_LIVE ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
