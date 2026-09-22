extends Node3D
## Source-anchored scenery only. No map mutation, gameplay objects, lights,
## collision, support surfaces, timers, process callbacks or random state.
## Main-thread API: create(map, world, FULL); result.set_detail(LOW/OFF/FULL).

const Library = preload("res://moth/library.gd")
const Profiles = preload("res://moth_scenery/profiles.gd")
const PanelShader = preload("res://moth_scenery/panel.gdshader")
const MoteShader = preload("res://moth_scenery/motes.gdshader")
enum Detail { OFF, LOW, FULL }
const OWNER_META := "moth_scenery_owner"
const FACE_OFFSET := 0.032
const INSET := 0.16
const MAX_BLOCKS := 2048
const MAX_BATCHES := 10
const MAX_SURFACES := 216
const MAX_MOTES := 192
const EQUIPMENT := ["reactor", "relay-feed", "pump", "sluice"]
const WALLS := ["building", "base-wall", "base-hq", "base-bastion", "wall", "dam-buttress", "bulkhead"]

var _profile: Dictionary = {}
var _plates: Array[Dictionary] = []
var _pockets: Array[Dictionary] = []
var _detail := -1
var _clock := -1.0
var _counts: Dictionary = {}
var _map_id := ""

static func create(map: Dictionary, parent: Node3D, detail: int = Detail.FULL) -> Node3D:
	clear(parent)
	var script = load("res://moth_scenery/scenery.gd")
	var node = script.new()
	node.name = "MothScenery"
	node.set_meta(OWNER_META, true)
	node._map_id = str(map.get("id", ""))
	node._profile = Profiles.get_profile(node._map_id)
	node._plan(map)
	parent.add_child(node)
	node.set_detail(detail)
	return node

static func decorate(map: Dictionary, parent: Node3D, detail: int = Detail.FULL) -> Node3D:
	return create(map, parent, detail)

static func clear(parent: Node3D) -> void:
	# Immediate free gives repeat calls a strict ceiling, even in the same frame.
	for child: Node in parent.get_children():
		if child.get_meta(OWNER_META, false) == true:
			parent.remove_child(child)
			child.free()

func set_detail(level: int) -> void:
	level = clampi(level, Detail.OFF, Detail.FULL)
	if _detail == level: return
	_detail = level
	for child: Node in get_children(): child.free()
	_counts = {"map": _map_id, "detail": _detail, "surfaces": 0, "motes": 0, "pockets": 0, "batches": 0, "triangles": 0, "planned_surfaces": _plates.size(), "surface_limit": _profile.get("surfaces", 0), "mote_limit": _profile.get("motes", 0)}
	if _detail == Detail.OFF or _profile.is_empty(): return
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var groups := {}
	for plate: Dictionary in _plates:
		if _detail == Detail.LOW and not plate.essential: continue
		if not groups.has(plate.kind): groups[plate.kind] = []
		groups[plate.kind].append(plate)
	for key: String in groups:
		var entries: Array = groups[key]
		var mm := _multimesh(mesh, entries.size())
		for i in range(entries.size()):
			mm.set_instance_transform(i, entries[i].transform)
			mm.set_instance_custom_data(i, Color(float(entries[i].block % 17) / 17.0, 1.0 if entries[i].size.y > entries[i].size.x else 0.0, 0, 0))
		var batch := _batch("Mounted_" + key, mm, _panel_material(key))
		batch.visibility_range_end = 125.0 if key == "vent" else 180.0
		_counts.surfaces += entries.size()
	if _detail == Detail.FULL:
		var mote_material: ShaderMaterial = _mote_material(2.2) if not _pockets.is_empty() else null
		for pocket: Dictionary in _pockets:
			var mm := _multimesh(mesh, pocket.points.size())
			for i in range(pocket.points.size()):
				var point: Dictionary = pocket.points[i]
				mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, point.position))
				mm.set_instance_custom_data(i, point.custom)
			var batch := _batch("Ambient_" + str(_counts.pockets), mm, mote_material)
			batch.custom_aabb = pocket.bounds
			batch.visibility_range_end = 55.0
			_counts.motes += pocket.points.size()
			_counts.pockets += 1
	_counts.batches = get_child_count()
	_counts.triangles = (_counts.surfaces + _counts.motes) * 2

func stats() -> Dictionary:
	return _counts.duplicate(true)

func placement_snapshot() -> Dictionary:
	# Diagnostics are caller-owned; no reference to the source dictionary is kept.
	return {"plates": _plates.duplicate(true), "pockets": _pockets.duplicate(true)}

func geometry_hash() -> String:
	var rows: Array[String] = []
	for plate: Dictionary in _plates:
		rows.append("%s|%d|%s|%s|%s" % [plate.kind, plate.block, plate.transform, plate.size, plate.essential])
	for pocket: Dictionary in _pockets:
		rows.append(str(pocket.bounds))
		for point: Dictionary in pocket.points: rows.append(str(point.position) + "|" + str(point.custom))
	return "\n".join(rows).sha256_text()

func set_clock_for_capture(seconds: float = -1.0) -> void:
	_clock = seconds if is_finite(seconds) else -1.0
	for child: MultiMeshInstance3D in get_children():
		child.material_override.set_shader_parameter("clock_override", _clock)

func _multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	return mm

func _batch(label: String, mm: MultiMesh, material: Material) -> MultiMeshInstance3D:
	var batch := MultiMeshInstance3D.new()
	batch.name = label
	batch.multimesh = mm
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
	return batch

func _panel_material(kind: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PanelShader
	var texture_key: String = _profile.panel
	var normal_key := "holographic_grid"
	var style := 0
	match kind:
		"circuit":
			texture_key = "circuit_board-etch"
			normal_key = "metal"
			style = 1
		"feed":
			texture_key = "circuit_board"
			normal_key = "metal"
			style = 1
		"vent":
			texture_key = "corrugated_metal"
			normal_key = "corrugated_metal"
			style = 2
		"strip":
			texture_key = "holographic_grid"
			style = 3
		"inlay":
			texture_key = "alien_chitin"
			normal_key = "rough_stucco"
			style = 4
	material.set_shader_parameter("baked_tile", Library.texture(texture_key))
	material.set_shader_parameter("circuit_tile", Library.texture("circuit_board" if kind == "feed" else "circuit_board-etch"))
	material.set_shader_parameter("housing_tile", Library.texture("carbon_fiber" if kind in ["circuit", "feed"] else "brushed_metal"))
	var normal := Library.normal(normal_key)
	material.set_shader_parameter("normal_tile", normal)
	material.set_shader_parameter("has_normal", normal != null)
	var lut := Library.material_lut(_profile.lut)
	material.set_shader_parameter("has_lut", not lut.is_empty())
	if not lut.is_empty():
		material.set_shader_parameter("lut_r", lut.r)
		material.set_shader_parameter("lut_t", lut.t)
	material.set_shader_parameter("tint", Color(_profile.tint))
	material.set_shader_parameter("light_tint", Color(_profile.light))
	material.set_shader_parameter("style", style)
	material.set_shader_parameter("emission_strength", 0.90 if kind == "strip" else 0.62)
	material.set_shader_parameter("clock_override", _clock)
	return material

func _mote_material(height: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = MoteShader
	material.set_shader_parameter("dust_field", Library.texture("dust-field"))
	material.set_shader_parameter("flow_field", Library.texture("flow-field"))
	var snow: bool = _profile.air == "snow"
	if snow:
		var frames := Library.effect("effect-weather-snow")
		if not frames.is_empty(): material.set_shader_parameter("snow_frame", frames.frames[0])
	material.set_shader_parameter("snow", snow)
	material.set_shader_parameter("tint", Color(_profile.air_color))
	material.set_shader_parameter("height", height)
	material.set_shader_parameter("size", 0.095 if snow else (0.055 if _profile.air == "ash" else 0.045))
	material.set_shader_parameter("opacity", 0.48 if snow else 0.32)
	material.set_shader_parameter("fall_speed", 0.08 if snow else (-0.025 if _profile.air in ["ash", "vent"] else 0.024))
	material.set_shader_parameter("clock_override", _clock)
	return material

static func _valid_block(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key: String in ["x", "z", "w", "d", "h"]:
		var number: Variant = value.get(key)
		if not (number is float or number is int) or not is_finite(float(number)) or absf(float(number)) > 10000.0: return false
	return value.w > 0.1 and value.d > 0.1 and value.h > 0.1

func _plan(map: Dictionary) -> void:
	if _profile.is_empty(): return
	var blocks: Array = map.get("blocks", [])
	if blocks.size() > MAX_BLOCKS: return
	var candidates: Array[Dictionary] = []
	for index in range(blocks.size()):
		var b: Variant = blocks[index]
		if not _valid_block(b): continue
		var kind: String = b.get("kind", "")
		var equipment: bool = kind in EQUIPMENT
		var column: bool = kind in ["column", "pillar", "light-mast"] and b.h >= 4.0 and minf(b.w, b.d) >= 1.3
		if not equipment and not column and not kind in WALLS: continue
		if b.h < 2.0: continue
		candidates.append({"index": index, "b": b, "equipment": equipment, "column": column,
			"rank": (0 if equipment else (1 if column else 2)), "distance": absf(b.x) + absf(b.z) * 0.7})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.rank != b.rank: return a.rank < b.rank
		if not is_equal_approx(a.distance, b.distance): return a.distance < b.distance
		return a.index < b.index)
	# Each recipe stays within the individual source segment. Doors are gaps
	# between those segments; no trim ever spans multiple blocks or a roof opening.
	for candidate: Dictionary in candidates:
		var b: Dictionary = candidate.b
		var index: int = candidate.index
		var kind: String = b.get("kind", "")
		var normals: Array = [Vector3.BACK, Vector3.FORWARD] if b.w >= b.d else [Vector3.RIGHT, Vector3.LEFT]
		if candidate.column: normals = [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]
		# Ion's authored apron is a solid three metres high, not zero ground.
		var mount_base := 3.2 if _map_id == "ion-speedway" else 0.0
		for normal: Vector3 in normals:
			var span: float = b.w if normal.z != 0 else b.d
			if span < 0.8: continue
			if candidate.equipment:
				var panel_width := minf(span - 0.45, 2.6 if kind == "relay-feed" else 1.8)
				var panel_height := minf(b.h - 0.6, 1.25)
				var panel_y := minf(b.h * 0.54, 2.4)
				_plate(blocks, index, normal, "feed" if kind == "relay-feed" else "circuit", Vector2(panel_width, panel_height), Vector2(0, panel_y), true)
				if kind == "relay-feed":
					for side in [-1.0, 1.0]:
						_plate(blocks, index, normal, "circuit", Vector2(1.7, panel_height), Vector2(side * span * 0.21, panel_y), true)
				_plate(blocks, index, normal, "strip", Vector2(minf(span - 0.4, 12.0), 0.16), Vector2(0, b.h - 0.30), true)
				if span > 5.8:
					for side in [-1.0, 1.0]:
						_plate(blocks, index, normal, "vent", Vector2(minf((span - panel_width) * 0.32, 1.4 if kind == "relay-feed" else 3.0), panel_height), Vector2(side * span * 0.39, panel_y), false)
			elif candidate.column:
				var strip_height := minf(b.h - mount_base - 1.4, 6.0)
				_plate(blocks, index, normal, "strip", Vector2(minf(span - 0.35, 0.24), strip_height), Vector2(-span * 0.27, mount_base + 1.0 + strip_height * 0.5), true)
				if kind != "light-mast" and span > 2.0:
					_plate(blocks, index, normal, "vent" if _map_id == "ember-crucible" else "display", Vector2(minf(span * 0.40, 1.5), 1.1), Vector2(span * 0.12, 2.1), false)
					if _map_id == "ember-crucible" and span > 3.0:
						_plate(blocks, index, normal, "circuit", Vector2(1.25, 0.72), Vector2(span * 0.12, 3.35), true)
			else:
				if span < 2.2: continue
				# Natural ruins get a sparse ceramic inlay instead of banks of screens.
				var relic := _map_id == "verdant-reliquary"
				if not relic or index % 3 == 0:
					_plate(blocks, index, normal, "inlay" if relic else "display", Vector2(minf(span * 0.30, 1.65), 0.95), Vector2(-span * 0.20, minf(mount_base + 2.2, b.h * 0.70)), true)
				if b.h >= 4.5 and not relic:
					_plate(blocks, index, normal, "strip", Vector2(minf(span - 0.6, 8.5), 0.14), Vector2(0, b.h - 2.05), false)
				if index % 3 == 0 and span > 4.0:
					_plate(blocks, index, normal, "vent", Vector2(minf(span * 0.23, 1.2), 0.75), Vector2(span * 0.28, mount_base + 1.4), false)
	_plan_pockets(map, blocks, candidates)

func _plate(blocks: Array, index: int, normal: Vector3, kind: String, size: Vector2, offset: Vector2, essential: bool) -> void:
	if _plates.size() >= int(_profile.surfaces): return
	var b: Dictionary = blocks[index]
	var span: float = b.w if normal.z != 0 else b.d
	if size.x <= 0.0 or size.y <= 0.0 or absf(offset.x) + size.x * 0.5 > span * 0.5 - INSET: return
	if offset.y - size.y * 0.5 < INSET or offset.y + size.y * 0.5 > b.h - INSET: return
	var right := Vector3.UP.cross(normal)
	var depth: float = b.d if normal.z != 0 else b.w
	var position := Vector3(b.x, offset.y, b.z) + normal * (depth * 0.5 + FACE_OFFSET) + right * offset.x
	var extent := right.abs() * size.x * 0.5 + Vector3.UP * size.y * 0.5 + normal.abs() * 0.12
	var check_bounds := AABB(position + normal * 0.13 - extent, extent * 2.0)
	if not _empty_box(blocks, check_bounds, index): return
	var transform := Transform3D(Basis(right, Vector3.UP, normal).scaled_local(Vector3(size.x, size.y, 1)), position)
	_plates.append({"block": index, "kind": kind, "transform": transform, "normal": normal, "size": size, "essential": essential})

static func _empty_box(blocks: Array, bounds: AABB, excluded: int = -1) -> bool:
	for index in range(blocks.size()):
		if index == excluded or not _valid_block(blocks[index]): continue
		var b: Dictionary = blocks[index]
		var solid := AABB(Vector3(b.x - b.w * 0.5, 0, b.z - b.d * 0.5), Vector3(b.w, b.h, b.d))
		if solid.intersects(bounds): return false
	return true

func _plan_pockets(map: Dictionary, blocks: Array, candidates: Array[Dictionary]) -> void:
	var limit: int = _profile.pockets
	if limit == 0: return
	var bounds: Dictionary = map.get("bounds", {})
	for candidate: Dictionary in candidates:
		if _pockets.size() >= limit: break
		var b: Dictionary = candidate.b
		if b.h < 3.0: continue
		# Motes sit beside equipment/masonry, outside its footprint. No giant
		# weather volumes over the whole arena; leave a 12m gap between pockets.
		for normal: Vector3 in [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
			if _pockets.size() >= limit: break
			var depth: float = b.d if normal.z != 0 else b.w
			var center := Vector3(b.x, 2.6, b.z) + normal * (depth * 0.5 + 2.6)
			var half := Vector3(1.8, 1.3, 1.8)
			var box := AABB(center - half, half * 2.0)
			if not _empty_box(blocks, box): continue
			if box.position.x < float(bounds.get("minX", 0)) + 1.0 or box.end.x > float(bounds.get("maxX", 0)) - 1.0: continue
			if box.position.z < float(bounds.get("minZ", 0)) + 1.0 or box.end.z > float(bounds.get("maxZ", 0)) - 1.0: continue
			var clear := true
			for prior: Dictionary in _pockets:
				if center.distance_to(prior.bounds.get_center()) < 12.0: clear = false
			# Avoid terrain above the pocket bottom (e.g. elevated support/roof).
			for triangle: Dictionary in map.get("terrain", {}).get("support_triangles", []):
				var v: Array = triangle.vertices
				var low := Vector3(v[0][0], v[0][1], v[0][2])
				var high := low
				for vertex: Array in v:
					low = low.min(Vector3(vertex[0], vertex[1], vertex[2]))
					high = high.max(Vector3(vertex[0], vertex[1], vertex[2]))
				if high.y > box.position.y and AABB(low, high - low).grow(0.05).intersects(box): clear = false
			if not clear: continue
			var points: Array[Dictionary] = []
			var count := int(_profile.motes) / limit
			for i in range(count):
				# Fixed low-discrepancy coordinates; no RNG, load-time seed or clock.
				var a := _radical_inverse(i + 1, 2)
				var c := _radical_inverse(i + 1, 3)
				var d := _radical_inverse(i + 1, 5)
				var position := center + Vector3((a - 0.5) * 3.1, (0.5 - c) * 2.2, (d - 0.5) * 3.1)
				points.append({"position": position, "custom": Color(a, c, d, 0)})
			_pockets.append({"bounds": box, "height": 2.2, "points": points, "block": candidate.index})

static func _radical_inverse(value: int, base: int) -> float:
	var result := 0.0
	var fraction := 1.0 / float(base)
	while value > 0:
		result += (value % base) * fraction
		value = int(value / base)
		fraction /= float(base)
	return result
