extends SceneTree
## TEST-ONLY native Horde upgrade loopback observer.
##
## The ACTUAL product scene (res://horde/demo.tscn) is instantiated as the only
## child of the real root and connects to the ACTUAL local authority started by
## godot/tests/horde/upgrade_loopback.mjs. That authority's offer is raised by a
## TEST-ONLY accelerated-offer fixture (an instrumented Match.prototype.step in
## the harness process): this is NOT natural three-wave gameplay.
##
## This observer never calls choose_offer(), the horde client or any adapter
## function to select a reward. It only emits one real InputEventKey (KEY_2
## press, release on the next frame) through the engine input path and then
## asserts what the product scene and the authoritative snapshots report.
##
##   GODOT_BIN=... godot --path godot --script res://tests/horde/upgrade_live.gd -- \
##     --map=meridian-exchange --waves=10 --endpoint=ws://127.0.0.1:PORT [--shot=/tmp/prefix]
const DemoScene = preload("res://horde/demo.tscn")
const LABEL := "TEST-ONLY accelerated-offer fixture (not natural 3-wave gameplay)"
const DEFAULT_DEADLINE := 24.0
const OFFER_LIMIT := 16.0
const CONFIRM_LIMIT := 8.0
const DELIVERY_RETRY_FRAMES := 30
## Frames to keep observing after the authority answered, so the ordinary input
## stream is proven to continue after the selection rather than racing the quit.
const LINGER_FRAMES := 15
## Delivery ladder for the synthetic key. The first entry is the engine's own
## parse path (the same call tests/horde/live.gd steers with); the later entries
## exist only for display servers that drop parsed events, and whichever entry
## actually reached the product input handler is reported as `delivery`.
const DELIVERIES := ["parse_input_event", "viewport_push_input", "handler_call"]
var endpoint := ""
var map_id := "meridian-exchange"
var waves := 10
var shot_prefix := ""
var session: Node
var last_error := ""
var elapsed := 0.0
var stage := "scene"
var stage_frames := 0
var checks := 0
var failures := 0
var notes: Array = []
var offer_ids: Array = []
var offer_wave := 0
var chosen := ""
var epoch_seen := 0
var seq_before := 0
var weapon_before := -1
var delivery := ""
var delivery_index := 0
var press_emitted := false
var reset_count := 0
var resets_at_press := 0
var reset_armed := false
var linger_frames := 0
var finished := false
var quitted := false
var evidence: Dictionary = {"label": LABEL, "notes": notes, "shots": []}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		notes.append(message)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg.begins_with("--map="): map_id = arg.trim_prefix("--map=")
		if arg.begins_with("--shot="): shot_prefix = arg.trim_prefix("--shot=")
		if arg.begins_with("--waves="):
			var value := arg.trim_prefix("--waves=")
			if value.is_valid_int(): waves = value.to_int()
	# The port expects a real window (a headless default viewport is 64x64 and
	# the Horde choice layer would lay out off-screen), so pin the harness size.
	root.size = Vector2i(960, 600)
	session = DemoScene.instantiate()
	root.add_child(session)
	print("HORDE_UPGRADE_LIVE_BOOT ", JSON.stringify({"label": LABEL, "scene": session.scene_file_path,
		"script": session.get_script().resource_path, "endpoint": endpoint, "map": map_id, "waves": waves,
		"deliveries": DELIVERIES}))

func key_event(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = false
	return event

## Real user path: one synthetic key event through the engine, exactly like a
## physical number key. Never a direct call to the choice function.
func emit_key(code: int, pressed: bool) -> void:
	delivery = DELIVERIES[delivery_index]
	var event := key_event(code, pressed)
	if delivery == "parse_input_event":
		Input.parse_input_event(event)
	elif delivery == "viewport_push_input":
		session.get_viewport().push_input(event)
	else:
		session.call("_input", event)

func reacted() -> bool:
	if not is_instance_valid(session): return false
	var client: Node = session.horde_client
	if not is_instance_valid(client): return false
	return int(client.upgrade_sent) > 0 or str(client.pending_choice) != "" or int(client.confirmed_count) > 0 \
		or str(client.rejected_reason) != "" or str(session.choice_status.text).begins_with("CHOICE")

func capture(tag: String) -> void:
	if shot_prefix.is_empty() or not is_instance_valid(session): return
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	var path := "%s-%s.png" % [shot_prefix, tag]
	var error := image.save_png(path)
	evidence.shots.append({"tag": tag, "path": path, "ok": error == OK,
		"size": [image.get_width(), image.get_height()]})
	print("HORDE_UPGRADE_LIVE_SHOT ", JSON.stringify({"tag": tag, "path": path, "ok": error == OK}))

func snapshot_evidence() -> Dictionary:
	var result := {"stage": stage, "delivery": delivery, "chosen": chosen, "offer_ids": offer_ids,
		"offer_wave": offer_wave, "epoch": epoch_seen, "seq_before": seq_before, "resets": reset_count,
		"resets_at_press": resets_at_press,
		"elapsed": snappedf(elapsed, 0.01)}
	if is_instance_valid(session) and is_instance_valid(session.horde_client):
		var client: Node = session.horde_client
		result["confirmed_choice"] = str(client.confirmed_choice)
		result["confirmed_count"] = int(client.confirmed_count)
		result["upgrade_sent"] = int(client.upgrade_sent)
		result["rejected_reason"] = str(client.rejected_reason)
		result["input_epoch"] = int(client.input_epoch)
		result["received_input"] = int(client.received_input)
		result["input_seq"] = int(session.client.input_seq)
		result["status"] = str(session.choice_status.text)
		result["model_offers"] = session.horde.offers.size()
		result["model_applied"] = int(session.horde.applied_count)
		result["model_selected"] = str(session.horde.selected_id)
		result["horde_label"] = str(session.horde_label.text)
	return result

func finish(ok: bool, message: String) -> void:
	if finished: return
	finished = true
	evidence["ok"] = ok and failures == 0
	evidence["message"] = message
	evidence["checks"] = checks
	evidence["failures"] = failures
	evidence.merge(snapshot_evidence())
	print("HORDE_UPGRADE_LIVE ", JSON.stringify(evidence))
	if not shot_prefix.is_empty():
		await capture("final")
	quitted = true
	quit(0 if (ok and failures == 0) else 1)

func _process(delta: float) -> bool:
	if quitted: return true
	elapsed += delta
	stage_frames += 1
	if not is_instance_valid(session):
		finish(false, "product scene vanished")
		return false
	if session.phase == -1:
		finish(false, "session error: " + str(session.label.text))
		return false
	if not finished and elapsed > DEFAULT_DEADLINE:
		finish(false, "deadline %.1fs in stage %s entry=%s" % [elapsed, stage, session.label.text])
		return false
	if finished: return false
	match stage:
		"scene":
			# Wait for the real handshake to reach the live round; the offer is
			# whatever the authority actually publishes.
			if session.phase == 3:
				# The product composition already listens on this signal, so arm by
				# our own flag rather than by the connection list.
				if not reset_armed:
					reset_armed = true
					session.horde_client.input_reset.connect(func(_reason: String) -> void: reset_count += 1)
				stage = "offer"
				stage_frames = 0
		"offer":
			if elapsed > OFFER_LIMIT:
				finish(false, "no pending offer snapshot within %.0fs (phase=%d label=%s)" % [OFFER_LIMIT, session.phase, session.label.text])
				return false
			if not session.horde.offer_pending: return false
			_probe_offer()
			stage = "press"
			stage_frames = 0
		"press":
			# Sample the live round immediately before the press: the authority's
			# input TTL can cross an epoch boundary on a slow frame before this.
			epoch_seen = int(session.horde_client.input_epoch)
			seq_before = int(session.client.input_seq)
			weapon_before = int(session.controls.weapon)
			resets_at_press = reset_count
			check(session.horde.offer_pending, "the offer is still live on the press frame")
			emit_key(KEY_2, true)
			press_emitted = true
			stage = "press_release"
			stage_frames = 0
		"press_release":
			# The release lands on a later frame; the press must have reached the
			# product input handler (not the choice function).
			emit_key(KEY_2, false)
			if not reacted():
				stage = "press_wait"
				stage_frames = 0
				return false
			_after_press()
			stage = "confirm"
			stage_frames = 0
		"press_wait":
			if reacted():
				_after_press()
				stage = "confirm"
				stage_frames = 0
				return false
			if stage_frames < DELIVERY_RETRY_FRAMES: return false
			if delivery_index + 1 >= DELIVERIES.size():
				finish(false, "KEY_2 never reached the product input handler (deliveries tried: %s)" % [", ".join(DELIVERIES)])
				return false
			delivery_index += 1
			notes.append("delivery %s did not register; retrying with %s" % [delivery, DELIVERIES[delivery_index]])
			stage = "press"
			stage_frames = 0
		"confirm":
			# Wait for BOTH independent publications: the authority's answer frame
			# (client) and the authoritative snapshot projection (model).
			var confirmed: bool = int(session.horde_client.confirmed_count) >= 1 \
				and str(session.horde_client.confirmed_choice) == chosen
			var projected: bool = int(session.horde.applied_count) >= 1 \
				and str(session.horde.selected_id) == chosen and not session.horde.offer_pending
			if confirmed and projected:
				linger_frames += 1
				if linger_frames >= LINGER_FRAMES: _confirm()
				return false
			if stage_frames > int(CONFIRM_LIMIT * 60.0):
				finish(false, "choice was never confirmed and projected (%s)" % [JSON.stringify(snapshot_evidence())])
				return false
	return false

func _probe_offer() -> void:
	offer_wave = int(session.horde.offer_wave)
	offer_ids = []
	for row: Dictionary in session.horde.offers: offer_ids.append(str(row.get("id", "")))
	chosen = str(session.horde.offer_id(2))
	check(session.phase == 3, "offer arrived inside the live round")
	check(int(session.horde_client.input_epoch) >= 1, "the live round carries an input epoch")
	check(session.horde.offers.size() == 3, "the authority snapshot offered exactly three rows")
	check(offer_wave == 3, "the offered wave is the fixture wave 3")
	# Native UI: real visible buttons for the offered rows.
	check(session.choice_panel.visible and session.choice_status.visible, "choice panel and status are visible with a live offer")
	check(session.choice_buttons.size() == 3, "one visible choice button per offered row")
	if session.choice_buttons.size() == 3:
		check("2" in session.choice_buttons[1].text, "the second button carries hotkey 2")
		check(str(session.horde.offers[1].get("name", "")) in session.choice_buttons[1].text, "the second button names the second offered row")
		check("UPGRADES" in session.horde_label.text and "1" in session.horde_label.text, "the Horde strip renders the offer with its hotkeys")
		for index in session.choice_buttons.size():
			check(session.choice_buttons[index].mouse_filter == Control.MOUSE_FILTER_STOP, "choice button %d consumes clicks" % (index + 1))
	check(session.intercept_offer_key(KEY_2) == 2, "KEY_2 maps to the second offered row")
	check(not chosen.is_empty() and offer_ids.has(chosen), "the hotkey target is one of the offered ids")
	check(session.horde.offer_index(chosen) == 2, "the chosen id is the second offered id")
	evidence["offer_button_texts"] = session.choice_buttons.map(func(button: Button) -> String: return button.text)
	capture("offer")

func _after_press() -> void:
	# The choice hotkey is intercepted before the control recorder: it must never
	# leak into held movement, pulses or weapon selection.
	check(session.controls.keys.is_empty(), "choice hotkey never entered held movement")
	check(session.controls.pulses.is_empty(), "choice hotkey never entered a control pulse")
	check(int(session.controls.weapon) == weapon_before, "choice hotkey never changed the selected weapon")
	check(epoch_seen == int(session.horde_client.input_epoch), "no input epoch boundary was crossed by the choice")
	check(reset_count == resets_at_press, "no input reset was emitted by the press")
	check(str(session.horde_client.rejected_reason) == "", "the authority did not refuse the choice")
	evidence["status_after_press"] = str(session.choice_status.text)

func _confirm() -> void:
	var client: Node = session.horde_client
	check(int(client.confirmed_count) == 1, "the client confirmed exactly one applied upgrade")
	check(str(client.confirmed_choice) == chosen, "the confirmed choice is the id the KEY_2 hotkey targeted")
	check(str(client.rejected_reason) == "", "no refusal was reported for the accepted choice")
	# Authoritative snapshot projection: the offer closed and the run carries the pick.
	check(int(session.horde.applied_count) == 1, "the snapshot reports upgradeCount 1")
	check(str(session.horde.selected_id) == chosen, "the snapshot reports the chosen upgradeSelected")
	check(session.horde.offers.is_empty() and not session.horde.offer_pending, "the authoritative offer is cleared after the selection")
	# Native UI after the authority answered.
	check(session.choice_buttons.is_empty(), "choice buttons are gone once the offer closes")
	check(session.choice_panel.visible and session.choice_status.visible, "the applied result stays visible")
	check("APPLIED" in session.choice_status.text.to_upper() or "ACCEPTED" in session.choice_status.text.to_upper(), "the status line reports the authority result")
	check("APPLIED" in session.horde_label.text.to_upper(), "the Horde strip reports the applied run upgrade")
	# Ordinary input stream continuity: the choice must not corrupt the sample cursor.
	check(reset_count == resets_at_press, "no input reset was emitted across the choice")
	check(epoch_seen == int(client.input_epoch), "the input epoch is unchanged after the selection")
	check(int(session.client.input_seq) > seq_before, "ordinary input samples kept flowing across the choice")
	check(int(client.received_input) > 0, "the authority acknowledged ordinary input samples for this round")
	check(int(client.input_seq) >= int(seq_before), "the ordinary input cursor never went backwards")
	evidence["status_after_confirm"] = str(session.choice_status.text)
	evidence["input_seq_after"] = int(session.client.input_seq)
	finish(true, "native KEY_2 -> authority -> snapshot upgrade loopback confirmed")
