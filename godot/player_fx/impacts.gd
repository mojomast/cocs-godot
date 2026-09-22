extends Node3D
## Confirmed per-surface impact feedback for the combat composition.
##
## Authority-confirmed only: consumes public `shot` events whose endpoint the
## composition's own map geometry (semantic blocks/terrain or built native
## colliders) confirms as a surface contact. Shots that hit an actor, shots
## whose endpoint is open air, and defeats already covered by the integrated
## weapon-effects path (`surface_hit` + valid normal) are skipped, never faked.
##
## Every visible effect is a shared-mesh billboard quad pair placed at the
## authoritative endpoint and offset along the confirmed normal; the pool is
## bounded, occluded impacts are skipped, and each event public ID is consumed
## once. Materials are per pooled slot, so no per-impact allocation happens.

const Surface = preload("res://player_fx/surface.gd")

const LIMITS := [6, 12, 20] # F9 Low / High / Extreme
const LIVES := [0.18, 0.28, 0.32]
const PROBE := 0.06
const MAX_DISTANCE := 70.0
const FLOOR_BAND := 1.5
const EVENT_WINDOW := 4096
const MAX_EVENTS := 512

const COLORS := {
	"metal": [Color(1.0, 0.95, 0.62, 1.0), Color(0.72, 0.72, 0.8, 0.45)],
	"stone": [Color(0.98, 0.93, 0.84, 1.0), Color(0.62, 0.56, 0.5, 0.5)],
	"ice": [Color(0.78, 1.0, 1.0, 1.0), Color(0.6, 0.86, 0.96, 0.45)],
	"ground": [Color(1.0, 0.74, 0.36, 1.0), Color(0.54, 0.42, 0.3, 0.55)],
}

var camera: Camera3D
var occlusion # RefCounted duck type: segment_blocked/ready/bodies/collision_root/boxes/terrain
var map: Dictionary = {}
var quality := 1
var effects: Array[Dictionary] = []
var seen: Dictionary = {}
var highest_event := -1
var clock := 0.0
var last_family := ""
var counters := {"shown": 0, "actor_hits": 0, "no_geometry": 0, "occluded": 0, "legacy": 0, "deduped": 0, "dropped": 0, "probes": 0, "confirmed": 0, "too_far": 0}

func configure(view: Camera3D, context) -> void:
	camera = view
	occlusion = context
	_trim()

func set_map(value: Dictionary) -> void:
	map = value

func set_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	_trim()
	if quality == 0:
		for effect: Dictionary in effects: effect.dust.visible = false

func limit() -> int:
	return int(LIMITS[quality])

func life() -> float:
	return float(LIVES[quality])

func reset() -> void:
	seen.clear()
	highest_event = -1
	clock = 0.0
	for effect: Dictionary in effects:
		effect.remaining = 0.0
		effect.core.visible = false
		effect.dust.visible = false
	counters.shown = 0
	counters.actor_hits = 0
	counters.no_geometry = 0
	counters.occluded = 0
	counters.legacy = 0
	counters.deduped = 0
	counters.dropped = 0
	counters.probes = 0
	counters.confirmed = 0
	counters.too_far = 0
	last_family = ""

func _trim() -> void:
	while effects.size() > limit():
		var effect: Dictionary = effects.pop_back()
		effect.core.free()
		effect.dust.free()

func _claim() -> Dictionary:
	var effect := _make_effect()
	effects.append(effect)
	return effect

func _make_effect() -> Dictionary:
	var core_material := StandardMaterial3D.new()
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	core_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	core_material.no_depth_test = true
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.15
	core_mesh.height = 0.3
	core_mesh.radial_segments = 8
	core_mesh.rings = 4
	core.mesh = core_mesh
	core.material_override = core_material
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.visible = false
	add_child(core)
	var dust_material := StandardMaterial3D.new()
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust_material.no_depth_test = true
	var dust := MeshInstance3D.new()
	dust.mesh = QuadMesh.new()
	dust.mesh.size = Vector2(0.8, 0.8)
	dust.material_override = dust_material
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.visible = false
	add_child(dust)
	return {"core": core, "dust": dust, "remaining": 0.0, "life": float(LIVES[quality]), "family": "", "progress": 0.0, "base": 0.0}

func _idle() -> Dictionary:
	for effect: Dictionary in effects:
		if effect.remaining <= 0.0: return effect
	if effects.size() >= limit(): return {}
	return _claim()

static func point(value: Variant) -> Variant:
	if not value is Dictionary: return null
	for key: String in ["x", "y", "z"]:
		if not (value.get(key) is int or value.get(key) is float): return null
		if not is_finite(float(value[key])): return null
	return Vector3(value.x, value.y, value.z)

static func identity(value: Variant) -> int:
	if not (value is int or value is float): return -1
	var numeric := float(value)
	if not is_finite(numeric) or numeric < 0.0 or numeric > 9007199254740991.0 or floorf(numeric) != numeric: return -1
	return int(numeric)

func _fresh(item: Dictionary) -> bool:
	var id := identity(item.get("id"))
	if id < 0: return true
	if id <= highest_event - EVENT_WINDOW or seen.has(id):
		counters.deduped += 1
		return false
	highest_event = maxi(highest_event, id)
	seen[id] = true
	for old: int in seen.keys():
		if old <= highest_event - EVENT_WINDOW: seen.erase(old)
	return true

func consume(items: Array, _local_id: int) -> void:
	for item: Variant in items.slice(0, MAX_EVENTS):
		if not item is Dictionary: continue
		var event: Dictionary = item
		if event.get("type") != "shot": continue
		if not _fresh(event): continue
		if identity(event.get("hit")) >= 0:
			counters.actor_hits += 1 # Authority confirmed an actor hit, not a surface.
			continue
		var normal: Variant = point(event.get("normal"))
		if event.get("surface_hit") == true and normal != null and normal.length() > 0.9 and normal.length() < 1.1:
			counters.legacy += 1 # The integrated weapon-effects path already draws it.
			continue
		var from: Variant = point(event.get("from"))
		var to: Variant = point(event.get("to"))
		if from == null or to == null: continue
		var offset: Vector3 = to - from
		var distance := offset.length()
		if distance < 0.6 or distance > 400.0: continue
		var direction := offset / distance
		var probe := _probe(to, direction)
		if probe.is_empty(): continue
		counters.confirmed += 1
		_spawn(to, probe.normal, probe.family)

## Confirm the authoritative endpoint against map geometry and derive the
## normal/material family from that same context.
func _probe(to: Vector3, direction: Vector3) -> Dictionary:
	if not is_instance_valid(camera) or occlusion == null: return {}
	if not bool(occlusion.ready): return {}
	counters.probes += 1
	if not bool(occlusion.segment_blocked(to - direction * PROBE, to + direction * PROBE)):
		counters.no_geometry += 1
		return {}
	if camera.is_position_behind(to):
		counters.occluded += 1
		return {}
	if camera.global_position.distance_to(to) > MAX_DISTANCE:
		counters.too_far += 1
		return {}
	if bool(occlusion.segment_blocked(camera.global_position, to)):
		counters.occluded += 1
		return {}
	var floor_y := 0.0
	var bounds: Variant = map.get("bounds")
	if bounds is AABB: floor_y = bounds.position.y
	var collision_root: Variant = occlusion.collision_root
	if is_instance_valid(collision_root):
		return _probe_native(to, direction, floor_y)
	return _probe_semantic(to, direction)

func _probe_native(to: Vector3, direction: Vector3, floor_y: float) -> Dictionary:
	var result := {"normal": -direction, "family": Surface.classify(map, "", "", false), "name": ""}
	var space := camera.get_world_3d().direct_space_state
	if space == null: return result
	var query := PhysicsRayQueryParameters3D.create(to + direction * PROBE, to - direction * PROBE)
	query.hit_from_inside = true
	query.hit_back_faces = true
	var excluded: Array[RID] = []
	for _attempt in range(12):
		query.exclude = excluded
		var hit := space.intersect_ray(query)
		if hit.is_empty(): break
		if occlusion.bodies.has(hit.rid):
			var name := _node_path(hit.collider)
			var ground: bool = hit.normal.y >= 0.7 and to.y <= floor_y + FLOOR_BAND
			return {"normal": hit.normal, "family": Surface.classify(map, name, "", ground), "name": name}
		excluded.append(hit.rid)
	return result

func _node_path(node: Variant) -> String:
	if not node is Node: return ""
	var parts := PackedStringArray()
	var current := node as Node
	var root: Variant = occlusion.collision_root
	for _step in range(24):
		if current == null or current == root: break
		parts.append(String(current.name))
		current = current.get_parent()
	return "/".join(parts)

func _probe_semantic(to: Vector3, direction: Vector3) -> Dictionary:
	var terrain: Variant = occlusion.terrain
	if terrain is TriangleMesh and not terrain.intersect_segment(to - direction * PROBE, to + direction * PROBE).is_empty():
		return {"normal": Vector3.UP, "family": Surface.GROUND, "name": "support"}
	var blocks: Array = map.get("blocks", []) if map.get("blocks", []) is Array else []
	var boxes: Array = occlusion.boxes if occlusion.boxes is Array else []
	var best := {}
	var best_distance := INF
	for index: int in range(mini(blocks.size(), boxes.size())):
		var box: AABB = boxes[index]
		if not blocks[index] is Dictionary: continue
		if not box.has_point(to + direction * PROBE) and not box.has_point(to - direction * PROBE) and box.intersects_segment(to - direction * PROBE, to + direction * PROBE) == null: continue
		var block: Dictionary = blocks[index]
		var relative := to - box.get_center()
		var normal := Vector3.ZERO
		if absf(relative.x) / maxf(box.size.x, 0.001) >= absf(relative.y) / maxf(box.size.y, 0.001) and absf(relative.x) / maxf(box.size.x, 0.001) >= absf(relative.z) / maxf(box.size.z, 0.001):
			normal = Vector3(signf(relative.x), 0, 0)
		elif absf(relative.y) / maxf(box.size.y, 0.001) >= absf(relative.z) / maxf(box.size.z, 0.001):
			normal = Vector3(0, signf(relative.y), 0)
		else:
			normal = Vector3(0, 0, signf(relative.z))
		if normal == Vector3.ZERO: normal = -direction
		var top := box.position.y + box.size.y
		var ground := normal.y >= 0.7 and absf(to.y - top) <= PROBE * 2.0 and box.size.y <= FLOOR_BAND
		var hint := str(block.get("material", ""))
		var candidate := {"normal": normal, "family": Surface.classify(map, hint, str(block.get("kind", "")), ground), "kind": str(block.get("kind", ""))}
		var delta := (to - box.get_center()).length()
		if delta < best_distance:
			best_distance = delta
			best = candidate
	if not best.is_empty(): return best
	if bool(occlusion.implicit_floor) and to.y <= PROBE * 2.0:
		return {"normal": Vector3.UP, "family": Surface.GROUND, "name": "floor"}
	return {}

func _spawn(at: Vector3, normal: Vector3, family: String) -> void:
	var effect := _idle()
	if effect.is_empty():
		counters.dropped += 1
		return
	var core: MeshInstance3D = effect.core
	var dust: MeshInstance3D = effect.dust
	var palette: Array = COLORS.get(family, COLORS[Surface.STONE])
	core.material_override.albedo_color = palette[0]
	dust.material_override.albedo_color = palette[1]
	effect.family = family
	effect.life = life()
	effect.remaining = effect.life
	effect.progress = 0.0
	effect.base = 1.0 if quality > 0 else 0.72
	last_family = family
	counters.shown += 1
	var safe_normal := normal if normal.length() > 0.5 else Vector3.UP
	core.global_position = at + safe_normal * 0.02
	dust.global_position = at + safe_normal * 0.05
	core.visible = true
	dust.visible = quality > 0

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	var dt := minf(delta, 2.0)
	clock += dt
	for effect: Dictionary in effects:
		if effect.remaining <= 0.0: continue
		effect.remaining = maxf(0.0, effect.remaining - dt)
		var progress: float = 1.0 - effect.remaining / maxf(effect.life, 0.001)
		effect.progress = progress
		var fade: float = (1.0 - progress)
		var core: MeshInstance3D = effect.core
		core.visible = effect.remaining > 0.0
		core.scale = Vector3.ONE * lerpf(0.55, 1.5, progress)
		core.material_override.albedo_color.a = effect.base * fade
		var dust: MeshInstance3D = effect.dust
		dust.visible = quality > 0 and effect.remaining > 0.0
		dust.scale = Vector3.ONE * lerpf(0.45, 1.35, progress)
		dust.material_override.albedo_color.a = 0.5 * fade
		if effect.remaining <= 0.0:
			core.visible = false
			dust.visible = false

func snapshot() -> Dictionary:
	var active := 0
	for effect: Dictionary in effects:
		if effect.remaining > 0.0: active += 1
	return {"pool": effects.size(), "limit": limit(), "active": active, "family": last_family, "quality": quality, "counters": counters.duplicate()}
