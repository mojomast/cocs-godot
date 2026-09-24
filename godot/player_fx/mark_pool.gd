extends Node3D
## Bounded pool of persistent surface-damage decals for the impact FX lane.
##
## Every mark is one quad drawn with res://player_fx/mark.gdshader: an analytic
## height field shaded as a displaced surface (dark pock, bright rim, radial
## cracks) so damage reads as geometry, not as a flat sprite. The quad lies in
## the caller-confirmed surface plane, offset along the confirmed normal, and
## world depth testing stays enabled, so a mark behind opaque cover can never
## change a pixel.
##
## Rules kept deliberately honest:
## - The pool is preallocated at configure/set_quality time. Placing a mark never
##   allocates a node, material or resource; when the pool is full the oldest
##   live mark is recycled into the new one and counted.
## - Lifetimes and caps are the F9 quality table below. A mark fades over the
##   last FADE fraction of its life and retires exactly at the end.
## - Nothing is inferred from gameplay state: callers pass a surface point and a
##   normal they already confirmed against authoritative geometry.
## - `enabled` is an evidence-only switch (the capture harness renders the same
##   event with and without persistent marks); it never changes gameplay.

const MarkShader = preload("res://player_fx/mark.gdshader")

const POCK := 0
const SCORCH := 1
const RING := 2

## F9 Low / High / Extreme. Pool cap equals concurrent cap: a new mark recycles
## the oldest live slot rather than growing the node count.
const LIMITS := [20, 44, 72]
## Documented mark lifetimes in seconds. Low keeps a short memory for weak hosts;
## Extreme keeps damage readable across a long fight.
const LIVES := [6.0, 14.0, 22.0]
const RING_SECONDS := 0.45
const RING_START_SCALE := 0.35
const FADE := 0.35 # alpha fades over this fraction of life, at the end
const OFFSET := 0.02
const OFFSET_PER_SIZE := 0.012
const MAX_MARKS_SEEN := 1000.0

var camera: Camera3D
var quality := 1
var enabled := true
var slots: Array[Dictionary] = []
var clock := 0.0
var last_family := ""
var last_kind := -1
var counters := {"placed": 0, "recycled": 0, "expired": 0, "denied": 0}
var _serial := 0
var _shared_mesh: QuadMesh

func _init() -> void:
	_shared_mesh = QuadMesh.new()
	_shared_mesh.size = Vector2.ONE

func configure(view: Camera3D) -> void:
	camera = view
	_resize()

func set_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	_resize()

func set_enabled(value: bool) -> void:
	enabled = value

func limit() -> int:
	return int(LIMITS[quality])

func life() -> float:
	return float(LIVES[quality])

func ready() -> bool:
	return is_instance_valid(camera) and not slots.is_empty()

## Number of live marks. O(pool) and allocation-free; pools are <= 72.
func live() -> int:
	var count := 0
	for slot: Dictionary in slots:
		if slot.remaining > 0.0: count += 1
	return count

func _resize() -> void:
	while slots.size() > limit():
		var slot: Dictionary = slots.pop_back()
		slot.node.free()
	while slots.size() < limit():
		slots.append(_make_slot())

func _make_slot() -> Dictionary:
	var material := ShaderMaterial.new()
	material.shader = MarkShader
	var node := MeshInstance3D.new()
	node.mesh = _shared_mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return {"node": node, "material": material, "remaining": 0.0, "life": 0.0, "age": 0.0,
		"serial": 0, "family": "", "kind": -1, "size": 1.0, "strength": 1.0, "compiled": false}

## Oldest-live eviction. The pool never grows: a full pool recycles a slot and
## reports it through counters.recycled, so the counters always explain the cap.
func _acquire() -> Dictionary:
	var free := {}
	var oldest := {}
	for slot: Dictionary in slots:
		if slot.remaining <= 0.0:
			if free.is_empty(): free = slot
			continue
		if oldest.is_empty() or int(slot.serial) < int(oldest.serial): oldest = slot
	if not free.is_empty(): return free
	if not oldest.is_empty():
		counters.recycled += 1
		return oldest
	counters.denied += 1
	return {}

## Place one pooled mark. `at`/`normal` must come from a confirmed surface.
## Returns false when the pool is disabled or not configured.
func place(at: Vector3, normal: Vector3, family: String, kind: int, size: float, seed: float,
		life_seconds: float = -1.0, strength: float = 1.0) -> bool:
	if not enabled or slots.is_empty() or not at.is_finite() or not normal.is_finite():
		counters.denied += 1
		return false
	var unit := normal.normalized()
	if unit.length_squared() < 0.25: # Zero/NaN normal: never fabricate a plane.
		counters.denied += 1
		return false
	var duration := life() if not (life_seconds > 0.0) else life_seconds
	if kind == RING: duration = RING_SECONDS
	var slot := _acquire()
	if slot.is_empty(): return false
	_serial += 1
	slot.serial = _serial
	slot.remaining = duration
	slot.life = duration
	slot.age = 0.0
	slot.family = family
	slot.kind = kind
	slot.size = maxf(0.06, size)
	slot.strength = clampf(strength, 0.05, 1.0)
	var material: ShaderMaterial = slot.material
	if not bool(slot.compiled):
		# First use of a preallocated slot: bind the shader once. No allocation.
		material.shader = MarkShader
		slot.compiled = true
	material.set_shader_parameter("family", _family_index(family))
	material.set_shader_parameter("kind", kind)
	material.set_shader_parameter("seed", fmod(seed, MAX_MARKS_SEEN))
	material.set_shader_parameter("opacity", slot.strength)
	material.set_shader_parameter("age", 0.0)
	material.set_shader_parameter("detail", 1.0 if quality > 0 else 0.0)
	material.set_shader_parameter("progress", 0.0)
	var basis := _basis(unit, seed)
	var node: MeshInstance3D = slot.node
	node.global_transform = Transform3D(basis, at + unit * (OFFSET + OFFSET_PER_SIZE * slot.size))
	node.scale = Vector3(slot.size, slot.size, 1.0)
	node.visible = true
	counters.placed += 1
	last_family = family
	last_kind = kind
	return true

## Short-lived shockwave band for large blasts (kind RING).
func place_ring(at: Vector3, normal: Vector3, size: float, seed: float) -> bool:
	return place(at, normal, "ground", RING, size, seed, RING_SECONDS)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	var dt := minf(delta, 2.0)
	clock += dt
	for slot: Dictionary in slots:
		if slot.remaining <= 0.0: continue
		slot.remaining = maxf(0.0, slot.remaining - dt)
		slot.age += dt
		var duration := maxf(float(slot.life), 0.001)
		var progress := clampf(float(slot.age) / duration, 0.0, 1.0)
		var fade := clampf(slot.remaining / maxf(duration * FADE, 0.001), 0.0, 1.0)
		var material: ShaderMaterial = slot.material
		material.set_shader_parameter("age", progress)
		material.set_shader_parameter("opacity", float(slot.strength) * fade)
		if int(slot.kind) == RING:
			var grow := lerpf(RING_START_SCALE, 1.0, progress)
			slot.node.scale = Vector3(slot.size * grow, slot.size * grow, 1.0)
			material.set_shader_parameter("progress", progress)
		if slot.remaining <= 0.0:
			slot.node.visible = false
			counters.expired += 1

func reset() -> void:
	clock = 0.0
	_serial = 0
	last_family = ""
	last_kind = -1
	for slot: Dictionary in slots:
		slot.remaining = 0.0
		slot.life = 0.0
		slot.age = 0.0
		slot.family = ""
		slot.kind = -1
		slot.node.visible = false
	counters.placed = 0
	counters.recycled = 0
	counters.expired = 0
	counters.denied = 0

func snapshot() -> Dictionary:
	return {"pool": slots.size(), "limit": limit(), "live": live(), "life": life(),
		"quality": quality, "enabled": enabled, "family": last_family, "kind": last_kind,
		"counters": counters.duplicate()}

static func _family_index(family: String) -> int:
	match family:
		"metal": return 0
		"ice": return 2
		"ground": return 3
		_: return 1

## Public entry point for callers that need the same plane orientation the decal
## will use (the impact edge guard probes the quad's own corners).
static func basis(normal: Vector3, seed: float) -> Basis:
	return _basis(normal, seed)

## Right-handed surface basis: local +Z is the confirmed normal, local +Y runs
## downhill when the surface has a slope, rotated by a deterministic seed so
## repeated damage does not line up. Mirrors the blood stain basis convention.
static func _basis(normal: Vector3, seed: float) -> Basis:
	var up := normal.normalized()
	var axis := Vector3.DOWN - up * Vector3.DOWN.dot(up)
	if axis.length_squared() < 0.0004:
		axis = Vector3.FORWARD - up * Vector3.FORWARD.dot(up)
	axis = axis.normalized()
	axis = (Quaternion(up, seed * 0.7).normalized() * axis).normalized()
	var right := axis.cross(up).normalized()
	return Basis(right, axis, up)
