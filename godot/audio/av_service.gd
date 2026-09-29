extends Node
## One composition boundary for music, existing voices, vehicle foley and
## cosmetic weather. Parent supplies ONLY authority-confirmed snapshots/events.
const Music = preload("res://audio/music_service.gd")
const Vehicle = preload("res://audio/vehicle_service.gd")
const Motifs = preload("res://audio/objective_motifs.gd")
const Weather = preload("res://ambience/weather_service.gd")
const Router = preload("res://audio/event_router.gd")
const Outcome = preload("res://audio/outcome.gd")
const Buses = preload("res://audio/buses.gd")
var music
var vehicle
var motifs
var weather
var moth_bed := AudioStreamPlayer.new()
var router := Router.new()
var host: Node
var camera: Camera3D
var settings: Dictionary = {}
var context_ready := false
var fresh := false
var focused := true
var mode := "default"
var scene := "menu"
var actor_id := -1
var actor: Dictionary = {}
var last_time := -1.0
var suspension_reason := "unbound"
var last_cue := ""
var intensity_stamp := -1000.0
var countdown_phase := ""
var countdown_beat := 0
var final_warned := false

func _ready() -> void:
	Buses.ensure()
	music = Music.new()
	add_child(music)
	vehicle = Vehicle.new()
	add_child(vehicle)
	motifs = Motifs.new()
	add_child(motifs)
	weather = Weather.new()
	add_child(weather)
	moth_bed.name = "ReviewedMothBed"
	moth_bed.bus = &"Ambience"
	add_child(moth_bed)
	var delivered: Resource = load("res://audio/moth/bed-ritual.wav")
	if delivered is AudioStreamWAV:
		var wav := delivered.duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 11025 # 0.5 seconds at original 22050 Hz
		wav.loop_end = 231525 # 10.5 seconds, within delivered 10.68s
		moth_bed.stream = wav
	apply_settings(settings)

func bind_session(owner: Node, eye: Camera3D, arena: Dictionary, match_mode: String, round_identity: Variant, seed: int = 1) -> void:
	host = owner
	camera = eye
	mode = match_mode
	music.bind(owner)
	music.set_mode_theme(mode)
	music.set_seed(seed)
	weather.bind(arena, eye, "playing", seed)
	_sync_weather_ownership()
	router.start_round(round_identity)
	context_ready = false
	last_time = -1.0
	intensity_stamp = -1000.0
	countdown_phase = ""
	countdown_beat = 0
	final_warned = false
	suspension_reason = "awaiting_snapshot"

func start_round(identity: Variant) -> void:
	if router.round_key == identity: return
	router.start_round(identity)
	scene = "explore"
	music.set_outcome("")
	music.reset()
	vehicle.stop_all()
	motifs.stop_all()
	context_ready = false
	last_time = -1.0
	intensity_stamp = -1000.0
	countdown_phase = ""
	countdown_beat = 0
	final_warned = false
	suspension_reason = "awaiting_snapshot"

func seek_reset(identity: Variant) -> void:
	router.seek_reset(identity)
	music.reset()
	vehicle.stop_all()
	motifs.stop_all()
	context_ready = false
	last_time = -1.0
	suspension_reason = "replay_seek"

func apply_settings(normalized: Dictionary) -> void:
	settings = normalized.duplicate()
	if "--mute" in OS.get_cmdline_user_args() or "--mute-capture" in OS.get_cmdline_user_args(): settings["mute"] = true
	Buses.apply(settings)
	if music != null: music.set_settings(settings)
	if vehicle != null: vehicle.apply_settings(settings)
	if motifs != null: motifs.apply_settings(settings)
	if weather != null: weather.apply_settings(settings)
	if weather != null: _sync_weather_ownership()
	if moth_bed.stream != null:
		var ambience: Variant = settings.get("ambience_volume", 100)
		var level := clampf(float(ambience) / 100.0, 0.0, 1.0) if ambience is int or ambience is float else 1.0
		moth_bed.volume_db = linear_to_db(maxf(0.001, level * 0.4))
		if settings.get("mute", false) == true or settings.get("ambience_enabled", true) == false or level <= 0.0: moth_bed.stop()
	if settings.get("mute", false) == true:
		suspension_reason = "muted"
		if music != null: music.reset()
		if vehicle != null: vehicle.stop_all()
		if motifs != null: motifs.stop_all()

func apply_snapshot(state: Dictionary, local_id: int, is_fresh: bool = true) -> void:
	actor_id = local_id
	fresh = is_fresh
	if not is_fresh:
		suspend("stale_snapshot")
		return
	context_ready = true
	weather.set_focus(focused)
	actor = {}
	var actors: Variant = state.get("actors", [])
	if actors is Array:
		for candidate: Variant in actors:
			if candidate is Dictionary and candidate.get("id") == actor_id:
				actor = candidate
				break
	var time: Variant = state.get("time")
	if (time is float or time is int) and is_finite(float(time)):
		if last_time >= 0.0 and float(time) < last_time - 0.001:
			# A replay seek needs an explicit caller reset; a minor correction is
			# not evidence of a new round or permission to replay old wire IDs.
			music.reset()
			vehicle.stop_all()
		last_time = float(time)
	weather.apply_snapshot(state)
	_sync_weather_ownership()
	var config: Variant = state.get("config")
	if config is Dictionary and config.get("mode") is String: music.set_mode_theme(config.mode)
	if focused and settings.get("mute", false) != true: music.start()
	var alive := actor.get("health", 0) is int or actor.get("health", 0) is float
	var hp := float(actor.get("health", 0)) if alive else 0.0
	var max_hp := float(actor.get("maxHealth", 100))
	var low := actor.get("vehicleId") == null and hp > 0 and max_hp > 0 and hp / max_hp <= 0.28
	music.set_tension(maxf(0.6 if low else 0.0, 0.25 * float(router.escalation)))
	var active_peak := clampf(1.0 - maxf(0.0, last_time - intensity_stamp) / 5.0, 0.0, 1.0)
	music.set_intensity(maxf(0.4 if low else 0.0, active_peak))
	if scene != "results":
		scene = "combat" if music.intensity >= 0.34 else "explore"
		music.set_scene(scene)
	var vehicles: Variant = state.get("vehicles", [])
	var mounted: Dictionary = {}
	if vehicles is Array and actor.get("vehicleId") != null:
		for candidate: Variant in vehicles:
			if candidate is Dictionary and candidate.get("id") == actor.vehicleId: mounted = candidate; break
	vehicle.apply_vehicle(mounted, actor)
	var race: Variant = state.get("race")
	if race is Dictionary: _observe_countdown(race)
	if not final_warned and config is Dictionary:
		var limit: Variant = config.get("timeLimit")
		if (limit is int or limit is float) and float(limit) > 0.0 and last_time >= 0.0 and float(limit) - last_time > 0.0 and float(limit) - last_time <= 10.0:
			final_warned = true
			music.set_tension(1.0)
			if not music.response("final"): motifs.event_plan({"type":"sudden-death"})
	if focused and settings.get("mute", false) != true:
		suspension_reason = ""

func apply_events(events: Array) -> void:
	# Source feedback.mjs intensity is a five-second presentation envelope.
	# Inspect existing combat reports only for arrangement; PortAudioFeedback
	# alone owns their actual shot/launch/hurt/explosion sound.
	if context_ready and fresh and focused and settings.get("mute", false) != true and not actor.is_empty() and last_time >= 0.0:
		for value: Variant in events.slice(0, 512):
			if not value is Dictionary: continue
			var kind := str(value.get("type", ""))
			if not kind in ["shot", "vehicle-shot", "launch", "explosion", "death", "melee", "near-rocket"]: continue
			var position: Variant = value.get("from", value.get("pos"))
			var near: bool = value.get("actor") == actor_id
			var radius := 18.0 if kind == "near-rocket" else 34.0
			if position is Dictionary and (position.get("x") is int or position.get("x") is float):
				if (position.get("z") is int or position.get("z") is float) and (actor.get("x") is int or actor.get("x") is float) and (actor.get("z") is int or actor.get("z") is float):
					near = near or Vector2(float(position.x) - float(actor.x), float(position.z) - float(actor.z)).length() <= radius
			if near:
				intensity_stamp = last_time
				music.set_intensity(maxf(music.intensity, 0.85 if kind == "near-rocket" else (1.0 if kind in ["explosion", "death"] else 0.72)))
	# Router consumes even muted/unfocused events, so they cannot be caught up
	# after focus recovery. Missing first snapshot consumes IDs without guessing.
	var plans: Array[Dictionary] = router.consume(events, actor_id, actor.get("team"), context_ready and fresh, actor.get("vehicleId"))
	if not focused or not fresh or settings.get("mute", false) == true: return
	for plan: Dictionary in plans:
		var kind: String = plan.type
		if kind in ["vehicle-shot", "vehicle-damage"]:
			vehicle.event_plan(plan)
			continue
		music.set_escalation(int(plan.escalation))
		var voiced := false
		if not str(plan.voice).is_empty(): voiced = music.cue(str(plan.voice))
		var answered := false
		if not str(plan.response).is_empty() and not voiced: answered = music.response(str(plan.response))
		if not voiced and not answered: motifs.event_plan(plan)
		last_cue = "%s:%d" % [kind, int(plan.id)]

func finish(outcome: String = "neutral") -> void:
	if scene == "results": return
	scene = "results"
	music.set_outcome(outcome if outcome in ["victory", "defeat"] else "neutral")
	vehicle.stop_all()
	motifs.stop_all()

func finish_state(state: Dictionary, local_actor_id: int, match_mode: String) -> void:
	finish(Outcome.resolve(state, match_mode, local_actor_id))

func _observe_countdown(race: Dictionary) -> void:
	var phase := str(race.get("phase", ""))
	var active := phase in ["countdown", "kickoff"]
	var count: Variant = race.get("countdown")
	var beat := maxi(1, ceili(float(count))) if active and (count is int or count is float) and is_finite(float(count)) else 0
	if phase in ["racing", "playing"] and countdown_phase in ["countdown", "kickoff"]:
		music.set_tension(0.0)
		music.countdown_beep(0) # GO only from observed countdown -> live edge.
	elif active and beat in [1, 2, 3] and (beat != countdown_beat or phase != countdown_phase):
		music.set_tension(clampf(0.2 + (3 - beat) * 0.25, 0.0, 1.0))
		music.countdown_beep(beat)
	countdown_phase = phase
	countdown_beat = beat

func tick(delta: float) -> void:
	if not focused or not fresh or settings.get("mute", false) == true: return
	if moth_bed.stream != null:
		if scene in ["menu", "explore"] and settings.get("ambience_enabled", true) == true and not moth_bed.playing: moth_bed.play()
		elif scene not in ["menu", "explore"] and moth_bed.playing: moth_bed.stop()
	music.tick(delta)
	weather.tick(delta)

func set_focus(value: bool) -> void:
	focused = value
	music.set_focus(value)
	vehicle.set_focus(value)
	motifs.set_focus(value)
	weather.set_focus(value)
	if not value: moth_bed.stop()
	if not value: suspend("focus")

func suspend(reason: String) -> void:
	suspension_reason = reason
	fresh = false
	music.reset()
	vehicle.stop_all()
	motifs.stop_all()
	weather.set_focus(false)
	moth_bed.stop()

func status() -> Dictionary:
	return {"music":music.status(), "vehicle":vehicle.status(), "motifs":motifs.status(), "weather":weather.diagnostics(), "routing":router.status(),
		"current_scene":scene, "last_cue_id":last_cue, "suspension_reason":suspension_reason,
		"moth_bed":moth_bed.playing, "ready":context_ready, "fresh":fresh, "focused":focused}

func _weather_owners() -> Array:
	var owners := []
	if not is_instance_valid(host): return owners
	var combat_node: Variant = host.get("combat")
	if combat_node is Node and is_instance_valid(combat_node):
		var pool: Variant = combat_node.get("world_particles")
		if pool is Node and is_instance_valid(pool) and pool.has_method("set_weather_precipitation_suppressed"): owners.append(pool)
	var world_node: Variant = host.get("world")
	if world_node is Node and is_instance_valid(world_node):
		var scenery: Node = world_node.get_node_or_null("MothScenery")
		if scenery != null and scenery.has_method("set_weather_precipitation_suppressed"): owners.append(scenery)
	return owners

func _sync_weather_ownership() -> void:
	if weather == null: return
	var owners := _weather_owners()
	var want: bool = weather.wants_precipitation_handoff()
	if not want:
		weather.set_native_weather_suppressed(false)
		for owner: Node in owners: owner.set_weather_precipitation_suppressed(false)
		return
	var acknowledged := true
	for owner: Node in owners:
		acknowledged = owner.set_weather_precipitation_suppressed(true) and acknowledged
	weather.set_native_weather_suppressed(acknowledged)

func _exit_tree() -> void:
	preload("res://audio/playback_cleanup.gd").release(moth_bed)
	if weather != null: weather.set_native_weather_suppressed(false)
	for owner: Node in _weather_owners(): owner.set_weather_precipitation_suppressed(false)
	preload("res://audio/playback_cleanup.gd").drain()
