class_name MothWorldFX
extends Node3D

# Public wire events only. Horde sourceId is payload, never a dedup key.
# Call reset at authoritative start/results/disconnect, before accepting IDs again.
const CAP := 32
const MAX_SCAN := 512
const ID_WINDOW := 4096
const MAX_SAFE_ID := 9007199254740991
const ShaderFX = preload("res://graphics_fx/moth_world.gdshader")
const SPECS := {
	"spark-impact": [0.65, 0.24, 0.8, 0.1],
	"effect-explosion": [3.0, 0.5, 0.9, 0.6],
	"effect-teleport": [1.9, 0.5, 0.85, 0.4],
	"effect-heal": [2.0, 0.6, 0.8, 0.15],
}
var slots: Array[Dictionary] = []
var sheets: Dictionary = {}
var seen: Dictionary = {}
var id_slots := PackedInt64Array()
var highest_id: int = -1
var spawned := 0
var overflow := 0
var duplicates := 0
var rejected := 0
var serial := 0

func _init() -> void:
	id_slots.resize(ID_WINDOW)
	id_slots.fill(-1)

# Inject Callable(library, "effect"), including a static GDScript method, or
# configure_resources({name: {frames: Array[Texture2D], fps: number}}).
# No external asset lane is preloaded. Missing/invalid sheets simply skip cues.
func configure(provider: Callable) -> void:
	var resources := {}
	if provider.is_valid():
		for key: String in SPECS: resources[key] = provider.call(key)
	configure_resources(resources)

func configure_resources(resources: Dictionary) -> void:
	reset()
	sheets.clear()
	for key: String in SPECS:
		var sheet: Variant = resources.get(key)
		if not sheet is Dictionary: continue
		var frames: Variant = sheet.get("frames")
		var fps: Variant = sheet.get("fps")
		if not frames is Array or frames.is_empty() or frames.size() > 32: continue
		if not number(fps) or fps <= 0 or fps > 120: continue
		var valid := true
		for frame: Variant in frames:
			if not frame is Texture2D or frame.get_width() <= 0 or frame.get_height() <= 0: valid = false
		if valid: sheets[key] = {"frames": frames.duplicate(), "fps": float(fps)}

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func identity(value: Variant) -> int:
	if not number(value) or value < 0 or value > MAX_SAFE_ID or float(value) != floor(float(value)): return -1
	return int(value)

static func point(value: Variant) -> Variant:
	if not value is Dictionary: return null
	for key: String in ["x", "y", "z"]:
		if not number(value.get(key)) or absf(float(value[key])) > 100000.0: return null
	return Vector3(value.x, value.y, value.z)

# actors must be the latest PUBLIC authoritative snapshot actors, not predicted
# or interpolated render nodes. Positions are read only; cues do not follow actors.
# local_id is intentionally not used for hit claims, flashes, camera shake or UI.
func consume(events: Array, _local_id: int = -1, actors: Array = []) -> void:
	var positions := {}
	for index: int in range(mini(actors.size(), MAX_SCAN)):
		var actor: Variant = actors[index]
		if not actor is Dictionary: continue
		var actor_id := identity(actor.get("id"))
		var pos: Variant = point(actor)
		if actor_id >= 0 and pos != null: positions[actor_id] = pos
	for index: int in range(mini(events.size(), MAX_SCAN)):
		var event: Variant = events[index]
		if not event is Dictionary: continue
		var id := identity(event.get("id"))
		if id < 0 or not event.get("type") is String:
			rejected += 1
			continue
		# Bounded sliding ID window, never payload equality or sourceId. The floor
		# prevents evicted history from replaying. Out-of-order IDs within the
		# window are accepted; older IDs are deliberately dropped.
		if seen.has(id) or id <= highest_id - ID_WINDOW:
			duplicates += 1
			continue
		highest_id = maxi(highest_id, id)
		# Modulo slots evict in O(1), including jumps and out-of-order arrivals.
		# IDs colliding here are at least one full window apart; the floor above
		# guarantees an older arrival can never evict a newer live-window ID.
		var bucket := id % ID_WINDOW
		if id_slots[bucket] >= 0: seen.erase(id_slots[bucket])
		id_slots[bucket] = id
		seen[id] = true
		_present(event, positions)

func _present(event: Dictionary, positions: Dictionary) -> void:
	var actor_id := identity(event.get("actor"))
	match event.type:
		"explosion", "vehicle-destroyed":
			var pos: Variant = point(event.get("pos"))
			if pos != null: _spawn("effect-explosion", pos, event.id, 1.47 if event.type == "vehicle-destroyed" else 1.0)
		"teleport", "teleporter":
			if actor_id < 0: return
			for key: String in ["from", "to"]:
				var pos: Variant = point(event.get(key))
				if pos != null: _spawn("effect-teleport", pos, event.id)
		"damage":
			# shot.hit is NOT proof of damage: source may retain a candidate target
			# behind a blocked trajectory. Only positive public damage gets a cue.
			if not number(event.get("amount")) or event.amount <= 0 or not positions.has(actor_id): return
			_spawn("spark-impact", positions[actor_id] + Vector3.UP, event.id)
		"pickup":
			if event.get("kind") in ["health", "megahealth"] and positions.has(actor_id):
				_spawn("effect-heal", positions[actor_id] + Vector3.UP, event.id, 0.65)
		"mender-heal":
			# Source emits x,z,radius,healed but no y. Require authoritative actor
			# height rather than silently inventing ground level on multi-level maps.
			if not positions.has(actor_id) or not number(event.get("healed")) or event.healed <= 0: return
			if not number(event.get("radius")) or event.radius <= 0: return
			var pos: Variant = point({"x":event.get("x"), "y":positions[actor_id].y, "z":event.get("z")})
			if pos != null: _spawn("effect-heal", pos + Vector3.UP, event.id, clampf(event.radius / 2.0, 1.0, 2.0))

func _allocate() -> Dictionary:
	var node := MeshInstance3D.new()
	node.top_level = true # event positions are world coordinates, regardless of parent transform
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 4.0
	var material := ShaderMaterial.new()
	material.shader = ShaderFX
	node.material_override = material
	add_child(node)
	var slot := {"node":node, "material":material, "remaining":0.0, "serial":0}
	slots.append(slot)
	return slot

func _spawn(key: String, pos: Vector3, event_id: int, multiplier: float = 1.0) -> void:
	if not sheets.has(key): return
	var slot: Dictionary = {}
	for candidate: Dictionary in slots:
		if candidate.remaining <= 0:
			slot = candidate
			break
	if slot.is_empty():
		if slots.size() < CAP: slot = _allocate()
		else:
			# Oldest visible slot replaced, no transient cap overshoot or queue.
			slot = slots[0]
			for candidate: Dictionary in slots:
				if candidate.serial < slot.serial: slot = candidate
			overflow += 1
	serial += 1
	spawned += 1
	var spec: Array = SPECS[key]
	slot.merge({"key":key, "remaining":spec[1], "total":spec[1], "size":spec[0] * multiplier,
		"opacity":spec[2], "grow":spec[3], "serial":serial, "event_id":event_id, "frame":0}, true)
	slot.node.position = pos
	slot.node.visible = true
	_update_slot(slot)

func _update_slot(slot: Dictionary) -> void:
	var age: float = slot.total - slot.remaining
	var sheet: Dictionary = sheets[slot.key]
	slot.frame = mini(sheet.frames.size() - 1, int(age * sheet.fps))
	slot.material.set_shader_parameter("frame_texture", sheet.frames[slot.frame])
	slot.material.set_shader_parameter("opacity", slot.opacity * minf(1.0, slot.remaining / (slot.total * 0.4)))
	slot.node.scale = Vector3.ONE * (slot.size + slot.grow * age)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0: return
	for slot: Dictionary in slots:
		if slot.remaining <= 0: continue
		slot.remaining = maxf(0.0, slot.remaining - delta)
		if slot.remaining <= 0:
			slot.node.visible = false
			slot.material.set_shader_parameter("frame_texture", null)
		else: _update_slot(slot)

func _process(delta: float) -> void:
	advance(delta)

func active_count() -> int:
	var count := 0
	for slot: Dictionary in slots:
		if slot.remaining > 0: count += 1
	return count

func reset() -> void:
	# Immediate release at round boundary; normal expiry retains bounded reusable
	# nodes. Parent free releases children/materials through Godot ownership.
	for slot: Dictionary in slots: slot.node.free()
	slots.clear()
	seen.clear()
	id_slots.fill(-1)
	highest_id = -1
	spawned = 0
	overflow = 0
	duplicates = 0
	rejected = 0
	serial = 0
