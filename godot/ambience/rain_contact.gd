extends Node3D
## Source delayed RipplePool; static-map physics is read only, never synthesized.
const LIMIT := 18
const QUERY_BUDGET := 6
var mesh := MultiMesh.new()
var display := MultiMeshInstance3D.new()
var slots: Array[Dictionary] = []
var map: WeakRef
var serial := 0
var queries := 0
var used := 0
var cursor := 0
var visible_count := 0
var total_scheduled := 0

func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var material := ShaderMaterial.new()
	material.shader = preload("res://ambience/rain_contact.gdshader")
	plane.material = material
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.mesh = plane
	mesh.instance_count = LIMIT
	mesh.visible_instance_count = 0
	display.multimesh = mesh
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(display)

func bind(world: Node3D) -> void:
	clear()
	map = weakref(world) if is_instance_valid(world) else null

func clear() -> void:
	slots.clear()
	serial = 0
	cursor = 0
	visible_count = 0
	queries = 0
	used = 0
	mesh.visible_instance_count = 0

func begin_tick() -> void:
	queries = 0
	used = 0

func _support(position: Vector3) -> Dictionary:
	if queries >= QUERY_BUDGET or map == null: return {}
	var world: Node3D = map.get_ref()
	if not is_instance_valid(world) or not world.is_inside_tree(): return {}
	queries += 1
	var ray := PhysicsRayQueryParameters3D.create(position, position - Vector3(0,26,0))
	ray.collide_with_areas = false
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty(): return {}
	var collider: Node = hit.collider
	if collider != world and not world.is_ancestor_of(collider): return {}
	# A wall/underside is not supporting ground. Existing sloped support keeps
	# its normal, so the ring cannot float horizontally through the terrain.
	if hit.normal.y < 0.5: return {}
	return hit

func schedule(position: Vector3, velocity: Vector3, color: Color, stamp: float) -> bool:
	serial += 1
	if serial % 5 != 0 or used >= 3 or queries >= QUERY_BUDGET or velocity.y >= 0.0: return false
	var hit := _support(position)
	if hit.is_empty(): return false
	var drop: float = position.y - hit.position.y
	if drop <= 0.05 or drop > 26.0: return false
	var delay := clampf(drop / -velocity.y, 0.0, 0.9)
	var landing := position + Vector3(velocity.x,0,velocity.z)*delay
	var final_hit := _support(landing)
	# Source falls back to initial ground height. Native refuses unsupported
	# destination instead (ledge/void); no floating contacts over absent geometry.
	if final_hit.is_empty(): return false
	used += 1
	var normal: Vector3 = final_hit.normal
	var slot := {"position": Vector3(landing.x, final_hit.position.y, landing.z) + normal*0.02,
		"normal": normal, "born": stamp+delay, "color": color.srgb_to_linear()}
	if slots.size() < LIMIT: slots.append(slot)
	else:
		slots[cursor] = slot
		cursor = (cursor+1)%LIMIT
	total_scheduled += 1
	return true

static func envelope(age: float) -> Vector2:
	var t := clampf(age / 0.5, 0.0, 1.0)
	return Vector2(0.126+0.3*t, 0.5*(1.0-t)*(1.0-t))

func update(stamp: float, origin: Vector3) -> void:
	if map != null and not is_instance_valid(map.get_ref()):
		clear()
		return
	visible_count = 0
	global_position = origin
	for slot: Dictionary in slots:
		var age: float = stamp-slot.born
		if age < 0.0 or age >= 0.5: continue
		var shape := envelope(age)
		var normal: Vector3 = slot.normal
		var tangent := Vector3.RIGHT.slide(normal).normalized()
		var basis := Basis(tangent, normal, tangent.cross(normal)).scaled(Vector3.ONE*shape.x)
		mesh.set_instance_transform(visible_count, Transform3D(basis, slot.position-origin))
		var color: Color = slot.color
		color.a = shape.y
		mesh.set_instance_color(visible_count, color)
		visible_count += 1
	mesh.visible_instance_count = visible_count

func diagnostics() -> Dictionary:
	return {"slots":slots.size(), "limit":LIMIT, "visible":visible_count, "queries":queries,
		"query_limit":QUERY_BUDGET, "scheduled":total_scheduled, "draw_nodes":1, "triangle_limit":LIMIT*2}
