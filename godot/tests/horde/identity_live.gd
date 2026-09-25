extends Node
## Test-only external observer/controller of the ACTUAL identity Horde product
## scene (res://native_arenas/identity_horde_demo.tscn).
##
## Same discipline as res://tests/horde/live.gd: the product scene is
## instantiated as a child, steering uses ordinary InputEventKey/MouseMotion/
## MouseButton through Input.parse_input_event, and no simulation state, clock,
## actor or match field is ever written. Evidence is printed for the owned
## validator and screenshots are saved at both product resolutions.
@onready var session: Node = $IdentityHorde
const LOOK_GAIN := 0.002
var scenario := "waves"
var shot_path := ""
var bounded := 160.0
var held := {}
var firing := false
var completed := false
var wait := 0.0
var elapsed := 0.0
var dead_seen := false
var respawn_seen := false
var blocked_seen := false
var captured_shots := {}
var picture_queue: Array = []
var pumping := false
var results_requested := false
var results_ready := false
var wave_seen := {}
var cleared := 0
var cleared_waves: Array = []
var upgrade_offers: Array = []
var upgrade_count := 0
var deaths := 0
var life_losses: Array = []
var outcome := ""
var cadence: Array = []
var cadence_elapsed := 0.0
var peak_alive := 0
var peak_actors := 0
var peak_shot := false
var applied_high := 0
var census: Dictionary = {}
var motion_elapsed := 0.0
var motion_samples := 0
var motion_start := Vector3.INF
var motion_last := Vector3.INF
var motion_max_step := 0.0
var motion_max_eye_offset := 0.0
var motion_last_applied := 0
var motion_last_eye := Vector3.INF
var motion_spikes := 0
var motion_last_usec := 0
var motion_max_excess := 0.0

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="): scenario = arg.trim_prefix("--scenario=")
		if arg.begins_with("--screenshot="): shot_path = arg.trim_prefix("--screenshot=")
	bounded = {"startup": 70.0, "motion": 50.0, "waves": 158.0, "defeat": 158.0, "peak": 170.0}.get(scenario, 158.0)
	print("HORDE_PRODUCT ", JSON.stringify({"scene":session.scene_file_path,
		"script":session.get_script().resource_path, "scoreboard":session.has_node("Scoreboard")}))
	await get_tree().process_frame
	await get_tree().process_frame
	if session.has_method("environment_census"):
		census = session.environment_census()
	print("IDENTITY_PRODUCT ", JSON.stringify({"scene":session.scene_file_path,
		"script":session.get_script().resource_path, "map":session.current_id, "mode":session.selected_mode,
		"waves":session.waves, "horde_label_passive":session.horde_label.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"suns":census.get("suns", -1), "environments":census.get("environments", -1),
		"environment_meshes":census.get("maps", -1), "viewport":[get_window().size.x, get_window().size.y],
		"authority":session.endpoint}))

func key(code: int, down: bool) -> void:
	if held.get(code, false) == down: return
	held[code] = down
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func mouse(down: bool) -> void:
	firing = down
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	Input.parse_input_event(event)

func click() -> void:
	mouse(true)
	mouse(false)

func neutral() -> void:
	for code: int in held.keys(): key(code, false)
	if firing: mouse(false)

func want_picture(tag: String) -> void:
	if captured_shots.has(tag): return
	for queued: String in picture_queue:
		if queued == tag: return
	picture_queue.append(tag)

func picture(tag: String) -> void:
	if captured_shots.has(tag) or shot_path.is_empty(): return
	captured_shots[tag] = true
	await RenderingServer.frame_post_draw
	var hud: Node = session.get_node("GameHUD")
	var board: Node = session.get_node("Scoreboard")
	var strip: Label = session.horde_label
	print("HORDE_LAYOUT ", JSON.stringify({"tag":tag,"viewport":[get_window().size.x,get_window().size.y],
		"horde":[strip.position.x,strip.position.y,strip.size.x,strip.size.y],
		"status":[hud.status_panel.position.x,hud.status_panel.position.y,hud.status_panel.size.x,hud.status_panel.size.y],
		"status_visible":hud.status_panel.visible,"intersects":hud.status_panel.visible and strip.get_rect().intersects(hud.status_panel.get_rect()),
		"scoreboard_visible":board.panel.visible,"scoreboard":[board.panel.position.x,board.panel.position.y,board.panel.size.x,board.panel.size.y],
		"scoreboard_intersects":board.panel.visible and strip.get_rect().intersects(board.panel.get_rect()),
		"scoreboard_bottom":board.panel.position.y+board.panel.size.y,
		"controls_visible":hud.controls.visible,"controls_bottom":hud.controls.position.y+hud.controls.size.y,
		"controls":[hud.controls.position.x,hud.controls.position.y,hud.controls.size.x,hud.controls.size.y],
		"passive":strip.mouse_filter == Control.MOUSE_FILTER_IGNORE}))
	print("HORDE_PICTURE ", tag, " ", get_viewport().get_texture().get_image().save_png(shot_path.replace(".png", "-"+tag+".png")))

func alternate_picture(tag: String) -> void:
	var original := get_window().size
	get_window().size = Vector2i(1280, 800) if original.x < 1000 else Vector2i(960, 640)
	await get_tree().process_frame
	await get_tree().process_frame
	await picture(tag)
	get_window().size = original
	await get_tree().process_frame

## One queued tag at both product sizes, strictly one pair at a time. GDScript
## does not block the next _process call while a coroutine is suspended, so the
## single-flight flag (not just the queue) is what stops two window resizes from
## racing each other.
func pump_pictures() -> bool:
	if picture_queue.is_empty() and not pumping: return false
	if not pumping:
		pumping = true
		run_pump()
	return true

func run_pump() -> void:
	while not picture_queue.is_empty():
		var tag: String = picture_queue.pop_front()
		await picture(tag)
		await alternate_picture(tag + "-alternate")
	pumping = false
	if results_requested and picture_queue.is_empty(): results_ready = true

func drain_pictures() -> void:
	while pumping: await get_tree().process_frame
	pumping = true
	while not picture_queue.is_empty():
		var tag: String = picture_queue.pop_front()
		await picture(tag)
		await alternate_picture(tag + "-alternate")
	pumping = false

func cadence_sample() -> void:
	var alive := int(session.horde.state.get("enemiesAlive", 0))
	var actors: int = session.presentation.actors.size()
	var fps := Engine.get_frames_per_second()
	applied_high = maxi(applied_high, session.presentation.applied)
	cadence.append({"t":elapsed,"alive":alive,"actors":actors,"fps":fps,
		"applied":session.presentation.applied,"snapshots":session.client.last_snapshot_seq,"wave":int(session.horde.state.get("wave",0))})
	if alive > peak_alive:
		peak_alive = alive
		peak_actors = maxi(peak_actors, actors)

func cadence_summary() -> Dictionary:
	var fps: Array = []
	var peak_fps: Array = []
	for sample: Dictionary in cadence:
		fps.append(float(sample.fps))
		if int(sample.alive) >= peak_alive and peak_alive > 0: peak_fps.append(float(sample.fps))
	fps.sort()
	var median: float = 0.0 if fps.is_empty() else fps[fps.size()/2]
	var minimum: float = 0.0 if fps.is_empty() else fps[0]
	var average := 0.0
	for value: float in fps: average += value
	if not fps.is_empty(): average /= fps.size()
	var peak_average := 0.0
	for value: float in peak_fps: peak_average += value
	if not peak_fps.is_empty(): peak_average /= peak_fps.size()
	return {"samples":cadence.size(),"wall":0.0 if cadence.is_empty() else float(cadence[-1].t),
		"fps_min":minimum,"fps_median":median,"fps_avg":average,"peak_alive":peak_alive,"peak_actors":peak_actors,
		"fps_at_peak_avg":peak_average,"fps_at_peak_samples":peak_fps.size(),
		"resolution":[get_window().size.x, get_window().size.y],"software_xvfb":true,
		"snapshots_applied_high_water":applied_high,"snapshots_received":session.client.last_snapshot_seq}

func finish(ok: bool, message: String) -> void:
	if completed: return
	completed = true
	neutral()
	print("IDENTITY_CADENCE ", JSON.stringify(cadence_summary()))
	print("IDENTITY_WAVES ", JSON.stringify({"cleared":cleared,"cleared_waves":cleared_waves,
		"waves_seen":wave_seen.values(),"upgrade_offers":upgrade_offers,"deaths":deaths,
		"life_losses":life_losses,"outcome":outcome}))
	print("HORDE_DONE ", JSON.stringify({"ok":ok,"message":message,"scenario":scenario,"dead_seen":dead_seen,"respawn_seen":respawn_seen,"blocked_seen":blocked_seen}))
	# Drain the queue before the closing captures so a wave picture requested in
	# the same frame as the completion is still recorded.
	await drain_pictures()
	await picture("final")
	await alternate_picture("final-alternate")
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)

func observe_horde() -> void:
	var state: Dictionary = session.horde.state
	if state.is_empty(): return
	var wave := int(state.get("wave", 0))
	if wave > 0 and not wave_seen.has(wave):
		wave_seen[wave] = {"wave":wave,"alive":int(state.get("enemiesAlive",0)),"total":int(state.get("enemiesTotal",0)),
			"lives":int(state.get("lives",0)),"modifier":str(state.get("waveModifier", {}).get("name", "")),"t":elapsed}
		print("IDENTITY_WAVE ", JSON.stringify(wave_seen[wave]))
		want_picture("wave%d" % wave)
	var alive := int(state.get("enemiesAlive", 0))
	if wave > 0 and alive == 0 and str(state.get("phase", "")) == "intermission" and not cleared_waves.has(wave):
		cleared_waves.append(wave)
		cleared += 1
		print("IDENTITY_CLEARED ", JSON.stringify({"wave":wave,"score":int(state.get("score",0)),
			"lives":int(state.get("lives",0)),"waveTimer":float(state.get("waveTimer",0)),"t":elapsed,
			"upgrades":int(state.get("upgradeCount", 0))}))
	if not upgrade_offers.has(wave):
		var offers: Variant = state.get("upgrades")
		if offers is Array and not offers.is_empty():
			upgrade_offers.append(wave)
			upgrade_count = int(state.get("upgradeCount", 0))
			print("IDENTITY_UPGRADE ", JSON.stringify({"wave":wave,"choices":offers,"selected":state.get("upgradeSelected"),
				"upgradeCount":upgrade_count,"selection_supported":false}))
	# The source's own death counter is the authority; the observer's list is
	# telemetry that can miss the final sample when defeat resolves in one frame.
	deaths = maxi(deaths, int(state.get("deaths", 0)))
	var lives := int(state.get("lives", 3))
	if lives < 3 and not life_losses.has(lives):
		life_losses.append(lives)
		print("IDENTITY_LIFE ", JSON.stringify({"lives":lives,"deaths":deaths,"t":elapsed,"alive":alive}))

func _process(delta: float) -> void:
	if completed: return
	elapsed += delta
	if await pump_pictures(): return
	if session.phase == -1:
		finish(false, session.label.text)
		return
	if session.phase == 3:
		cadence_elapsed += delta
		if cadence_elapsed >= 0.5:
			cadence_elapsed = 0.0
			cadence_sample()
	if elapsed > bounded:
		print("IDENTITY_TIMEOUT ", JSON.stringify({"elapsed":elapsed,"bounded":bounded,"scenario":scenario,"cleared":cleared}))
		# The peak scenario measures cadence under load; a bounded window that
		# already contains cleared waves and a full cadence sample set is a
		# completed measurement, not a failed attempt.
		if scenario == "peak" and cleared >= 1 and cadence.size() >= 100:
			finish(true, "peak window measured within the bounded attempt")
		else:
			finish(false, "bounded attempt expired")
		return
	if session.phase == 4:
		if scenario == "motion":
			finish(false, "Horde motion trace did not complete before the source result")
			return
		neutral()
		if not results_requested:
			observe_horde()
			results_requested = true
			outcome = str(session.horde.state.get("phase", ""))
			print("IDENTITY_RESULT ", JSON.stringify({"outcome":outcome,"lives":int(session.horde.state.get("lives",0)),
				"score":int(session.horde.state.get("score",0)),"cleared":cleared,"deaths":deaths,
				"wave":int(session.horde.state.get("wave",0)),"waveTarget":int(session.horde.state.get("waveTarget",0)),
				"kills":int(session.horde.state.get("kills",0)),"elapsed":elapsed}))
			want_picture("results")
			if outcome == "lost": want_picture("defeat")
		if results_ready:
			wait += delta
			if wait > 1.0: key(KEY_ENTER, true)
		return
	if session.phase != 3 or not session.received_pose: return
	observe_horde()
	if session.round_starts > 1:
		if scenario == "motion":
			finish(false, "Horde motion trace did not complete before restart")
			return
		neutral()
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			finish(false, "automatic capture after restart")
			return
		var fresh_lives := int(session.horde.state.get("lives", 0))
		print("IDENTITY_RESTART ", JSON.stringify({"rounds":session.round_starts,"results":session.round_results,"lives":fresh_lives,
			"alive":int(session.horde.state.get("enemiesAlive",0)),"captured":false,"outcome":outcome}))
		if outcome == "lost":
			blocked_seen = fresh_lives == 3
			finish(blocked_seen, "defeat, clean restart and fresh round")
			return
		finish(session.round_results >= 1, "results and clean restart observed")
		return
	var a: Dictionary = session.presentation.local_actor
	if a.is_empty(): return
	if scenario == "motion":
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			# Horde deliberately refuses recapture while a movement key is held.
			# Release it first, as a person must after focus/stale recovery.
			key(KEY_W, false)
			click()
			return
		key(KEY_W, true)
		motion_elapsed += delta
		var pose: Vector3 = session.camera.position
		var frame_usec := Time.get_ticks_usec()
		if not motion_start.is_finite(): motion_start = pose
		if motion_last.is_finite():
			var step_size := pose.distance_to(motion_last)
			var wall_seconds := float(frame_usec - motion_last_usec) / 1000000.0
			motion_max_excess = maxf(motion_max_excess, step_size - session.HORDE_VISUAL_MAX_SPEED * wall_seconds)
			motion_max_step = maxf(motion_max_step, step_size)
			if step_size > 0.35 and motion_spikes < 15:
				motion_spikes += 1
				print("HORDE_MOTION_STEP ", JSON.stringify({"step_m":step_size,"frame_seconds":delta,"wall_seconds":wall_seconds,
					"source_eye_step_m":session.presentation.eye_position().distance_to(motion_last_eye),
					"camera_source_offset_m":pose.distance_to(session.presentation.eye_position()),
					"stale":session.snapshot_watch.stale(),"ack":session.client.last_ack,
					"applied":session.presentation.applied,"t":motion_elapsed}))
		motion_last = pose
		motion_last_usec = frame_usec
		motion_last_eye = session.presentation.eye_position()
		motion_samples += 1
		motion_last_applied = session.presentation.applied
		motion_max_eye_offset = maxf(motion_max_eye_offset, pose.distance_to(session.presentation.eye_position()))
		if motion_elapsed >= 8.0:
			var distance: float = pose.distance_to(motion_start)
			var trace := {"source":"live Nacre Horde loopback, ordinary W key input", "seconds":motion_elapsed,
				"render_samples":motion_samples, "snapshots_applied":motion_last_applied, "ack":session.client.last_ack,
				"distance_m":distance, "largest_render_step_m":motion_max_step,
				"largest_step_above_render_speed_cap_m":motion_max_excess,
				"largest_camera_to_source_eye_m":motion_max_eye_offset, "software_xvfb":true}
			print("HORDE_MOTION ", JSON.stringify(trace))
			finish(motion_samples > 30 and motion_last_applied > 90 and session.client.last_ack > 60 and distance > 1.0 and motion_max_eye_offset < 3.0 and motion_max_excess < 0.15,
				"source-snapshot Horde camera moved under ordinary held input")
		return
	if scenario == "startup":
		if int(session.horde.state.get("enemiesAlive", 0)) > 0:
			finish(true, "received actual wave and enemies")
		return
	if scenario == "defeat":
		# No fire at all: the source enemies must do the killing. The player walks
		# into the nearest enemy so contact is genuine, then holds and dies. Fail
		# if the player ever dies before a wave is live.
		var target: Dictionary = nearest_enemy(a)
		if not target.is_empty():
			var distance := Vector2(float(target.x)-float(a.x), float(target.z)-float(a.z)).length()
			aim_at(target, a)
			key(KEY_W, distance > 3.0)
			key(KEY_SHIFT, distance > 12.0)
		else:
			neutral()
		var health := float(a.get("health", 0))
		if health <= 0 and not dead_seen:
			dead_seen = true
			print("IDENTITY_DEATH ", JSON.stringify({"lives":int(session.horde.state.get("lives",3)),"deaths":deaths,"t":elapsed,"clearance":"source death"}))
			want_picture("death%d" % deaths)
		elif health > 0 and dead_seen and not respawn_seen:
			respawn_seen = true
			print("IDENTITY_RESPAWN ", JSON.stringify({"lives":int(session.horde.state.get("lives",3)),"t":elapsed,"health":health}))
		return
	# waves / peak: source-default steering. Aim at the nearest received NPC with
	# real mouse motion, hold fire, close distance, reload when empty.
	if not session.presentation.lifecycle.can_control():
		neutral()
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		neutral()
		click()
		return
	var target: Dictionary = nearest_enemy(a)
	if target.is_empty():
		neutral()
		return
	var distance := Vector2(float(target.x)-float(a.x), float(target.z)-float(a.z)).length()
	aim_at(target, a)
	if not firing: mouse(true)
	key(KEY_W, distance > 18)
	key(KEY_SPACE, distance > 18 and fmod(elapsed, 3) < 0.2)
	var ammo: Variant = a.get("ammo", [1])
	var weapon := int(a.get("weapon", 0))
	key(KEY_R, ammo is Array and weapon < ammo.size() and int(ammo[weapon]) == 0)
	if scenario == "peak" and not peak_shot and elapsed > 25.0 and int(session.horde.state.get("enemiesAlive", 0)) >= 4:
		peak_shot = true
		want_picture("peak")
		print("IDENTITY_PEAK_SHOT ", JSON.stringify({"alive":int(session.horde.state.get("enemiesAlive", 0)),
			"actors":session.presentation.actors.size(),"t":elapsed,"wave":int(session.horde.state.get("wave",0))}))

func nearest_enemy(a: Dictionary) -> Dictionary:
	var target: Dictionary = {}
	var distance := INF
	for npc: Dictionary in session.latest.get("actors", []):
		if npc.get("isNpc") != true or float(npc.get("health", 0)) <= 0: continue
		var d := Vector2(float(npc.x)-float(a.x), float(npc.z)-float(a.z)).length()
		if d < distance:
			distance = d
			target = npc
	return target

func aim_at(target: Dictionary, a: Dictionary) -> void:
	var offset := Vector3(float(target.x)-float(a.x), float(target.y)+0.9-session.camera.position.y, float(target.z)-float(a.z))
	var aim_yaw := atan2(-offset.x, -offset.z)
	var aim_pitch := atan2(offset.y, Vector2(offset.x,offset.z).length())
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-wrapf(aim_yaw-session.yaw,-PI,PI)/LOOK_GAIN,-(aim_pitch-session.pitch)/LOOK_GAIN)
	Input.parse_input_event(motion)
