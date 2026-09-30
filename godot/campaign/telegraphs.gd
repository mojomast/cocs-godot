extends Node3D
## Authority-clock counterplay, never a damage or local attack scheduler.
const MAX_RINGS := 24
const MAX_SEEN := 256
const SEGMENTS := 72
const FLASH_SECONDS := 0.22
var terrain: Node3D
var authority_time: float = 0.0
var has_state: bool = false
var actors: Dictionary = {}
var rings: Dictionary = {}
var seen: Dictionary = {}
var seen_order: Array[String] = []
var material: StandardMaterial3D

func _init() -> void:
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

func bind_terrain(value: Node3D) -> void:
	terrain = value
	_reconcile()

func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func apply_events(items: Array) -> void:
	for item: Variant in items:
		if not item is Dictionary: continue
		var event: Dictionary = item
		var type: String = str(event.get("type", ""))
		var kind: String = str(event.get("kind", "")) if type == "enemy-telegraph" else ("artillery" if type == "enemy-artillery" else ("boss" if type == "boss-slam" else ""))
		if kind not in ["artillery", "boss"]: continue
		if not _number(event.get("id")) or not _number(event.get("time")) or not _number(event.get("actor")): continue
		var event_id: String = str(int(event.id))
		if seen.has(event_id): continue
		seen[event_id] = true
		seen_order.append(event_id)
		if seen_order.size() > MAX_SEEN: seen.erase(seen_order.pop_front())
		if not _number(event.get("x")) or not _number(event.get("z")) or not _number(event.get("radius")): continue
		var flash: bool = type != "enemy-telegraph"
		if not flash and not _number(event.get("duration")): continue
		var duration: float = FLASH_SECONDS if flash else float(event.duration)
		var radius: float = float(event.radius)
		if duration <= 0 or duration > 30 or radius <= 0 or radius > 64: continue
		var start: float = float(event.time)
		if has_state and authority_time >= start + duration: continue
		var key: String = "%d:%s" % [int(event.actor), kind]
		if rings.has(key) and float(rings[key].start) > start: continue
		# At equal authority time a confirmed impact must win over its warning.
		if rings.has(key) and float(rings[key].start) == start and rings[key].flash and not flash: continue
		if not rings.has(key) and rings.size() >= MAX_RINGS: continue
		_drop(key)
		rings[key] = {"actor":int(event.actor), "kind":kind, "start":start, "end":start + duration, "duration":duration, "x":float(event.x), "z":float(event.z), "radius":radius, "flash":flash, "node":null}
	_reconcile()

func apply_state(state: Dictionary) -> void:
	if not _number(state.get("time")): return
	var next_time: float = float(state.time)
	# Round resets are explicit; out-of-order older snapshots cannot rewind cues.
	if has_state and next_time < authority_time: return
	authority_time = next_time
	has_state = true
	actors.clear()
	for actor: Variant in state.get("actors", []):
		if actor is Dictionary and _number(actor.get("id")): actors[int(actor.id)] = actor
	_reconcile()

func _reconcile() -> void:
	if not has_state: return
	for key: String in rings.keys():
		var entry: Dictionary = rings[key]
		if authority_time >= float(entry.end):
			_drop(key)
			continue
		# Future events wait for their corresponding authority snapshot.
		if authority_time < float(entry.start):
			if is_instance_valid(entry.node): entry.node.visible = false
			continue
		var actor: Dictionary = actors.get(entry.actor, {})
		if actor.is_empty() or not _number(actor.get("health")) or float(actor.health) <= 0:
			_drop(key)
			continue
		if not entry.flash:
			var field: String = "artillery" if entry.kind == "artillery" else "bossStomp"
			var remaining: Variant = actor.get(field + "Windup")
			var mark: Variant = actor.get(field + "Mark")
			if not _number(remaining) or float(remaining) <= 0 or not mark is Dictionary:
				_drop(key)
				continue
			if not _number(mark.get("x")) or not _number(mark.get("z")):
				_drop(key)
				continue
			# The actor's current mark supersedes old event coordinates. A changed
			# target means this event is stale; wait for the matching new event/radius.
			if Vector2(float(mark.x), float(mark.z)).distance_to(Vector2(entry.x, entry.z)) > 0.05:
				_drop(key)
				continue
		if not is_instance_valid(terrain) or not terrain.has_method("height_at"): continue
		_draw(entry)

func _height(x: float, z: float) -> float:
	return float(terrain.call("height_at", x, z)) + 0.055

func _point(entry: Dictionary, radius: float, angle: float) -> Vector3:
	var x: float = float(entry.x) + cos(angle) * radius
	var z: float = float(entry.z) + sin(angle) * radius
	return Vector3(x, _height(x, z), z)

func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	tool.set_color(color)
	tool.set_normal(Vector3.UP)
	tool.add_vertex(a); tool.add_vertex(b); tool.add_vertex(c)

func _draw(entry: Dictionary) -> void:
	if not is_instance_valid(entry.node):
		var node := MeshInstance3D.new()
		node.name = "GroundWarning_%d_%s" % [entry.actor, entry.kind]
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		entry.node = node
	entry.node.visible = true
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var progress: float = clampf((authority_time - float(entry.start)) / float(entry.duration), 0, 1)
	var pulse: float = 0.65 + 0.35 * absf(sin((authority_time - float(entry.start)) * TAU * 2))
	var base := Color("ffae35") if entry.kind == "artillery" else Color("ff7036")
	var radius: float = float(entry.radius)
	var inner: float = maxf(0, radius - 0.16)
	for i: int in range(SEGMENTS):
		var angle: float = TAU * i / SEGMENTS
		var next: float = TAU * (i + 1) / SEGMENTS
		# Alternating value dashes + growing pale arc make timing legible without hue.
		var color: Color = base * (pulse if i % 6 < 4 else 0.3)
		color.a = 1.0
		if float(i) / SEGMENTS <= progress: color = Color("ffe8bd")
		if entry.flash: color = Color("fff2d5") * (1.0 - progress * 0.6)
		_triangle(tool, _point(entry, inner, angle), _point(entry, radius, angle), _point(entry, radius, next), color)
		_triangle(tool, _point(entry, inner, angle), _point(entry, radius, next), _point(entry, inner, next), color)
	# Four inward hazard pointers; boss uses eight. Shape is distinct from pickups.
	var points: int = 4 if entry.kind == "artillery" else 8
	for i: int in range(points):
		var angle: float = TAU * i / points
		_triangle(tool, _point(entry, radius * 0.78, angle - 0.09), _point(entry, radius * 0.78, angle + 0.09), _point(entry, radius * 0.64, angle), Color("ffe8bd"))
	entry.node.mesh = tool.commit()

func _drop(key: String) -> void:
	if not rings.has(key): return
	var node: Variant = rings[key].node
	if is_instance_valid(node): node.free()
	rings.erase(key)

func clear_round() -> void:
	for key: String in rings.keys(): _drop(key)
	actors.clear(); seen.clear(); seen_order.clear()
	authority_time = 0.0
	has_state = false
