extends Node3D
## Massive injury fluid + death splatter for the Godot port.
##
## Public API (lead wires this in one call from the session composition):
##
##   const BloodFX = preload("res://blood_fx/controller.gd")
##   var blood_fx := BloodFX.new()
##   add_child(blood_fx)
##   blood_fx.configure(camera, surface_provider)
##   blood_fx.apply_state(state, local_id)
##   blood_fx.apply_events(items, local_id)
##   blood_fx.reset()
##   blood_fx.set_quality("Low" | "High" | "Extreme")
##   blood_fx.snapshot()
##
## Presentation only: it reads authoritative damage/death events and the public
## actor snapshot. It never predicts, invents or re-derives hits, never changes
## damage, and never claims GPU readback. See port/native-blood-fx/README.md.

const Settings = preload("res://blood_fx/settings.gd")
const SurfaceQuery = preload("res://blood_fx/surface_query.gd")
const Wire = preload("res://blood_fx/wire.gd")
const FluidProcess = preload("res://blood_fx/fluid.gdshader")
const FluidDraw = preload("res://blood_fx/fluid_draw.gdshader")
const StainShader = preload("res://blood_fx/stain.gdshader")
const FlowField = preload("res://moth/library.gd")

# Profiles. One pooled GPUParticles3D per live emission; the profile is a shader
# uniform, not a different resource.
const MIST := 0
const JET := 1
const ARTERIAL := 2
const BURST := 3

var settings: Settings = Settings.new()
var surfaces: SurfaceQuery = SurfaceQuery.new()
var camera: Camera3D
var quality: String = Settings.DEFAULT_QUALITY
var budget: int = 24576
var concurrent_cap: int = 14
var stain_cap: int = 80
var map_id := ""
var configured := false
var active := false
var paused := false
var focused := true
var require_public_state := true
var surface_error := ""

var fluid_slots: Array[Dictionary] = []
var stain_slots: Array[Dictionary] = []
var actors: Dictionary = {}
## Wire events can arrive after the snapshot which removes their victim. Keep
## only a short, public-state-derived pose for that reordered delivery.
var departed_actors: Dictionary = {}
var local_id := -1
var clock := 0.0
var last_state_usec := 0
var last_public_time := -1.0
var highest_event := -1
var last_event_id := -1
var last_event_position := Vector3.ZERO
var suspended := true

var spurts := 0
var mist_events := 0
var arterial_hits := 0
var absorbed_mist_events := 0
var death_bursts := 0
var stains_placed := 0
var stains_rejected := 0
var stains_recycled := 0
var duplicates := 0
var rejected := 0
var unknown_actors := 0
var no_bleed := 0
var absorbed_only := 0
var dropped := 0
var recycled := 0
var drains := 0
var events_seen := 0
var marks_wall := 0
var marks_floor := 0
var marks_slope := 0
var marks_skipped_edge := 0
var marks_skipped_facing := 0
var marks_skipped_solid := 0
var marks_skipped_reach := 0
var clusters_placed := 0
var fan_rays_cast := 0
var fan_marks := 0
var impact_marks := 0

var _ids := PackedInt64Array()
var _serial := 0
var _stain_serial := 0
var _suspended := true
var _shared_fluid_mesh: QuadMesh
var _shared_stain_mesh: QuadMesh
var _fluid_shader: Shader
var _draw_shader: Shader
var _stain_shader: Shader
var _flow_texture: Texture2D

func _init() -> void:
	_ids.resize(settings.id_window)
	_ids.fill(-1)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

# --- configuration ------------------------------------------------------------

## surface_provider: Callable(from: Vector3, to: Vector3) -> Dictionary
##                    {hit: bool, position: Vector3, normal: Vector3}
## Accepts a Callable, a semantic-locked-map dictionary, or a collision root
## Node3D, so the composition can wire whichever geometry source it owns.
func configure(view_camera: Camera3D, surface_provider: Variant = null) -> Dictionary:
	if settings == null: settings = Settings.new()
	reset()
	camera = view_camera
	surfaces = SurfaceQuery.build(surface_provider, camera, settings.collision_mask)
	surface_error = str(surfaces.error)
	if fluid_slots.is_empty():
		_build_pools()
	for slot: Dictionary in fluid_slots:
		slot.node.visibility_aabb = AABB(Vector3(-4096, -4096, -4096), Vector3(8192, 8192, 8192))
	set_quality(quality)
	configured = true
	set_process(true)
	_sync_suspension()
	return {"ok": true, "quality": quality, "budget": budget, "fluid_emitters": fluid_slots.size(),
		"stain_pool": stain_slots.size(), "surface_kind": surfaces.kind, "surface_ready": surfaces.ready,
		"surface_error": surface_error, "settings": settings.describe()}


## Rebind only the surface provider (map change) without rebuilding pools.
func bind_surfaces(surface_provider: Variant) -> Dictionary:
	surfaces = SurfaceQuery.build(surface_provider, camera, settings.collision_mask)
	surface_error = str(surfaces.error)
	_clear_stains()
	return {"ok": true, "surface_kind": surfaces.kind, "surface_ready": surfaces.ready, "surface_error": surface_error}


func apply_variant(name: String) -> bool:
	# Mutates the existing settings object in place: any host customisation
	# already applied survives a variant switch.
	if settings == null: settings = Settings.new()
	if not settings.apply_variant(name): return false
	if configured:
		var pool := maxi(1, fluid_slots.size())
		var base := budget / pool
		var remainder := budget % pool
		for i in fluid_slots.size():
			fluid_slots[i].node.amount = base + (1 if i < remainder else 0)
		_apply_material_colors()
	return true


func _build_pools() -> void:
	_fluid_shader = FluidProcess
	_draw_shader = FluidDraw
	_stain_shader = StainShader
	_shared_fluid_mesh = QuadMesh.new()
	_shared_fluid_mesh.size = Vector2.ONE
	_shared_stain_mesh = QuadMesh.new()
	_shared_stain_mesh.size = Vector2.ONE
	_flow_texture = FlowField.texture("flow-field")
	for i in settings.fluid_emitters:
		var material := ShaderMaterial.new()
		material.shader = _fluid_shader
		material.set_shader_parameter("up_axis", Vector3.UP)
		material.set_shader_parameter("tint", settings.fluid_color)
		var draw := ShaderMaterial.new()
		draw.shader = _draw_shader
		draw.set_shader_parameter("flow_field", _flow_texture)
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE
		mesh.material = draw
		var node := GPUParticles3D.new()
		node.name = "BloodFluid%02d" % i
		node.top_level = true
		node.emitting = false
		node.visible = false
		node.amount = 1
		node.amount_ratio = 1.0
		node.lifetime = 4.0
		node.explosiveness = 1.0
		node.fixed_fps = 0
		node.interpolate = false
		node.fract_delta = false
		node.local_coords = false
		node.use_fixed_seed = true
		node.seed = 90210 + i
		node.speed_scale = 0.0
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.draw_order = GPUParticles3D.DRAW_ORDER_INDEX
		node.draw_pass_1 = mesh
		node.process_material = material
		node.visibility_aabb = AABB(Vector3(-4096, -4096, -4096), Vector3(8192, 8192, 8192))
		add_child(node)
		fluid_slots.append({"node": node, "material": material, "draw": draw, "remaining": 0.0, "age": 0.0,
			"serial": 0, "priority": 0.0, "profile": -1, "ratio": 0.0, "position": Vector3.ZERO})
	for i in settings.stain_pool:
		var material := ShaderMaterial.new()
		material.shader = _stain_shader
		material.set_shader_parameter("fluid_color", settings.fluid_color)
		var node := MeshInstance3D.new()
		node.name = "BloodStain%03d" % i
		node.mesh = _shared_stain_mesh
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 0.0
		node.visible = false
		add_child(node)
		stain_slots.append({"node": node, "material": material, "remaining": 0.0, "total": 0.0, "age": 0.0,
			"delay": 0.0, "fade": 0.0, "growth": 0.0, "opacity": 0.0, "serial": 0, "surface": -1,
			"scale_base": Vector3.ONE, "grow_from": Vector3.ONE})


func _apply_material_colors() -> void:
	for slot: Dictionary in fluid_slots:
		var material: ShaderMaterial = slot.material
		material.set_shader_parameter("tint", settings.fluid_color)
	for slot: Dictionary in stain_slots:
		var material: ShaderMaterial = slot.material
		material.set_shader_parameter("fluid_color", settings.fluid_color)

# --- quality, pause, lifecycle -----------------------------------------------

func set_quality(level: Variant) -> bool:
	if not level is String or level not in Settings.QUALITY: return false
	quality = level
	budget = settings.budget(quality)
	concurrent_cap = settings.cap(quality)
	stain_cap = settings.stains(quality)
	var pool := maxi(1, fluid_slots.size())
	var base := budget / pool
	var remainder := budget % pool
	for i in fluid_slots.size():
		var slot: Dictionary = fluid_slots[i]
		# The remainder is spread over the first emitters so the total allocation
		# is exactly the documented budget at every quality level.
		slot.node.amount = base + (1 if i < remainder else 0)
		if slot.remaining > 0.0: slot.node.restart(true)
	_sync_suspension()
	return true


func set_paused(value: bool) -> void:
	paused = value
	_sync_suspension()


func set_active(value: bool, public_watchdog: bool = true) -> void:
	active = value and configured
	require_public_state = public_watchdog
	last_state_usec = Time.get_ticks_usec()
	_sync_suspension()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
		# Focus loss drains instead of freezing: returning to the window must
		# never replay a held burst or leave a stale wound emitting.
		drain()
		_sync_suspension()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true
		_sync_suspension()
	elif what == NOTIFICATION_EXIT_TREE:
		drain()


func _sync_suspension() -> void:
	var tree_paused := is_inside_tree() and get_tree().paused
	var hidden := is_inside_tree() and not is_visible_in_tree()
	_suspended = not active or paused or not focused or tree_paused or hidden
	for slot: Dictionary in fluid_slots:
		slot.node.speed_scale = 0.0 if _suspended else 1.0
		slot.node.visible = (not _suspended) and slot.remaining > 0.0

## Soft drain: stop every visual but keep the wire dedup window and the public
## clock, so a drained event can never replay when focus/freshness returns.
func drain() -> void:
	drains += 1
	for slot: Dictionary in fluid_slots:
		slot.remaining = 0.0
		slot.profile = -1
		slot.ratio = 0.0
		slot.node.emitting = false
		slot.node.speed_scale = 0.0
		slot.node.hide()
	_clear_stains()
	_sync_suspension()


## Round boundary: results, restart, disconnect or a map replacement. Clears the
## wire window too, because a new round may reuse authoritative event IDs.
func reset() -> void:
	active = false
	clock = 0.0
	last_public_time = -1.0
	highest_event = -1
	last_event_id = -1
	_ids.fill(-1)
	actors.clear()
	departed_actors.clear()
	drain()

func _clear_stains() -> void:
	for slot: Dictionary in stain_slots:
		slot.remaining = 0.0
		slot.total = 0.0
		slot.age = 0.0
		slot.delay = 0.0
		slot.node.hide()

# --- authoritative input ------------------------------------------------------

func apply_state(state: Dictionary, local_actor_id: int = -1) -> void:
	if not configured: return
	if state.get("over", false):
		reset()
		return
	var now := Time.get_ticks_usec()
	var public_time: Variant = state.get("time")
	if Wire.numeric(public_time) and is_finite(float(public_time)):
		if last_public_time >= 0.0 and float(public_time) < last_public_time: reset()
		last_public_time = float(public_time)
	var next_map := str(state.get("mapId", ""))
	if next_map.is_empty() and state.get("config") is Dictionary:
		next_map = str(state.config.get("mapId", ""))
	if not map_id.is_empty() and not next_map.is_empty() and next_map != map_id:
		# Pools belong to the previous geometry: never leave a stain from map A
		# sitting inside map B. The host re-binds surfaces for the new map.
		reset()
		surfaces.ready = false
		surface_error = "Map changed to %s; host must re-bind the surface provider" % next_map
	if not next_map.is_empty(): map_id = next_map
	local_id = local_actor_id
	_ingest_actors(state.get("actors", []))
	last_state_usec = now
	if not active: set_active(true)
	_sync_suspension()


func _ingest_actors(values: Variant) -> void:
	if not values is Array: return
	var seen := {}
	for index in mini(values.size(), 512):
		var value: Variant = values[index]
		if not value is Dictionary: continue
		var actor: Dictionary = value
		var id := Wire.identity(actor.get("id"))
		if id < 0: continue
		seen[id] = true
		var entry: Dictionary = actors.get(id, {})
		# health_prev stays unknown until a second snapshot proves a real drop.
		entry.health_prev = entry.get("health", -1.0)
		entry.health = Wire.number(actor.get("health"), -1.0)
		entry.max_health = Wire.number(actor.get("maxHealth"), entry.get("max_health", entry.health))
		entry.x = Wire.number(actor.get("x"))
		entry.y = Wire.number(actor.get("y"))
		entry.z = Wire.number(actor.get("z"))
		entry.vx = Wire.number(actor.get("vx"))
		entry.vy = Wire.number(actor.get("vy"))
		entry.vz = Wire.number(actor.get("vz"))
		entry.armor = Wire.number(actor.get("armor"))
		entry.temporary_shield = Wire.number(actor.get("temporaryShield"))
		entry.juggernaut_shield = Wire.number(actor.get("juggernautShield"))
		entry.vehicle = actor.get("vehicleId")
		actors[id] = entry
	for id: int in actors.keys():
		if not seen.has(id):
			var old: Dictionary = actors[id]
			old["departure_time"] = last_public_time
			departed_actors[id] = old
			actors.erase(id)
	for id: int in departed_actors.keys():
		if seen.has(id) or last_public_time < 0.0 or last_public_time - float(departed_actors[id].departure_time) > 0.75:
			departed_actors.erase(id)


func apply_events(items: Array, local_actor_id: int = -1) -> void:
	if not configured: return
	if local_actor_id >= 0: local_id = local_actor_id
	for index in mini(items.size(), settings.events_per_callback):
		var value: Variant = items[index]
		if not value is Dictionary: continue
		var event: Dictionary = value
		var type := str(event.get("type", ""))
		# Horde's authoritative sapper detonation sets health to zero directly
		# and emits enemy-detonate, not a separate death event.
		if type != "damage" and type != "death" and type != "enemy-detonate": continue
		events_seen += 1
		var id := Wire.identity(event.get("id"))
		if id < 0:
			rejected += 1
			continue
		if id <= highest_event - settings.id_window or _ids[id % settings.id_window] == id:
			duplicates += 1
			continue
		# The ID is recorded even while drained or suspended, so an already
		# delivered event can never produce a second spurt after a focus return.
		_ids[id % settings.id_window] = id
		highest_event = maxi(highest_event, id)
		if _suspended or not active: continue
		if type == "damage": _damage_event(event, id)
		else: _death_event(event, id)

# --- damage: directional spurts ----------------------------------------------

func _damage_event(event: Dictionary, id: int) -> void:
	var victim := Wire.identity(event.get("actor"))
	if victim < 0:
		rejected += 1
		return
	var amount := Wire.number(event.get("amount"), -1.0)
	if amount <= 0.0:
		no_bleed += 1
		return
	var shield := maxf(0.0, Wire.number(event.get("shield"), 0.0))
	# `amount` includes every absorbed stage, so amount - shield is the wire
	# health-damage bound. It is refined below with observed snapshot health so
	# an armour-only hit at full health never bleeds.
	var wire_damage := amount - shield
	if wire_damage <= 0.0:
		no_bleed += 1
		return
	var actor: Dictionary = actors.get(victim, {})
	if actor.is_empty() and departed_actors.has(victim) and Wire.numeric(event.get("time")):
		var previous: Dictionary = departed_actors[victim]
		if absf(float(event.time) - float(previous.departure_time)) <= 0.75: actor = previous
	if actor.is_empty():
		unknown_actors += 1
		return
	# The last hit is valid when a snapshot already shows the health bar falling
	# through zero; it is not valid against an actor known dead beforehand.
	if float(actor.get("health", 0.0)) <= 0.0 and float(actor.get("health_prev", -1.0)) <= 0.0:
		no_bleed += 1
		return
	var real := _real_damage(actor, wire_damage)
	if real <= 0.0:
		absorbed_only += 1
		# Owner art direction: every hit reads as a hit. Absorbed damage emits a light
		# entry mist and nothing else: never an arterial puff, never a spurt and never
		# surface staining. `absorbed_mist_strength = 0` disables it entirely.
		if settings.absorbed_mist_strength > 0.0:
			var absorbed_position := _actor_point(actor)
			var absorbed_direction := _shot_direction(actor, Wire.identity(event.get("source")), victim, id)
			var absorbed_entry := absorbed_position - absorbed_direction * settings.wound_offset
			_emit(MIST, absorbed_entry, -absorbed_direction, settings.absorbed_mist_strength, victim == local_id,
				float(posmod(id, 100000)), 1.0, _reach(absorbed_entry, -absorbed_direction, 1.6))
			absorbed_mist_events += 1
			last_event_id = id
			last_event_position = absorbed_position
		return
	var position := _actor_point(actor)
	var source := Wire.identity(event.get("source"))
	var direction := _shot_direction(actor, source, victim, id)
	var local := victim == local_id
	var strength := clampf(real / maxf(1.0, settings.full_reference), settings.min_strength, 1.0)
	var lethal := real >= float(actor.get("health", 0.0))
	var entry := position - direction * settings.wound_offset
	var exit := position + direction * settings.wound_offset
	var seed := float(posmod(id, 100000))
	var profile := MIST
	if lethal or real >= settings.arterial_min:
		profile = ARTERIAL
	elif real > settings.mist_max:
		profile = JET
	# The entry wound always mists; the exit side carries the jet.
	_emit(MIST, entry, -direction, strength * 0.85, local, seed, 1.0, _reach(entry, -direction, 1.6))
	if profile == MIST:
		mist_events += 1
		last_event_id = id
		last_event_position = position
		return
	var reach := _reach(exit, direction, settings.spurt_stain_reach + 1.6)
	_emit(profile, exit, direction, strength, local, seed + 7.0, 1.0, reach)
	spurts += 1
	if profile == ARTERIAL: arterial_hits += 1
	if not reach.is_empty() and float(reach.get("distance", 99.0)) <= settings.spurt_stain_reach:
		_impact_cluster(exit, direction, reach, strength, seed)
	last_event_id = id
	last_event_position = position


## Real health damage. The wire bound is `amount - shield`; when the public
## snapshot proves the health bar did not move and the victim still carries
## armour/overshield, the hit was absorbed and no fluid is emitted.
func _real_damage(actor: Dictionary, wire_damage: float) -> float:
	var previous := float(actor.get("health_prev", -1.0))
	var current := float(actor.get("health", -1.0))
	if previous < 0.0 or current < 0.0: return wire_damage
	var drop := previous - current
	if drop <= 0.0:
		if float(actor.get("armor", 0.0)) > 0.0 or float(actor.get("temporary_shield", 0.0)) > 0.0 \
			or float(actor.get("juggernaut_shield", 0.0)) > 0.0:
			return 0.0
		return wire_damage
	return minf(wire_damage, drop)


func _shot_direction(actor: Dictionary, source: int, victim: int, id: int) -> Vector3:
	if source >= 0 and source != victim and actors.has(source):
		var delta := _actor_point(actor) - _actor_point(actors[source])
		if delta.length_squared() > 0.0004: return delta.normalized()
	var velocity := Vector3(float(actor.get("vx", 0.0)), 0.0, float(actor.get("vz", 0.0)))
	if velocity.length_squared() > 0.09: return velocity.normalized()
	# No authoritative source direction (environmental damage): a deterministic
	# fluid axis is presentation only and never claims an attacker.
	return Wire.fallback_direction(id)


func _actor_point(actor: Dictionary) -> Vector3:
	return Vector3(float(actor.get("x", 0.0)), float(actor.get("y", 0.0)) + settings.body_centre, float(actor.get("z", 0.0)))

# --- death: dense burst + surface staining ------------------------------------

func _death_event(event: Dictionary, id: int) -> void:
	var victim := Wire.identity(event.get("actor"))
	if victim < 0:
		rejected += 1
		return
	var actor: Dictionary = actors.get(victim, {})
	var fallback: Variant = _actor_point(actor) if not actor.is_empty() else null
	var event_point: Variant = Wire.point(event.get("pos"))
	var position: Vector3
	if event_point != null: position = event_point
	elif fallback != null: position = fallback
	else:
		rejected += 1
		return
	var local := victim == local_id
	var shot: Variant = Wire.point(event.get("direction"))
	var biased := shot != null
	var direction := _death_direction(actor, event, id)
	var seed := Wire.number(event.get("seed"), float(posmod(id, 100000)))
	var overkill := maxf(0.0, Wire.number(event.get("overkill"), 0.0))
	var strength := clampf(1.0 + overkill / maxf(1.0, settings.full_reference) * 0.5, 1.0, 1.6)
	var origin := position
	if local and is_instance_valid(camera) and camera.is_inside_tree():
		# The eye is inside the splatter. Move the dense core behind the camera
		# and below eye height, on top of the coverage cap in _emit().
		var back := camera.global_transform.basis.z.normalized()
		origin += back * settings.local_death_offset + Vector3.DOWN * settings.local_death_offset * 0.5
	var reach := _reach(origin, direction, 6.0)
	var down := _reach(origin + Vector3.UP * 0.4, Vector3.DOWN, settings.stain_depth)
	if not down.is_empty() and (reach.is_empty() or float(down.distance) < float(reach.distance)): reach = down
	_emit(BURST, origin, direction, strength, local, seed, 1.0, reach)
	_splatter(position, direction, biased, strength, seed)
	death_bursts += 1
	last_event_id = id
	last_event_position = position


func _death_direction(actor: Dictionary, event: Dictionary, id: int) -> Vector3:
	var provided: Variant = Wire.point(event.get("direction"))
	if provided != null:
		var value: Vector3 = provided
		if value.length_squared() > 0.0004: return value.normalized()
	if not actor.is_empty():
		var velocity := Vector3(float(actor.get("vx", 0.0)), 0.0, float(actor.get("vz", 0.0)))
		if velocity.length_squared() > 0.09: return velocity.normalized()
	return Wire.fallback_direction(id)


func _splatter(position: Vector3, direction: Vector3, biased: bool, strength: float, seed: float) -> void:
	var drips := settings.death_drip_count(quality)
	# 1) The surface actually below the death point. A ramp, a deck or mid-air
	#    over the void all answer with a real query result or no stain at all.
	var down := _reach(position + Vector3.UP * 0.35, Vector3.DOWN, settings.stain_depth)
	var pool_hit := not down.is_empty()
	if pool_hit:
		var pool_size := settings.pool_size * (0.6 + 0.4 * strength)
		_place_stain(position, pool_size, down, seed, 0.0, 1.0 + 1.4 * (1.0 - absf(float(down.normal.y))),
			Vector3.ZERO, SHAPE_POOL)
	# 2) Bounded radial fan: vertical surfaces get spatter too, biased toward the
	#    lethal shot direction when the event carries one.
	var budget := settings.death_mark_count(quality)
	budget -= (1 if pool_hit else 0)
	_radial_fan(position, direction, biased, strength, seed, maxi(0, budget))
	# 3) Short-lived drips near the primary pool, delayed so they appear after
	#    the burst lands. Bounded by the quality table.
	if not pool_hit: return
	var pool_position: Vector3 = down.position
	var pool_normal: Vector3 = down.normal
	for k in drips:
		var angle := seed * 0.031 + float(k) * 2.399963
		var offset := Vector3(sin(angle), 0.0, cos(angle)) * (0.22 + 0.16 * float(k))
		var probe := pool_position + pool_normal * 0.04 + offset + Vector3.UP * 0.25
		var drip := _reach(probe, Vector3.DOWN, settings.stain_depth * 0.5)
		if drip.is_empty(): continue
		var vertical := 1.0 - absf(float(drip.normal.y))
		_place_stain(probe, settings.drip_size, drip, seed + 31.0 * float(k + 1),
			0.18 + 0.22 * float(k), 1.0 + 1.6 * vertical, Vector3.ZERO, SHAPE_DRIP)


## Bounded radial fan from the body. Rays are spread over the full circle but
## compressed toward the lethal azimuth (`fan_bias_pull`) and each ray is cast at
## the configured pitch bands, so walls, low walls, the floor below and (for the
## biased half) the ceiling are all sampled. Every candidate surface must face the
## body and be reachable from it, and each hit grows a small cluster of marks.
func _radial_fan(position: Vector3, direction: Vector3, biased: bool, strength: float,
		seed: float, budget: int) -> void:
	if budget <= 0 or not surfaces.ready: return
	var rays := settings.fan_ray_count(quality)
	var lethal_yaw := atan2(direction.x, direction.z)
	var spin := seed * 0.017
	var casts := 0
	var cast_budget := settings.fan_budget(quality)
	var placed := 0
	# Cast the rays nearest the lethal azimuth first and spread outward, so the
	# mark budget always buys the surface the burst was aimed at.
	for i: int in _fan_order(rays):
		if placed >= budget or casts >= cast_budget: break
		var u := (float(i) + 0.5) / float(rays) * 2.0 - 1.0
		var yaw := spin + TAU * (float(i) + 0.5) / float(rays)
		var weight := 1.0
		if biased:
			var offset := signf(u) * pow(absf(u), 1.0 + settings.fan_bias_pull) * PI
			yaw = lethal_yaw + offset
			weight = clampf(1.0 - 0.55 * absf(offset) / PI, 0.35, 1.0)
		for band_value: Variant in settings.fan_bands:
			if casts >= cast_budget or placed >= budget: break
			var band := float(band_value)
			if band > 0.3 and biased and absf(u) > 0.36: continue
			casts += 1
			fan_rays_cast += 1
			var cos_pitch := cos(band)
			var cast := Vector3(sin(yaw) * cos_pitch, sin(band), cos(yaw) * cos_pitch)
			var hit := _reach(position, cast, settings.fan_reach)
			if hit.is_empty():
				marks_skipped_reach += 1
				continue
			if not _faces_body(position, hit):
				marks_skipped_facing += 1
				continue
			placed += _cluster(position, hit, weight, strength, seed + float(i) * 7.31 + band * 13.0,
				settings.death_cluster_count(quality), budget - placed)


## Ray order for the radial fan: middle (lethal-biased) index first, then
## alternating outward. Deterministic and allocation-light.
static func _fan_order(rays: int) -> Array:
	var order: Array = []
	if rays <= 0: return order
	var middle := rays / 2
	order.append(middle)
	var span := 1
	while order.size() < rays:
		var right := middle + span
		var left := middle - span
		if right < rays: order.append(right)
		if order.size() >= rays: break
		if left >= 0: order.append(left)
		span += 1
	return order


## A surface may only be marked when it faces the body: a normal pointing away
## means the burst would have to pass through the surface to mark it.
func _faces_body(origin: Vector3, hit: Dictionary) -> bool:
	var position: Vector3 = hit.position
	var toward := origin - position
	if toward.length_squared() < 0.0004: return true
	var normal: Vector3 = hit.normal
	return normal.dot(toward.normalized()) > settings.fan_facing_min


## Small cluster on one surface. Marks are tighter near the impact point, sparser
## outward, and streak along the incoming direction projected into the plane.
## Returns the number of marks actually placed (bounded by `budget`).
func _cluster(origin: Vector3, hit: Dictionary, weight: float, strength: float, seed: float,
		marks: int, budget: int) -> int:
	var position: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var axis: Vector3 = position - origin
	var basis := _stain_basis(normal, seed, axis, SHAPE_STREAK)
	var spread := settings.wall_mark_spread * (0.45 + 0.75 * weight) * (0.6 + 0.5 * strength)
	var vertical := absf(normal.y)
	clusters_placed += 1
	var placed := 0
	for k in marks:
		if placed >= budget: break
		var t := 0.0
		if marks > 1: t = float(k) / float(marks - 1)
		var angle := seed * 1.7 + float(k) * 2.399963
		var radius := spread * sqrt(t) * (0.55 + 0.65 * absf(sin(seed + float(k) * 3.1)))
		var offset := (basis.x * cos(angle) + basis.y * sin(angle)) * radius
		var size := settings.wall_mark_size * weight * (1.0 - 0.6 * t) * (0.7 + 0.4 * strength) * (0.75 + 0.5 * absf(sin(seed * 0.7 + float(k) * 4.3)))
		var elongation := 1.0 + (settings.wall_mark_elongation - 1.0) * (0.35 + 0.65 * t)
		if _place_stain(origin, size, _plane_hit(position + offset, normal, float(hit.distance)),
				seed + float(k) * 11.7, 0.0, elongation, axis, SHAPE_STREAK):
			fan_marks += 1
			placed += 1
	# Optional short drip tails running down a vertical surface below the cluster.
	var tails := settings.wall_drip_count(quality)
	if tails <= 0 or vertical > 0.5: return placed
	var down := Vector3.DOWN - normal * Vector3.DOWN.dot(normal)
	if down.length_squared() < 0.04: return placed
	down = down.normalized()
	for k in tails:
		if placed >= budget: break
		var tail := position + down * (settings.wall_mark_size * (0.7 + 0.9 * float(k)))
		if _place_stain(origin, settings.drip_size * 0.8, _plane_hit(tail, normal, float(hit.distance)),
				seed + 47.0 + float(k) * 9.0, 0.25 + 0.2 * float(k), 1.9, Vector3.ZERO, SHAPE_DRIP):
			fan_marks += 1
			placed += 1
	return placed


## Impact spatter when a spurting jet visibly reaches a surface: a cluster of
## marks, tight at the impact point and stretched along the jet direction, with
## optional drip tails on vertical surfaces. Bounded per event.
func _impact_cluster(origin: Vector3, direction: Vector3, hit: Dictionary, strength: float, seed: float) -> void:
	var marks := mini(settings.spurt_mark_count(quality), settings.spurt_mark_budget)
	var position: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var axis := direction if direction.length_squared() > 0.0004 else (position - origin)
	var basis := _stain_basis(normal, seed, axis, SHAPE_STREAK)
	var spread := settings.spurt_spread * (0.4 + 0.6 * strength)
	var vertical := absf(normal.y)
	clusters_placed += 1
	for k in marks:
		var t := sqrt(float(k) / maxf(1.0, float(marks)))
		var angle := seed * 2.1 + float(k) * 2.399963
		var radius := spread * t * (0.6 + 0.7 * absf(cos(seed * 1.3 + float(k) * 2.7)))
		var offset := (basis.x * cos(angle) + basis.y * sin(angle)) * radius
		var size := settings.spurt_stain_size * (0.5 + 0.5 * strength) * (1.0 - 0.6 * t) * (0.75 + 0.5 * absf(cos(seed * 0.9 + float(k) * 2.3)))
		var elongation := 1.0 + (settings.spurt_elongation - 1.0) * (0.3 + 0.7 * t)
		if _place_stain(origin, size, _plane_hit(position + offset, normal, float(hit.distance)),
				seed + float(k) * 13.3, 0.0, elongation, axis, SHAPE_STREAK):
			impact_marks += 1
	var tails := settings.spurt_drip_count(quality)
	if tails <= 0 or vertical > 0.5: return
	var down := Vector3.DOWN - normal * Vector3.DOWN.dot(normal)
	if down.length_squared() < 0.04: return
	down = down.normalized()
	for k in tails:
		var tail := position + down * (settings.spurt_stain_size * 0.9 * (0.8 + 0.9 * float(k)))
		if _place_stain(origin, settings.drip_size * 0.7, _plane_hit(tail, normal, float(hit.distance)),
				seed + 61.0 + float(k) * 7.0, 0.22 + 0.18 * float(k), 1.8, Vector3.ZERO, SHAPE_DRIP):
			impact_marks += 1

# --- fluid emitters ----------------------------------------------------------

func _emit(profile: int, position: Vector3, direction: Vector3, strength: float, local: bool,
		seed: float, life_scale: float, reach: Dictionary) -> void:
	var axis := direction
	if axis.length_squared() < 0.000001: axis = Vector3.DOWN
	axis = axis.normalized()
	var radius := 0.45 * strength * settings.fluid_scale
	var dampen := _coverage_dampen(position, radius, local)
	if dampen <= 0.0:
		dropped += 1
		return
	var priority := _priority(position, local, profile)
	var slot := _acquire_fluid(priority)
	if slot.is_empty(): return
	_serial += 1
	var node: GPUParticles3D = slot.node
	var material: ShaderMaterial = slot.material
	# Droplet size in metres. Thousands of small fast droplets read as a fluid jet;
	# a few giant quads read as fog and blind the player.
	var size := settings.fluid_scale * (0.085 + 0.075 * strength)
	var cone := lerpf(0.55, 0.22, clampf(settings.viscosity, 0.0, 1.0))
	var drag := lerpf(0.8, 2.4, clampf(settings.viscosity, 0.0, 1.0))
	var gravity := 9.8 * settings.gravity_scale
	var speed_min := 0.0
	var speed_max := 0.0
	var life := 0.0
	var stagger := 0.6
	var pulse_count := 1.0
	var pulse_depth := 0.0
	var spawn := 0.06
	var tint: Color = settings.fluid_color
	match profile:
		MIST:
			cone = minf(1.0, cone + 0.5)
			speed_min = settings.mist_speed * 0.35
			speed_max = settings.mist_speed * (0.7 + 0.6 * strength)
			life = settings.mist_life
			stagger = 0.85
			spawn = 0.12
			size *= 0.75
			tint = settings.fluid_color_mist
		JET:
			cone *= 0.85
			speed_min = settings.jet_speed * 0.3 * strength
			speed_max = settings.jet_speed * strength
			life = settings.jet_life
			spawn = 0.07
		ARTERIAL:
			cone *= 0.6
			speed_min = settings.arterial_speed * 0.35 * strength
			speed_max = settings.arterial_speed * strength
			life = settings.jet_life * 1.35
			pulse_count = settings.pulse_count
			pulse_depth = 0.85
			spawn = 0.08
			size *= 1.05
			tint = settings.fluid_color_arterial
		BURST:
			cone = 1.0
			speed_min = settings.burst_speed * 0.25 * strength
			speed_max = settings.burst_speed * strength
			life = settings.burst_life
			stagger = 0.0
			spawn = 0.22
			size *= 1.0
			tint = settings.fluid_color_arterial
	life *= life_scale
	# Bounded reach: keep the fastest droplet inside the first authoritative
	# surface on this axis. Presentation approximation, never a collision change.
	if not reach.is_empty():
		var clear := maxf(0.25, float(reach.distance) * 0.85)
		if profile == BURST:
			# A burst is a sphere, so only its radius is bounded: blood may still
			# fly upward from a floor hit.
			var radius_limit := clampf(clear, 0.9, 5.5)
			speed_max = minf(speed_max, radius_limit / maxf(0.3, life))
		elif speed_max > 0.001:
			life = minf(life, clampf(clear / speed_max, 0.16, life))
	var ratio := clampf(strength, settings.min_strength, 1.0) if profile != BURST else 1.0
	ratio = clampf(ratio * dampen, 0.0, 1.0)
	if ratio <= 0.0:
		dropped += 1
		return
	var draw: ShaderMaterial = slot.draw
	draw.set_shader_parameter("size_scale", size)
	draw.set_shader_parameter("near_fade_start", settings.eye_fade_near * (2.5 if local else 1.0))
	draw.set_shader_parameter("near_fade_end", settings.eye_fade_far * (2.5 if local else 1.0))
	material.set_shader_parameter("origin", position)
	material.set_shader_parameter("direction", axis)
	material.set_shader_parameter("up_axis", Vector3.UP)
	material.set_shader_parameter("profile", profile)
	material.set_shader_parameter("cone", cone)
	material.set_shader_parameter("speed_min", speed_min)
	material.set_shader_parameter("speed_max", speed_max)
	material.set_shader_parameter("life", life)
	material.set_shader_parameter("stagger", stagger)
	material.set_shader_parameter("gravity", gravity)
	material.set_shader_parameter("drag", drag)
	material.set_shader_parameter("pulse_count", pulse_count)
	material.set_shader_parameter("pulse_depth", pulse_depth)
	material.set_shader_parameter("density_gain", settings.density)
	material.set_shader_parameter("spawn_radius", spawn)
	material.set_shader_parameter("event_seed", seed)
	material.set_shader_parameter("tint", tint)
	node.amount_ratio = ratio
	node.restart(true)
	node.speed_scale = 0.0 if _suspended else 1.0
	node.visible = not _suspended
	slot.remaining = life * (1.0 + maxf(0.0, stagger)) + 0.2
	slot.age = 0.0
	slot.serial = _serial
	slot.priority = priority
	slot.profile = profile
	slot.ratio = ratio
	slot.position = position


func _acquire_fluid(priority: float) -> Dictionary:
	var free: Dictionary = {}
	var free_count := 0
	var worst: Dictionary = {}
	for slot: Dictionary in fluid_slots:
		if slot.remaining <= 0.0:
			if free.is_empty(): free = slot
			free_count += 1
			continue
		if worst.is_empty() or _score(slot) < _score(worst): worst = slot
	var live := fluid_slots.size() - free_count
	if live < concurrent_cap and not free.is_empty():
		return free
	# At the cap the pool recycles its weakest live emitter instead of growing
	# the concurrent count or queueing an allocation.
	if not worst.is_empty() and priority + 0.05 >= _score(worst):
		recycled += 1
		return worst
	dropped += 1
	return {}


func _score(slot: Dictionary) -> float:
	return float(slot.priority) - minf(float(slot.age), 3.0) - (1.0 if slot.profile == JET else 0.0)


func _priority(position: Vector3, local: bool, profile: int) -> float:
	var value := 4.0 if local else 0.0
	if profile == ARTERIAL: value += 1.4
	elif profile == BURST: value += 1.1
	if is_instance_valid(camera) and camera.is_inside_tree():
		var distance := camera.global_position.distance_to(position)
		value += 1.0 / (1.0 + distance * 0.03)
		if not camera.is_position_behind(position): value += 1.0
	return value


## Angular size cap. The eye must never be blinded by a single emitter: the
## dampening is a real function of the emitter radius, the eye distance and the
## vertical FOV, and is reported in the snapshot for verification.
func _coverage_dampen(position: Vector3, radius: float, local: bool) -> float:
	if not is_instance_valid(camera) or not camera.is_inside_tree(): return 1.0
	var distance := camera.global_position.distance_to(position)
	if distance <= 0.05: return 0.0
	var half_fov := deg_to_rad(maxf(5.0, camera.fov)) * 0.5
	var angular := asin(clampf(radius / distance, 0.0, 1.0))
	var fraction := angular / half_fov
	var limit := settings.local_coverage_limit if local else settings.coverage_limit
	var dampen := 1.0
	if fraction > limit and fraction > 0.0001: dampen = limit / fraction
	if local: dampen *= settings.local_gain
	return clampf(dampen, 0.0, 1.0)

# --- pooled surface stains ----------------------------------------------------

func _reach(origin: Vector3, direction: Vector3, limit: float) -> Dictionary:
	if not surfaces.ready: return {}
	var unit := direction
	if unit.length_squared() < 0.000001: return {}
	unit = unit.normalized()
	return surfaces.query(origin, origin + unit * maxf(0.05, limit))


## Occlusion check: the finished stain must be reachable from the wound/death
## point without passing through other geometry.
func _visible_from(origin: Vector3, hit: Dictionary) -> bool:
	if not settings.stain_visibility_check or not surfaces.ready: return true
	var position: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var start := position + normal * 0.05
	var distance := start.distance_to(origin)
	if distance <= 0.14: return true
	var end := origin - (origin - start) / distance * 0.08
	return surfaces.query(start, end).is_empty()


## Edge / corner guard. A mark must lie in the plane it was queried on, so short
## probes around the candidate re-query the same surface at its own offset: a
## different depth means the quad would straddle an edge or float, and a miss
## means the surface ends there. Returns false when the mark must be shrunk or
## skipped instead of drawn wrong.
func _mark_flat(position: Vector3, normal: Vector3, basis: Basis, size: float) -> bool:
	if not settings.stain_edge_check or not surfaces.ready: return true
	var reach := settings.stain_edge_tolerance + size * 0.5
	for i in 3:
		var offset: Vector3 = (basis.y * size * 0.5) if i == 0 else ((-basis.y * size * 0.5) if i == 1 else (basis.x * size * 0.5))
		var probe := surfaces.query(position + offset + normal * reach, position + offset - normal * reach)
		if probe.is_empty(): return false
		if absf(float(probe.distance) - reach) > settings.stain_edge_tolerance: return false
	return true


const SHAPE_POOL := 0
const SHAPE_STREAK := 1
const SHAPE_DRIP := 2
const SURFACE_FLOOR := 0
const SURFACE_SLOPE := 1
const SURFACE_WALL := 2


## Marks are placed only on a real queried surface, in its own plane, offset along
## the normal. `axis_hint` orients the long axis (jet streaks); SHAPE_POOL and
## SHAPE_DRIP instead follow the surface downhill direction. `edge_shrink` allows
## one half-size retry before the mark is rejected.
func _place_stain(origin: Vector3, size: float, hit: Dictionary, seed: float, delay: float,
		elongation: float, axis_hint: Vector3 = Vector3.ZERO, shape: int = SHAPE_POOL) -> bool:
	if hit.is_empty() or not surfaces.ready:
		stains_rejected += 1
		return false
	if surfaces.solid_at(hit.position, hit.normal):
		# A mark must never sit inside solid geometry (for example on a floor quad
		# that lies under a wall's footprint).
		marks_skipped_solid += 1
		stains_rejected += 1
		return false
	if not _visible_from(origin, hit):
		stains_rejected += 1
		return false
	var position: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var width := maxf(0.05, size)
	var basis := _stain_basis(normal, seed, axis_hint, shape)
	if not _mark_flat(position, normal, basis, width):
		# Clamp once to half size, then skip rather than draw a wrong quad.
		width *= 0.5
		basis = _stain_basis(normal, seed, axis_hint, shape)
		if width < 0.06 or not _mark_flat(position, normal, basis, width):
			marks_skipped_edge += 1
			stains_rejected += 1
			return false
	var slot := _acquire_stain()
	if slot.is_empty():
		stains_rejected += 1
		return false
	_stain_serial += 1
	slot.serial = _stain_serial
	slot.age = 0.0
	slot.delay = delay
	slot.growth = settings.stain_growth_seconds
	slot.fade = settings.stain_fade_seconds
	slot.opacity = settings.stain_opacity
	slot.scale_base = Vector3(width, width * maxf(0.5, elongation), 1.0)
	if shape == SHAPE_STREAK:
		slot.grow_from = Vector3(0.55, 0.18, 1.0)
	elif shape == SHAPE_DRIP:
		slot.grow_from = Vector3(0.6, 0.1, 1.0)
	else:
		slot.grow_from = Vector3(0.35, 0.35, 1.0)
	slot.remaining = maxf(0.5, settings.stain_fade_seconds) if settings.stain_fade_seconds > 0.0 else INF
	slot.total = slot.remaining
	slot.surface = _classify_surface(normal)
	match slot.surface:
		SURFACE_WALL:
			marks_wall += 1
		SURFACE_SLOPE:
			marks_slope += 1
		_:
			marks_floor += 1
	var material: ShaderMaterial = slot.material
	material.set_shader_parameter("fluid_color", settings.fluid_color)
	material.set_shader_parameter("opacity", 0.0 if delay > 0.0 else settings.stain_opacity)
	material.set_shader_parameter("seed", seed)
	material.set_shader_parameter("elongation", elongation)
	var node: MeshInstance3D = slot.node
	node.global_transform = Transform3D(basis, position + normal * settings.stain_normal_offset)
	node.scale = slot.scale_base * slot.grow_from
	node.visible = delay <= 0.0
	stains_placed += 1
	return true


static func _classify_surface(normal: Vector3) -> int:
	var vertical := absf(normal.y)
	if vertical >= 0.7: return SURFACE_FLOOR
	if vertical <= 0.4: return SURFACE_WALL
	return SURFACE_SLOPE


## Local +Y of a pool/drip runs down the surface so an elongated drip always
## descends in world space; a streak instead points along the incoming jet's
## in-plane projection. The basis is right-handed, so no axis is mirrored by the
## transform decomposition.
func _stain_basis(normal: Vector3, seed: float, axis_hint: Vector3 = Vector3.ZERO, shape: int = SHAPE_POOL) -> Basis:
	var up := normal.normalized()
	var axis := Vector3.DOWN - up * Vector3.DOWN.dot(up)
	if axis.length_squared() < 0.0004:
		axis = Vector3.FORWARD - up * Vector3.FORWARD.dot(up)
	axis = axis.normalized()
	if shape == SHAPE_STREAK and axis_hint.length_squared() > 0.0004:
		var hint := axis_hint - up * axis_hint.dot(up)
		if hint.length_squared() > 0.0004: axis = hint.normalized()
		axis = (Quaternion(up, (fmod(seed, 7.0) - 3.5) * 0.08).normalized() * axis).normalized()
	else:
		axis = (Quaternion(up, seed * 0.7).normalized() * axis).normalized()
	var right := axis.cross(up).normalized()
	return Basis(right, axis, up)


## A synthesised in-plane hit: the point is known to be in the surface plane, so
## the edge probe and the reachability check still decide whether it may be drawn.
func _plane_hit(position: Vector3, normal: Vector3, distance: float) -> Dictionary:
	return {"hit": true, "position": position, "normal": normal, "distance": distance, "surface": "plane"}


func _acquire_stain() -> Dictionary:
	var free: Dictionary = {}
	var oldest: Dictionary = {}
	var free_count := 0
	for slot: Dictionary in stain_slots:
		if slot.remaining <= 0.0:
			if free.is_empty(): free = slot
			free_count += 1
			continue
		if oldest.is_empty() or float(slot.serial) < float(oldest.serial): oldest = slot
	var live := stain_slots.size() - free_count
	if not free.is_empty() and live < stain_cap: return free
	if not oldest.is_empty():
		# Documented oldest-recycled eviction: bounded, never grows the pool.
		stains_recycled += 1
		return oldest
	if not free.is_empty(): return free
	stains_recycled += 1
	return stain_slots[0] if not stain_slots.is_empty() else {}


func _retire_stain(slot: Dictionary) -> void:
	slot.remaining = 0.0
	slot.total = 0.0
	slot.delay = 0.0
	slot.node.hide()

# --- frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	if not is_inside_tree(): return
	_sync_suspension()
	if _suspended: return
	if require_public_state and (Time.get_ticks_usec() - last_state_usec) / 1000000.0 > settings.stale_seconds:
		# Stale public state: drain rather than hold a frozen wound forever.
		drain()
		active = false
		return
	var dt := clampf(delta, 0.0, 0.05)
	clock += dt
	for slot: Dictionary in fluid_slots:
		if slot.remaining <= 0.0: continue
		slot.remaining -= dt
		slot.age += dt
		if slot.remaining <= 0.0:
			slot.profile = -1
			slot.ratio = 0.0
			slot.node.emitting = false
			slot.node.speed_scale = 0.0
			slot.node.hide()
	for slot: Dictionary in stain_slots:
		if slot.remaining <= 0.0: continue
		if slot.delay > 0.0:
			slot.delay -= dt
			if slot.delay > 0.0: continue
			slot.node.show()
			slot.age = 0.0
		slot.age += dt
		slot.remaining -= dt
		var grow := 1.0 if slot.growth <= 0.0 else clampf(slot.age / slot.growth, 0.0, 1.0)
		var grow_from: Vector3 = slot.grow_from
		slot.node.scale = (slot.scale_base as Vector3) * grow_from.lerp(Vector3.ONE, grow)
		var opacity: float = slot.opacity
		if slot.fade > 0.0 and slot.remaining < slot.fade:
			opacity *= clampf(slot.remaining / slot.fade, 0.0, 1.0)
		slot.material.set_shader_parameter("opacity", opacity)
		if slot.remaining <= 0.0: _retire_stain(slot)

# --- diagnostics -------------------------------------------------------------

func snapshot() -> Dictionary:
	var allocated := 0
	var submitted := 0
	var emitters := 0
	var spurts_live := 0
	var bursts_live := 0
	var stains_live := 0
	var stains_pending := 0
	var stains_wall := 0
	var stains_floor := 0
	var stains_slope := 0
	for slot: Dictionary in fluid_slots:
		allocated += int(slot.node.amount)
		if slot.remaining > 0.0:
			emitters += 1
			submitted += int(round(float(slot.node.amount) * float(slot.node.amount_ratio)))
			if slot.profile == BURST: bursts_live += 1
			elif slot.profile >= 0: spurts_live += 1
	for slot: Dictionary in stain_slots:
		if slot.remaining <= 0.0: continue
		stains_live += 1
		if slot.delay > 0.0: stains_pending += 1
		match int(slot.surface):
			SURFACE_WALL: stains_wall += 1
			SURFACE_SLOPE: stains_slope += 1
			SURFACE_FLOOR: stains_floor += 1
	return {
		"backend": "GPUParticles3D + pooled surface quads",
		"simulation": "transform-feedback" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else "RD-compute",
		"quality": quality, "budget": budget, "allocated_slots": allocated,
		"submitted_slots": submitted, "gpu_live_readback": false,
		"live_count_note": "submitted_slots is allocated capacity x amount_ratio for live emitters, not a GPU particle readback",
		"pool_nodes": fluid_slots.size(), "active_emitters": emitters, "concurrent_cap": concurrent_cap,
		"spurt_emitters": spurts_live, "burst_emitters": bursts_live,
		"stain_pool": stain_slots.size(), "stain_cap": stain_cap, "stains_live": stains_live, "stains_pending": stains_pending,
		"stains_wall": stains_wall, "stains_floor": stains_floor, "stains_slope": stains_slope,
		"marks_wall": marks_wall, "marks_floor": marks_floor, "marks_slope": marks_slope,
		"marks_skipped_edge": marks_skipped_edge, "marks_skipped_facing": marks_skipped_facing,
		"marks_skipped_solid": marks_skipped_solid,
		"marks_skipped_reach": marks_skipped_reach, "clusters_placed": clusters_placed,
		"fan_rays_cast": fan_rays_cast, "fan_marks": fan_marks, "impact_marks": impact_marks,
		"stain_nodes_created": stain_slots.size(), "shared_shaders": 3, "shared_meshes": 2,
		"slot_materials": fluid_slots.size() + stain_slots.size(),
		"buffer_payload_estimate_bytes": allocated * 320,
		"buffer_estimate_backend": "Godot 4.5.2 GLES3 two 96-byte process + two 64-byte instance buffers per allocated slot; excludes driver overhead",
		"variant": settings.variant(), "fluid_color": settings.fluid_color.to_html(false),
		"surfaces": surfaces.snapshot(), "surface_error": surface_error,
		"map_id": map_id, "active": active, "suspended": _suspended, "paused": paused, "focused": focused,
		"clock": clock, "drains": drains,
		"events_seen": events_seen, "spurts": spurts, "mist_events": mist_events, "arterial_hits": arterial_hits,
		"absorbed_mist_events": absorbed_mist_events,
		"death_bursts": death_bursts, "stains_placed": stains_placed, "stains_rejected": stains_rejected,
		"stains_recycled": stains_recycled, "duplicates": duplicates, "rejected": rejected,
		"unknown_actors": unknown_actors, "no_bleed": no_bleed, "absorbed_only": absorbed_only,
		"dropped": dropped, "recycled": recycled,
		"last_event_id": last_event_id, "last_event_position": [last_event_position.x, last_event_position.y, last_event_position.z],
		"time_source": last_public_time,
	}
