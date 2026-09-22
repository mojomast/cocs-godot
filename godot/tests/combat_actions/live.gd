extends SceneTree
## Injected native InputEvents -> actual Session sampler -> WebSocket -> normal
## production server. No simulation writes; this is protocol, not GUI evidence.
const Session = preload("res://world/session.gd")
class FixtureSession extends Session:
	func on_lobby(frame: Dictionary) -> void:
		if phase == 1:
			client.send_frame({"type":"host","mapId":current_id,"config":{"mode":"deathmatch","botCount":0,"timeLimit":60}})
			phase = 2
		else: super.on_lobby(frame)

var s := FixtureSession.new()
var stage := 0
var age := 0.0
var total := 0.0
var event_counts := {}
var power_effect := false
var ads_true := false
var ads_false := false
var focus_false := false
var sequence_before_spectator := 0

func _initialize() -> void:
	call_deferred("setup")

func setup() -> void:
	# Detached Session avoids a world/render fixture; its real input and sampler
	# still use the X11 pointer state. Transport is attached and polls normally.
	for n: Node in [s.camera,s.label,s.selector,s.environment,s.sun,s.presentation,s.pickups,s.combat,s.combat_label]: s.add_child(n)
	root.add_child(s.client)
	s.catalog.open()
	s.current_id = "meridian-exchange"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--endpoint="): s.endpoint = arg.trim_prefix("--endpoint=")
	s.client.lobby.connect(s.on_lobby)
	s.client.started.connect(s.on_started)
	s.client.snapshot.connect(snapshot)
	s.client.events.connect(events)
	s.client.connection_error.connect(func(message: String) -> void: fail(message))
	s.trace_enabled = true
	s.connect_selected_match()

func mouse(pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = pressed
	s._input(e)
	print("COMBAT_STIMULUS ",JSON.stringify({"stage":stage,"rmb":pressed,"local_aim":s.aim_requested()}))

func key(code: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	s._input(e)

func events(items: Array) -> void:
	for item: Dictionary in items:
		if item.get("actor") == s.client.actor_id:
			var type := str(item.get("type", ""))
			event_counts[type] = int(event_counts.get(type,0)) + 1
			print("COMBAT_AUTHORITY_EVENT ", JSON.stringify(item))

func snapshot(frame: Dictionary) -> void:
	s.on_snapshot(frame)
	var actor := s.presentation.local_actor
	if actor.is_empty(): return
	print("COMBAT_AUTHORITY ",JSON.stringify({"stage":stage,"ack":s.client.last_ack,"ads":actor.get("ads"),"active":actor.get("active"),"cooldown":actor.get("cooldown"),"harness":actor.get("harness"),"health":actor.get("health")}))
	if stage == 1 and actor.get("ads") == true: ads_true = true
	if stage == 2 and actor.get("ads") == false: ads_false = true
	if stage == 4 and actor.get("ads") == false: focus_false = true
	if float(actor.get("cooldown",0)) > 0: power_effect = true

func next() -> void:
	stage += 1
	age = 0

func fail(message: String) -> void:
	push_error("COMBAT_LIVE " + message)
	cleanup()
	quit(1)

func cleanup() -> void:
	s.client.disconnect_server()
	s.client.free()
	s.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> bool:
	total += delta
	age += delta
	if total > 20:
		fail("timeout stage %d" % stage)
		return true
	s._process(delta)
	match stage:
		0:
			if not s.received_pose: return false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			next()
			mouse(true)
		1:
			if ads_true and age > 0.25:
				next()
				mouse(false)
		2:
			if ads_false and age > 0.25:
				next()
				mouse(true)
		3:
			if age > 0.25:
				next()
				s._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		4:
			if focus_false and age > 0.25:
				s._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				mouse(true) # Deliberate duplicate held input must not re-arm.
				if s.aim_requested(): fail("focus regained held ADS"); return true
				mouse(false)
				next()
				key(KEY_Q,true)
				key(KEY_F,true)
				key(KEY_G,true)
		5:
			if age > 1.2:
				if not power_effect or event_counts.get("power",0) != 1 or event_counts.get("melee",0) != 1 or event_counts.get("grenade",0) != 1:
					fail("source action effects missing/repeated " + JSON.stringify(event_counts)); return true
				for code: int in [KEY_Q,KEY_F,KEY_G]: key(code,false)
				# Synthetic read-only identity boundary, checked against real transport
				# sequence: Session must not even call send_input for spectators.
				s.client.spectating = true
				sequence_before_spectator = s.client.input_seq
				next()
				mouse(true)
				for code: int in [KEY_Q,KEY_F,KEY_G,KEY_X,KEY_Z]: key(code,true)
		6:
			if age > 0.15:
				if s.client.input_seq != sequence_before_spectator: fail("spectator queued input"); return true
				print("COMBAT_LIVE_OK ", JSON.stringify({"ads_true":ads_true,"ads_false":ads_false,"focus_neutral":focus_false,"power_effect":power_effect,"events":event_counts,"spectator_no_queue":true,"synthetic_events":true,"normal_server":true,"gui_acceptance":false}))
				cleanup()
				quit(0)
				return true
	return false
