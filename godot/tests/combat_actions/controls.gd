extends SceneTree
const Actions = preload("res://world/combat_actions.gd")
const Session = preload("res://world/session.gd")
const ArmsRace = preload("res://arms_race/demo.gd")
const Combined = preload("res://combined_arms/controls.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func key(code: int, pressed: bool, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	e.echo = echo
	return e

func mouse(button: int, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	return e

func prepare(s: Node) -> void:
	for node: Node in [s.camera,s.label,s.selector,s.environment,s.sun,s.client,s.presentation,s.pickups,s.combat,s.combat_label]: s.add_child(node)
	s.phase = 3
	s.received_pose = true
	s.presentation.lifecycle.status = "alive"
	s.presentation.local_actor = {"weapon":0,"health":100,"dead":0}
	s.snapshot_watch.observe()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _initialize() -> void:
	var a := Actions.new()
	for code: int in Actions.EDGE_KEYS:
		var field: String = Actions.EDGE_KEYS[code]
		a.record(key(code, true), true)
		a.record(key(code, false), true)
		check(a.sample(0, 0, true)[field], field + " tap retained")
		check(a.sample(0, 0, true)[field], field + " queue failure retains pulse")
		a.queued()
		check(not a.sample(0, 0, true)[field], field + " queued once")
		a.record(key(code, true), true)
		a.queued()
		a.record(key(code, true, true), true)
		a.record(key(code, true), true)
		check(bool(a.sample(0, 0, true)[field]) == (field == "melee"),
			field + " held repeats only melee at source cooldown; other edges never retrigger")
		a.clear()
		a.record(key(code, true), true)
		check(not a.sample(0, 0, true)[field], field + " boundary requires release")
		a.record(key(code, false), false)
		a.record(key(code, true), true)
		check(a.sample(0, 0, true)[field], field + " fresh press re-arms")
		a.record(key(code, false), true)
		a.queued()
	a.record(key(KEY_F, true), true)
	check(a.sample(0,0,true).melee and not a.sample(0,0,true).mobility, "F is melee, intentionally no longer mobility")
	a.record(key(KEY_X, true), true)
	a.record(key(KEY_Z, true), true)
	check(a.sample(0,0,true).mobility and a.sample(0,0,true).altFire, "X/Z are held controls")
	a.queued()
	check(a.sample(0,0,true).mobility and a.sample(0,0,true).altFire, "held controls persist through queue")
	check(a.sample(0,0,true).melee, "holding F requests the next source-permitted kick")
	a.record(key(KEY_F,false),true)
	check(not a.sample(0,0,true).melee, "F release stops repeat kicks")
	a.record(key(KEY_Z, false), true)
	a.record(mouse(MOUSE_BUTTON_MIDDLE, true), true)
	check(a.sample(0,0,true).altFire, "MMB alternate")
	a.record(mouse(MOUSE_BUTTON_MIDDLE, false), true)
	check(not a.sample(0,0,true).altFire, "alternate release explicit false")
	a.record(key(KEY_W, true), true)
	a.record(key(KEY_D, true), true)
	var diagonal := a.sample(0.7,0,true)
	check(is_equal_approx(Vector2(diagonal.x,diagonal.z).length(),1), "recorded movement normalized")
	var neutral := a.sample(0,0,false)
	for field: String in ["fire","ads","altFire","jump","reload","interact","power","melee","grenade","mobility","sprint","crouch"]:
		check(neutral.has(field) and not neutral[field], "explicit neutral " + field)
	check(neutral.x == 0 and neutral.z == 0, "neutral movement")
	a.record(key(KEY_W,true),true)
	check(a.sample(0,0,true).z == 0, "held movement cannot resume after boundary")
	a.record(key(KEY_W,false),false)
	a.record(key(KEY_W,true),true)
	check(a.sample(0,0,true).z == -1, "fresh movement resumes after release")

	var s := Session.new()
	prepare(s)
	s.release_pointer()
	var click := mouse(MOUSE_BUTTON_LEFT,true)
	s._input(click)
	s._unhandled_input(click)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "eligible click captures")
	s._input(mouse(MOUSE_BUTTON_LEFT,false))
	check(s.combat_actions.sample(0,0,true).fire, "capture click tap survives until send")
	s.combat_actions.queued()
	check(not s.combat_actions.sample(0,0,true).fire, "capture click pulse consumed once")
	s._input(mouse(MOUSE_BUTTON_RIGHT, true))
	check(s.aim_requested(), "shared session responsive ADS press")
	s.update_look(Vector2(100,0))
	check(is_equal_approx(s.yaw,-0.255), "ADS look applies source .85 once")
	s._input(mouse(MOUSE_BUTTON_RIGHT, false))
	check(not s.aim_requested(), "shared session ADS release")
	for boundary: String in ["focus","stale","dead","spectator","results","weapon","reload"]:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		s._input(mouse(MOUSE_BUTTON_RIGHT, true))
		check(s.aim_requested(), boundary + " starts aimed")
		match boundary:
			"focus": s._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"stale": s.snapshot_watch.advance(1.0)
			"dead": s.presentation.lifecycle.status = "dead"
			"spectator": s.client.spectating = true
			"results": s.phase = 4
			"weapon": s.presentation.local_actor.weapon = 1
			"reload": s.presentation.local_actor.reloading = true
		check(not s.aim_requested(), boundary + " cancels ADS")
		s._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		s.snapshot_watch.observe()
		s.presentation.lifecycle.status = "alive"
		s.client.spectating = false
		s.phase = 3
		s.presentation.local_actor.reloading = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		s._input(mouse(MOUSE_BUTTON_RIGHT, true))
		check(not s.aim_requested(), boundary + " cannot resume held ADS")
		s._input(mouse(MOUSE_BUTTON_RIGHT, false))
		s._input(mouse(MOUSE_BUTTON_RIGHT, true))
		check(s.aim_requested(), boundary + " fresh release/press works")
		s._input(mouse(MOUSE_BUTTON_RIGHT, false))
	s.free()
	var arms := ArmsRace.new()
	prepare(arms)
	arms._input(mouse(MOUSE_BUTTON_RIGHT, true))
	check(not arms.weapon_controls_active() and arms.aim_requested(), "Arms Race ADS independent from pinned weapon selection")
	arms.free()
	var c := Combined.new()
	c.accept(key(KEY_ENTER,true),true)
	c.accept(mouse(MOUSE_BUTTON_RIGHT,true),true,true)
	check(c.command(0,0,true,false).ads, "Combined infantry ADS")
	check(not c.command(0,0,true,true).ads, "Combined driving neutral ADS")
	c.release()
	c.accept(key(KEY_ENTER,false),true)
	c.accept(key(KEY_ENTER,true),true)
	c.accept(mouse(MOUSE_BUTTON_RIGHT,true),true,true)
	check(not c.command(0,0,true,false).ads, "Combined boundary no held resume")
	c.accept(mouse(MOUSE_BUTTON_RIGHT,false),true,true)
	c.accept(mouse(MOUSE_BUTTON_RIGHT,true),true,false)
	check(not c.command(0,0,true,false).ads, "mounted press cannot latch infantry ADS")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("NATIVE_COMBAT_ACTIONS checks=",checks," failures=",failures," synthetic=true")
	quit(1 if failures else 0)
