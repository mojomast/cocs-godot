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
	for triangle: Dictionary in map.get("terrain", {}).get("support_triangles", []):
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
		if box.has_point(from) or box.intersects_segment(from, end) != null: return true
	if terrain != null and not terrain.intersect_segment(from, end).is_empty(): return true
	if implicit_floor and end.y < 0: return true
	return false

func snapshot() -> Dictionary:
	return {"map":map_id, "ready":ready, "backend":"native physics" if not bodies.is_empty() else "semantic geometry", "boxes":boxes.size(), "physics_bodies":bodies.size(), "queries":queries, "blocked":blocked}
