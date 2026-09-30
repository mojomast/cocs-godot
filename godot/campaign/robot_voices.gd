extends Node3D
## Snapshot-driven synthetic creature speech. No AI or local attack scheduler.
const Buses = preload("res://audio/buses.gd")
const MODELS := ["scrapper", "skirmisher", "sentinel", "mortar", "bulwark", "warden"]
const KINDS := ["encounter", "attack", "hurt", "death"]
const WINDUPS := ["artilleryWindup", "flankWindup", "phalanxWindup", "bossStompWindup"]
const MAX_DISTANCE := 42.0
var cache: Dictionary = {}
var players: Array[AudioStreamPlayer3D] = []
var busy_until: Array[float] = [0.0, 0.0]
var owners: Array[int] = [-1, -1]
var priorities: Array[int] = [0, 0]
var actors: Dictionary = {}
var actor_cooldown: Dictionary = {}
var class_cooldown: Dictionary = {}
var variations: Dictionary = {}
var encounters: Dictionary = {}
var authority_time := -1.0
var global_until := -1.0
var enabled := false
var muted := false
var listener := Vector3.ZERO
var played := 0
var epoch := 0
var drain_next := false

func _ready() -> void:
	Buses.ensure()
	for model: String in MODELS:
		for kind: String in KINDS:
			for variant: int in 2:
				var key := "%s_%s_%d" % [model, kind, variant]
				cache[key] = load("res://campaign/robot_voice_assets/%s.wav" % key)
	for index: int in 2:
		var player := AudioStreamPlayer3D.new()
		player.bus = &"Effects"
		player.unit_size = 8.0
		player.max_distance = MAX_DISTANCE
		player.volume_db = -8.0
		add_child(player)
		players.append(player)

func apply_settings(options: Dictionary) -> void:
	# Announcer is the existing opt-in recorded narration channel. Creature
	# vocalizations are diegetic Effects; its slider is applied once by Buses.
	Buses.apply(options)
	var next_muted := options.get("mute", false) == true or float(options.get("effects_volume", 100)) <= 0 or "--mute" in OS.get_cmdline_user_args() or "--mute-capture" in OS.get_cmdline_user_args()
	if muted and not next_muted and authority_time >= 0: drain_next = true
	muted = next_muted
	if muted: stop_voices()

func set_active(value: bool) -> void:
	if enabled == value: return
	if not enabled and value and authority_time >= 0: drain_next = true
	enabled = value
	if not enabled: stop_voices()

func stop_voices() -> void:
	for player: AudioStreamPlayer3D in players:
		player.stop()
		player.stream = null
	busy_until.assign([0.0, 0.0])
	owners.assign([-1, -1])

func clear_round() -> void:
	stop_voices()
	actors.clear()
	actor_cooldown.clear()
	class_cooldown.clear()
	variations.clear()
	encounters.clear()
	authority_time = -1.0
	global_until = -1.0
	enabled = false
	drain_next = false
	epoch += 1

static func point(actor: Dictionary) -> Vector3:
	return Vector3(float(actor.get("x", 0)), float(actor.get("y", 0)) + 1.2, float(actor.get("z", 0)))

static func winding(actor: Dictionary) -> bool:
	for field: String in WINDUPS:
		if float(actor.get(field, 0)) > 0: return true
	return false

func apply_state(state: Dictionary, eye: Vector3) -> void:
	var time := float(state.get("time", -1))
	if not is_finite(time) or time <= authority_time: return
	authority_time = time
	listener = eye
	if state.get("campaign", {}).get("phase", "playing") != "playing": set_active(false)
	var next: Dictionary = {}
	var candidates: Array[Dictionary] = []
	for value: Variant in state.get("actors", []):
		if not value is Dictionary or value.get("npcModel") not in MODELS: continue
		var actor: Dictionary = value
		var id := int(actor.get("id", -1))
		if id < 0: continue
		next[id] = actor.duplicate(true)
		var previous: Dictionary = actors.get(id, {})
		if previous.is_empty(): continue # new actor alone is not a spotting event
		var health := float(actor.get("health", 0))
		var old_health := float(previous.get("health", 0))
		if old_health <= 0: continue
		if health <= 0:
			candidates.append({"actor":actor, "kind":"death"})
		elif health < old_health:
			candidates.append({"actor":actor, "kind":"hurt"})
		elif winding(actor) and not winding(previous):
			candidates.append({"actor":actor, "kind":"attack"})
	# Public campaign remaining-count + step identify actual encounter activation.
	# Consume even when inaudible/suspended: never queue spawn chatter on resume.
	var campaign: Dictionary = state.get("campaign", {})
	var step := int(campaign.get("stepIndex", -1))
	if campaign.get("phase") == "playing" and step >= 0 and int(campaign.get("enemiesRemaining", 0)) > 0 and not encounters.has(step):
		encounters[step] = true
		var chosen: Dictionary = {}
		for actor: Dictionary in next.values():
			if float(actor.get("health", 0)) <= 0: continue
			if chosen.is_empty() or actor.npcModel == "warden" or (chosen.npcModel != "warden" and point(actor).distance_to(eye) < point(chosen).distance_to(eye)):
				chosen = actor
		if not chosen.is_empty(): candidates.append({"actor":chosen, "kind":"encounter"})
	actors = next
	# Death/removal stops an ongoing live phrase before the optional death grunt.
	for index: int in players.size():
		var actor: Dictionary = actors.get(owners[index], {})
		if actor.is_empty():
			players[index].stop()
			players[index].stream = null
			busy_until[index] = 0
		elif float(actor.get("health", 0)) <= 0:
			if priorities[index] != 2:
				players[index].stop()
				busy_until[index] = 0
		elif owners[index] >= 0: players[index].global_position = point(actor)
	for id: Variant in actor_cooldown.keys():
		if not actors.has(id): actor_cooldown.erase(id)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.actor.npcModel == "warden" and b.actor.npcModel != "warden")
	if not drain_next:
		for candidate: Dictionary in candidates: request(candidate.actor, candidate.kind, time)
	drain_next = false

func request(actor: Dictionary, kind: String, now: float) -> bool:
	var model := str(actor.get("npcModel", ""))
	var id := int(actor.get("id", -1))
	if not enabled or muted or model not in MODELS or kind not in KINDS or players.size() != 2: return false
	if id < 0 or (float(actor.get("health", 0)) <= 0 and kind != "death"): return false
	if point(actor).distance_to(listener) > MAX_DISTANCE: return false
	if now < float(actor_cooldown.get(id, -1)) or now < float(class_cooldown.get(model, -1)): return false
	var boss := model == "warden"
	if now < global_until and not boss: return false
	var slot := -1
	for index: int in 2:
		if now >= busy_until[index]:
			slot = index
			break
	if slot < 0 and boss:
		for index: int in 2:
			if priorities[index] == 0:
				slot = index
				break
	if slot < 0: return false
	var variation_key := model + "_" + kind
	var variant := int(variations.get(variation_key, 0)) % 2
	var stream: AudioStream = cache.get("%s_%d" % [variation_key, variant])
	if stream == null: return false
	variations[variation_key] = variant + 1
	players[slot].stop()
	players[slot].stream = stream
	players[slot].global_position = point(actor)
	players[slot].play()
	busy_until[slot] = now + stream.get_length()
	owners[slot] = id
	priorities[slot] = 2 if kind == "death" else (1 if boss else 0)
	actor_cooldown[id] = now + (1.8 if boss else 2.8)
	class_cooldown[model] = now + 1.4
	global_until = now + 0.65
	played += 1
	return true

func _exit_tree() -> void:
	clear_round()
	cache.clear()
