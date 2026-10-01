extends SceneTree
## Scripted real-widget / real-input journey against untouched live authority.
const Settings = preload("res://ui/settings_access.gd")
var session: Node
var menu: Node
var output := ""
var failures: Array[String] = []
var measurements: Dictionary = {"weapons":[], "screenshots":[], "motion":[]}
var latest: Dictionary = {}
var finished := false
var started := 0
var recording: AudioEffectRecord
var frame_milliseconds: Array[float] = []

func _initialize() -> void:
	started = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--feel-output="): output = arg.trim_prefix("--feel-output=")
	call_deferred("run")

func _process(_dt: float) -> bool:
	frame_milliseconds.append(_dt * 1000.0)
	if not finished and Time.get_ticks_msec() - started > 195000:
		check(false, "live journey watchdog")
		finish()
	return false

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); printerr("FEEL_LIVE_CHECK ", label)

func wait_for(predicate: Callable, label: String, seconds: float = 8) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline and not finished:
		if predicate.call(): return true
		if is_instance_valid(session) and "startup_error" in session and not str(session.startup_error).is_empty(): break
		await process_frame
	check(false, "Timed out: " + label)
	return false

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = root.size / 2
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func point_at(target: Vector3) -> void:
	var direction: Vector3 = target - session.presentation.eye_position()
	var wanted_yaw := atan2(-direction.x, -direction.z)
	var wanted_pitch := atan2(direction.y, Vector2(direction.x, direction.z).length())
	var gain: float = .003 * Settings.sensitivity()
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(wrapf(float(session.yaw) - wanted_yaw, -PI, PI), float(session.pitch) - wanted_pitch) / gain
	event.screen_relative = event.relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func actor() -> Dictionary:
	return session.presentation.local_actor

func position() -> Vector3:
	var p := actor()
	return Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0)))

func menu_toggle() -> bool:
	var old_epoch: int = session.client.input_epoch
	key(KEY_F3, true)
	await process_frame
	key(KEY_F3, false)
	return await wait_for(func() -> bool: return not menu.pending and session.client.input_epoch > old_epoch, "F3 authority pause/resume acknowledgment")

func command(button: BaseButton) -> bool:
	check(not button.disabled, "command widget enabled")
	var revision: int = int(menu.state.get("revision", 0))
	if button.toggle_mode: button.button_pressed = not button.button_pressed
	else: button.pressed.emit()
	return await wait_for(func() -> bool: return not menu.pending and int(menu.state.get("revision", 0)) > revision, "widget authority confirmation")

func capture(name: String, size: Vector2i) -> void:
	root.size = size
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty(), "rendered " + name)
	if not image.is_empty(): check(image.save_png(output.path_join(name + ".png")) == OK, "saved " + name)
	var rect: Rect2 = menu.panel.get_global_rect()
	if name != "native-combat":
		check(root.get_visible_rect().encloses(rect), "menu panel fits " + name)
		check(menu.resume.is_visible_in_tree(), "resume accessible " + name)
	else:
		check(not menu.overlay.visible, "combat capture has resumed gameplay")
	measurements.screenshots.append({"name":name, "size":[size.x,size.y], "panel":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})

func select_weapon(index: int) -> bool:
	var code: int = KEY_0 if index == 9 else KEY_1 + index
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		await capture_if_needed()
		key(code, true)
		await process_frame
		key(code, false)
		if int(actor().get("weapon", -1)) == index: return true
		await create_timer(.15).timeout
	check(false, "Timed out: weapon selection %d" % index)
	return false

func capture_if_needed() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: return
	measurements["recaptureAfterStale"] = int(measurements.get("recaptureAfterStale", 0)) + 1
	key(KEY_W, false); key(KEY_SPACE, false); mouse(false)
	root.grab_focus()
	await process_frame
	mouse(true); await process_frame; mouse(false)

func normal_encounter() -> void:
	var start_health: float = actor().health
	var start_armor: float = actor().armor
	var points: Array = session.world.recipe.campaign.criticalPath
	var cursor := 1
	var deadline := Time.get_ticks_msec() + 65000
	while int(session.campaign.state.get("enemiesRemaining", 0)) == 0 and Time.get_ticks_msec() < deadline:
		await capture_if_needed()
		if cursor >= points.size(): break
		var p: Dictionary = points[cursor]
		var target := Vector3(float(p.x), float(p.y), float(p.z))
		if Vector2(position().x-target.x,position().z-target.z).length() < 2: cursor += 1; continue
		point_at(target + Vector3(0, 1.4, 0)); key(KEY_W, true)
		await process_frame
	key(KEY_W, false)
	check(int(session.campaign.state.get("enemiesRemaining", 0)) > 0, "ordinary movement reaches first encounter")
	var hits_before: int = session.combat.hits
	var kills_before: int = int(actor().frags)
	var fire_start: float = latest.time
	deadline = Time.get_ticks_msec() + 25000
	while int(actor().frags) == kills_before and Time.get_ticks_msec() < deadline:
		await capture_if_needed()
		var targets: Array = latest.get("actors", []).filter(func(a: Dictionary) -> bool: return a.get("isNpc", false) and float(a.get("health", 0)) > 0)
		if targets.is_empty(): break
		var target: Dictionary = targets[0]
		point_at(Vector3(float(target.x), float(target.y) + .35, float(target.z)))
		key(KEY_W, position().distance_to(Vector3(float(target.x),float(target.y),float(target.z))) > 14)
		mouse(true)
		await process_frame
	key(KEY_W, false); mouse(false)
	check(session.combat.hits > hits_before and int(actor().frags) > kills_before, "real aimed fire kills a campaign robot")
	measurements["normalCombat"] = {"hits":session.combat.hits-hits_before,"kills":int(actor().frags)-kills_before,"healthBefore":start_health,"armorBefore":start_armor,"healthAfter":actor().health,"armorAfter":actor().armor,"firstFireToKillSourceSeconds":float(latest.time)-fire_start,"elapsedAuthority":latest.time,"routeVertex":cursor,"cheatsEverEnabled":false}

func run() -> void:
	if output.is_empty(): check(false, "owned output required"); finish(); return
	root.grab_focus()
	root.size = Vector2i(640, 400)
	# Software-rendered diagnostic: retain full-resolution UI; reduce only 3D
	# rasterization so input production can meet the unchanged freshness contract.
	root.scaling_3d_scale = 0.35
	var scene: PackedScene = load("res://campaign/demo.tscn")
	session = scene.instantiate()
	root.add_child(session)
	session.client.snapshot.connect(func(frame: Dictionary) -> void: latest = frame.state)
	if not await wait_for(func() -> bool: return session.phase == -2, "briefing"): finish(); return
	session.campaign_hud.primary.pressed.emit()
	if not await wait_for(func() -> bool: return session.phase == 3 and session.received_pose, "real native campaign starts", 25): finish(); return
	menu = session.solo_cheats
	if not await wait_for(func() -> bool: return menu.available(), "cheat availability"): finish(); return
	mouse(true); await process_frame; mouse(false)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "gameplay click captures")
	await normal_encounter()
	if not await menu_toggle(): finish(); return
	check(menu.overlay.visible and menu.state.get("paused") == true, "menu visible after authority pause")
	var paused_time: float = latest.time
	var paused_position := position()
	key(KEY_W, true); mouse(true)
	await create_timer(.65).timeout
	check(float(latest.time) == paused_time and position() == paused_position, "menu freezes real authority time and position")
	for name: String in ["invulnerable", "unlimitedAmmo", "flight"]:
		if not await command(menu.toggles[name]): finish(); return
		check(menu.state.get(name) == true, name + " authority confirmed")
	if not await command(menu.actions[0]): finish(); return
	measurements["grantAmmo"] = actor().ammo.duplicate()
	check(actor().ammo.size() == 10 and actor().ammo.all(func(amount: Variant) -> bool: return str(amount) == "∞" or (str(amount).is_valid_float() and float(amount) > 0)), "all ten weapons on authority snapshot")
	if not await command(menu.actions[1]): finish(); return
	check(float(actor().health) == float(actor().maxHealth) and float(actor().armor) >= 100, "heal action confirmed")
	await capture("cheats-wide", Vector2i(1280, 800))
	var settings: Node = root.get_node_or_null("LocalSettings")
	if settings != null: settings.set_value("ui_scale", 150, false)
	await capture("cheats-compact", Vector2i(760, 520))
	menu.actions[2].grab_focus()
	await capture("cheats-compact-actions", Vector2i(760, 520))
	check(menu.actions[2].get_global_rect().intersects(menu.panel.get_global_rect()), "compact bottom action can be reached by scrolling focus")
	if settings != null: settings.set_value("ui_scale", 100, false)
	root.size = Vector2i(640, 400)
	if not await menu_toggle(): finish(); return
	check(not menu.overlay.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "close ack recaptures pointer")
	var shots_before: int = int(actor().shots)
	var closed_position := position()
	await create_timer(.4).timeout
	check(position().distance_to(closed_position) < .05 and int(actor().shots) == shots_before, "held menu inputs do not replay after epoch reset")
	key(KEY_W, false); mouse(false)
	var before_flight := position()
	key(KEY_SPACE, true)
	var flight_deadline := Time.get_ticks_msec() + 8000
	while position().y <= before_flight.y + 3 and Time.get_ticks_msec() < flight_deadline:
		await capture_if_needed()
		key(KEY_SPACE, true)
		await process_frame
	if position().y <= before_flight.y + 3:
		check(false, "Timed out: real input flight ascent"); finish(); return
	key(KEY_SPACE, false)
	await create_timer(.5).timeout
	var eye: Vector3 = session.presentation.eye_position()
	var flight_error: float = session.camera.position.distance_to(eye)
	check(flight_error < 1.0, "flight camera settles to authoritative eye")
	measurements.motion.append({"flightRise":position().y-before_flight.y,"settledCameraError":flight_error})
	# Fire real input into the world; camera aim is forwarded mouse motion.
	point_at(position() + Vector3(0, 1.3, -35))
	recording = AudioEffectRecord.new()
	recording.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), recording)
	recording.set_recording_active(true)
	for index: int in range(10):
		if not await select_weapon(index): finish(); return
		await create_timer(.3).timeout
		var before: int = int(actor().shots)
		var recoil_before: int = session.first_person.rig.recoil_count
		mouse(true)
		var fire_deadline := Time.get_ticks_msec() + 10000
		while int(actor().shots) <= before and Time.get_ticks_msec() < fire_deadline:
			await capture_if_needed()
			mouse(true)
			await process_frame
		if int(actor().shots) <= before:
			check(false, "Timed out: actual weapon fire %d" % index); finish(); return
		mouse(false)
		check(session.first_person.rig.recoil_count > recoil_before, "authoritative shot reaches first-person recoil %d" % index)
		measurements.weapons.append({"weapon":index,"shots":int(actor().shots)-before,"recoilEvents":session.first_person.rig.recoil_count-recoil_before,"ammo":actor().ammo[index]})
	recording.set_recording_active(false)
	var mix: AudioStreamWAV = recording.get_recording()
	if not await menu_toggle(): finish(); return
	if not await command(menu.actions[2]): finish(); return
	check(not menu.state.invulnerable and not menu.state.unlimitedAmmo and not menu.state.flight, "clear disables every toggle")
	if not await menu_toggle(): finish(); return
	check(actor().grounded, "flight off lands through authority")
	await capture("native-combat", Vector2i(960, 600))
	# Offline PCM analysis is intentionally last: looping over millions of
	# samples on the render thread must not starve a live input freshness gate.
	if mix != null and not mix.data.is_empty():
		mix.save_to_wav(output.path_join("actual-gameplay-mix.wav"))
		measurements["mixedAudio"] = audio_metrics(mix)
	export_audio()
	finish()

func audio_metrics(sound: AudioStreamWAV) -> Dictionary:
	var energy := 0.0
	var early := 0.0
	var mechanical := 0.0
	var tail := 0.0
	var peak := 0.0
	var samples: int = sound.data.size() / 2
	var channels: int = 2 if sound.stereo else 1
	for i: int in samples:
		var value := float(sound.data.decode_s16(i * 2)) / 32767.0
		var t := float(i) / (sound.mix_rate * channels)
		energy += value * value
		peak = maxf(peak, absf(value))
		if t < .028: early += value * value
		elif t < .09: mechanical += value * value
		else: tail += value * value
	return {"seconds":float(samples)/(sound.mix_rate*channels),"rms":sqrt(energy/maxi(1,samples)),"peak":peak,"earlyEnergy":early,"mechanicalEnergy":mechanical,"tailEnergy":tail}

func export_audio() -> void:
	var audio: Node = session.combat.audio_feedback
	var baseline_script: GDScript = load(output.path_join("audio_before.gd"))
	if baseline_script == null: check(false, "load published-baseline audio comparator"); return
	var baseline: Node = baseline_script.new()
	baseline._build_tables()
	var rows: Array[Dictionary] = []
	for weapon: int in range(10):
		var cue := "launch" if weapon in [1,4,5] else "shot"
		var cache_key := "%s/%d" % [cue,weapon]
		check(audio._sounds.has(cache_key), "real-event cached audio " + cache_key)
		if not audio._sounds.has(cache_key): continue
		var sound: AudioStreamWAV = audio._sounds[cache_key]
		var before: AudioStreamWAV = baseline._make_sound(cue, baseline._cue_seconds(cue,weapon), weapon)
		check(sound.save_to_wav(output.path_join("weapon-%d-after.wav" % weapon)) == OK, "export actual shot audio")
		check(before.save_to_wav(output.path_join("weapon-%d-before.wav" % weapon)) == OK, "export baseline audio")
		rows.append({"weapon":weapon,"cue":cue,"before":audio_metrics(before),"after":audio_metrics(sound),"differentPCM":before.data != sound.data})
	baseline.free()
	measurements["audio"] = rows

func finish() -> void:
	if finished: return
	finished = true
	frame_milliseconds.sort()
	if not frame_milliseconds.is_empty(): measurements["engineFrameDeltaMilliseconds"] = {"median":frame_milliseconds[frame_milliseconds.size()/2],"p95":frame_milliseconds[mini(frame_milliseconds.size()-1,int(frame_milliseconds.size()*.95))],"max":frame_milliseconds.back()}
	if is_instance_valid(session) and "coalesced_snapshots" in session.client: measurements["coalescedSnapshots"] = session.client.coalesced_snapshots
	var report := {"passed":failures.is_empty(),"failures":failures,"measurements":measurements,"scriptedInput":true,"actorStateInjection":false,"humanPlaytest":false}
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("live-report.json"), FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	if is_instance_valid(session): session.client.disconnect_server()
	print("CAMPAIGN_FEEL_LIVE ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
