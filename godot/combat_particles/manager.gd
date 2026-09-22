extends Node3D
## World-space GPUParticles3D pool. Public events only; presentation never predicts
## explosions, damage, projectile disappearance, or gameplay collision outcomes.
const Catalog = preload("res://world/catalog.gd")
const Wire = preload("res://world/projectiles.gd")
const Library = preload("res://moth/library.gd")
const Occupancy = preload("res://combat_particles/occupancy.gd")
const Simulation = preload("res://combat_particles/simulation.gdshader")
const Draw = preload("res://combat_particles/draw.gdshader")
const POOL_SIZE := 32
const BURST_END := 20
const TRAIL_END := 28
const MAX_SCAN := 512
const ID_WINDOW := 4096
const HARD_LIMIT := 1000000
const QUALITY := {"Low": 8192, "High": 32768, "Extreme": HARD_LIMIT}
const NATIVE_IDS := ["aurora-basin", "cinder-array", "prism-foundry", "lattice", "lattice-world"]
const STALE_SECONDS := 0.8
var slots: Array[Dictionary] = []
var camera: Camera3D
var occupancy := Occupancy.new()
var bounds := AABB(Vector3(-52, -2, -44), Vector3(104, 50, 88))
var map_id := ""
var quality := "High"
var budget := 32768
var configured := false
var active := false
var paused := false
var focused := true
var require_public_state := true
var ambient_enabled := true
var clock := 0.0
var last_state_usec := 0
var last_public_time := -1.0
var spawned := 0
var dropped := 0
var duplicates := 0
var rejected := 0
var recycled := 0
var last_event_id := -1
var last_event_position := Vector3.ZERO
var last_projectile_id := -1
var _highest_id := -1
var _ids := PackedInt64Array()
var _mesh: QuadMesh
var _draw: ShaderMaterial
var _suspended := true
var _serial := 0
var _ambient_profile := 5
var _ambient_tint := Color(0.3, 0.7, 0.65)

func _init() -> void:
	_ids.resize(ID_WINDOW)
	_ids.fill(-1)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

## map_or_bounds: catalog ID, AABB, semantic source_map dictionary, or
## {id, bounds: AABB, collision_root: Node3D}. Native maps should supply their
## built collision_root; this captures decks, bridges and walls at actual positions.
func configure(view_camera: Camera3D, map_or_bounds: Variant) -> Dictionary:
	var map := {}
	var root: Node = null
	var next_id := "custom"
	var next_bounds := bounds
	if map_or_bounds is String:
		next_id = map_or_bounds
		if next_id in NATIVE_IDS:
			next_bounds = _native_bounds(next_id)
			# Optional native-authority metadata, read without a compile-time
			# dependency on the independently owned arena lane.
			var path := "res://native_arenas/generated/%s.json" % next_id
			if FileAccess.file_exists(path):
				var native: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
				if native is Dictionary and native.get("id") == next_id and native.get("arena") is Dictionary:
					map = native.arena
			if is_instance_valid(view_camera) and view_camera.is_inside_tree(): root = _native_collision_root(view_camera.get_tree().current_scene, next_id)
		else:
			var catalog := Catalog.new()
			if not catalog.open(): return {"ok": false, "error": catalog.error}
			map = catalog.resolve_map(next_id)
			if map.is_empty(): return {"ok": false, "error": catalog.error}
	elif map_or_bounds is AABB:
		next_bounds = map_or_bounds
	elif map_or_bounds is Dictionary:
		map = map_or_bounds
		next_id = str(map.get("id", "custom"))
		root = map.get("collision_root") as Node
		if map.get("bounds") is AABB: next_bounds = map.bounds
	else:
		return {"ok": false, "error": "Expected catalog ID, AABB or map dictionary"}
	if map.get("bounds") is Dictionary:
		var b: Dictionary = map.bounds
		next_bounds = AABB(Vector3(b.minX, -2, b.minZ), Vector3(b.maxX - b.minX, 66, b.maxZ - b.minZ))
	if not next_bounds.position.is_finite() or not next_bounds.size.is_finite() or next_bounds.size.x <= 0 or next_bounds.size.y <= 0 or next_bounds.size.z <= 0:
		return {"ok": false, "error": "Invalid world bounds"}
	reset()
	camera = view_camera
	map_id = next_id
	bounds = next_bounds
	occupancy.build(bounds, map, root)
	if slots.is_empty(): _build_pool()
	_ambient_profile = 5
	_ambient_tint = Color(0.28, 0.64, 0.6)
	if "cinder" in map_id or "ember" in map_id or "sunscar" in map_id:
		_ambient_profile = 3
		_ambient_tint = Color(0.75, 0.31, 0.09)
	elif "aurora" in map_id or "tidal" in map_id:
		_ambient_profile = 4
		_ambient_tint = Color(0.45, 0.7, 0.8)
	for slot: Dictionary in slots:
		slot.material.set_shader_parameter("occupancy", occupancy.texture)
		slot.material.set_shader_parameter("bounds_min", bounds.position)
		slot.material.set_shader_parameter("bounds_size", bounds.size)
		slot.node.visibility_aabb = bounds
	configured = true
	set_quality(quality)
	set_process(true)
	return {"ok": true, "map_id": map_id, "collision_shapes": occupancy.source_shapes, "solid_cells": occupancy.solid_cells, "unsupported_collision_shapes": occupancy.unsupported_shapes}

func _native_bounds(id: String) -> AABB:
	if id == "cinder-array": return AABB(Vector3(-92, -2, -82), Vector3(184, 87, 164))
	return AABB(Vector3(-100, -4, -100), Vector3(200, 90, 200))

func _native_collision_root(node: Node, id: String) -> Node:
	if node == null: return null
	# Never voxelize the entire session: moving actors/vehicles would otherwise
	# become frozen obstacles. Select only the authored native map subtree.
	var script: Script = node.get_script() as Script
	if script != null and script.resource_path in ["res://native_arenas/maps/%s.gd" % id, "res://%s/map.gd" % id.replace("-", "_")]: return node
	for child: Node in node.get_children():
		var found := _native_collision_root(child, id)
		if found != null: return found
	return null

func _build_pool() -> void:
	_mesh = QuadMesh.new()
	_mesh.size = Vector2.ONE
	_draw = ShaderMaterial.new()
	_draw.shader = Draw
	_draw.set_shader_parameter("flow_field", Library.texture("flow-field"))
	_mesh.material = _draw
	for i in range(POOL_SIZE):
		var material := ShaderMaterial.new()
		material.shader = Simulation
		var node := GPUParticles3D.new()
		node.name = "WorldParticlePool%02d" % i
		node.top_level = true
		node.emitting = false
		node.visible = false
		node.amount = 1
		node.amount_ratio = 1.0
		node.lifetime = 600.0
		node.explosiveness = 1.0
		node.fixed_fps = 0
		node.interpolate = false
		node.fract_delta = false
		node.local_coords = false
		node.use_fixed_seed = true
		node.seed = 44021 + i
		node.speed_scale = 0.0
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.draw_order = GPUParticles3D.DRAW_ORDER_INDEX
		node.draw_pass_1 = _mesh
		node.process_material = material
		add_child(node)
		slots.append({"node": node, "material": material, "remaining": 0.0, "id": -1, "priority": -1.0,
			"serial": 0, "pos": Vector3.ZERO, "profile": 0, "age": 0.0, "present": false})

func set_quality(level: Variant) -> bool:
	if not level is String or not QUALITY.has(level): return false
	quality = level
	budget = 131072 if quality == "High" and map_id in NATIVE_IDS else int(QUALITY[quality])
	# Amount changes resize the existing buffers. No second pool or deferred old
	# emitters survive quality switching; pool/shader/mesh identities stay stable.
	for i in range(slots.size()):
		var slot: Dictionary = slots[i]
		slot.node.amount = budget / POOL_SIZE
		var gain := minf(1.0, sqrt(32768.0 / budget))
		slot.material.set_shader_parameter("density_gain", gain)
		if slot.remaining > 0: slot.node.restart(true)
	_sync_suspension()
	return true

func set_active(value: bool, public_watchdog: bool = true) -> void:
	active = value and configured
	require_public_state = public_watchdog
	last_state_usec = Time.get_ticks_usec()
	if active: _ambient()
	_sync_suspension()

func set_paused(value: bool) -> void:
	paused = value
	_sync_suspension()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
		_sync_suspension()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true
		_sync_suspension()

func _sync_suspension() -> void:
	var tree_paused := is_inside_tree() and get_tree().paused
	var hidden := is_inside_tree() and not is_visible_in_tree()
	_suspended = not active or paused or not focused or tree_paused or hidden
	for slot: Dictionary in slots:
		slot.node.speed_scale = 0.0 if _suspended else 1.0
		slot.node.visible = not _suspended and slot.remaining > 0

func apply_state(public_state: Dictionary, local_id: int = -1) -> void:
	if not configured: return
	if public_state.get("over", false):
		reset()
		return
	var public_time: Variant = public_state.get("time")
	if (public_time is float or public_time is int) and is_finite(float(public_time)):
		if last_public_time >= 0 and float(public_time) < last_public_time: reset()
		last_public_time = float(public_time)
	last_state_usec = Time.get_ticks_usec()
	if not active: set_active(true)
	for i in range(BURST_END, TRAIL_END): slots[i].present = false
	var rockets: Variant = public_state.get("rockets", [])
	if rockets is Array:
		# Two bounded passes give local authoritative projectiles first refusal.
		for local_pass in [true, false]:
			for i in range(mini(rockets.size(), MAX_SCAN)):
				var r: Variant = rockets[i]
				if not r is Dictionary: continue
				var owner := Wire.identity(r.get("owner"))
				if (owner == local_id and local_id >= 0) != local_pass: continue
				var id := Wire.identity(r.get("id"))
				var weapon := Wire.identity(r.get("weapon"))
				var pos: Variant = Wire.point(r.get("pos"))
				var dir: Variant = Wire.point(r.get("dir"))
				if id < 0 or owner < 0 or weapon not in [1, 4, 5] or pos == null or dir == null or dir.length_squared() < 0.000001: continue
				if not bounds.has_point(pos): continue
				var slot := _find_trail(id)
				if not slot.is_empty() and slot.present: continue
				var priority := _priority(pos, local_pass)
				if slot.is_empty():
					slot = _choose(BURST_END, TRAIL_END, priority)
					if slot.is_empty(): continue
					_start(slot, 2 if weapon == 4 else 1, pos, id, priority, 2.0)
				var previous: Vector3 = slot.pos
				# A teleport/stale discontinuity must not draw a corridor through walls.
				if previous.distance_to(pos) > 12.0: previous = pos
				slot.material.set_shader_parameter("previous_position", previous)
				slot.material.set_shader_parameter("source_position", pos)
				slot.material.set_shader_parameter("source_direction", dir.normalized())
				slot.material.set_shader_parameter("source_alive", true)
				slot.pos = pos
				slot.priority = priority
				slot.age = 0.0 # current authoritative trails retain their priority
				slot.present = true
				slot.remaining = 2.0
				last_projectile_id = id
	for i in range(BURST_END, TRAIL_END):
		if not slots[i].present: slots[i].material.set_shader_parameter("source_alive", false)
	_sync_suspension()

func _find_trail(id: int) -> Dictionary:
	for i in range(BURST_END, TRAIL_END):
		if slots[i].id == id and slots[i].remaining > 0: return slots[i]
	return {}

func consume(events: Array, local_id: int = -1) -> void:
	if not configured or not active or _suspended: return
	for i in range(mini(events.size(), MAX_SCAN)):
		var event: Variant = events[i]
		if not event is Dictionary: continue
		if event.get("type") not in ["explosion", "vehicle-destroyed"]: continue
		var id := Wire.identity(event.get("id"))
		var pos: Variant = Wire.point(event.get("pos"))
		if id < 0 or pos == null or not bounds.has_point(pos):
			rejected += 1
			continue
		if id <= _highest_id - ID_WINDOW or _ids[id % ID_WINDOW] == id:
			duplicates += 1
			continue
		_highest_id = maxi(_highest_id, id)
		_ids[id % ID_WINDOW] = id
		var local := local_id >= 0 and (Wire.identity(event.get("actor")) == local_id or Wire.identity(event.get("owner")) == local_id)
		var priority := _priority(pos, local)
		var slot := _choose(0, BURST_END, priority)
		if slot.is_empty(): continue
		_start(slot, 0, pos, id, priority, 3.0)
		if event.get("weapon") == 4: slot.material.set_shader_parameter("tint", Color(0.15, 0.65, 1.0))
		last_event_id = id
		last_event_position = pos

func _priority(pos: Vector3, local: bool) -> float:
	var value := 4.0 if local else 0.0
	if is_instance_valid(camera):
		var distance := camera.global_position.distance_to(pos)
		value += 1.0 / (1.0 + distance * 0.03)
		if not camera.is_position_behind(pos): value += 1.0
	return value

func _choose(begin: int, end: int, priority: float) -> Dictionary:
	var oldest: Dictionary = slots[begin]
	for i in range(begin, end):
		var slot: Dictionary = slots[i]
		if slot.remaining <= 0: return slot
		var score := float(slot.priority) - minf(float(slot.age), 3.0)
		var oldest_score := float(oldest.priority) - minf(float(oldest.age), 3.0)
		if score < oldest_score or (is_equal_approx(score, oldest_score) and slot.serial < oldest.serial): oldest = slot
	# Age gradually releases burst priority as its visible energy fades. A stale
	# near-camera burst must not monopolize the pool over fresh visible combat.
	if priority + 0.05 < float(oldest.priority) - minf(float(oldest.age), 3.0):
		dropped += 1
		return {}
	recycled += 1
	return oldest

func _start(slot: Dictionary, profile: int, pos: Vector3, id: int, priority: float, duration: float) -> void:
	_serial += 1
	slot.merge({"remaining": duration, "id": id, "priority": priority, "serial": _serial, "pos": pos, "profile": profile, "age": 0.0}, true)
	var mat: ShaderMaterial = slot.material
	mat.set_shader_parameter("source_position", pos)
	mat.set_shader_parameter("previous_position", pos)
	mat.set_shader_parameter("profile", profile)
	mat.set_shader_parameter("event_seed", float(id % 100000))
	mat.set_shader_parameter("emitter_age", 0.0)
	mat.set_shader_parameter("source_alive", true)
	mat.set_shader_parameter("tint", Color(0.16, 0.65, 1.0) if profile == 2 else Color(0.95, 0.42, 0.1))
	slot.node.restart(true)
	slot.node.speed_scale = 0.0 if _suspended else 1.0
	slot.node.visible = not _suspended
	spawned += 1

func _ambient() -> void:
	if not ambient_enabled: return
	for i in range(TRAIL_END, POOL_SIZE):
		if slots[i].remaining > 0: continue
		# Four world-fixed quadrants, never camera-following weather. Native roots
		# provide actual collision geometry; catalog bounds retain original metres.
		var offset := Vector3(0.25 if i % 2 == 0 else 0.75, 0.0, 0.25 if i < 30 else 0.75)
		var pos := bounds.position + bounds.size * offset
		pos.y = 13.0 if map_id == "cinder-array" else 8.0
		_start(slots[i], _ambient_profile, pos, 740219 + i, -2.0, INF)
		slots[i].material.set_shader_parameter("tint", _ambient_tint)
		slots[i].material.set_shader_parameter("field_extent", Vector3(bounds.size.x * 0.24, 7.0, bounds.size.z * 0.24))

func _process(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	_sync_suspension()
	if _suspended: return
	if require_public_state and (Time.get_ticks_usec() - last_state_usec) / 1000000.0 > STALE_SECONDS:
		reset()
		return
	var dt := clampf(delta, 0.0, 0.05)
	clock += dt
	for slot: Dictionary in slots:
		if slot.remaining <= 0: continue
		slot.remaining -= dt
		slot.age += dt
		if slot.remaining <= 0:
			slot.node.emitting = false
			slot.node.speed_scale = 0.0
			slot.node.hide()
			slot.id = -1

func reset() -> void:
	active = false
	clock = 0.0
	last_public_time = -1.0
	_highest_id = -1
	_ids.fill(-1)
	last_event_id = -1
	last_projectile_id = -1
	for slot: Dictionary in slots:
		slot.remaining = 0.0
		slot.id = -1
		slot.node.emitting = false
		slot.node.speed_scale = 0.0
		slot.node.hide()
	_sync_suspension()

func snapshot() -> Dictionary:
	var allocated := 0
	var draw_slots := 0
	var emitters := 0
	var trails := 0
	var bursts := 0
	for i in range(slots.size()):
		var slot: Dictionary = slots[i]
		allocated += slot.node.amount
		if slot.node.visible and slot.remaining > 0:
			draw_slots += slot.node.amount
			emitters += 1
			if i < BURST_END: bursts += 1
			elif i < TRAIL_END: trails += 1
	return {"backend": "GPUParticles3D", "simulation": "transform-feedback" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else "RD-compute",
		"quality": quality, "budget": budget, "allocated_slots": allocated, "draw_slots": draw_slots,
		"gpu_live_readback": false, "live_count_note": "draw_slots is submitted capacity; faded/solid/depth-occluded particles do not imply visible pixels",
		"pool_nodes": slots.size(), "active_emitters": emitters, "burst_emitters": bursts, "trail_emitters": trails,
		"particle_draw_passes": emitters, "shared_meshes": 1 if configured else 0, "shared_draw_materials": 1 if configured else 0,
		"buffer_payload_estimate_bytes": allocated * 320, "buffer_estimate_backend": "Godot 4.5.2 GLES3 two 96-byte process + two 64-byte instance buffers; excludes driver overhead",
		"occupancy_bytes": occupancy.bytes.size(), "solid_cells": occupancy.solid_cells, "collision_shapes": occupancy.source_shapes,
		"unsupported_collision_shapes": occupancy.unsupported_shapes,
		"map_id": map_id, "active": active, "suspended": _suspended, "clock": clock,
		"spawned": spawned, "dropped": dropped, "recycled": recycled, "duplicates": duplicates, "rejected": rejected,
		"last_event_id": last_event_id, "last_event_position": [last_event_position.x, last_event_position.y, last_event_position.z], "last_projectile_id": last_projectile_id}
