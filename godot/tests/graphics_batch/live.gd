extends SceneTree
## Normal-rate source authority with automated protocol inputs, never state injection.
const Session = preload("res://world/session.gd")
const GameHUD = preload("res://ui/game_hud.gd")
const Scoreboard = preload("res://ui/scoreboard.gd")

class AutomatedSession extends Session:
	var input_clock := 0.0
	var round_clock := 0.0
	func on_lobby(frame: Dictionary) -> void:
		if phase == 1:
			client.send_frame({"type":"host","mapId":current_id,"config":{"mode":"teamdeathmatch","botCount":2,"timeLimit":60,"fragLimit":100}})
			phase = 2
		else:
			super.on_lobby(frame)
	func on_started(frame: Dictionary) -> void:
		round_clock = 0
		super.on_started(frame)
	func _process(delta: float) -> void:
		# Suppress the human-input sender; everything else uses production callbacks.
		send_elapsed = -1
		super._process(delta)
		if phase != 3: return
		round_clock += delta
		input_clock += delta
		if input_clock < 1.0 / 60.0: return
		input_clock = fmod(input_clock, 1.0 / 60.0)
		var active: bool = received_pose and not snapshot_watch.stale() and presentation.lifecycle.can_control()
		if active and can_capture_pointer(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if active:
			var actor: Dictionary = presentation.local_actor
			# Ordinary steering toward the arena centre keeps capture framing useful.
			yaw = atan2(float(actor.x),float(actor.z))
			if Vector2(actor.x,actor.z).length() < 8: yaw += PI * 0.5
		var direction := ControlMath.movement(yaw, 1.0, 0.0) if active else Vector2.ZERO
		var controls := {"x":direction.x,"z":direction.y,"yaw":yaw,"pitch":pitch,"fire":active and fmod(round_clock, 10.0) < 8.0,"reload":active and fmod(round_clock, 10.0) >= 8.0}
		var choices: Array[int] = []
		for index in range(10):
			if WeaponSelection.available(presentation.local_actor,index): choices.append(index)
		if active and not choices.is_empty(): controls.weapon = choices[int(round_clock / 8.0) % choices.size()]
		if client.send_input(controls) != OK: on_error("Graphics live input enqueue failed")

var session: Node
var output := ""
var elapsed := 0.0
var records: Array = []
var events: Array = []
var transitions: Array = []
var pictures: Array[String] = []
var previous := Vector3.ZERO
var moving := 0
var snapshots := 0
var weapons: Dictionary = {}
var failed := false
var finishing := false
var capturing := false
var restarted := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("start")

func start() -> void:
	session = AutomatedSession.new()
	# Match the two production session.tscn UI children.
	session.add_child(Scoreboard.new())
	session.add_child(GameHUD.new())
	root.add_child(session)
	session.client.snapshot.connect(observe)
	session.client.events.connect(func(items: Array) -> void: events.append_array(items))
	session.client.started.connect(func(frame: Dictionary) -> void: transitions.append(frame))
	session.client.results.connect(func(frame: Dictionary) -> void: transitions.append(frame))

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("GRAPHICS_LIVE: " + message)

func observe(frame: Dictionary) -> void:
	snapshots += 1
	var actor: Dictionary = session.presentation.local_actor
	if not actor.is_empty():
		var position := Vector3(actor.x,actor.y,actor.z)
		if snapshots > 1 and position.distance_to(previous) > .01: moving += 1
		previous = position
		weapons[str(actor.get("weapon",-1))] = true
	records.append({"snapshot":frame,"camera":[session.camera.position.x,session.camera.position.y,session.camera.position.z],"phase":session.phase})

func _process(delta: float) -> bool:
	elapsed += delta
	if not is_instance_valid(session) or finishing: return false
	if elapsed > 90 or session.phase == -1:
		check(false,"normal-rate deadline/session error")
		finishing = true
		call_deferred("finish")
	if not capturing and session.phase == 3 and session.presentation.lifecycle.can_control():
		if pictures.is_empty() and elapsed > 12:
			capturing = true
			call_deferred("capture",Vector2i(960,640))
		elif pictures.size() == 1 and elapsed > 28:
			capturing = true
			call_deferred("capture",Vector2i(1280,800))
	if session.phase == 4 and not restarted:
		restarted = true
		session.request_restart()
	if restarted and session.round_starts == 2 and session.phase == 3 and session.round_clock > 2:
		finishing = true
		call_deferred("finish")
	return false

func capture(size: Vector2i) -> void:
	root.size = size
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var filename := "live-%dx%d.png" % [size.x,size.y]
	check(root.get_texture().get_image().save_png(output.path_join(filename)) == OK,"live image saved")
	pictures.append(filename)
	capturing = false

func finish() -> void:
	check(snapshots > 100 and moving > 20,"source-correlated movement")
	check(not events.is_empty(),"public combat events received")
	check(restarted and session.round_starts == 2,"natural results and restart")
	check(pictures.size() == 2,"both graphical sizes")
	var summary := {"passed":not failed,"snapshots":snapshots,"movement_transitions":moving,"weapons":weapons.keys(),"events":events.size(),"pictures":pictures,"round_starts":session.round_starts,"elapsed_seconds":elapsed,"automated_protocol_inputs":true,"state_injection":false}
	var file := FileAccess.open(output.path_join("live.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"summary":summary,"records":records,"events":events,"transitions":transitions}))
	file.close()
	print("GRAPHICS_LIVE_RESULT ",JSON.stringify(summary))
	session.queue_free()
	await process_frame
	quit(1 if failed else 0)
