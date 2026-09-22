class_name PortProjectiles
extends Node3D

# Presentation only: no prediction, collision, damage, or disappearance explosions.
# A short emissive exhaust is part of the rocket mesh, never a hitscan tracer.
const MAX_PROJECTILES := 128
const MAX_SCAN := 512
var markers: Dictionary = {}
var rocket_mesh: ArrayMesh
var generic_mesh: SphereMesh

static func identity(value: Variant) -> int:
	if not (value is int or value is float): return -1
	var number := float(value)
	if not is_finite(number) or number < 0 or number > 2147483647 or number != floor(number): return -1
	return int(number)

static func point(value: Variant) -> Variant:
	if not value is Dictionary: return null
	for key: String in ["x", "y", "z"]:
		if not (value.get(key) is float or value.get(key) is int): return null
		if not is_finite(float(value[key])) or absf(float(value[key])) > 100000.0: return null
	return Vector3(value.x, value.y, value.z)

func _init() -> void:
	# Shared low-poly mesh, pointing along local -Z. Three surfaces per rocket.
	rocket_mesh = ArrayMesh.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.085
	body.bottom_radius = 0.085
	body.height = 0.42
	body.radial_segments = 8
	append_part(body, Vector3.ZERO, Color(0.65, 0.72, 0.78))
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.085
	nose.height = 0.18
	nose.radial_segments = 8
	append_part(nose, Vector3(0, 0, -0.30), Color(1.0, 0.32, 0.08))
	var exhaust := CylinderMesh.new()
	exhaust.top_radius = 0.075
	exhaust.bottom_radius = 0.0
	exhaust.height = 0.65
	exhaust.radial_segments = 8
	append_part(exhaust, Vector3(0, 0, 0.535), Color(1.0, 0.66, 0.12))
	generic_mesh = SphereMesh.new()
	generic_mesh.radius = 0.14
	generic_mesh.height = 0.28
	generic_mesh.radial_segments = 8
	generic_mesh.rings = 4
	generic_mesh.material = material(Color(0.35, 0.9, 1.0))

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.albedo_color = color
	return result

func append_part(primitive: PrimitiveMesh, offset: Vector3, color: Color) -> void:
	var arrays := primitive.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var rotation := Basis(Vector3.RIGHT, -PI / 2.0)
	for index: int in range(vertices.size()):
		vertices[index] = rotation * vertices[index] + offset
		normals[index] = rotation * normals[index]
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	rocket_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	rocket_mesh.surface_set_material(rocket_mesh.get_surface_count() - 1, material(color))

func apply_state(state: Dictionary) -> void:
	var present: Dictionary = {}
	var items: Variant = state.get("rockets", [])
	if items is Array and not state.get("over", false):
		for index: int in range(mini(items.size(), MAX_SCAN)):
			var item: Variant = items[index]
			if not item is Dictionary: continue
			var id := identity(item.get("id"))
			var owner := identity(item.get("owner"))
			var weapon := identity(item.get("weapon"))
			var pos: Variant = point(item.get("pos"))
			var direction: Variant = point(item.get("dir"))
			if id < 0 or owner < 0 or weapon < 0 or pos == null or direction == null: continue
			if direction.length_squared() < 0.000001 or present.has(id): continue
			if present.size() >= MAX_PROJECTILES: break
			present[id] = {"pos":pos,"dir":direction,"owner":owner,"weapon":weapon}
	# Retire missing IDs before allocating replacements: even a completely new
	# saturated snapshot never transiently doubles the scene/render-node budget.
	for id: int in markers.keys():
		if not present.has(id):
			markers[id].free()
			markers.erase(id)
	for id: int in present:
		var item: Dictionary = present[id]
		if not markers.has(id):
			var marker := MeshInstance3D.new()
			marker.name = "Projectile_%d" % id
			marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(marker)
			markers[id] = marker
		var node: MeshInstance3D = markers[id]
		node.mesh = rocket_mesh if item.weapon == 1 else generic_mesh
		node.position = item.pos
		var forward: Vector3 = item.dir.normalized()
		var up := Vector3.RIGHT if absf(forward.dot(Vector3.UP)) > 0.99 else Vector3.UP
		node.basis = Basis.looking_at(forward, up)
		node.set_meta("owner", item.owner)
		node.set_meta("weapon", item.weapon)

func clear_round() -> void:
	for node: Node in markers.values(): node.free()
	markers.clear()
