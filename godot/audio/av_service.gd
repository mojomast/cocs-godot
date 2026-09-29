extends Node
## One composition boundary for music, existing voices, vehicle foley and
## cosmetic weather. Parent supplies ONLY authority-confirmed snapshots/events.
const Music = preload("res://audio/music_service.gd")
const Vehicle = preload("res://audio/vehicle_service.gd")
const Motifs = preload("res://audio/objective_motifs.gd")
const Weather = preload("res://ambience/weather_service.gd")
const Router = preload("res://audio/event_router.gd")
var music
var vehicle
var motifs
var weather
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

func _ready() -> void:
	music = Music.new()
	add_child(music)
	vehicle = Vehicle.new()
	add_child(vehicle)
	motifs = Motifs.new()
	add_child(motifs)
	weather = Weather.new()
	add_child(weather)
	apply_settings(settings)

func bind_session(owner: Node, eye: Camera3D, arena: Dictionary, match_mode: String, round_identity: Variant, seed: int = 1) -> void:
	host = owner
	camera = eye
	mode = match_mode
	music.bind(owner)
	music.set_mode_theme(mode)
	music.set_seed(seed)
	weather.bind(arena, eye, "playing", seed)
	router.start_round(round_identity)
	context_ready = false
	last_time = -1.0
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
	if music != null: music.set_settings(settings)
	if vehicle != null: vehicle.apply_settings(settings)
	if motifs != null: motifs.apply_settings(settings)
	if weather != null: weather.apply_settings(settings)
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
	var alive := actor.get("health", 0) is int or actor.get("health", 0) is float
	var hp := float(actor.get("health", 0)) if alive else 0.0
	var max_hp := float(actor.get("maxHealth", 100))
	var low := not actor.has("vehicleId") and hp > 0 and max_hp > 0 and hp / max_hp <= 0.28
	music.set_tension(0.6 if low else 0.0)
	music.set_intensity(maxf(0.4 if low else 0.0, music.intensity * 0.95))
	if scene != "results": music.set_scene("combat" if music.intensity >= 0.34 else "explore")
	var vehicles: Variant = state.get("vehicles", [])
	var mounted: Dictionary = {}
	if vehicles is Array and actor.get("vehicleId") != null:
		for candidate: Variant in vehicles:
			if candidate is Dictionary and candidate.get("id") == actor.vehicleId: mounted = candidate; break
	vehicle.apply_vehicle(mounted, actor)
	if focused and settings.get("mute", false) != true:
		suspension_reason = ""
		music.start()

func apply_events(events: Array) -> void:
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

func tick(delta: float) -> void:
	if not focused or not fresh or settings.get("mute", false) == true: return
	music.tick(delta)
	weather.tick(delta)

func set_focus(value: bool) -> void:
	focused = value
	music.set_focus(value)
	vehicle.set_focus(value)
	motifs.set_focus(value)
	weather.set_focus(value)
	if not value: suspend("focus")

func suspend(reason: String) -> void:
	suspension_reason = reason
	fresh = false
	music.reset()
	vehicle.stop_all()
	motifs.stop_all()
	weather.set_focus(false)

func status() -> Dictionary:
	return {"music":music.status(), "vehicle":vehicle.status(), "motifs":motifs.status(), "weather":weather.diagnostics(), "routing":router.status(),
		"current_scene":scene, "last_cue_id":last_cue, "suspension_reason":suspension_reason,
		"ready":context_ready, "fresh":fresh, "focused":focused}
