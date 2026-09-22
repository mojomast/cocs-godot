extends Node3D
## Passive authoritative actor FX. Positions are source-space feet, Y-up.
## Owns no gameplay nodes, writes no actor state, and sends no network input.
const Factory = preload("res://shader_lab/factory.gd")
const Interference = preload("res://combat_shields/interference.gdshader")
const MAX_ACTORS := 32
const MAX_OBSERVATIONS := 256 # CPU history is independent of the shell budget.
const MAX_BURSTS := 16
const EVENT_WINDOW := 2048
const MAX_PENDING := 64
const STALE_SECONDS := 1.0
var factory = Factory.new() # Optional dedicated factory injection before configure().
var camera: Camera3D
var actor_visuals: Dictionary = {} # Optional read-only presentation anchors.
var quality := 1
var tracks: Dictionary = {}
var slots: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var pending: Array[Dictionary] = []
var seen: Dictionary = {}
var highest_event := -1
var clock := 0.0
var last_state := -10.0
var source_time := -1.0
var map_id := ""
var local_actor_id := -1
var suspended := false
var finished := false
var counters := {"events": 0, "ripples": 0, "shatters": 0, "phase": 0, "recovery": 0, "dash": 0, "dropped": 0}
var sphere: SphereMesh
var ring: TorusMesh

static func number(value: Variant, fallback: float = 0.0) -> float:
	return float(value) if Factory.finite_number(value) else fallback

static func wire_id(value: Variant) -> bool:
	return Factory.finite_number(value) and float(value) >= 0.0 and float(value) <= 9007199254740991.0 and floorf(float(value)) == float(value)

static func point(value: Variant) -> Variant:
	if not value is Dictionary: return null
	for key in ["x", "y", "z"]:
		if not Factory.finite_number(value.get(key)) or absf(float(value[key])) > 10000.0: return null
	return Vector3(value.x, value.y, value.z)

static func protection_kind(actor: Dictionary) -> String:
	if number(actor.get("protection")) > 0.0: return "spawn protection"
	if number(actor.get("temporaryShield")) > 0.0: return "temporary shield"
	if number(actor.get("juggernautShield")) > 0.0: return "juggernaut shield"
	var verb: Variant = actor.get("verbState")
	if verb is Dictionary and verb.get("verb") == "alignment-review" and verb.get("active") == true and number(verb.get("pool")) > 0.0 and number(verb.get("poolIn")) > 0.0: return "alignment absorb pool"
	var npc: Variant = actor.get("npcShield")
	if npc is Dictionary and number(npc.get("reduction"), 0.7) > 0.0: return "directional damage reduction"
	if number(actor.get("armor")) > 0.0: return "armor energy"
	return ""

func configure(view_camera: Camera3D) -> void:
	camera = view_camera
	if sphere == null:
		sphere = SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		ring = TorusMesh.new()
		ring.inner_radius = 0.91
		ring.outer_radius = 1.0
	set_quality(quality)

func bind_actor_visuals(visuals: Dictionary) -> void:
	# Keep the presentation's dictionary by reference so additions/removals follow
	# automatically. Its nodes are read only; source snapshots still gate all FX.
	actor_visuals = visuals

func set_quality(level: Variant) -> void:
	quality = 0 if level in [0, "low"] else 1
	if sphere != null:
		sphere.radial_segments = 24 if quality == 0 else 48
		sphere.rings = 12 if quality == 0 else 24
		ring.rings = 24 if quality == 0 else 48
		ring.ring_segments = 6
	# Shrinking actually releases nodes and factory registrations immediately.
	while slots.size() > actor_limit():
		var slot: Dictionary = slots.pop_back()
		if tracks.has(slot.owner): tracks[slot.owner].slot = {}
		_destroy_slot(slot)
	while bursts.size() > burst_limit(): _destroy_slot(bursts.pop_back())
	for slot: Dictionary in slots + bursts:
		slot.material.set_shader_parameter("low_quality", quality == 0)
	_render()

func actor_limit() -> int: return 16 if quality == 0 else MAX_ACTORS
func burst_limit() -> int: return 8 if quality == 0 else MAX_BURSTS

func _make_slot() -> Dictionary:
	if sphere == null: configure(camera)
	var material: ShaderMaterial = factory.create_material("shield", {"opacity": 0.32, "intensity": 0.85, "normal_strength": 0.12})
	if material == null: return {}
	material.shader = Interference
	material.set_shader_parameter("low_quality", quality == 0)
	var node := MeshInstance3D.new()
	node.mesh = sphere
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return {"node": node, "material": material, "owner": -1, "until": -1.0, "start": 0.0, "origin": Vector3.ZERO, "scale": Vector3.ONE, "style": 0.0}

func _destroy_slot(slot: Dictionary) -> void:
	factory.release(slot.material)
	slot.node.free()

func _clear_visuals() -> void:
	tracks.clear()
	pending.clear()
	for slot: Dictionary in slots + bursts:
		slot.owner = -1
		slot.until = -1.0
		slot.node.visible = false

func reset() -> void:
	_clear_visuals()
	for slot: Dictionary in slots + bursts: _destroy_slot(slot)
	slots.clear()
	bursts.clear()
	seen.clear()
	highest_event = -1
	clock = 0.0
	last_state = -10.0
	source_time = -1.0
	map_id = ""
	finished = false
	local_actor_id = -1
	for key in counters: counters[key] = 0

func _exit_tree() -> void: reset()

func set_suspended(value: bool) -> void:
	suspended = value
	_clear_visuals()
	last_state = -10.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: set_suspended(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: set_suspended(false)

func _claim(id: int) -> Dictionary:
	for slot: Dictionary in slots:
		if slot.owner == -1:
			slot.owner = id
			return slot
	if slots.size() >= actor_limit(): return {}
	var slot := _make_slot()
	if not slot.is_empty():
		slot.owner = id
		slots.append(slot)
	return slot

func _unassign(id: int) -> void:
	var slot: Dictionary = tracks[id].slot
	if not slot.is_empty():
		slot.owner = -1
		slot.node.visible = false
	tracks[id].slot = {}

func _release(id: int) -> void:
	_unassign(id)
	tracks.erase(id)
	for burst: Dictionary in bursts:
		if burst.owner == id:
			burst.until = -1.0
			burst.node.visible = false

func _priority(id: int, kind: String, pos: Vector3, alive: bool, seated: bool) -> Dictionary:
	var visual: Variant = actor_visuals.get(id)
	var visible_actor := true
	if is_instance_valid(visual) and visual is Node3D:
		pos = to_local(visual.global_position)
		visible_actor = visual.is_visible_in_tree()
	var eligible := alive and not seated and id != local_actor_id and not kind.is_empty() and visible_actor and not _near_camera(pos)
	var distance := 0.0
	var on_screen := true
	if is_instance_valid(camera):
		var world_position := to_global(pos)
		distance = camera.global_position.distance_squared_to(world_position)
		eligible = eligible and not camera.is_position_behind(world_position)
		on_screen = camera.is_position_in_frustum(world_position)
	return {"id":id, "position":pos, "eligible":eligible, "rank":(1 if kind == "armor energy" else 0) if eligible else 2, "on_screen":on_screen, "distance":distance}

static func _priority_before(a: Dictionary, b: Dictionary) -> bool:
	if a.rank != b.rank: return a.rank < b.rank
	if a.on_screen != b.on_screen: return a.on_screen
	if a.distance != b.distance: return a.distance < b.distance
	return a.id < b.id

func apply_state(state: Dictionary, local_id: int) -> void:
	if state.get("over") == true:
		_clear_visuals()
		finished = true
		return
	if suspended or finished: return
	var actors: Variant = state.get("actors")
	if not actors is Array: return
	var next_time := number(state.get("time"), source_time)
	var next_map := str(state.get("mapId", map_id))
	if (source_time >= 0.0 and next_time < source_time - 0.001) or (not map_id.is_empty() and next_map != map_id): reset()
	source_time = next_time
	map_id = next_map
	local_actor_id = local_id
	last_state = clock
	if sphere == null: configure(camera)
	var present := {}
	var observations: Array[Dictionary] = []
	# Sort a private list of references, never the authoritative actor array. CPU
	# history has a separate generous bound; no mesh is needed to observe changes.
	for actor: Variant in actors:
		if not actor is Dictionary or not wire_id(actor.get("id")): continue
		var pos: Variant = point(actor)
		if pos == null: continue
		var id := int(actor.id)
		if present.has(id): continue
		present[id] = true
		var height := clampf(number(actor.get("baseHeight"), 1.8), 0.8, 4.0)
		var alive := number(actor.get("health")) > 0.0 and number(actor.get("dead")) <= 0.0
		var candidate := _priority(id, protection_kind(actor), pos + Vector3.UP * height * 0.5, alive, actor.get("vehicleId") != null)
		candidate.actor = actor
		observations.append(candidate)
	observations.sort_custom(_priority_before)
	present.clear()
	for candidate: Dictionary in observations.slice(0, MAX_OBSERVATIONS):
		var actor: Dictionary = candidate.actor
		var id: int = candidate.id
		present[id] = true
		if not tracks.has(id):
			tracks[id] = {"slot": {}, "alive": false, "observed": false, "armor": 0.0, "previous_armor": 0.0, "health": 0.0, "grounded": false, "last_hit": -10.0, "last_break": -10.0, "last_phase": -10.0, "last_heal": -10.0, "hit_direction":Vector3.FORWARD, "hit_direction_known":false}
		var track: Dictionary = tracks[id]
		var alive := number(actor.get("health")) > 0.0 and number(actor.get("dead")) <= 0.0
		var height := clampf(number(actor.get("baseHeight"), 1.8), 0.8, 4.0)
		var center := Vector3(actor.x, actor.y, actor.z) + Vector3.UP * height * 0.5
		track.position = center
		track.scale = Vector3(height * 0.40, height * 0.61, height * 0.36)
		track.yaw = number(actor.get("yaw"))
		track.kind = protection_kind(actor)
		track.seated = actor.get("vehicleId") != null
		var npc: Variant = actor.get("npcShield")
		track.arc_cos = cos(clampf(number(npc.get("arc"), 0.6), 0.05, PI)) if npc is Dictionary else 0.8
		track.previous_armor = track.armor
		track.armor = maxf(0.0, number(actor.get("armor")))
		if alive and track.observed:
			if not track.alive: _phase(id, track, center)
			elif track.grounded and actor.get("grounded") == false and number(actor.get("vy")) > 1.0:
				_burst(id, center - Vector3.UP * height * 0.4, Vector3(0.65, 0.25, 0.65), 1.0, 0.32, Color("9be7ff"))
			if track.alive and number(actor.get("health")) > track.health + 0.01: _recovery(id, track)
			if track.previous_armor > 0.0 and track.armor <= 0.0 and clock - track.last_hit < 0.4: _shatter(id, track)
		track.health = number(actor.get("health"))
		track.grounded = actor.get("grounded") == true
		track.alive = alive
		track.observed = true
		if not track.slot.is_empty(): _update_slot(track)
	for id: int in tracks.keys():
		if not present.has(id): _release(id)
	_drain_pending()
	_render()

func _update_slot(track: Dictionary) -> void:
	var slot: Dictionary = track.slot
	slot.node.scale = track.scale
	slot.node.rotation.y = track.yaw
	slot.material.set_shader_parameter("style", 0.0)
	slot.material.set_shader_parameter("opacity", 0.12 if track.kind == "armor energy" else 0.43)
	slot.material.set_shader_parameter("accent", Color("ffcf7b") if track.kind in ["armor energy", "juggernaut shield"] else Color("65ecff"))
	slot.material.set_shader_parameter("secondary", Color("a67cff"))
	slot.material.set_shader_parameter("directional", 1.0 if track.kind == "directional damage reduction" else 0.0)
	slot.material.set_shader_parameter("arc_cos", track.arc_cos)

func apply_events(items: Array, local_id: int) -> void:
	local_actor_id = local_id
	for event: Variant in items:
		if not event is Dictionary or not wire_id(event.get("id")): continue
		var id := int(event.id)
		if seen.has(id) or id <= highest_event - EVENT_WINDOW: continue
		highest_event = maxi(highest_event, id)
		seen[id] = true
		for old: int in seen.keys():
			if old <= highest_event - EVENT_WINDOW: seen.erase(old)
		if suspended or finished: continue
		if not wire_id(event.get("actor")): continue
		if not event.get("type") in ["damage", "spawn", "teleport", "dash", "mender-heal", "pickup"]: continue
		counters.events += 1
		if tracks.has(int(event.actor)):
			_event(event)
		elif pending.size() < MAX_PENDING:
			pending.append({"event": event.duplicate(true), "until": clock + 0.75})
		else: counters.dropped += 1
	_render()

func _drain_pending() -> void:
	for index in range(pending.size() - 1, -1, -1):
		var item: Dictionary = pending[index]
		if clock > item.until: pending.remove_at(index)
		elif tracks.has(int(item.event.actor)):
			_event(item.event)
			pending.remove_at(index)

func _event(event: Dictionary) -> void:
	var id := int(event.actor)
	var track: Dictionary = tracks[id]
	if not track.alive: return
	match event.type:
		"damage":
			if number(event.get("amount")) <= 0.0: return
			track.last_hit = clock
			var direction := Vector3.FORWARD
			var direction_known := false
			if wire_id(event.get("source")) and tracks.has(int(event.source)):
				direction = tracks[int(event.source)].position - track.position
				direction_known = direction.length_squared() >= 0.0001
			if direction.length_squared() < 0.0001: direction = Vector3.FORWARD
			track.hit_direction = direction.normalized().rotated(Vector3.UP, -track.yaw)
			track.hit_direction_known = direction_known
			if not track.kind.is_empty() and id != local_actor_id: counters.ripples += 1
			if event.get("shieldBreak") == true or (track.previous_armor > 0.0 and track.armor <= 0.0): _shatter(id, track)
		"spawn": _phase(id, track, track.position)
		"teleport", "dash":
			var from: Variant = point(event.get("from"))
			var to: Variant = point(event.get("to"))
			if from == null or to == null: return
			if from.distance_squared_to(to) < 0.01: return
			if event.type == "teleport":
				_phase(id, track, to)
				_burst(id, from, track.scale, 1.0, 0.55, Color("c28dff"))
			else:
				if id != local_actor_id: counters.dash += 1
				var count := 2 if quality == 0 else 4
				for step in range(count):
					_burst(id, from.lerp(to, float(step) / float(count)), track.scale * 0.8, 1.0, 0.28 + step * 0.035, Color("70dfff"))
		"mender-heal":
			# The actor is the MENDER, healed is a count, not recipient identities.
			if number(event.get("healed")) > 0.0: _recovery(id, track)
		"pickup":
			if event.get("kind") in ["health", "megahealth"]: _recovery(id, track)

func _phase(id: int, track: Dictionary, pos: Vector3) -> void:
	if clock - track.last_phase < 0.3: return
	track.last_phase = clock
	if _burst(id, pos, track.scale, 1.0, 0.65, Color("78e8ff")): counters.phase += 1

func _recovery(id: int, track: Dictionary) -> void:
	if clock - track.last_heal < 0.35: return
	track.last_heal = clock
	if _burst(id, track.position - Vector3.UP * 0.55, Vector3(0.8, 0.8, 0.8), 2.0, 0.75, Color("66ffbd")): counters.recovery += 1

func _shatter(id: int, track: Dictionary) -> void:
	if clock - track.last_break < 0.35: return
	track.last_break = clock
	if _burst(id, track.position, track.scale, 3.0, 0.42, Color("a7edff")): counters.shatters += 1

func _burst(id: int, pos: Vector3, dimensions: Vector3, style: float, duration: float, color: Color) -> bool:
	if id == local_actor_id: return false
	var chosen := {}
	for slot: Dictionary in bursts:
		if slot.until <= clock:
			chosen = slot
			break
	if chosen.is_empty() and bursts.size() < burst_limit():
		chosen = _make_slot()
		if not chosen.is_empty(): bursts.append(chosen)
	if chosen.is_empty():
		counters.dropped += 1
		return false
	chosen.owner = id
	chosen.start = clock
	chosen.until = clock + duration
	chosen.origin = pos
	chosen.scale = dimensions
	chosen.style = style
	chosen.node.mesh = ring if style == 2.0 else sphere
	chosen.node.rotation = Vector3.ZERO
	chosen.material.set_shader_parameter("style", style)
	chosen.material.set_shader_parameter("directional", 0.0)
	chosen.material.set_shader_parameter("hit_age", 2.0)
	chosen.material.set_shader_parameter("accent", color)
	chosen.material.set_shader_parameter("secondary", Color("b28dff") if style != 2.0 else Color("a1ffe4"))
	chosen.material.set_shader_parameter("opacity", 0.5)
	return true

func _near_camera(pos: Vector3) -> bool:
	return is_instance_valid(camera) and camera.global_position.distance_squared_to(to_global(pos)) < 5.0

func _render() -> void:
	var candidates: Array[Dictionary] = []
	for id: int in tracks:
		var track: Dictionary = tracks[id]
		var candidate := _priority(id, track.kind, track.position, track.alive, track.seated)
		if candidate.eligible and not suspended and not finished: candidates.append(candidate)
	candidates.sort_custom(_priority_before)
	var selected := {}
	for candidate: Dictionary in candidates.slice(0, actor_limit()): selected[candidate.id] = candidate
	# Release losers before claiming winners, so array order and last frame's
	# owners cannot starve a newly eligible shield. Keep observation history.
	for id: int in tracks:
		if not selected.has(id): _unassign(id)
	for id: int in selected:
		var track: Dictionary = tracks[id]
		if track.slot.is_empty():
			track.slot = _claim(id)
			if track.slot.is_empty(): continue
			_update_slot(track)
		track.slot.node.position = selected[id].position
		track.slot.node.visible = true
		track.slot.material.set_shader_parameter("hit_age", clampf(clock - track.last_hit, 0.0, 2.0))
		track.slot.material.set_shader_parameter("hit_direction", track.hit_direction)
		track.slot.material.set_shader_parameter("hit_direction_known", track.hit_direction_known)
	for slot: Dictionary in bursts:
		var owner_alive: bool = tracks.has(slot.owner) and tracks[slot.owner].alive and not tracks[slot.owner].seated
		var active: bool = owner_alive and not suspended and not finished and slot.until > clock and slot.owner != local_actor_id and not _near_camera(slot.origin)
		slot.node.visible = active
		if not active: continue
		var progress := clampf((clock - slot.start) / (slot.until - slot.start), 0.0, 1.0)
		slot.node.position = slot.origin + Vector3.UP * progress * (0.9 if slot.style == 2.0 else 0.0)
		slot.node.scale = slot.scale * (1.0 + progress * (0.45 if slot.style == 3.0 else 0.15))
		slot.material.set_shader_parameter("progress", progress)

func _process(delta: float) -> void:
	if suspended or finished or not is_finite(delta) or delta < 0.0: return
	clock += minf(delta, 2.0)
	if last_state >= 0.0 and clock - last_state > STALE_SECONDS: _clear_visuals()
	_drain_pending()
	# Own only our materials: safe even if a caller injects a shared factory.
	for slot: Dictionary in slots + bursts: slot.material.set_shader_parameter("effect_time", fmod(clock, 3600.0))
	_render()

func debug_state() -> Dictionary:
	var visible_shells := 0
	var active_bursts := 0
	var kinds := {}
	for id: int in tracks:
		kinds[id] = tracks[id].kind
		if not tracks[id].slot.is_empty() and tracks[id].slot.node.visible: visible_shells += 1
	for slot: Dictionary in bursts:
		if slot.node.visible: active_bursts += 1
	return {"actors": tracks.size(), "observation_limit":MAX_OBSERVATIONS, "slots": slots.size(), "pool": bursts.size(), "visible_shells": visible_shells, "active_bursts": active_bursts, "materials": slots.size() + bursts.size(), "seen": seen.size(), "pending": pending.size(), "clock": clock, "kinds": kinds, "counters": counters.duplicate(), "quality": quality}
