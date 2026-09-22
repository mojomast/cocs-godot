extends Node3D
## Map-only deterministic presentation. Source Node Match remains authoritative.
const IDS := ["lacuna-court", "vermilion-fold", "nacre-engine"]
var recipe: Dictionary = {}
var materials: Dictionary = {}
var batches: Dictionary = {}
var metrics: Dictionary = {}
var built := false
var graybox := false

func get_arena_id() -> String:
	return str(recipe.get("id", ""))

func get_spawn_points() -> Array:
	return recipe.get("arena", {}).get("spawns", [])

func build(id: String = "lacuna-court", gray: bool = false) -> bool:
	if built: return get_arena_id() == id
	if id not in IDS: return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://identity_maps/generated/" + id + ".json"))
	if not parsed is Dictionary: return false
	recipe = parsed
	graybox = gray
	var started := Time.get_ticks_usec()
	_make_materials()
	var arena: Dictionary = recipe.arena
	for block: Dictionary in arena.blocks:
		var size := Vector3(block.w, block.h - block.baseY, block.d)
		var center := Vector3(block.x, (block.h + block.baseY) * 0.5, block.z)
		var mesh := BoxMesh.new()
		mesh.size = size
		_append_arrays(mesh.get_mesh_arrays(), center, str(block.material))
		var body := StaticBody3D.new()
		body.name = str(block.id)
		body.position = center
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
	for surface: Dictionary in arena.terrain.surfaces:
		_surface(surface, "floor")
	for surface: Dictionary in recipe.art:
		if not graybox or str(surface.id).ends_with("-infill"):
			_surface(surface, str(surface.material))
	_flush()
	built = true
	metrics.build_ms = float(Time.get_ticks_usec() - started) / 1000.0
	metrics.geometry_hash = recipe.geometryHash
	metrics.graybox = graybox
	return true

func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func _make_materials() -> void:
	var p: Array = recipe.palette
	for key: String in ["floor","shell","cut","enamel","accent"]:
		var m := StandardMaterial3D.new()
		var index: int = {"floor":0,"shell":0,"cut":1,"enamel":2,"accent":3}[key]
		m.albedo_color = Color("a4a8ac") if graybox else Color(str(p[index]))
		m.roughness = 0.82 if key in ["floor","shell","cut"] else 0.37
		m.metallic = 0.45 if key == "accent" else 0.0
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials[key] = m

func _triangle(a: Vector3, b: Vector3, c: Vector3, material: String) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.length_squared() < 0.5: return
	var center := (a + b + c) / 3.0
	var key := "%s:%d:%d" % [material, floori(center.x / 12.0), floori(center.z / 12.0)]
	if not batches.has(key):
		batches[key] = {"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"material":material}
	for vertex: Vector3 in [a,b,c]:
		batches[key].vertices.append(vertex)
		batches[key].normals.append(normal)

func _append_arrays(arrays: Array, center: Vector3, material: String) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0,indices.size(),3):
		_triangle(vertices[indices[i]]+center,vertices[indices[i+1]]+center,vertices[indices[i+2]]+center,material)

func _surface(s: Dictionary, material: String) -> void:
	var faces := PackedVector3Array()
	for triangle: Array in s.triangles:
		var a := _v(s.vertices[triangle[0]])
		var b := _v(s.vertices[triangle[1]])
		var c := _v(s.vertices[triangle[2]])
		_triangle(a,b,c,material)
		faces.append_array(PackedVector3Array([a,b,c]))
	if faces.is_empty(): return
	var body := StaticBody3D.new()
	body.name = str(s.id)
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func _flush() -> void:
	var triangles := 0
	for key: String in batches:
		var batch: Dictionary = batches[key]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = batch.vertices
		arrays[Mesh.ARRAY_NORMAL] = batch.normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(0,materials[batch.material])
		var instance := MeshInstance3D.new()
		instance.name = key.replace(":","_")
		instance.mesh = mesh
		add_child(instance)
		triangles += batch.vertices.size() / 3
	metrics = {"triangles":triangles,"material_cells":batches.size(),"materials":materials.size(),"nodes":get_child_count()+1}
	batches.clear()
