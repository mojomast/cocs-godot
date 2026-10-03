extends RefCounted
## Visual-only recipient for public accepted melee. No sound, damage or input.
const Wire = preload("res://world/projectiles.gd")
const MAX_AGE := 0.40
const MAX_AHEAD := 0.25
const EVENT_WINDOW := 4096
var seen: Dictionary = {}
var order: Array[int] = []
var highest := -1
var lifetimes: Dictionary = {}
var source_time := -1.0
var silence := 0.0
var round_over := false
var counters := {"dispatched":0,"duplicates":0,"invalid":0,"suppressed":0}

static func valid(event: Dictionary) -> bool:
	var time: Variant = event.get("time")
	return event.get("type") == "melee" and Wire.identity(event.get("id")) >= 0 and Wire.identity(event.get("actor")) >= 0 and (time is int or time is float) and is_finite(float(time)) and float(time) >= 0.0 and Wire.point(event.get("pos")) != null

func clear() -> void:
	seen.clear(); order.clear(); lifetimes.clear()
	highest = -1; source_time = -1.0; silence = 0.0; round_over = false
	counters = {"dispatched":0,"duplicates":0,"invalid":0,"suppressed":0}

func advance(dt: float) -> void:
	if is_finite(dt) and dt > 0: silence += dt

func interrupt(actors: Dictionary) -> void:
	for visual: Node in actors.values():
		if is_instance_valid(visual) and visual.has_method("interrupt_world_melee"): visual.interrupt_world_melee()

func observe(state: Dictionary, actors: Dictionary, local_id: int) -> void:
	var time: Variant = state.get("time")
	if not (time is int or time is float) or not is_finite(float(time)) or float(time) < 0:
		source_time = -1.0
		interrupt(actors)
		return
	if source_time >= 0 and float(time) < source_time-0.001:
		interrupt(actors)
		for visual: Node in actors.values():
			if is_instance_valid(visual) and visual.has_method("reset_world_melee_epoch"): visual.reset_world_melee_epoch()
		clear() # An explicit source-clock rewind establishes a new playback epoch.
	source_time = float(time)
	silence = 0.0
	round_over = state.get("over",false) == true
	var present: Dictionary = {}
	for actor: Dictionary in state.get("actors",[]):
		var id := Wire.identity(actor.get("id"))
		if id < 0: continue
		present[id] = true
		var visual: Node = actors.get(id)
		var eligible: bool = not round_over and id != local_id and is_instance_valid(visual) and visual.has_method("can_accept_world_melee") and visual.can_accept_world_melee()
		var signature := [actor.get("character"),actor.get("deaths"),actor.get("spawnId"),actor.get("respawnCount"),actor.get("vehicleId")]
		var old: Dictionary = lifetimes.get(id,{})
		var floor_time: float = old.get("floor",source_time-MAX_AGE)
		if not old.is_empty() and (not old.present or old.signature != signature or old.eligible != eligible):
			floor_time = source_time
			if is_instance_valid(visual) and visual.has_method("interrupt_world_melee"): visual.interrupt_world_melee()
		lifetimes[id] = {"present":true,"eligible":eligible,"signature":signature,"floor":floor_time}
	for id: int in lifetimes.keys():
		if not present.has(id):
			if lifetimes[id].present: lifetimes[id].floor = source_time
			lifetimes[id].present = false
			lifetimes[id].eligible = false
			if source_time-float(lifetimes[id].floor) > MAX_AGE+MAX_AHEAD+1.0: lifetimes.erase(id)
	if round_over: interrupt(actors)

func consume(items: Array, actors: Dictionary, local_id: int, active: bool = true) -> void:
	if not active: interrupt(actors)
	for value: Variant in items.slice(0,512):
		if not value is Dictionary or value.get("type") != "melee": continue
		var event: Dictionary = value
		var id := Wire.identity(event.get("id"))
		if id < 0:
			counters.invalid += 1
			continue
		if seen.has(id) or id <= highest-EVENT_WINDOW:
			counters.duplicates += 1
			continue
		seen[id] = true # Consume even malformed, hidden, absent or suspended events.
		order.append(id)
		if order.size() > EVENT_WINDOW: seen.erase(order.pop_front())
		if not valid(event):
			counters.invalid += 1
			continue
		highest = maxi(highest,id)
		var actor_id := Wire.identity(event.actor)
		var visual: Node = actors.get(actor_id)
		var life: Dictionary = lifetimes.get(actor_id,{})
		var age := source_time-float(event.time)
		var allowed := active and not round_over and source_time >= 0 and silence <= 0.5 and age <= MAX_AGE and age >= -MAX_AHEAD and actor_id != local_id and not life.is_empty()
		if allowed: allowed = life.present and life.eligible and float(event.time) >= float(life.floor)-0.001 and is_instance_valid(visual) and visual.has_method("can_accept_world_melee") and visual.can_accept_world_melee()
		if not allowed:
			counters.suppressed += 1
			if is_instance_valid(visual) and visual.has_method("interrupt_world_melee"): visual.interrupt_world_melee()
			continue
		if visual.accept_world_melee(event): counters.dispatched += 1
