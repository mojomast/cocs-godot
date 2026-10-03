extends SceneTree
## Production scene, real InputEvents and public UI only. No combat setters,
## simulator steps, synthetic focus notifications or forged device-loss signals.
const PoseBounds = preload("res://fighting/presentation/pose_bounds.gd")
const STAGES := ["basalt-reach", "canopy-divide", "crown-array", "helix-conservatory"]
const PAIRS := [["Meta", "Mistral"], ["ChatGPT", "Claude"], ["Grok", "Gemini"], ["DeepSeek", "Kimi"]]
var shell: Variant
var output := ""
var failures: Array = []
var checks: Array = []
var cases: Array = []
var observations: Array = []
var contacts: Array = []
var seen_events := {}
var recorded_states: Array = []
var replay_compared := {}
var request_serial := 0
var monitor: Observer
var last_observed_tick := -1
var session_serial := -1
var sample_camera := false
var camera_samples: Array = []
var last_render_usec := 0
var case_id := "startup"

class Observer extends Node:
	var fixture: Variant
	func _physics_process(_delta: float) -> void:
		fixture.observe_tick()
	func _process(_delta: float) -> void:
		fixture.observe_camera()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String, measured: Variant = null) -> bool:
	checks.append({"case": case_id, "label": label, "passed": value, "measured": measured})
	if not value:
		failures.append(case_id + ": " + label)
	return value

func frame(count: int = 1) -> void:
	for unused in count:
		await process_frame

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func action(actor: int, name: String, pressed: bool) -> void:
	key(int(shell.router.bindings[actor][name]), pressed)

func tap_action(actor: int, name: String) -> void:
	action(actor, name, true)
	action(actor, name, false)

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null:
			return found
	return null

func choice_button(node: Node, caption: String) -> Button:
	if node is HBoxContainer:
		var has_caption := false
		for child in node.get_children():
			if child is Label and child.text == caption:
				has_caption = true
		if has_caption:
			for child in node.get_children():
				if child is Button:
					return child
	for child in node.get_children():
		var found := choice_button(child, caption)
		if found != null:
			return found
	return null

func activate_button(button: Button) -> void:
	if not check(button != null, "requested production control exists"):
		return
	button.grab_focus() # Only test focus targeting; activation traverses the GUI.
	await frame()
	key(KEY_ENTER, true)
	key(KEY_ENTER, false)
	await frame(2)

func activate(text: String) -> void:
	await activate_button(find_button(root, text))

func choose(caption: String, text: String) -> void:
	for unused in 16:
		var button := choice_button(shell.ui, caption)
		if not check(button != null, "choice exists: " + caption):
			return
		if button.text == text or button.text.contains(text):
			return
		await activate_button(button)
	check(false, "bounded selection reaches " + caption + " = " + text)

func select_device(actor: int, device: int) -> void:
	# A disconnected binding can have a misleading default button caption.
	# Observe actual routing; never regard a text match alone as assignment proof.
	for unused in 12:
		if int(shell.router.devices[actor]) == device:
			return
		await activate_button(choice_button(shell.ui, "Player %d device" % (actor+1)))
	check(false, "public device cycling reaches requested routing", {"actor": actor, "requested": device, "actual": shell.router.devices[actor]})

func wait_for(predicate: Callable, limit: int, label: String) -> bool:
	for unused in limit:
		if predicate.call():
			return true
		await frame()
	return check(false, "deadline: " + label)

func wait_ticks(count: int) -> void:
	var start := int(shell.state.tick)
	await wait_for(func(): return int(shell.state.tick) >= start + count, maxi(90, count * 5), "simulation advances " + str(count))

func pause() -> void:
	if not shell.paused:
		key(KEY_ESCAPE, true)
		key(KEY_ESCAPE, false)
		await wait_for(func(): return shell.paused, 30, "Escape pauses")

func new_selection() -> void:
	if shell.active:
		await pause()
		await activate("Character select")
	await frame(3)
	check(not shell.active and shell.world == null and shell.visuals.is_empty() and shell.effects == null, "selection releases match presentation")

func start(mode: String, stage_index: int, operators: Array) -> void:
	await new_selection()
	await choose("Mode", mode)
	await choose("Player 1 operator", operators[0])
	await choose("Player 2 operator", operators[1])
	for unused in STAGES.size():
		if shell.stage_id == STAGES[stage_index]:
			break
		await activate_button(choice_button(shell.ui, "Stage candidate"))
	check(shell.stage_id == STAGES[stage_index], "actual stage selected")
	await activate("Start match")
	if not check(shell.active, "production start succeeds", shell.error_text):
		return
	await wait_for(func(): return shell.state.phase == "fight", 600, "intro to fight")
	check(shell.state.stage_id == STAGES[stage_index] and shell.visuals.size() == 2, "real stage and two production rigs")
	check(shell.visuals.all(func(v): return v.available and v.unavailable_reason.is_empty()), "production rig resources available")
	check(shell.simulation.last_error.is_empty(), "core reports no configuration error")
	sample_camera = true

func observe_tick() -> void:
	if not is_instance_valid(shell) or not shell.active or shell.state.is_empty():
		return
	if session_serial != int(shell.fx_session_serial):
		session_serial = int(shell.fx_session_serial)
		last_observed_tick = -1
		seen_events.clear()
	var tick := int(shell.state.tick)
	if tick == last_observed_tick:
		return
	last_observed_tick = tick
	var state: Dictionary = shell.state.duplicate(true)
	observations.append({"case": case_id, "session": session_serial, "tick": tick, "phase": state.phase,
		"fighters": state.fighters, "inputs": shell.last_inputs.duplicate(true), "ai_clock": shell.ai.save_state().clock})
	for event in state.events:
		if not seen_events.has(event.id):
			seen_events[event.id] = true
			contacts.append({"case": case_id, "session": session_serial, "event": event.duplicate(true)})
	if shell.recording:
		var index := shell.record_inputs.size() - 1
		if index == recorded_states.size():
			recorded_states.append(shell.simulation.save_state())
	if shell.replay_index > 0 and shell.replay_index <= recorded_states.size():
		var index := int(shell.replay_index) - 1
		if not replay_compared.has(index):
			replay_compared[index] = shell.simulation.save_state() == recorded_states[index]

func observe_camera() -> void:
	if not sample_camera or not is_instance_valid(shell) or not shell.active or shell.paused or shell.camera == null:
		return
	var started := Time.get_ticks_usec()
	var viewport: Rect2 = root.get_visible_rect()
	var safe := Rect2(Vector2(0, shell.hud.get_global_rect().end.y + 8), Vector2(viewport.size.x, 0))
	safe.size.y = shell.input_label.get_global_rect().position.y - 8 - safe.position.y
	var envelopes: Array = []
	var inside := safe.has_area()
	for pose in shell.camera.poses:
		var box: Rect2 = pose.envelope()
		var low: Vector2 = shell.camera.unproject_position(Vector3(box.position.x, box.position.y, 0))
		var high: Vector2 = shell.camera.unproject_position(Vector3(box.end.x, box.end.y, 0))
		var projected := Rect2(Vector2(minf(low.x, high.x), minf(low.y, high.y)), Vector2(absf(high.x-low.x), absf(high.y-low.y)))
		inside = inside and safe.grow(1).encloses(projected) and projected.has_area()
		envelopes.append({"world": [box.position.x, box.position.y, box.size.x, box.size.y], "pixels": [projected.position.x, projected.position.y, projected.size.x, projected.size.y]})
	var now := Time.get_ticks_usec()
	camera_samples.append({"case": case_id, "session": session_serial, "tick": shell.state.tick,
		"height": shell.camera.size, "center": [shell.camera.position.x, shell.camera.position.y],
		"inside": inside, "poses": envelopes, "sampling_usec": now-started,
		"frame_delta_usec": now-last_render_usec if last_render_usec else 0,
		"render_frame": Engine.get_frames_drawn(), "view": [viewport.size.x, viewport.size.y]})
	last_render_usec = now

func capture(label: String) -> void:
	await frame(2)
	await RenderingServer.frame_post_draw
	var path := case_id + "-" + label + ".png"
	var image := root.get_texture().get_image()
	check(not image.is_empty() and image.save_png(output.path_join(path)) == OK, "native capture saved " + label)
	var viewport: Rect2 = root.get_visible_rect()
	var controls: Array = []
	for control in [shell.hud, shell.input_label, shell.timer_label, shell.phase_label] + shell.bars + shell.meters + shell.names + shell.cues:
		var rect: Rect2 = control.get_global_rect()
		controls.append({"class": control.get_class(), "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
		check(viewport.grow(1).encloses(rect), "HUD control remains in visible window", controls[-1])
	check(shell.hud.get_global_rect().end.y < shell.input_label.get_global_rect().position.y, "top HUD and bottom input history do not overlap")
	cases.append({"id": case_id + "/" + label, "stage": shell.stage_id, "operators": shell.operators.duplicate(), "image": path,
		"utc": Time.get_datetime_string_from_system(true), "tick": shell.state.tick, "render_frame": Engine.get_frames_drawn(),
		"window": [root.size.x, root.size.y], "viewport": [viewport.size.x, viewport.size.y], "scale": root.content_scale_factor,
		"fullscreen": root.mode == Window.MODE_FULLSCREEN, "controls": controls,
		"fighters": shell.state.fighters.duplicate(true), "camera": camera_samples[-1] if not camera_samples.is_empty() else {}})

func bridge(operation: String, values: Dictionary = {}) -> Dictionary:
	request_serial += 1
	var request := values.duplicate(true)
	request.merge({"id": request_serial, "operation": operation, "pid": OS.get_process_id()}, true)
	var path := output.path_join("request-%04d.json" % request_serial)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify(request))
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)
	var response := output.path_join("response-%04d.json" % request_serial)
	if not await wait_for(func(): return FileAccess.file_exists(response), 600, "OS bridge " + operation):
		return {}
	var value: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(response))
	check(value.get("ok", false), "OS bridge succeeded: " + operation, value)
	return value

func approach(actor: int) -> bool:
	var direction := "right" if shell.state.fighters[actor].facing > 0 else "left"
	action(actor, direction, true)
	var reached := await wait_for(func(): return abs(shell.state.fighters[0].x-shell.state.fighters[1].x) <= 720, 500, "ordinary walk into throw range")
	action(actor, direction, false)
	await wait_ticks(2)
	return reached

func has_event(kind: String, actor: int, after: int) -> bool:
	for row in contacts.slice(after):
		if row.event.type == kind and int(row.event.actor) == actor:
			return true
	return false

func throws_both_sides() -> void:
	var neutral_size := float(shell.camera.size)
	for actor in 2:
		for tech in [false, true]:
			await pause()
			var previous_world := weakref(shell.world)
			await activate("Rematch")
			await wait_for(func(): return shell.state.phase == "fight", 600, "throw rematch ready")
			await frame(2)
			check(previous_world.get_ref() == null, "rematch frees previous world/camera/FX resources")
			check(absf(float(shell.camera.size)-neutral_size) < 0.5, "rematch camera returns to neutral framing instead of inheriting combat zoom", {"baseline": neutral_size, "actual": shell.camera.size})
			if not await approach(actor):
				return
			var start_events := contacts.size()
			var hp := int(shell.state.fighters[1-actor].hp)
			tap_action(actor, "Grab")
			if not await wait_for(func(): return has_event("throw_start", actor, start_events), 90, "real throw catch"):
				return
			if tech:
				tap_action(1-actor, "Grab")
				await wait_for(func(): return has_event("throw_tech", actor, start_events) or has_event("throw_tech", 1-actor, start_events), 90, "defender tech input")
			if actor == 0:
				await capture("throw-tech" if tech else "paired-catch")
			await wait_ticks(90)
			var damage := hp-int(shell.state.fighters[1-actor].hp)
			var expected := 0
			if not tech:
				for operator in shell.roster.operators:
					if operator.id == shell.operators[actor]:
						expected = int(operator.moves.throw_f.damage)
			check(damage == expected, "two-sided real throw/tech damage", {"actor": actor, "tech": tech, "expected": expected, "actual": damage})
			check(not str(shell.state.fighters[1-actor].animation).begins_with("victim_"), "throw pair releases victim")
			check(shell.ai.save_state().clock == 0, "local versus never advances AI")

func focus_release() -> void:
	for actor in 2:
		action(actor, "Guard", true)
	await wait_ticks(2)
	check(shell.last_inputs.all(func(c): return (int(c.held)&64) != 0), "both actors held guard before focus loss")
	await bridge("focus-away")
	await wait_for(func(): return not shell.focused and shell.paused, 180, "real application focus-out path")
	var frozen: Dictionary = shell.simulation.save_state()
	var ai_frozen: Dictionary = shell.ai.save_state()
	await frame(20)
	check(shell.simulation.save_state() == frozen and shell.ai.save_state() == ai_frozen, "unfocused simulation and AI unchanged")
	check(shell.router.down.all(func(d): return d.is_empty()) and shell.router.queued == [0,0], "focus loss releases both actors and queued edges")
	await bridge("focus-game")
	await wait_for(func(): return shell.focused, 180, "real application focus-in path")
	await activate("Resume")
	await wait_ticks(2)
	check(shell.last_inputs.all(func(c): return c.held == 0 and c.axis_x == 0 and c.axis_y == 0), "focus return never replays stale held inputs")
	for actor in 2:
		action(actor, "Guard", false)
		tap_action(actor, "L")
	await wait_ticks(2)
	check(shell.state.fighters.all(func(f): return f.move_id == "stand_l"), "both actors accept fresh edges after focus recovery")

func virtual_disconnects() -> void:
	for disconnected in 2:
		await pause()
		var pad_ids: Array = []
		for actor in 2:
			var previously_connected := Input.get_connected_joypads()
			await bridge("pad-create", {"actor": actor})
			await wait_for(func(): return Input.get_connected_joypads().filter(func(id): return not previously_connected.has(id)).size() == 1, 300, "one new owned kernel virtual pad enumerated")
			var added := Input.get_connected_joypads().filter(func(id): return not previously_connected.has(id))
			if not check(added.size() == 1, "virtual device identity bound to actual enumeration"):
				return
			pad_ids.append(added[0])
		await activate("Fighting Settings & bindings")
		# Ordinary selection order must work: P1 owns pad 0 before P2 cycles.
		for actor in [0, 1]:
			await select_device(actor, int(pad_ids[actor]))
			check(int(shell.router.devices[actor]) == int(pad_ids[actor]) and
				int(shell.router.devices[1-actor]) == (-1 if actor == 0 else int(pad_ids[0])),
				"P1-first then P2-second selection preserves exclusive ownership",
				{"selected_actor": actor, "expected_pads": pad_ids.duplicate(), "routes": shell.router.devices.duplicate()})
		check(shell.router.devices == pad_ids and shell.router.devices[0] != shell.router.devices[1], "distinct real enumerated virtual pads selected via settings")
		await activate("Back")
		await activate("Resume")
		for actor in 2:
			var event := InputEventJoypadButton.new()
			event.device = int(shell.router.devices[actor])
			event.button_index = JOY_BUTTON_LEFT_STICK
			event.pressed = true
			Input.parse_input_event(event)
		await wait_ticks(2)
		check(shell.last_inputs.all(func(c): return (int(c.held)&64) != 0), "both routed virtual-pad InputEvents reach core")
		var unplugged_id := int(shell.router.devices[disconnected])
		await bridge("pad-disconnect", {"actor": disconnected})
		await wait_for(func(): return not Input.get_connected_joypads().has(unplugged_id) and shell.paused, 300, "real kernel disconnect reaches production signal handler")
		check(shell.router.down.all(func(d): return d.is_empty()) and shell.router.queued == [0,0], "disconnect releases BOTH actors", {"disconnected_actor": disconnected})
		var before: Dictionary = shell.simulation.save_state()
		await frame(10)
		check(shell.simulation.save_state() == before, "disconnect modal freezes combat")
		await activate("Resume")
		check(shell.paused, "cannot resume with missing assigned device")
		await activate("Fighting Settings & bindings")
		var caption := choice_button(shell.ui, "Player %d device" % (disconnected+1))
		var other := 1-disconnected
		var other_pad := int(pad_ids[other])
		check(caption.text == "Pad %d · disconnected" % unplugged_id and
			int(shell.router.devices[disconnected]) == unplugged_id and
			int(shell.router.devices[other]) == other_pad and Input.get_connected_joypads().has(other_pad),
			"device label never claims keyboard while routing disconnected pad",
			{"caption": caption.text, "route": shell.router.devices[disconnected], "other_route": shell.router.devices[other]})
		# Exactly one real GUI activation, not select_device's retry/cycling loop.
		var recovery_tick := int(shell.state.tick)
		await activate_button(caption)
		check(int(shell.router.devices[disconnected]) == -1 and int(shell.router.devices[other]) == other_pad and
			caption.text == "Keyboard %d" % (disconnected+1),
			"one activation recovers missing pad to Keyboard without releasing other assignment",
			{"disconnected_actor": disconnected, "routes": shell.router.devices.duplicate(), "other_pad": other_pad})
		check(is_instance_valid(caption) and caption.has_focus() and
			choice_button(shell.ui, "Player %d device" % (disconnected+1)) == caption,
			"device recovery refresh preserves the focused button")
		await frame(5)
		check(shell.paused and int(shell.state.tick) == recovery_tick,
			"device selection remains paused until explicit Resume")
		check(shell.router.down.all(func(d): return d.is_empty()) and shell.router.queued == [0,0],
			"single-activation recovery keeps both actors held and queued inputs released")
		await activate("Back")
		await activate("Resume")
		check(not shell.paused and int(shell.router.devices[disconnected]) == -1 and int(shell.router.devices[other]) == other_pad,
			"explicit Resume accepts recovered keyboard plus still-assigned other pad")
		await wait_ticks(2)
		check(shell.last_inputs.all(func(c): return c.held == 0), "keyboard recovery does not retain pad buttons")
		# Only now release the other assignment for the later all-keyboard case.
		await pause()
		await activate("Fighting Settings & bindings")
		await select_device(other, -1)
		check(shell.router.devices == [-1,-1], "both keyboards selected after mixed-device recovery proof")
		await activate("Back")
		await activate("Resume")
		await wait_ticks(2)
		await bridge("pads-destroy")

func training_journey() -> void:
	case_id = "training"
	await start("Training", 0, ["Meta", "Mistral"])
	await pause()
	await activate("Training controls")
	var before := int(shell.state.tick)
	await activate("Advance one frame")
	await frame(6)
	check(shell.paused and int(shell.state.tick) == before+1, "training frame advance executes exactly one step")
	await choose("Dummy", "crouch guard")
	await choose("Training speed", "50%")
	await choose("Box display", "Authored attack envelopes")
	await activate("Back")
	await activate("Resume")
	await wait_ticks(3)
	check(shell.last_inputs[1].axis_y == -1 and shell.last_inputs[1].held == 64 and shell.training_boxes.visible, "training dummy and hitbox controls affect actual presentation/input")
	await pause()
	await activate("Training controls")
	await choose("Dummy", "stand")
	await choose("Training speed", "100%")
	await activate("Reset training match")
	await wait_for(func(): return shell.state.phase == "fight", 600, "public training reset ready")
	check(shell.record_inputs.is_empty() and shell.state.wins == [0,0], "training reset clears record and results")
	await pause()
	await activate("Training controls")
	recorded_states.clear()
	replay_compared.clear()
	await activate("Record inputs from this state")
	await approach(0)
	var hp_before := int(shell.state.fighters[1].hp)
	var contacts_before := contacts.size()
	tap_action(0, "L")
	await wait_ticks(45)
	check(shell.state.fighters[1].hp < hp_before and has_event("hit", 0, contacts_before), "recorded training attack produces real damage/contact")
	await pause()
	await activate("Training controls")
	await activate("Stop recording")
	await pause()
	await activate("Training controls")
	check(recorded_states.size() == shell.record_inputs.size() and recorded_states.size() > 30, "recorded command/state inventory complete")
	var terminal: Dictionary = recorded_states[-1] if not recorded_states.is_empty() else {}
	await activate("Replay recorded inputs")
	await wait_for(func(): return shell.replay_index == -1 and shell.paused, 1600, "replay completes through production UI")
	check(replay_compared.size() == recorded_states.size() and replay_compared.values().all(func(v): return v), "training replay matches saved state at EVERY recorded tick")
	check(shell.simulation.save_state() == terminal, "training replay terminal state exact")
	check(shell.ai.save_state().clock == 0, "stand-dummy training never advances AI")
	await activate("Reset training match")
	check(shell.record_inputs.is_empty() and shell.replay_index == -1, "public reset clears completed replay")

func ai_lifecycle() -> void:
	case_id = "AI-pause-resume"
	await start("Versus AI", 0, ["Meta", "Mistral"])
	var clock := int(shell.ai.save_state().clock)
	var tick := int(shell.state.tick)
	await wait_ticks(12)
	check(int(shell.ai.save_state().clock)-clock == int(shell.state.tick)-tick, "AI executes exactly once per active fight tick")
	await pause()
	var paused: Dictionary = shell.simulation.save_state()
	var ai_paused: Dictionary = shell.ai.save_state()
	await frame(20)
	check(shell.simulation.save_state() == paused and shell.ai.save_state() == ai_paused, "paused simulation and AI clock/RNG/history do not advance")
	await activate("Resume")
	clock = int(shell.ai.save_state().clock)
	tick = int(shell.state.tick)
	await wait_ticks(12)
	check(int(shell.ai.save_state().clock)-clock == int(shell.state.tick)-tick, "resume advances live AI without catch-up burst")
	await pause()
	var old_world: WeakRef = weakref(shell.world)
	await activate("Character select")
	var inactive: Dictionary = shell.ai.save_state()
	var inactive_sim: Dictionary = shell.simulation.save_state()
	await frame(20)
	check(shell.ai.save_state() == inactive and shell.simulation.save_state() == inactive_sim, "inactive selection preserves AI/simulation exactly")
	check(old_world.get_ref() == null and shell.world == null, "selection actually frees old world descendants")

func hazard_route(stage: int) -> void:
	if stage == 1:
		var n := contacts.size()
		tap_action(0, "Special")
		await wait_for(func(): return has_event("projectile_spawn", 0, n), 120, "real projectile for responsive camera")
		await capture("projectile")
		await wait_ticks(90)
	elif stage == 2:
		action(0, "down", true)
		await wait_ticks(20)
		tap_action(0, "Mobility")
		action(0, "down", false)
		tap_action(1, "up") # Direction must persist across a physics tick.
		action(1, "up", true)
		await wait_ticks(2)
		action(1, "up", false)
		await wait_for(func(): return shell.state.fighters[1].y > 0, 120, "Gemini ordinary jump")
		tap_action(1, "Mobility")
		await wait_for(func(): return shell.state.fighters[0].y > 1000 and shell.state.fighters[1].move_id == "special2", 180, "Grok charged launch and Gemini double jump")
		await capture("charged-and-double-jump")
		await wait_ticks(120)
	else:
		action(0, "left", true)
		action(1, "right", true)
		await wait_for(func(): return shell.state.fighters[1].x-shell.state.fighters[0].x >= 14500, 1200, "ordinary max-separation walk")
		action(0, "left", false)
		action(1, "right", false)
		await capture("separation")
		action(0, "right", true)
		action(1, "right", true)
		await wait_for(func(): return shell.state.fighters[0].x >= 6500, 2000, "ordinary corner approach")
		action(0, "right", false)
		action(1, "right", false)
		await capture("corner")

func run() -> void:
	output = OS.get_environment("FIGHTING_ACCEPTANCE_EVIDENCE")
	if output.is_empty():
		push_error("Bounded UI driver/evidence directory required")
		quit(2)
		return
	monitor = Observer.new()
	monitor.fixture = self
	monitor.process_physics_priority = 100
	monitor.process_priority = 100
	root.add_child(monitor)
	change_scene_to_file("res://fighting/main.tscn")
	await scene_changed
	shell = current_scene
	await bridge("focus-game")
	for stage in STAGES.size():
		for compact in [false, true]:
			case_id = STAGES[stage] + ("-compact150" if compact else "-wide100")
			sample_camera = false
			root.mode = Window.MODE_WINDOWED
			root.size = Vector2i(760,520) if compact else Vector2i(1280,800)
			root.content_scale_factor = 1.5 if compact else 1.0
			if not compact:
				root.mode = Window.MODE_FULLSCREEN
			await frame(3)
			await bridge("focus-game")
			var pair: Array = ["Mistral", "Qwen"] if stage == 3 and compact else PAIRS[stage]
			await start("Local two-player", stage, pair)
			if not shell.active or not failures.is_empty():
				finish()
				return
			var bind_times: Array = []
			for visual in shell.visuals:
				var probe := PoseBounds.new()
				var begin := Time.get_ticks_usec()
				probe.configure(visual)
				bind_times.append({"operator": visual.operator_id, "configure_usec": Time.get_ticks_usec()-begin, "groups": probe.groups.size()})
			check(bind_times.all(func(t): return t.groups > 0), "real bind-cache construction measured separately", bind_times)
			await wait_ticks(3)
			await capture("neutral")
			if stage == 0 and not compact:
				await throws_both_sides()
				await focus_release()
				await virtual_disconnects()
			elif not compact or stage == 2:
				await hazard_route(stage)
			if compact:
				await pause()
				await activate("Fighting Settings & bindings")
				await choose("Reduced motion", "On")
				await choose("FX budget", "Low")
				await activate("Back")
				await activate("Resume")
				await wait_ticks(2)
				check(shell.camera.reduced_motion and shell.low_fx, "public reduced-motion/low-FX settings applied")
				await capture("reduced-low")
				await pause()
				await activate("Fighting Settings & bindings")
				await choose("Reduced motion", "Off")
				await activate("Back")
				await activate("Resume")
			if not failures.is_empty():
				finish()
				return
	await training_journey()
	await ai_lifecycle()
	case_id = "live-Home"
	var old_shell := weakref(shell)
	await activate("Home")
	await frame(5)
	check(current_scene != null and current_scene.scene_file_path == "res://ui/main_menu.tscn", "actual Home scene entered")
	check(old_shell.get_ref() == null, "Home frees fighting scene and observers hold no owning reference")
	check(camera_samples.size() > 50 and camera_samples.all(func(row): return row.inside), "all sampled real body envelopes remain HUD-safe", {"frames": camera_samples.size(), "failures": camera_samples.filter(func(row): return not row.inside).slice(0,10)})
	finish()

func finish() -> void:
	var report := {"version": 1, "status": "passed" if failures.is_empty() else "failed", "executed": true,
		"checks": checks, "cases": cases, "failures": failures, "unrun": [], "contacts": contacts,
		"observations": observations, "camera_samples": camera_samples, "replay_frames": replay_compared.size(),
		"not_claimed": ["physical controller unplug", "human fighting feel/balance", "GPU hardware performance", "human stage art approval"],
		"controller_path": "kernel uinput enumeration/removal plus InputEventJoypadButton injection",
		"focus_path": "actual X11 focus change; no notification injection"}
	var file := FileAccess.open(output.path_join("ui-native.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	print("FIGHTING_UI_RESULT ", JSON.stringify({"passed": failures.is_empty(), "failures": failures, "cases": cases.size()}))
	if failures.is_empty():
		print("FIGHTING_UI_JOURNEY_OK")
	quit(0 if failures.is_empty() else 1)
