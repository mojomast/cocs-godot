class_name PortCombatFeedback
extends Node3D

# Shared passive combat composition. Damage/shot confirmation comes only from
# authority events. Detached diagnostic consumers retain their minimal fallback.
const MAX_TRACERS: int = 128
const TRACER_SECONDS: float = 0.12
var tracers: Array[Dictionary] = []
var shots: int = 0
var launches: int = 0
var local_launches: int = 0
var explosions: int = 0
const Projectiles = preload("res://world/projectiles.gd")
const MothEffects = preload("res://graphics_fx/moth_world.gd")
const MothLibrary = preload("res://moth/library.gd")
var moth_effects: Node3D
var public_actors: Array = []
const MAX_BLASTS := 32
const BLAST_SECONDS := 0.32
var projectiles: Node3D
var blasts: Array[Dictionary] = []
var blast_mesh: SphereMesh
var hits: int = 0
var hurts: int = 0
var hit_remaining: float = 0.0
var hurt_remaining: float = 0.0
const Overlay = preload("res://world/combat_overlay.gd")
const AudioFeedback = preload("res://world/audio_feedback.gd")
const PlayerFx = preload("res://player_fx/director.gd")
const Impacts = preload("res://player_fx/impacts.gd")
var overlay: Control
var audio_feedback: Node
var player_fx: Node
var impacts: Node3D
const CombatShields = preload("res://combat_shields/controller.gd")
const BloodFX = preload("res://blood_fx/controller.gd")
const BloodSurfaces = preload("res://blood_fx/surface_query.gd")
const CombatQuality = preload("res://world/combat_quality.gd")
const WeaponEffects = preload("res://weapon_effects/controller.gd")
const WorldParticles = preload("res://combat_particles/manager.gd")
const Occlusion = preload("res://world/combat_occlusion.gd")
var shields: Node3D
var blood_fx: Node3D
var weapon_effects: Node3D
var world_particles: Node3D
var occlusion := Occlusion.new()
var quality_controls: CanvasLayer
var effect_camera: Camera3D
var effect_session: Node
var effect_local_id := -1
var attached_rig: Node
var map_key := ""
var source_time := -1.0
var effects_active := false
var last_state_usec := 0
var pending_events: Array = []
var event_ids: Dictionary = {}
var highest_event := -1
const EVENT_WINDOW := 4096
var metrics_age := 0.0
var map_error := ""

func configure_effects(camera: Camera3D, session: Node) -> void:
	effect_camera = camera
	effect_session = session
	if not is_instance_valid(weapon_effects):
		weapon_effects = WeaponEffects.new()
		add_child(weapon_effects)
		weapon_effects.configure_occlusion(occlusion.segment_blocked)
		weapon_effects.configure_moth(func(key: String) -> Dictionary:
			return MothLibrary.effect({"pulse":"spark-impact", "plasma":"arc-burst", "shock":"arc-burst"}.get(key, "")))
	if not is_instance_valid(world_particles):
		world_particles = WorldParticles.new()
		add_child(world_particles)
	if not is_instance_valid(shields):
		shields = CombatShields.new()
		add_child(shields)
		shields.configure(camera)
		shields.set_quality("high")
	if not is_instance_valid(quality_controls):
		quality_controls = CombatQuality.new()
		add_child(quality_controls)
		quality_controls.quality_changed.connect(_quality_changed)
	if not is_instance_valid(player_fx):
		player_fx = PlayerFx.new()
		add_child(player_fx)
		player_fx.configure(camera)
	if not is_instance_valid(impacts):
		impacts = Impacts.new()
		add_child(impacts)
		impacts.configure(camera, occlusion)
	if not is_instance_valid(blood_fx):
		blood_fx = BloodFX.new()
		add_child(blood_fx)
	_quality_changed(quality_controls.quality)
	_attach_rig()

func _quality_changed(level: int) -> void:
	if is_instance_valid(shields): shields.set_quality("low" if level == 0 else "high")
	# Low retains essential weapon cues, dropping secondary smoke/casings.
	if is_instance_valid(weapon_effects): weapon_effects.set_quality(1 if level == 0 else 2)
	if is_instance_valid(world_particles): world_particles.set_quality(CombatQuality.LEVELS[level])
	if is_instance_valid(player_fx): player_fx.set_quality(level)
	if is_instance_valid(impacts): impacts.set_quality(level)
	if is_instance_valid(blood_fx): blood_fx.set_quality(CombatQuality.LEVELS[level])
	_update_metrics()

func _attach_rig() -> void:
	var rig := _effect_rig()
	if not is_instance_valid(rig) or rig == attached_rig or not is_instance_valid(weapon_effects): return
	attached_rig = rig
	weapon_effects.attach_rig(rig)
	if "flash" in rig: rig.flash.hide()

func _configure_map(state: Dictionary) -> void:
	if not is_instance_valid(effect_camera): return
	var id := str(state.get("mapId", ""))
	var world: Node
	if is_instance_valid(effect_session):
		if id.is_empty() and "current_id" in effect_session: id = effect_session.current_id
		if id.is_empty() and "map_id" in effect_session: id = effect_session.map_id
		if "world" in effect_session: world = effect_session.world
	var key := "%s/%s" % [id, world.get_instance_id() if is_instance_valid(world) else 0]
	if key == map_key: return
	if not map_key.is_empty(): clear_round()
	map_key = key
	var map := {}
	var native := Occlusion.native_root(world, id)
	if native != null:
		var bounds := AABB(Vector3(-100, -4, -100), Vector3(200, 90, 200))
		if id == "cinder-array": bounds = AABB(Vector3(-92, -2, -82), Vector3(184, 87, 164))
		map = {"id":id, "bounds":bounds, "collision_root":native}
	else:
		var catalog := Occlusion.Catalog.new()
		if catalog.open() and catalog.entries.has(id): map = catalog.resolve_map(id)
	occlusion.configure(effect_camera, map)
	map_error = "" if occlusion.ready else "No authoritative map geometry: " + id
	if is_instance_valid(impacts):
		impacts.configure(effect_camera, occlusion)
		impacts.set_map(map)
	if not map.is_empty():
		var result: Dictionary = world_particles.configure(effect_camera, map)
		if not result.get("ok", false): map_error = str(result.get("error", "Particle map configuration failed"))
		if is_instance_valid(blood_fx):
			# Semantic exports for the locked nine maps; StaticBody3D roots for
			# native/identity maps. Both are real surface queries, never guessed planes.
			var blood_source: Variant = map if map.has("collision_root") else BloodSurfaces.semantic_provider(map)
			var blood_result: Dictionary = blood_fx.configure(effect_camera, blood_source)
			if not blood_result.get("ok", false): map_error = str(blood_result.get("error", map_error))
	else:
		world_particles.reset()
		if is_instance_valid(blood_fx): blood_fx.reset()
	if is_instance_valid(projectiles): projectiles.configure_occlusion(occlusion.segment_blocked)

func _allowed() -> bool:
	if not is_instance_valid(effect_session): return true
	if last_state_usec <= 0: return false # A reset requires a fresh public frame.
	if get_tree().paused or not is_visible_in_tree(): return false
	if "phase" in effect_session and effect_session.phase not in [3, "active"]: return false
	if "snapshot_watch" in effect_session and effect_session.snapshot_watch.stale(): return false
	if "application_focused" in effect_session and not effect_session.application_focused: return false
	if "controls" in effect_session and not effect_session.controls.focused: return false
	if last_state_usec > 0 and Time.get_ticks_usec()-last_state_usec > 800000: return false
	return true

func _sync_activity() -> void:
	var active := _allowed()
	if active == effects_active: return
	effects_active = active
	if is_instance_valid(shields): shields.set_suspended(not active)
	if not active:
		# Drain, rather than freeze/replay held bursts when focus/freshness returns.
		pending_events.clear()
		if is_instance_valid(weapon_effects): weapon_effects.reset()
		if is_instance_valid(world_particles): world_particles.reset()
		if is_instance_valid(projectiles): projectiles.clear_round()
		if is_instance_valid(audio_feedback): audio_feedback.clear_round()
		if is_instance_valid(player_fx): player_fx.clear_transient()
		if is_instance_valid(impacts): impacts.reset()
		if is_instance_valid(blood_fx): blood_fx.reset()
		hit_remaining = 0.0
		hurt_remaining = 0.0
	if is_instance_valid(world_particles): world_particles.set_paused(not active)
	if is_instance_valid(blood_fx): blood_fx.set_paused(not active)
	if is_instance_valid(quality_controls): quality_controls.set_active(active)

func _fresh_events(items: Array) -> Array:
	var fresh: Array = []
	for item: Variant in items.slice(0, 512):
		if not item is Dictionary: continue
		var id := WeaponEffects.identity(item.get("id"))
		if id < 0 or id <= highest_event-EVENT_WINDOW or event_ids.has(id): continue
		highest_event = maxi(highest_event, id)
		event_ids[id] = true
		fresh.append(item)
	for id: int in event_ids.keys():
		if id <= highest_event-EVENT_WINDOW: event_ids.erase(id)
	return fresh

func flush_effects() -> void:
	_sync_activity()
	_attach_rig()
	if pending_events.is_empty(): return
	var events := pending_events
	pending_events = []
	if not effects_active: return
	# Session listeners run before first-person listeners. This pass runs at 40,
	# after network/rig processing (0), before weapon animation (50). Combined
	# Arms creates its rig before its network node, so refresh transforms at zero
	# elapsed time too: current recoil/camera, without applying recoil twice.
	if is_instance_valid(attached_rig): attached_rig.advance(0.0)
	var safe: Array = []
	for event: Dictionary in events:
		if event.get("type") == "shot":
			var from: Variant = point(event.get("from"))
			var to: Variant = point(event.get("to"))
			if from == null or to == null or occlusion.segment_blocked(from, to): continue
		safe.append(event)
	weapon_effects.consume(safe, effect_local_id, public_actors)
	for event: Dictionary in safe:
		if event.get("type") == "launch" and WeaponEffects.numeric(event.get("time")) and absf(float(event.time)-source_time) <= 0.25 and is_instance_valid(projectiles):
			projectiles.cache_launch(event, weapon_effects.resolve_launch_origin(event, effect_local_id), effect_local_id)
	shields.apply_events(events, effect_local_id)
	world_particles.consume(events, effect_local_id)
	if is_instance_valid(blood_fx): blood_fx.apply_events(events, effect_local_id)
	if is_instance_valid(player_fx): player_fx.apply_events(safe, effect_local_id)
	if is_instance_valid(impacts): impacts.consume(safe, effect_local_id)

func _update_metrics() -> void:
	if not is_instance_valid(quality_controls): return
	var metrics := {}
	if is_instance_valid(world_particles):
		var data: Dictionary = world_particles.snapshot()
		for key in ["backend", "budget", "allocated_slots", "draw_slots", "active_emitters", "pool_nodes", "buffer_payload_estimate_bytes", "collision_shapes", "unsupported_collision_shapes"]: metrics[key] = data[key]
		metrics["capacity_note"] = "Submitted capacity, not live GPU readback; buffer bytes are an estimate"
	if is_instance_valid(weapon_effects):
		var allocated := 0
		for slot: Dictionary in weapon_effects.slots + weapon_effects.lines:
			if is_instance_valid(slot.node): allocated += 1
		metrics["weapon_pool_nodes"] = allocated
		metrics["weapon_flashes"] = weapon_effects.flashes
		metrics["weapon_tracers"] = weapon_effects.tracer_count
	if is_instance_valid(shields): metrics["shield_materials"] = shields.debug_state().materials
	if is_instance_valid(player_fx):
		var fx_state: Dictionary = player_fx.snapshot()
		metrics["player_fx_low"] = fx_state.low_health
		metrics["player_fx_heartbeat"] = snappedf(fx_state.heartbeat, 0.01)
		metrics["player_fx_direction"] = "actor" if fx_state.direction_known else ("environmental" if fx_state.damage_environmental else "none")
		metrics["player_fx_protection"] = fx_state.protection
		metrics["player_fx_cues"] = JSON.stringify(fx_state.counters)
	if is_instance_valid(impacts):
		var impact_state: Dictionary = impacts.snapshot()
		metrics["impact_pool"] = impact_state.pool
		metrics["impact_active"] = impact_state.active
		metrics["impact_family"] = impact_state.family if not str(impact_state.family).is_empty() else "none"
		metrics["impact_counters"] = JSON.stringify(impact_state.counters)
		# Persistent surface damage (player_fx/mark_pool.gd): live decals and the
		# skip/recycle accounting the tests and the F10 panel read.
		var impact_counts: Dictionary = impact_state.counters
		metrics["impact_marks_pool"] = impact_state.marks_pool
		metrics["impact_marks_live"] = impact_state.marks_live
		metrics["impact_marks_recycled"] = int(impact_counts.get("marks_recycled", 0))
		metrics["impact_marks_skipped"] = int(impact_counts.get("marks_skipped_occluded", 0)) \
			+ int(impact_counts.get("marks_skipped_far", 0)) + int(impact_counts.get("marks_skipped_edge", 0))
		metrics["impact_scorches"] = int(impact_counts.get("scorches_placed", 0))
	if is_instance_valid(blood_fx):
		var blood_state: Dictionary = blood_fx.snapshot()
		for key in ["allocated_slots", "submitted_slots", "active_emitters", "concurrent_cap", "stains_live", "stains_recycled", "no_bleed", "absorbed_only", "duplicates"]:
			if blood_state.has(key): metrics["blood_%s" % key] = blood_state[key]
	metrics["occlusion"] = occlusion.snapshot().backend
	if not map_error.is_empty(): metrics["map_error"] = map_error
	quality_controls.set_metrics(metrics)

func _effect_identity() -> int:
	if not is_instance_valid(effect_session): return -1
	if "client" in effect_session: return effect_session.client.actor_id
	if "net" in effect_session: return effect_session.net.actor_id
	return -1

func _effect_rig() -> Node:
	var parent := get_parent()
	if parent == null: return null
	if "rig" in parent: return parent.rig
	if "first_person" in parent and is_instance_valid(parent.first_person): return parent.first_person.rig
	return null

func _init() -> void:
	process_priority = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	blast_mesh = SphereMesh.new()
	blast_mesh.radius = 1.0
	blast_mesh.height = 2.0
	blast_mesh.radial_segments = 12
	blast_mesh.rings = 6

func apply_state(state: Dictionary) -> void:
	var next_id := _effect_identity()
	var time: Variant = state.get("time")
	if is_instance_valid(effect_camera):
		if WeaponEffects.numeric(time) and source_time >= 0 and float(time) < source_time-0.001:
			clear_round()
		elif next_id != effect_local_id:
			# Seat/identity changes drain old anchors; only a round boundary permits
			# public event IDs to be reused.
			var remembered := event_ids.duplicate()
			var highest := highest_event
			clear_round()
			event_ids = remembered
			highest_event = highest
		if state.get("over", false):
			clear_round()
			return
		_configure_map(state)
	effect_local_id = next_id
	if WeaponEffects.numeric(time): source_time = float(time)
	last_state_usec = Time.get_ticks_usec()
	public_actors = state.get("actors", []) if state.get("actors", []) is Array else []
	_sync_activity()
	if is_instance_valid(effect_camera) and not effects_active: return
	if is_instance_valid(player_fx): player_fx.apply_state(state, effect_local_id)
	if is_instance_valid(shields):
		if is_instance_valid(effect_session) and "presentation" in effect_session:
			shields.bind_actor_visuals(effect_session.presentation.actors)
		elif is_instance_valid(effect_session) and "actors" in effect_session:
			shields.bind_actor_visuals(effect_session.actors.actors)
		shields.apply_state(state, effect_local_id)
	if is_instance_valid(world_particles) and map_error.is_empty(): world_particles.apply_state(state, effect_local_id)
	if is_instance_valid(blood_fx) and map_error.is_empty(): blood_fx.apply_state(state, effect_local_id)
	if not is_instance_valid(projectiles):
		projectiles = Projectiles.new()
		add_child(projectiles)
		projectiles.configure_occlusion(occlusion.segment_blocked)
	projectiles.apply_state(state)

func _ready() -> void:
	moth_effects = MothEffects.new()
	add_child(moth_effects)
	moth_effects.configure(Callable(MothLibrary, "effect"))
	audio_feedback = AudioFeedback.new()
	add_child(audio_feedback)
	audio_feedback.set_muted("--mute" in OS.get_cmdline_user_args())
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	overlay = Overlay.new()
	overlay.visible = false
	layer.add_child(overlay)
	var parent := get_parent()
	if parent != null and "camera" in parent:
		configure_effects(parent.camera, parent)
	elif parent != null and "session" in parent and is_instance_valid(parent.session) and "world" in parent.session:
		configure_effects(parent.session.world.camera, parent.session)

func point(value: Variant) -> Variant:
	if not value is Dictionary: return null
	for key: String in ["x", "y", "z"]:
		if not (value.get(key) is float or value.get(key) is int): return null
		if not is_finite(float(value[key])): return null
	return Vector3(value.x, value.y, value.z)

func apply_events(items: Array, local_id: int) -> void:
	var integrated := is_instance_valid(weapon_effects)
	if integrated:
		items = _fresh_events(items)
		_sync_activity()
		if effects_active:
			pending_events.append_array(items.slice(0, maxi(0,512-pending_events.size())))
	else:
		if is_instance_valid(moth_effects): moth_effects.consume(items, local_id, public_actors)
	if is_instance_valid(audio_feedback) and (not integrated or effects_active): audio_feedback.apply_events(items, local_id)
	for value: Variant in items:
		if not value is Dictionary: continue
		var item: Dictionary = value
		match item.get("type", ""):
			"launch":
				if Projectiles.point(item.get("pos")) == null or Projectiles.identity(item.get("actor")) < 0 or Projectiles.identity(item.get("weapon")) < 0: continue
				launches += 1
				if Projectiles.identity(item.get("actor")) == local_id: local_launches += 1
			"explosion":
				var pos: Variant = Projectiles.point(item.get("pos"))
				if pos == null: continue
				explosions += 1
				if integrated: continue
				if blasts.size() >= MAX_BLASTS: remove_blast(0)
				var material := StandardMaterial3D.new()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.albedo_color = Color(1.0, 0.48, 0.1, 0.65)
				var node := MeshInstance3D.new()
				node.mesh = blast_mesh
				node.material_override = material
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.position = pos
				node.scale = Vector3.ONE * 0.18
				add_child(node)
				blasts.append({"node":node, "remaining":BLAST_SECONDS})
			"shot":
				var from: Variant = point(item.get("from"))
				var to: Variant = point(item.get("to"))
				if from == null or to == null: continue
				shots += 1
				if integrated: continue
				if tracers.size() >= MAX_TRACERS: remove_tracer(0)
				var mesh := ImmediateMesh.new()
				var material := StandardMaterial3D.new()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.albedo_color = Color(1.0, 0.85, 0.25)
				mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
				mesh.surface_add_vertex(from)
				mesh.surface_add_vertex(to)
				mesh.surface_end()
				var node := MeshInstance3D.new()
				node.mesh = mesh
				add_child(node)
				tracers.append({"node":node,"remaining":TRACER_SECONDS})
			"damage":
				var amount: Variant = item.get("amount")
				if not (amount is int or amount is float): continue
				if not is_finite(float(amount)) or float(amount) <= 0: continue
				var victim: int = Projectiles.identity(item.get("actor"))
				if victim < 0: continue
				# JSON null is environmental damage, never actor zero.
				var source: Variant = item.get("source")
				if local_id >= 0 and victim == local_id:
					hurts += 1
					if not integrated or effects_active: hurt_remaining = 0.35
				if local_id >= 0 and Projectiles.identity(source) == local_id and victim != local_id:
					hits += 1
					if not integrated or effects_active: hit_remaining = 0.2

func remove_tracer(index: int) -> void:
	var node: Node = tracers[index].node
	remove_child(node)
	node.free()
	tracers.remove_at(index)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	hit_remaining = maxf(0.0, hit_remaining - maxf(delta, 0.0))
	hurt_remaining = maxf(0.0, hurt_remaining - maxf(delta, 0.0))
	if is_instance_valid(player_fx): player_fx.advance(delta)
	if is_instance_valid(impacts): impacts.advance(delta)
	for index: int in range(tracers.size() - 1, -1, -1):
		tracers[index].remaining -= maxf(delta, 0.0)
		if tracers[index].remaining <= 0: remove_tracer(index)
	for index: int in range(blasts.size() - 1, -1, -1):
		blasts[index].remaining -= delta
		if blasts[index].remaining <= 0:
			remove_blast(index)
			continue
		var progress: float = 1.0 - blasts[index].remaining / BLAST_SECONDS
		var node: MeshInstance3D = blasts[index].node
		node.scale = Vector3.ONE * lerpf(0.18, 0.95, progress)
		node.material_override.albedo_color = Color(1.0, lerpf(0.65, 0.2, progress), 0.08, 0.65 * (1.0 - progress))

func remove_blast(index: int) -> void:
	blasts[index].node.free()
	blasts.remove_at(index)

func _process(delta: float) -> void:
	advance(delta)
	flush_effects()
	var rig := _effect_rig()
	if is_instance_valid(overlay):
		overlay.set_ads_weight(float(rig.get_aim_state().weight) if is_instance_valid(rig) else 0.0)
	metrics_age += delta
	if metrics_age >= 0.25:
		metrics_age = 0.0
		_update_metrics()
	if is_instance_valid(overlay):
		var session := get_parent()
		var aiming: bool = session != null and session.has_method("can_capture_pointer") and session.can_capture_pointer() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		overlay.update_feedback(aiming, hit_remaining, hurt_remaining, player_fx.model() if is_instance_valid(player_fx) else {})

func text() -> String:
	return ("HIT CONFIRMED " if hit_remaining > 0 else "") + ("TAKING DAMAGE" if hurt_remaining > 0 else "")

func clear_round() -> void:
	pending_events.clear()
	event_ids.clear()
	highest_event = -1
	source_time = -1.0
	last_state_usec = 0
	effect_local_id = -1
	effects_active = false
	if is_instance_valid(weapon_effects): weapon_effects.reset()
	if is_instance_valid(world_particles): world_particles.reset()
	public_actors = [] # Never mutate the snapshot-owned array.
	if is_instance_valid(shields): shields.reset()
	if is_instance_valid(quality_controls): quality_controls.set_active(false)
	if is_instance_valid(moth_effects): moth_effects.reset()
	if is_instance_valid(projectiles): projectiles.clear_round()
	if is_instance_valid(player_fx): player_fx.clear_round()
	if is_instance_valid(impacts): impacts.reset()
	if is_instance_valid(blood_fx): blood_fx.reset()
	while not blasts.is_empty(): remove_blast(0)
	launches = 0
	local_launches = 0
	explosions = 0
	if is_instance_valid(audio_feedback): audio_feedback.clear_round()
	while not tracers.is_empty(): remove_tracer(0)
	shots = 0
	hits = 0
	hurts = 0
	hit_remaining = 0.0
	hurt_remaining = 0.0
	if is_instance_valid(overlay): overlay.update_feedback(false, 0.0, 0.0)
