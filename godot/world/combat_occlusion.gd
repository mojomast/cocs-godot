extends RefCounted
## Read-only cosmetic visibility. Original maps are mesh-only: use their locked
## semantic blocks/support triangles. Native maps use only their built colliders.
const Catalog = preload("res://world/catalog.gd")
const END_EPSILON := 0.004
var camera: Camera3D
var collision_root: Node
var map_id := ""
var ready := false
var boxes: Array[AABB] = []
var terrain: TriangleMesh
var implicit_floor := false
var bodies: Dictionary = {}
var queries := 0
var blocked := 0

func configure(view: Camera3D, map: Dictionary) -> bool:
	camera = view
	map_id = str(map.get("id", ""))
	boxes.clear()
	bodies.clear()
	terrain = null
	implicit_floor = false
	ready = false
	collision_root = map.get("collision_root") as Node
	if is_instance_valid(collision_root):
		_collect_bodies(collision_root)
		ready = not bodies.is_empty()
		return ready
	for block: Dictionary in map.get("blocks", []):
		# Source spatial.boxHit uses ground-to-h blocks (including bridges).
		boxes.append(AABB(Vector3(block.x-block.w/2.0, 0, block.z-block.d/2.0), Vector3(block.w, block.h, block.d)))
	var faces := PackedVector3Array()
	for triangle: Dictionary in map.get("terrain", {}).get("support_triangles", []) + map.get("terrain", {}).get("wall_triangles", []):
		for vertex: Array in triangle.vertices: faces.append(Vector3(vertex[0], vertex[1], vertex[2]))
	if not faces.is_empty():
		terrain = TriangleMesh.new()
		if not terrain.create_from_faces(faces): return false
	elif map.has("bounds") and map.bounds is Dictionary:
		# Source floorAt returns zero everywhere for unraised sports maps, even
		# outside playable bounds (the bounds constrain movement, not rayWorld).
		implicit_floor = true
	ready = not map_id.is_empty() and (terrain != null or implicit_floor or not boxes.is_empty())
	return ready

func _collect_bodies(node: Node) -> void:
	if node is StaticBody3D: bodies[node.get_rid()] = true
	for child: Node in node.get_children(): _collect_bodies(child)

static func native_root(node: Node, id: String) -> Node:
	if not is_instance_valid(node): return null
	var script := node.get_script() as Script
	if script != null and script.resource_path in ["res://native_arenas/maps/%s.gd" % id, "res://%s/map.gd" % id.replace("-", "_")]: return node
	# The three identity arenas use one parameterized map builder. Only a map
	# actually built for this id may supply its collider-backed combat surfaces.
	if script != null and script.resource_path == "res://identity_maps/map.gd" \
			and node.has_method("get_arena_id") and node.get_arena_id() == id:
		return node
	# Cinderwake's collider-backed scene consumes the same received gate mask.
	if id == "cinderwake-drydock" and script != null \
			and script.resource_path == "res://horde_maps/cinderwake.gd" \
			and node.has_method("get_arena_id") and node.get_arena_id() == id:
		return node
	for child: Node in node.get_children():
		var found := native_root(child, id)
		if found != null: return found
	return null

func segment_blocked(from: Vector3, to: Vector3) -> bool:
	queries += 1
	var result := _blocked(from, to)
	if result: blocked += 1
	return result

func _blocked(from: Vector3, to: Vector3) -> bool:
	if not ready or not from.is_finite() or not to.is_finite(): return true
	var distance := from.distance_to(to)
	if distance <= END_EPSILON: return false
	# Authority endpoints may lie exactly on walls. Test the open segment, never
	# adjust the rendered endpoint or claim an impact/damage from this query.
	var end := to - (to-from) / distance * END_EPSILON
	if not bodies.is_empty():
		if not is_instance_valid(collision_root) or not is_instance_valid(camera) or not camera.is_inside_tree(): return true
		var query := PhysicsRayQueryParameters3D.create(from, end)
		query.hit_from_inside = true
		query.hit_back_faces = true
		var excluded: Array[RID] = []
		for attempt in range(32):
			query.exclude = excluded
			var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): return false
			if bodies.has(hit.rid): return true
			excluded.append(hit.rid) # Dynamic actors/decor never become map authority.
		return true
	for box: AABB in boxes:
		var inside: bool = from.x >= box.position.x and from.x <= box.end.x and from.y >= box.position.y and from.y <= box.end.y and from.z >= box.position.z and from.z <= box.end.z
		if inside or not box_contact(box, from, end).is_empty(): return true
	if terrain != null and not terrain.intersect_segment(from, end).is_empty(): return true
	if implicit_floor and end.y < 0: return true
	return false

func snapshot() -> Dictionary:
	return {"map":map_id, "ready":ready, "backend":"native physics" if not bodies.is_empty() else "semantic geometry", "boxes":boxes.size(), "physics_bodies":bodies.size(), "queries":queries, "blocked":blocked}

## Exact first contact on a closed segment. Unlike visibility, no endpoint
## shortening: normals/positions must belong to the face the incoming ray hits.
## Empty means no evidence; never fabricate a plane from the shooting direction.
func contact(from: Vector3, to: Vector3) -> Dictionary:
	if not ready or not from.is_finite() or not to.is_finite(): return {}
	if not bodies.is_empty():
		if not is_instance_valid(camera) or not camera.is_inside_tree(): return {}
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.hit_back_faces = true
		var excluded: Array[RID] = []
		for attempt in range(32):
			query.exclude = excluded
			var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): return {}
			if bodies.has(hit.rid):
				if hit.normal.length_squared() < 0.5: return {}
				return hit
			excluded.append(hit.rid)
		return {}
	var best := {}
	var distance := INF
	for index: int in boxes.size():
		var hit := box_contact(boxes[index], from, to)
		if not hit.is_empty() and from.distance_squared_to(hit.position) < distance:
			best = hit
			best.block = index
			distance = from.distance_squared_to(hit.position)
	if terrain != null:
		var hit := terrain.intersect_segment(from, to)
		if not hit.is_empty() and from.distance_squared_to(hit.position) < distance: best = hit
	elif implicit_floor and from.y >= 0.0 and to.y < 0.0:
		var point := from.lerp(to, from.y / (from.y - to.y))
		if from.distance_squared_to(point) < distance: best = {"position":point,"normal":Vector3.UP}
	return best

static func box_contact(box: AABB, from: Vector3, to: Vector3) -> Dictionary:
	var direction := to - from
	var distance := direction.length()
	if distance < 1e-9: return {}
	var enter := 0.0
	var leave := 1.0
	var normal := Vector3.ZERO
	for axis: int in 3:
		if absf(direction[axis]) < 1e-8 * distance:
			if from[axis] < box.position[axis] or from[axis] > box.end[axis]: return {}
			continue
		var first: float = (box.position[axis] - from[axis]) / direction[axis]
		var last: float = (box.end[axis] - from[axis]) / direction[axis]
		var sign := -1.0
		if first > last:
			var swap := first
			first = last
			last = swap
			sign = 1.0
		if first >= enter:
			enter = first
			normal = Vector3.ZERO
			normal[axis] = sign
		leave = minf(leave, last)
		if enter > leave: return {}
	if normal == Vector3.ZERO: return {} # inside is not a receiving face
	return {"position":from + direction * enter,"normal":normal}
