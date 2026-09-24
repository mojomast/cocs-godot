extends Node3D
## Confirmed per-surface impact feedback for the combat composition.
##
## Authority-confirmed only: consumes public `shot`, `explosion`,
## `vehicle-destroyed` and `death` events whose endpoint or blast floor the
## composition's own map geometry (semantic blocks/terrain or built native
## colliders) confirms as a surface contact. Shots that hit an actor, shots whose
## endpoint is open air, and defeats already covered by the integrated
## weapon-effects path (`surface_hit` + valid normal) are skipped, never faked.
##
## Two bounded pools, both preallocated so an impact never allocates:
## - `effects`: the short material burst (flash billboard pair) at the endpoint.
##   F9 Low/High/Extreme caps 6/12/20, lives 0.18/0.28/0.32 s.
## - `marks`: persistent shader-based surface damage (pock/crack per material
##   family, scorch for blasts, shockwave band for large blasts) owned by
##   res://player_fx/mark_pool.gd and drawn with res://player_fx/mark.gdshader.
##   F9 Low/High/Extreme caps 20/44/72, lives 6/14/22 s.
##
## Every visible effect is placed at the authoritative endpoint (or the confirmed
## blast floor) and offset along the confirmed normal; occluded, behind-viewer
## and over-distance contacts are skipped and counted, and each authoritative
## public event ID is consumed once. Materials are per pooled slot, so no
## per-impact allocation happens.

const Surface = preload("res://player_fx/surface.gd")
const MarkPool = preload("res://player_fx/mark_pool.gd")

const LIMITS := [6, 12, 20] # F9 Low / High / Extreme (burst pool)
const LIVES := [0.18, 0.28, 0.32]
const PROBE := 0.06
const MAX_DISTANCE := 70.0
const FLOOR_BAND := 1.5
const EVENT_WINDOW := 4096
const MAX_EVENTS := 512

# Persistent surface damage: metres per material family. Hard surfaces read
# tighter than dirt; Low widens slightly because fewer pixels carry the read.
const MARK_SIZES := {"metal": 0.24, "stone": 0.30, "ice": 0.32, "ground": 0.38}
const MARK_MIN_SIZE := 0.09
const MARK_EDGE_SHRINK := 0.5
const LOW_QUALITY_GAIN := 1.15

# Blast treatment. Large blasts (rockets, grenade launchers, alt-fire explosives,
# vehicle kills, or any event carrying radius >= 3) also get a shockwave band.
const BLAST_REACH := 6.0
const BLAST_STEP := 0.25
const BLAST_SIZE_SMALL := 1.7
const BLAST_SIZE_LARGE := 2.8
const DEATH_SCORCH_SIZE := 1.1
const LARGE_BLAST_WEAPONS := [1, 5] # Rocket Launcher, Grenade Launcher
const EXPLOSIVE_DEATH_STYLES := ["combust"] # authoritative fire deaths only
const BLAST_MAX_DISTANCE := 80.0
const PUFF_SECONDS := 0.5
const PUFF_COLORS := {
	"metal": Color(0.72, 0.7, 0.66, 1.0),
	"stone": Color(0.74, 0.68, 0.58, 1.0),
	"ice": Color(0.82, 0.92, 0.98, 1.0),
	"ground": Color(0.66, 0.55, 0.4, 1.0),
}

const COLORS := {
	"metal": [Color(1.0, 0.95, 0.62, 1.0), Color(0.72, 0.72, 0.8, 0.45)],
	"stone": [Color(0.98, 0.93, 0.84, 1.0), Color(0.62, 0.56, 0.5, 0.5)],
	"ice": [Color(0.78, 1.0, 1.0, 1.0), Color(0.6, 0.86, 0.96, 0.45)],
	"ground": [Color(1.0, 0.74, 0.36, 1.0), Color(0.54, 0.42, 0.3, 0.55)],
}

const FLASH := 0
const PUFF := 1

var camera: Camera3D
var occlusion # RefCounted duck type: segment_blocked/ready/bodies/collision_root/boxes/terrain
var map: Dictionary = {}
var quality := 1
var marks: Node3D
var effects: Array[Dictionary] = []
var seen: Dictionary = {}
var highest_event := -1
var clock := 0.0
var last_family := ""
var last_mark_kind := -1
var last_blast := ""
var counters := {
	"shown": 0, "actor_hits": 0, "no_geometry": 0, "occluded": 0, "legacy": 0,
	"deduped": 0, "dropped": 0, "probes": 0, "confirmed": 0, "too_far": 0,
	# Persistent marks (player_fx/mark_pool.gd mirrors into marks_live/placed/
	# recycled/expired/denied after every consume/advance/reset).
	"marks_live": 0, "marks_placed": 0, "marks_recycled": 0, "marks_expired": 0, "marks_denied": 0,
	"marks_skipped_occluded": 0, "marks_skipped_far": 0, "marks_skipped_edge": 0, "marks_dropped": 0,
	# Blast treatment.
	"blasts_seen": 0, "scorches_placed": 0, "death_scorches": 0, "shockwaves_placed": 0,
	"blasts_skipped_no_ground": 0, "blasts_skipped_occluded": 0, "blasts_skipped_far": 0, "puffs": 0,
}

func _init() -> void:
	marks = MarkPool.new()
	add_child(marks)

func configure(view: Camera3D, context) -> void:
	camera = view
	occlusion = context
	_resize()
	if is_instance_valid(marks):
		marks.configure(view)
		marks.set_quality(quality)

func set_map(value: Dictionary) -> void:
	map = value

func set_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	_resize()
	if quality == 0:
		for effect: Dictionary in effects: effect.dust.visible = false
	if is_instance_valid(marks): marks.set_quality(quality)

func limit() -> int:
	return int(LIMITS[quality])

func life() -> float:
	return float(LIVES[quality])

func mark_limit() -> int:
	return marks.limit() if is_instance_valid(marks) else 0

func mark_life() -> float:
	return marks.life() if is_instance_valid(marks) else 0.0

func reset() -> void:
	seen.clear()
	highest_event = -1
	clock = 0.0
	for effect: Dictionary in effects:
		effect.remaining = 0.0
		effect.core.visible = false
		effect.dust.visible = false
	for key: String in counters: counters[key] = 0
	last_family = ""
	last_mark_kind = -1
	last_blast = ""
	if is_instance_valid(marks): marks.reset()

## Preallocated burst pool. `_resize` only runs on configure/quality changes, so
## an impact never allocates a node or material.
func _resize() -> void:
	while effects.size() > limit():
		var effect: Dictionary = effects.pop_back()
		effect.core.free()
		effect.dust.free()
	while effects.size() < limit():
		effects.append(_make_effect())

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
	return {"core": core, "dust": dust, "remaining": 0.0, "life": float(LIVES[quality]),
		"family": "", "progress": 0.0, "base": 0.0, "kind": FLASH, "strength": 1.0}

func _idle() -> Dictionary:
	for effect: Dictionary in effects:
		if effect.remaining <= 0.0: return effect
	return {}

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
		var event_type := str(event.get("type", ""))
		if event_type == "shot":
			_shot(event)
		elif event_type == "explosion" or event_type == "vehicle-destroyed":
			_blast(event, false)
		elif event_type == "death":
			_blast(event, true)
	_sync_marks()

## Confirmed shot: burst flash at the authoritative endpoint plus one persistent
## pock on the confirmed surface.
func _shot(event: Dictionary) -> void:
	if not _fresh(event): return
	if identity(event.get("hit")) >= 0:
		counters.actor_hits += 1 # Authority confirmed an actor hit, not a surface.
		return
	var normal: Variant = point(event.get("normal"))
	if event.get("surface_hit") == true and normal != null and normal.length() > 0.9 and normal.length() < 1.1:
		counters.legacy += 1 # The integrated weapon-effects path already draws it.
		return
	var from: Variant = point(event.get("from"))
	var to: Variant = point(event.get("to"))
	if from == null or to == null: return
	var offset: Vector3 = to - from
	var distance := offset.length()
	if distance < 0.6 or distance > 400.0: return
	var direction := offset / distance
	var probe := _probe(to, direction, true, true)
	if probe.is_empty(): return
	counters.confirmed += 1
	_spawn(to, probe.normal, probe.family)
	var seed := float(posmod(identity(event.get("id")), 100000))
	_place_mark(probe.get("point", to), probe.normal, probe.family, MarkPool.POCK, _mark_size(probe.family), seed)
	_sync_marks()

## Explosion / vehicle kill / burning death: scorch on the confirmed surface
## under the blast, a bounded dust puff, and (large blasts) one shockwave band.
func _blast(event: Dictionary, death: bool) -> void:
	if not _fresh(event): return
	if death and not EXPLOSIVE_DEATH_STYLES.has(str(event.get("style", ""))):
		return # Only authoritative fire deaths scar the ground; never every kill.
	var origin: Variant = point(event.get("pos"))
	if origin == null: return
	counters.blasts_seen += 1
	var surface := _blast_surface(origin)
	if surface.is_empty(): return
	var family := str(surface.family)
	var id := identity(event.get("id"))
	var seed := float(posmod(id, 100000))
	var large := (not death) and _large_blast(event)
	var size: float = DEATH_SCORCH_SIZE if death else (BLAST_SIZE_LARGE if large else BLAST_SIZE_SMALL)
	size *= LOW_QUALITY_GAIN if quality == 0 else 1.0
	if _place_mark(surface.position, surface.normal, family, MarkPool.SCORCH, size, seed):
		counters.scorches_placed += 1
		if death: counters.death_scorches += 1
		last_blast = "death" if death else ("large" if large else "small")
	if large and quality > 0:
		if marks.place_ring(surface.position, surface.normal, size * 1.15, seed + 3.0):
			counters.shockwaves_placed += 1
	_puff(surface.position, surface.normal, family, 1.0 if large else 0.8, PUFF_SECONDS)
	_sync_marks()

## Confirm the authoritative endpoint against map geometry and derive the
## normal/material family from that same context.
func _probe(to: Vector3, direction: Vector3, tally := true, for_mark := false) -> Dictionary:
	if not is_instance_valid(camera) or occlusion == null: return {}
	if not bool(occlusion.ready): return {}
	if tally: counters.probes += 1
	if not bool(occlusion.segment_blocked(to - direction * PROBE, to + direction * PROBE)):
		if tally: counters.no_geometry += 1
		return {}
	if camera.is_position_behind(to):
		if tally: counters.occluded += 1
		if for_mark: counters.marks_skipped_occluded += 1
		return {}
	if camera.global_position.distance_to(to) > MAX_DISTANCE:
		if tally: counters.too_far += 1
		if for_mark: counters.marks_skipped_far += 1
		return {}
	if bool(occlusion.segment_blocked(camera.global_position, to)):
		if tally: counters.occluded += 1
		if for_mark: counters.marks_skipped_occluded += 1
		return {}
	return _surface_at(to, direction)

## The first authoritative surface on the normal axis at `to`, with no camera or
## counter side effects. `_probe` wraps it for shot endpoints; `_blast_surface`
## walks it downward for blast floors.
func _surface_at(to: Vector3, direction: Vector3) -> Dictionary:
	var floor_y := 0.0
	var bounds: Variant = map.get("bounds")
	if bounds is AABB: floor_y = bounds.position.y
	var collision_root: Variant = occlusion.collision_root
	if is_instance_valid(collision_root):
		return _probe_native(to, direction, floor_y)
	return _probe_semantic(to, direction)

func _probe_native(to: Vector3, direction: Vector3, floor_y: float) -> Dictionary:
	var result := {"normal": -direction, "family": Surface.classify(map, "", "", false), "name": "", "point": to}
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
			var hit_point: Variant = hit.get("position")
			return {"normal": hit.normal, "family": Surface.classify(map, name, "", ground), "name": name,
				"point": hit_point if hit_point is Vector3 else to}
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
	if terrain is TriangleMesh:
		var crossing: Variant = terrain.intersect_segment(to - direction * PROBE, to + direction * PROBE)
		if crossing is PackedVector3Array and not (crossing as PackedVector3Array).is_empty():
			return {"normal": Vector3.UP, "family": Surface.GROUND, "name": "support", "point": (crossing as PackedVector3Array)[0]}
		if crossing is Vector3:
			return {"normal": Vector3.UP, "family": Surface.GROUND, "name": "support", "point": crossing}
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
		var candidate := {"normal": normal, "family": Surface.classify(map, hint, str(block.get("kind", "")), ground), "kind": str(block.get("kind", "")),
			"point": _face_point(to, box, normal)}
		var delta := (to - box.get_center()).length()
		if delta < best_distance:
			best_distance = delta
			best = candidate
	if not best.is_empty(): return best
	if bool(occlusion.implicit_floor) and to.y <= PROBE * 2.0:
		return {"normal": Vector3.UP, "family": Surface.GROUND, "name": "floor", "point": Vector3(to.x, 0.0, to.z)}
	return {}

## Snap a probe point onto the chosen box face so marks sit exactly in the
## confirmed plane instead of a probe-length away from it.
static func _face_point(to: Vector3, box: AABB, normal: Vector3) -> Vector3:
	var point := to
	if absf(normal.x) > 0.5:
		point.x = box.position.x if normal.x < 0.0 else box.position.x + box.size.x
	elif absf(normal.y) > 0.5:
		point.y = box.position.y if normal.y < 0.0 else box.position.y + box.size.y
	elif absf(normal.z) > 0.5:
		point.z = box.position.z if normal.z < 0.0 else box.position.z + box.size.z
	return point

## First surface directly below a blast origin, bounded by BLAST_REACH, then the
## same camera/occlusion confirmation shots get. Never guesses a floor.
func _blast_surface(origin: Vector3) -> Dictionary:
	if not is_instance_valid(camera) or occlusion == null or not bool(occlusion.ready): return {}
	if camera.global_position.distance_to(origin) > BLAST_MAX_DISTANCE:
		counters.blasts_skipped_far += 1
		return {}
	var contact := {}
	var point := Vector3.ZERO
	var steps := int(BLAST_REACH / BLAST_STEP)
	for index in range(1, steps + 1):
		var candidate := origin + Vector3.DOWN * (float(index) * BLAST_STEP)
		contact = _surface_at(candidate, Vector3.DOWN)
		if not contact.is_empty():
			var snap: Variant = contact.get("point")
			point = snap if snap is Vector3 else candidate
			break
	if contact.is_empty():
		counters.blasts_skipped_no_ground += 1
		return {}
	if camera.is_position_behind(point):
		counters.blasts_skipped_occluded += 1
		return {}
	if camera.global_position.distance_to(point) > BLAST_MAX_DISTANCE:
		counters.blasts_skipped_far += 1
		return {}
	if bool(occlusion.segment_blocked(camera.global_position, point)):
		counters.blasts_skipped_occluded += 1
		return {}
	return {"position": point, "normal": contact.normal, "family": contact.family}

## Large-blast classification used only for presentation size and the shockwave.
## Rockets/grenades are index 1/5 in the public weapon table; alt-fire explosives
## and vehicle kills always count; any event carrying a real radius >= 3 counts.
static func _large_blast(event: Dictionary) -> bool:
	if str(event.get("type", "")) == "vehicle-destroyed": return true
	if event.get("alt") == true: return true
	var radius: Variant = event.get("radius")
	if (radius is int or radius is float) and is_finite(float(radius)) and float(radius) >= 3.0: return true
	return identity(event.get("weapon")) in LARGE_BLAST_WEAPONS

func _mark_size(family: String) -> float:
	var base: float = MARK_SIZES.get(family, MARK_SIZES["stone"])
	return base * (LOW_QUALITY_GAIN if quality == 0 else 1.0)

## Edge / corner guard. A mark may only be drawn when the normal axis is still a
## confirmed surface at every quad corner, so a mark near a wall edge is shrunk
## once and skipped rather than drawn floating past the edge.
func _mark_flat(point: Vector3, normal: Vector3, basis: Basis, size: float) -> bool:
	if occlusion == null or not bool(occlusion.ready): return true
	var reach := PROBE * 2.0 + size * 0.6
	var half := size * 0.5
	var corners: Array[Vector3] = [Vector3.ZERO, basis.x * half, -basis.x * half, basis.y * half, -basis.y * half]
	for corner: Vector3 in corners:
		var probe := point + corner
		if not bool(occlusion.segment_blocked(probe + normal * PROBE, probe - normal * reach)): return false
	return true

func _place_mark(at: Vector3, normal: Vector3, family: String, kind: int, size: float, seed: float) -> bool:
	if not is_instance_valid(marks) or not marks.enabled: return false
	var unit := normal.normalized()
	if unit.length_squared() < 0.25: return false
	var width := maxf(size, MARK_MIN_SIZE)
	var basis := MarkPool.basis(unit, seed)
	if not _mark_flat(at, unit, basis, width):
		width = maxf(width * MARK_EDGE_SHRINK, 0.0)
		basis = MarkPool.basis(unit, seed + 0.5)
		if width < MARK_MIN_SIZE or not _mark_flat(at, unit, basis, width):
			counters.marks_skipped_edge += 1
			return false
	if not marks.place(at, unit, family, kind, width, seed):
		counters.marks_dropped += 1
		return false
	last_mark_kind = kind
	return true

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
	effect.kind = FLASH
	effect.strength = 1.0
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

## Bounded dust/debris puff attached to the confirmed blast floor. Uses the same
## preallocated burst slots as the flash; it never allocates.
func _puff(at: Vector3, normal: Vector3, family: String, strength: float, seconds: float) -> void:
	var effect := _idle()
	if effect.is_empty():
		counters.dropped += 1
		return
	var unit := normal.normalized()
	effect.family = family
	effect.kind = PUFF
	effect.strength = clampf(strength, 0.2, 1.5)
	effect.base = 0.5
	effect.life = maxf(seconds, 0.05)
	effect.remaining = effect.life
	effect.progress = 0.0
	effect.core.visible = false
	effect.dust.material_override.albedo_color = PUFF_COLORS.get(family, PUFF_COLORS["stone"])
	effect.dust.global_position = at + unit * 0.08
	effect.dust.scale = Vector3.ONE * 0.5
	effect.dust.visible = quality > 0
	counters.puffs += 1

func _sync_marks() -> void:
	if not is_instance_valid(marks): return
	var state: Dictionary = marks.snapshot()
	counters.marks_live = int(state.live)
	counters.marks_placed = int(state.counters.placed)
	counters.marks_recycled = int(state.counters.recycled)
	counters.marks_expired = int(state.counters.expired)
	counters.marks_denied = int(state.counters.denied)

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
		var dust: MeshInstance3D = effect.dust
		if int(effect.kind) == PUFF:
			core.visible = false
			dust.visible = quality > 0 and effect.remaining > 0.0
			dust.scale = Vector3.ONE * lerpf(0.5, 2.6, progress) * float(effect.strength)
			dust.material_override.albedo_color.a = effect.base * fade
		else:
			core.visible = effect.remaining > 0.0
			core.scale = Vector3.ONE * lerpf(0.55, 1.5, progress)
			core.material_override.albedo_color.a = effect.base * fade
			dust.visible = quality > 0 and effect.remaining > 0.0
			dust.scale = Vector3.ONE * lerpf(0.45, 1.35, progress)
			dust.material_override.albedo_color.a = 0.5 * fade
		if effect.remaining <= 0.0:
			core.visible = false
			dust.visible = false
	if is_instance_valid(marks): marks.advance(dt)
	_sync_marks()

func snapshot() -> Dictionary:
	var active := 0
	for effect: Dictionary in effects:
		if effect.remaining > 0.0: active += 1
	_sync_marks()
	var mark_state: Dictionary = marks.snapshot() if is_instance_valid(marks) else {}
	return {
		"pool": effects.size(), "limit": limit(), "active": active,
		"family": last_family, "quality": quality, "counters": counters.duplicate(),
		"mark_family": str(mark_state.get("family", "")), "mark_kind": last_mark_kind, "blast": last_blast,
		"marks_pool": int(mark_state.get("pool", 0)), "marks_limit": mark_limit(),
		"marks_live": int(mark_state.get("live", 0)), "marks_life": mark_life(),
		"marks_counters": mark_state.get("counters", {}),
	}
