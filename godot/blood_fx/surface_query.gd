extends RefCounted
## Real surface query behind every stain. Three interchangeable backends:
##
##   callable  - host-supplied `Callable(from: Vector3, to: Vector3) -> Dictionary`
##               returning {hit: bool, position: Vector3, normal: Vector3}.
##   physics   - Godot physics raycasts. Native arena builders and identity-map
##               builders place StaticBody3D world geometry, so this is exact.
##   semantic  - the locked nine-map semantic export: ground-to-height blocks plus
##               terrain support/wall triangles, with the source's implicit y=0
##               floor when a map ships no support triangles (matching
##               world/combat_occlusion.gd semantics used by the composition).
##
## A query never invents a surface: it returns {} when nothing is hit inside the
## requested segment. Backends are bounded in both triangles and traversed cells.

const Wire = preload("res://blood_fx/wire.gd")
const CELL := 8.0
const MAX_TRIANGLES := 60000
const MAX_CELLS := 4096
const MIN_DIRECTION := 0.0000001
const MIN_DISTANCE := 0.00001
const BOUNDARY_EPSILON := 0.002
const SHAPE_MARGIN_CLEARANCE := 0.05

var kind := "none"
var ready := false
var error := ""
var map_id := ""
var camera: Camera3D
var provider: Callable
var collision_root: Node3D
var mask := 1
var exclude: Array[RID] = []
var boxes: Array[AABB] = []
var vertices := PackedVector3Array()   # 3 vertices per triangle
var normals := PackedVector3Array()    # 1 normal per triangle
var cells: Dictionary = {}
var grid_min := Vector2.ZERO
var implicit_floor := false
var floor_bounds := Rect2()
var queries := 0
var hits := 0
var misses := 0
var rejected := 0

# --- construction -------------------------------------------------------------

## Accepts a host Callable, a semantic/id map dictionary, or a collision root.
static func build(spec: Variant, view: Camera3D, collision_mask: int = 1) -> Variant:
	var surface = load("res://blood_fx/surface_query.gd").new()
	surface.camera = view
	surface.mask = collision_mask
	if spec is Callable:
		surface.kind = "callable"
		surface.provider = spec
		surface.ready = spec.is_valid()
		if not surface.ready: surface.error = "Empty surface provider Callable"
	elif spec is Object and spec.has_method("query"):
		surface.kind = "callable"
		surface.provider = Callable(spec, "query")
		surface.ready = surface.provider.is_valid()
	elif spec is Node3D:
		surface.configure_physics(spec)
	elif spec is Dictionary:
		if spec.get("collision_root") is Node3D:
			surface.configure_physics(spec.collision_root, str(spec.get("id", "")))
		else:
			surface.configure_semantic(spec)
	else:
		surface.error = "Unsupported surface source"
	return surface


## Callable adapter for the locked nine-map semantic export. The returned lambda
## captures the query object, so the host only has to keep the Callable.
static func semantic_provider(map: Dictionary, collision_mask: int = 1) -> Callable:
	var surface: Variant = load("res://blood_fx/surface_query.gd").new()
	surface.mask = collision_mask
	surface.configure_semantic(map)
	return func(from: Vector3, to: Vector3) -> Dictionary: return surface.query(from, to)


## Callable adapter for native arenas / identity maps whose builders use StaticBody3D.
static func physics_provider(root: Node3D, collision_mask: int = 1) -> Callable:
	var surface: Variant = load("res://blood_fx/surface_query.gd").new()
	surface.mask = collision_mask
	surface.configure_physics(root)
	return func(from: Vector3, to: Vector3) -> Dictionary: return surface.query(from, to)


func configure_semantic(map: Dictionary) -> bool:
	kind = "semantic"
	ready = false
	error = ""
	boxes.clear()
	vertices = PackedVector3Array()
	normals = PackedVector3Array()
	cells.clear()
	implicit_floor = false
	map_id = str(map.get("id", ""))
	if map.get("bounds") is Dictionary:
		var b: Dictionary = map.bounds
		floor_bounds = Rect2(float(b.minX), float(b.minZ), float(b.maxX) - float(b.minX), float(b.maxZ) - float(b.minZ))
	elif map.get("bounds") is AABB:
		var box: AABB = map.bounds
		floor_bounds = Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	for block: Variant in map.get("blocks", []):
		if not block is Dictionary: continue
		var width := Wire.number(block.get("w"), 0.0)
		var depth := Wire.number(block.get("d"), 0.0)
		var height := Wire.number(block.get("h"), 0.0)
		var base := Wire.number(block.get("baseY"), 0.0)
		if width <= 0.0 or depth <= 0.0 or height - base <= 0.0: continue
		boxes.append(AABB(Vector3(Wire.number(block.get("x")) - width * 0.5, base, Wire.number(block.get("z")) - depth * 0.5),
			Vector3(width, height - base, depth)))
	var terrain: Dictionary = map.get("terrain", {}) if map.get("terrain") is Dictionary else {}
	if terrain.get("support_triangles", []) is Array and not terrain.get("support_triangles", []).is_empty():
		_collect_triangles(terrain.support_triangles)
	elif terrain.get("surfaces") is Array:
		_collect_surfaces(terrain.surfaces)
	_collect_triangles(terrain.get("wall_triangles", []))
	if terrain.get("walls") is Array:
		# Polygon walls ship `vertices` plus optional `triangles`; never invented.
		_collect_surfaces(terrain.walls)
	if vertices.is_empty() and not floor_bounds.has_area():
		error = "Semantic map has no surfaces and no bounds"
		return false
	if vertices.is_empty():
		implicit_floor = true
	_build_grid()
	ready = true
	return true


func configure_physics(root: Node3D, id: String = "") -> bool:
	kind = "physics"
	ready = false
	error = ""
	map_id = id
	collision_root = root
	boxes.clear()
	vertices = PackedVector3Array()
	normals = PackedVector3Array()
	cells.clear()
	implicit_floor = false
	if not is_instance_valid(root):
		error = "Physics surface root is not valid"
		return false
	if not root.is_inside_tree():
		error = "Physics surface root is not inside the scene tree"
		return false
	ready = true
	return true


func _collect_triangles(entries: Array) -> void:
	for entry: Variant in entries:
		if not entry is Dictionary: continue
		var face: Dictionary = entry
		var source: Array = face.get("vertices", [])
		if source.size() < 3: continue
		var points: Array = []
		var indices: Array = face.get("indices", [])
		if indices.size() >= 3:
			for index: Variant in indices.slice(0, 3):
				if not Wire.numeric(index): break
				var i := int(index)
				if i < 0 or i >= source.size(): break
				points.append(_array_point(source[i]))
		if points.size() != 3:
			# support/wall triangles index into their per-surface vertex array;
			# the entry's own three corners are the authoritative face.
			points = [_array_point(source[0]), _array_point(source[1]), _array_point(source[2])]
		_append_face(points, face.get("normal"))


func _collect_surfaces(entries: Array) -> void:
	for entry: Variant in entries:
		if not entry is Dictionary: continue
		var surface: Dictionary = entry
		var source: Array = surface.get("vertices", [])
		for triangle: Variant in surface.get("triangles", []):
			if not triangle is Array or triangle.size() < 3: continue
			var points: Array = []
			for index: Variant in triangle.slice(0, 3):
				if not Wire.numeric(index): break
				var i := int(index)
				if i < 0 or i >= source.size(): break
				points.append(_array_point(source[i]))
			_append_face(points, null)


func _array_point(value: Variant) -> Variant:
	if not value is Array or value.size() < 3: return null
	for i in 3:
		if not Wire.numeric(value[i]): return null
	return Vector3(value[0], value[1], value[2])


func _append_face(points: Array, authored_normal: Variant) -> void:
	if points.size() != 3 or points[0] == null or points[1] == null or points[2] == null: return
	if vertices.size() / 3 >= MAX_TRIANGLES: return
	var a: Vector3 = points[0]
	var b: Vector3 = points[1]
	var c: Vector3 = points[2]
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 0.0000000001:
		return  # Degenerate source triangle: no surface to stain.
	if authored_normal is Array and authored_normal.size() >= 3 and Wire.numeric(authored_normal[1]):
		var provided := Vector3(Wire.number(authored_normal[0]), Wire.number(authored_normal[1]), Wire.number(authored_normal[2]))
		if provided.length_squared() > 0.5: normal = provided
	vertices.append_array(PackedVector3Array([a, b, c]))
	normals.append(normal.normalized())


func _build_grid() -> void:
	grid_min = Vector2(INF, INF)
	var grid_max := Vector2(-INF, -INF)
	var count := vertices.size() / 3
	for i in count:
		for corner in 3:
			var point := vertices[i * 3 + corner]
			grid_min = grid_min.min(Vector2(point.x, point.z))
			grid_max = grid_max.max(Vector2(point.x, point.z))
	for i in count:
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for corner in 3:
			var point := vertices[i * 3 + corner]
			low = low.min(Vector2(point.x, point.z))
			high = high.max(Vector2(point.x, point.z))
		# A triangle is inserted in every cell it overlaps; cells stay bounded.
		for x in range(floori((low.x - grid_min.x) / CELL), floori((high.x - grid_min.x) / CELL) + 1):
			for z in range(floori((low.y - grid_min.y) / CELL), floori((high.y - grid_min.y) / CELL) + 1):
				var key := (x << 16) | (z & 0xFFFF)
				var list: PackedInt32Array = cells.get(key, PackedInt32Array())
				list.append(i)
				cells[key] = list
	# Cells hold every triangle index exactly once per overlapped cell.


# --- queries ------------------------------------------------------------------

func query(from: Vector3, to: Vector3) -> Dictionary:
	queries += 1
	if not from.is_finite() or not to.is_finite():
		rejected += 1
		return {}
	var result := {}
	match kind:
		"callable": result = _query_callable(from, to)
		"physics": result = _query_physics(from, to)
		"semantic": result = _query_semantic(from, to)
	if result.is_empty():
		misses += 1
	else:
		hits += 1
	return result


## True when a point is inside a conservative solid volume. Semantic geometry
## answers from its block boxes (a floor quad under a wall's footprint is inside
## the wall, not on the floor); physics uses a real point query so a collider
## interior can never receive a mark. Callable providers cannot answer this and
## report false, which keeps the previous behaviour for host-owned queries.
func solid_at(point: Vector3, normal: Vector3 = Vector3.UP) -> bool:
	if not point.is_finite(): return true
	# Always test just off the mark's own plane: a face boundary is inclusive in
	# AABB.has_point, while a floor quad under a wall's footprint stays inside.
	var probe := point + normal.normalized() * BOUNDARY_EPSILON
	match kind:
		"semantic":
			for box: AABB in boxes:
				if box.has_point(probe): return true
			if implicit_floor and probe.y < 0.0: return true
			return false
		"physics":
			if not is_instance_valid(camera) or not camera.is_inside_tree(): return false
			var world := camera.get_world_3d()
			if world == null: return false
			# Collision shapes carry a margin, so probe further clear of the surface.
			var parameters := PhysicsPointQueryParameters3D.new()
			parameters.position = point + normal.normalized() * SHAPE_MARGIN_CLEARANCE
			parameters.collision_mask = mask
			parameters.collide_with_bodies = true
			parameters.collide_with_areas = false
			return not world.direct_space_state.intersect_point(parameters, 1).is_empty()
		_:
			return false


func _query_callable(from: Vector3, to: Vector3) -> Dictionary:
	if not provider.is_valid(): return {}
	var value: Variant = provider.call(from, to)
	if not value is Dictionary: return {}
	var data: Dictionary = value
	if data.get("hit", false) != true: return {}
	# The documented provider contract uses real Vector3 values; a plain
	# {x, y, z} dictionary is accepted as well for wire-shaped fixtures.
	var position: Variant = _point_value(data.get("position"))
	var normal: Variant = _point_value(data.get("normal"))
	if position == null or normal == null or normal.length_squared() < 0.5: return {}
	var position_vector: Vector3 = position
	return {"hit": true, "position": position_vector, "normal": normal.normalized(),
		"distance": from.distance_to(position_vector), "surface": "callable"}


static func _point_value(value: Variant) -> Variant:
	if value is Vector3:
		return value if (value as Vector3).is_finite() else null
	return Wire.point(value)


func _query_physics(from: Vector3, to: Vector3) -> Dictionary:
	if not is_instance_valid(camera) or not camera.is_inside_tree(): return {}
	var world := camera.get_world_3d()
	if world == null: return {}
	var parameters := PhysicsRayQueryParameters3D.create(from, to)
	parameters.collision_mask = mask
	parameters.hit_from_inside = true
	parameters.hit_back_faces = true
	if not exclude.is_empty(): parameters.exclude = exclude
	var hit: Dictionary = world.direct_space_state.intersect_ray(parameters)
	if hit.is_empty(): return {}
	var position: Variant = hit.get("position")
	if not position is Vector3: return {}
	var normal: Variant = hit.get("normal")
	if not normal is Vector3 or normal.length_squared() < 0.5: normal = Vector3.UP
	return {"hit": true, "position": position, "normal": normal.normalized(),
		"distance": from.distance_to(position), "surface": "physics", "collider": hit.get("collider")}


func _query_semantic(from: Vector3, to: Vector3) -> Dictionary:
	var direction := to - from
	var distance := direction.length()
	if distance < MIN_DISTANCE: return {}
	var unit := direction / distance
	var best := {}
	# Blocks are conservative ground-to-height volumes, exactly like the source
	# spatial.boxHit contract used by world/combat_occlusion.gd.
	for box: AABB in boxes:
		var hit := _box_hit(box, from, unit, distance)
		if hit.is_empty(): continue
		if best.is_empty() or float(hit.distance) < float(best.distance): best = hit
	if not vertices.is_empty():
		var triangle := _nearest_triangle(from, unit, distance)
		if not triangle.is_empty() and (best.is_empty() or float(triangle.distance) < float(best.distance)): best = triangle
	if best.is_empty() and implicit_floor:
		var plane := _floor_hit(from, unit, distance)
		if not plane.is_empty(): best = plane
	return best


func _box_hit(box: AABB, from: Vector3, direction: Vector3, distance: float) -> Dictionary:
	var entry := 0.0
	var exit := distance
	var axis := -1
	var face_sign := -1.0
	for i in 3:
		var origin := from[i]
		var step := direction[i]
		var low := box.position[i]
		var high := box.position[i] + box.size[i]
		var sign := -1.0
		if absf(step) < MIN_DIRECTION:
			if origin < low or origin > high: return {}
			continue
		var t1 := (low - origin) / step
		var t2 := (high - origin) / step
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
			# Entering through the high face: the outward normal is +axis.
			sign = 1.0
		if t1 > entry:
			entry = t1
			axis = i
			face_sign = sign
		if t2 < exit: exit = t2
		if entry > exit: return {}
	if axis < 0 or entry <= MIN_DISTANCE or entry > distance: return {}
	var normal := Vector3.ZERO
	normal[axis] = face_sign
	return {"hit": true, "position": from + direction * entry, "normal": normal,
		"distance": entry, "surface": "block"}


func _nearest_triangle(from: Vector3, direction: Vector3, distance: float) -> Dictionary:
	var best := -1.0
	var best_index := -1
	var candidate := _cells_along(from, direction, distance)
	if candidate.is_empty():
		for i in range(vertices.size() / 3):
			var t := _triangle_hit(i, from, direction, distance)
			if t > 0.0 and (best_index < 0 or t < best):
				best = t
				best_index = i
	else:
		for i: int in candidate:
			var t := _triangle_hit(i, from, direction, distance)
			if t > 0.0 and (best_index < 0 or t < best):
				best = t
				best_index = i
	if best_index < 0: return {}
	return {"hit": true, "position": from + direction * best, "normal": normals[best_index],
		"distance": best, "surface": "terrain"}


func _cells_along(from: Vector3, direction: Vector3, distance: float) -> Array:
	var end := from + direction * distance
	var low := Vector2(minf(from.x, end.x), minf(from.z, end.z))
	var high := Vector2(maxf(from.x, end.x), maxf(from.z, end.z))
	var x0 := floori((low.x - grid_min.x) / CELL)
	var x1 := floori((high.x - grid_min.x) / CELL)
	var z0 := floori((low.y - grid_min.y) / CELL)
	var z1 := floori((high.y - grid_min.y) / CELL)
	if (x1 - x0 + 1) * (z1 - z0 + 1) > MAX_CELLS: return []
	var order: Array[int] = []
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var key := (x << 16) | (z & 0xFFFF)
			if not cells.has(key): continue
			order.append_array(cells[key])
	return order


func _triangle_hit(index: int, from: Vector3, direction: Vector3, max_distance: float) -> float:
	var a := vertices[index * 3]
	var edge1 := vertices[index * 3 + 1] - a
	var edge2 := vertices[index * 3 + 2] - a
	var pvec := direction.cross(edge2)
	var det := edge1.dot(pvec)
	if absf(det) < 0.0000001: return -1.0
	var inv := 1.0 / det
	var tvec := from - a
	var u := tvec.dot(pvec) * inv
	if u < 0.0 or u > 1.0: return -1.0
	var qvec := tvec.cross(edge1)
	var v := direction.dot(qvec) * inv
	if v < 0.0 or u + v > 1.0: return -1.0
	var t := edge2.dot(qvec) * inv
	if t <= MIN_DISTANCE or t > max_distance: return -1.0
	return t


func _floor_hit(from: Vector3, direction: Vector3, distance: float) -> Dictionary:
	if absf(direction.y) < MIN_DIRECTION: return {}
	var t := -from.y / direction.y
	if t <= MIN_DISTANCE or t > distance: return {}
	var point := from + direction * t
	if not floor_bounds.has_point(Vector2(point.x, point.z)): return {}
	return {"hit": true, "position": point, "normal": Vector3.UP, "distance": t, "surface": "implicit-floor"}


func snapshot() -> Dictionary:
	return {"kind": kind, "ready": ready, "error": error, "map_id": map_id,
		"mask": mask, "blocks": boxes.size(), "triangles": vertices.size() / 3, "cells": cells.size(),
		"implicit_floor": implicit_floor, "queries": queries, "hits": hits, "misses": misses, "rejected": rejected}
