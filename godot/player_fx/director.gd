extends Node
## Local-player screen feedback state, driven only by authoritative public
## state/events. This node owns no meshes; it produces the overlay model and
## counters consumed by res://world/combat_overlay.gd and reported in metrics.
##
## Rules kept deliberately honest:
## - Damage direction needs a public attacker actor position. When the damage
##   event has no actor source, or the attacker is no longer in the public
##   actor list, the cue degrades to the neutral environmental pulse instead of
##   guessing a bearing.
## - Shield-break cues require the authoritative `shieldBreak` flag and no
##   spawn protection; immunity never produces a break cue.
## - Death and respawn cues come from public actor health/dead/protection
##   transitions. The materialize cue mirrors the genuine protection seconds
##   and ends when the pool does.
## - Every timer expires, results/restart drains, and consumed public event IDs
##   are remembered so stale frames can never replay a cue.

const LOW_HEALTH_FRACTION := 0.35 # Documented: strictly below 35% max health.
const DIRECTION_SECONDS := 0.9
const ENVIRONMENT_SECONDS := 0.5
const BREAK_SECONDS := 0.8
const DEATH_SECONDS := 1.6
const HEARTBEAT_HZ := 1.15
const EVENT_WINDOW := 4096
const MAX_EVENTS := 512

var camera: Camera3D
var quality := 1
var local_id := -1
var public_actors: Array = []
var have_actor := false
var alive := false
var health := 0.0
var max_health := 100.0
var protection := 0.0
var armor := 0.0
var low_health := 0.0
var heartbeat := 0.0
var heartbeat_phase := 0.0
var damage_source := -1
var damage_remaining := 0.0
var damage_environmental := false
var direction_angle := 0.0
var direction_known := false
var break_remaining := 0.0
var death_remaining := 0.0
var materialize_remaining := 0.0
var materialize_window := 0.0
var respawn_pending := false
var seen: Dictionary = {}
var highest_event := -1
var counters := {"damage": 0, "environmental": 0, "break": 0, "death": 0, "respawn": 0, "suppressed": 0, "dedup": 0}

func configure(view: Camera3D) -> void:
	camera = view

func set_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	heartbeat = 0.0 if quality == 0 else _heartbeat_strength()

func reset_counters() -> void:
	for key: String in counters: counters[key] = 0

func clear_round() -> void:
	clear_transient()
	local_id = -1
	public_actors = []
	health = 0.0
	max_health = 100.0
	armor = 0.0
	heartbeat_phase = 0.0
	seen.clear()
	highest_event = -1
	reset_counters()

## Focus loss, stale snapshots and identity changes drain held cues without
## forgetting the identity mapping, so a return to play cannot replay them.
func clear_transient() -> void:
	damage_source = -1
	damage_remaining = 0.0
	damage_environmental = false
	direction_known = false
	direction_angle = 0.0
	break_remaining = 0.0
	death_remaining = 0.0
	materialize_remaining = 0.0
	materialize_window = 0.0
	low_health = 0.0
	heartbeat = 0.0
	have_actor = false
	alive = false
	respawn_pending = false
	protection = 0.0

static func number(value: Variant, fallback: float = 0.0) -> float:
	return float(value) if value is int or value is float else fallback

static func identity(value: Variant) -> int:
	if not (value is int or value is float): return -1
	var numeric := float(value)
	if not is_finite(numeric) or numeric < 0.0 or numeric > 9007199254740991.0 or floorf(numeric) != numeric: return -1
	return int(numeric)

## Camera-relative bearing of a world point: 0 is dead ahead, positive is to
## the viewer's right, range (-PI, PI]. Screen mapping uses edge_direction().
static func bearing_angle(basis: Basis, origin: Vector3, target: Vector3) -> float:
	if not origin.is_finite() or not target.is_finite(): return 0.0
	if basis.determinant() == 0.0: return 0.0
	var local := basis.inverse() * (target - origin)
	if not local.is_finite(): return 0.0
	return atan2(local.x, -local.z)

static func edge_direction(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle)) if is_finite(angle) else Vector2.UP

func _local_actor() -> Dictionary:
	for actor: Variant in public_actors:
		if actor is Dictionary and identity(actor.get("id")) == local_id: return actor
	return {}

func _actor_position(id: int) -> Variant:
	if id < 0: return null
	for actor: Variant in public_actors:
		if not actor is Dictionary or identity(actor.get("id")) != id: continue
		var pos := Vector3(number(actor.get("x")), number(actor.get("y")), number(actor.get("z")))
		return pos if pos.is_finite() else null
	return null

func _heartbeat_strength() -> float:
	return low_health if quality > 0 and low_health > 0.0 else 0.0

func apply_state(state: Dictionary, id: int) -> void:
	if state.get("over", false):
		clear_round()
		return
	if id >= 0: local_id = id
	public_actors = state.get("actors", []) if state.get("actors", []) is Array else []
	if local_id < 0: return
	var actor := _local_actor()
	if actor.is_empty():
		# The local actor left the public frame: drain local cues, keep history.
		clear_transient()
		return
	var was_present := have_actor
	var was_alive := alive
	health = maxf(0.0, number(actor.get("health"), health))
	max_health = maxf(1.0, number(actor.get("maxHealth"), 100.0))
	protection = maxf(0.0, number(actor.get("protection")))
	armor = maxf(0.0, number(actor.get("armor")))
	var dead := number(actor.get("dead")) > 0.0 or health <= 0.0
	alive = not dead
	have_actor = true
	if was_alive and dead:
		# Elimination cue, then wait for the genuine protected respawn.
		death_remaining = DEATH_SECONDS
		counters.death += 1
		damage_remaining = 0.0
		break_remaining = 0.0
		materialize_remaining = 0.0
		materialize_window = 0.0
		heartbeat = 0.0
		respawn_pending = true
	elif not was_alive and not dead and was_present:
		# Alive again: only the authoritative protection pool drives the cue.
		materialize_remaining = 0.0
		materialize_window = 0.0
		respawn_pending = false
		if protection > 0.0:
			materialize_window = protection
			materialize_remaining = protection
			counters.respawn += 1
	elif not dead and not was_present:
		# First sight of the local actor (round start / reconnect).
		if protection > 0.0:
			materialize_window = protection
			materialize_remaining = protection
	elif not dead and materialize_window > 0.0:
		# Mirror the live pool: the cue ends exactly when protection does.
		materialize_remaining = minf(materialize_remaining, protection)
		if protection <= 0.0:
			materialize_remaining = 0.0
			materialize_window = 0.0
	var ratio := health / max_health if max_health > 0.0 else 1.0
	low_health = 0.0
	if alive and ratio < LOW_HEALTH_FRACTION:
		low_health = clampf((LOW_HEALTH_FRACTION - ratio) / LOW_HEALTH_FRACTION, 0.0, 1.0)
	heartbeat = _heartbeat_strength()

func _fresh(items: Array) -> Array:
	var fresh: Array = []
	for item: Variant in items.slice(0, MAX_EVENTS):
		if not item is Dictionary: continue
		var id := identity(item.get("id"))
		if id < 0: fresh.append(item) # Detached synthetic events carry no public ID.
		elif id <= highest_event - EVENT_WINDOW or seen.has(id): counters.dedup += 1
		else:
			highest_event = maxi(highest_event, id)
			seen[id] = true
			fresh.append(item)
	for id: int in seen.keys():
		if id <= highest_event - EVENT_WINDOW: seen.erase(id)
	return fresh

func apply_events(items: Array, id: int) -> void:
	if id >= 0: local_id = id
	if local_id < 0 or not have_actor or not alive: return
	for event: Dictionary in _fresh(items):
		if event.get("type") != "damage": continue
		if identity(event.get("actor")) != local_id: continue
		var amount := number(event.get("amount"))
		if amount <= 0.0 or not is_finite(amount): continue
		var source := identity(event.get("source"))
		if source >= 0 and source != local_id:
			damage_source = source
			damage_environmental = false
			damage_remaining = DIRECTION_SECONDS
			counters.damage += 1
			if event.get("shieldBreak") == true:
				if protection > 0.0:
					counters.suppressed += 1 # Immunity/spawn protection is not a break.
				else:
					break_remaining = BREAK_SECONDS
					counters.break += 1
		else:
			damage_source = -1
			damage_environmental = true
			damage_remaining = ENVIRONMENT_SECONDS
			counters.environmental += 1

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	var dt := minf(delta, 2.0)
	damage_remaining = maxf(0.0, damage_remaining - dt)
	break_remaining = maxf(0.0, break_remaining - dt)
	death_remaining = maxf(0.0, death_remaining - dt)
	materialize_remaining = maxf(0.0, materialize_remaining - dt)
	heartbeat_phase = fmod(heartbeat_phase + dt, 3600.0)
	# Recompute the true bearing every frame; the world may have moved.
	direction_known = false
	direction_angle = 0.0
	if damage_remaining > 0.0 and not damage_environmental and is_instance_valid(camera):
		var attacker: Variant = _actor_position(damage_source)
		var local: Variant = _actor_position(local_id)
		var origin: Vector3 = local if local != null else camera.global_position
		if attacker != null and origin.is_finite():
			direction_angle = bearing_angle(camera.global_transform.basis, origin, attacker)
			direction_known = true
		else:
			# Never guess: degrade to the neutral pulse when the attacker is gone.
			damage_environmental = true
	var pulse := 0.0
	if quality > 0 and low_health > 0.0:
		var wave := sin(heartbeat_phase * TAU * HEARTBEAT_HZ)
		if wave > 0.0: pulse = low_health * wave * wave
	heartbeat = pulse

func model() -> Dictionary:
	return {
		"direction": damage_remaining > 0.0,
		"direction_angle": direction_angle,
		"direction_known": direction_known and not damage_environmental,
		"direction_environment": damage_environmental and damage_remaining > 0.0,
		"direction_strength": (clampf(damage_remaining / DIRECTION_SECONDS, 0.0, 1.0) if not damage_environmental else clampf(damage_remaining / ENVIRONMENT_SECONDS, 0.0, 1.0)),
		"low_health": low_health,
		"heartbeat": heartbeat if quality > 0 else 0.0,
		"break": clampf(break_remaining / BREAK_SECONDS, 0.0, 1.0),
		"death": clampf(death_remaining / DEATH_SECONDS, 0.0, 1.0),
		"materialize": clampf(materialize_remaining / maxf(materialize_window, 0.001), 0.0, 1.0),
		"protection": protection,
		"alive": alive,
	}

func snapshot() -> Dictionary:
	return {
		"local_id": local_id, "health": health, "max_health": max_health, "armor": armor,
		"protection": protection, "alive": alive, "low_health": low_health, "heartbeat": heartbeat,
		"damage_remaining": damage_remaining, "damage_environmental": damage_environmental,
		"damage_source": damage_source, "direction_known": direction_known, "direction_angle": direction_angle,
		"break_remaining": break_remaining, "death_remaining": death_remaining,
		"materialize_remaining": materialize_remaining, "materialize_window": materialize_window,
		"seen": seen.size(), "counters": counters.duplicate(), "quality": quality,
	}

func text() -> String:
	if have_actor and not alive: return "ELIMINATED"
	if break_remaining > 0.0: return "SHIELD BREAK"
	if low_health > 0.0: return "LOW HEALTH"
	return ""
