extends Node3D
## Campaign terrain is the same single-sheet triangles consumed by source Match.
## Heights are feet heights. Scenery has no gameplay collision; blocks do.
const IDS := ["rootfall-verge", "siltwake-crossing", "emberline-ascent", "crown-array"]
const CELL := 4.0
const CHUNK := 32.0
var recipe: Dictionary = {}
var materials: Dictionary = {}
var heights: Dictionary = {}
var terrain_chunks := 0
var art_batches := 0
var art_instances := 0
var _meshes: Dictionary = {}

func get_arena_id() -> String:
	return str(recipe.get("id", ""))

func get_spawn_points() -> Array:
	return recipe.get("arena", {}).get("spawns", [])

func build(id: String) -> bool:
	if id not in IDS: return false
	if get_arena_id() == id: return true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://campaign/generated/" + id + ".json"))
	if not parsed is Dictionary: return false
	var data: Dictionary = parsed
	if data.get("schemaVersion") != 1 or data.get("id") != id: return false
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	recipe = data
	heights.clear()
	materials.clear()
	_meshes.clear()
	terrain_chunks = 0
	art_batches = 0
	art_instances = 0
	_make_materials()
	for surface: Dictionary in recipe.arena.terrain.surfaces:
		for v: Array in surface.vertices: heights[Vector2i(roundi(v[0]), roundi(v[2]))] = float(v[1])
		_surface(surface)
	_build_blocks()
	_build_art()
	return true

func height_at(x: float, z: float) -> float:
	if recipe.is_empty() or not is_finite(x) or not is_finite(z): return NAN
	var bounds: Dictionary = recipe.arena.bounds
	if x < bounds.minX or x > bounds.maxX or z < bounds.minZ or z > bounds.maxZ: return NAN
	var ix := mini(floori((x - float(bounds.minX)) / CELL) * int(CELL) + int(bounds.minX), int(bounds.maxX) - int(CELL))
	var iz := mini(floori((z - float(bounds.minZ)) / CELL) * int(CELL) + int(bounds.minZ), int(bounds.maxZ) - int(CELL))
	var u := (x - ix) / CELL
	var v := (z - iz) / CELL
	var a: float = heights[Vector2i(ix, iz)]
	var b: float = heights[Vector2i(ix, iz + int(CELL))]
	var c: float = heights[Vector2i(ix + int(CELL), iz + int(CELL))]
	var d: float = heights[Vector2i(ix + int(CELL), iz)]
	return a + (c-b)*u + (b-a)*v if v >= u else a + (d-a)*u + (c-d)*v

func _make_materials() -> void:
	var names := ["ground", "trail", "rock", "stone", "metal", "light"]
	for i: int in names.size():
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(str(recipe.palette[i]))
		mat.roughness = 0.92
		if names[i] == "metal":
			mat.metallic = 0.35
			mat.roughness = 0.65
		if names[i] == "light":
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 1.4
		materials[names[i]] = mat
	var foliage := StandardMaterial3D.new()
	foliage.vertex_color_use_as_albedo = true
	foliage.roughness = 1.0
	materials.foliage = foliage

static func _v(p: Array) -> Vector3:
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _surface(surface: Dictionary) -> void:
	var origin := _v(surface.vertices[0])
	origin.y = 0.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for triangle: Array in surface.triangles:
		var a := _v(surface.vertices[int(triangle[0])]) - origin
		var b := _v(surface.vertices[int(triangle[1])]) - origin
		var c := _v(surface.vertices[int(triangle[2])]) - origin
		var normal := (b-a).cross(c-a).normalized()
		# Source upward winding; Godot clockwise front faces.
		for p: Vector3 in [a, c, b]:
			st.set_normal(normal)
			st.add_vertex(p)
		faces.append_array(PackedVector3Array([a, b, c]))
	var mesh := MeshInstance3D.new()
	mesh.name = str(surface.id)
	mesh.position = origin
	mesh.mesh = st.commit()
	mesh.material_override = materials[surface.material]
	add_child(mesh)
	var body := StaticBody3D.new()
	body.position = origin
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	terrain_chunks += 1

func _build_blocks() -> void:
	var groups: Dictionary = {}
	var body := StaticBody3D.new()
	body.name = "AuthoritativeBlocks"
	add_child(body)
	for block: Dictionary in recipe.arena.blocks:
		var size := Vector3(block.w, block.h - block.baseY, block.d)
		var center := Vector3(block.x, (block.h + block.baseY)*0.5, block.z)
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.position = center
		collision.shape = shape
		body.add_child(collision)
		_group(groups, "box", str(block.material), center, size)
	for group: Dictionary in groups.values(): _batch(group, true)

func _group(groups: Dictionary, kind: String, material: String, at: Vector3, size: Vector3) -> void:
	var cell := Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK))
	var key := "%s/%s/%d/%d" % [kind, material, cell.x, cell.y]
	if not groups.has(key):
		groups[key] = {"kind":kind, "material":material, "origin":Vector3(cell.x*CHUNK, 0, cell.y*CHUNK), "transforms":[]}
	var group: Dictionary = groups[key]
	var origin: Vector3 = group.origin
	var transform := Transform3D(Basis.from_scale(size), at - origin)
	group.transforms.append(transform)

func _build_art() -> void:
	var groups: Dictionary = {}
	for prop: Dictionary in recipe.art:
		_group(groups, str(prop.kind), str(prop.material), _v(prop.position), _v(prop.scale))
	for group: Dictionary in groups.values(): _batch(group, false)

func _batch(group: Dictionary, solid: bool) -> void:
	var kind: String = group.kind
	if not _meshes.has(kind): _meshes[kind] = _prop_mesh(kind)
	var mesh: Mesh = _meshes[kind]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = group.transforms.size()
	var bounds := AABB()
	for i: int in group.transforms.size():
		var transform: Transform3D = group.transforms[i]
		multi.set_instance_transform(i, transform)
		var instance_bounds: AABB = transform * mesh.get_aabb()
		bounds = instance_bounds if i == 0 else bounds.merge(instance_bounds)
	# Explicit union includes full scaled crowns, beacon tops, and giant ridge
	# blocks; a fixed 32m cell box would incorrectly cull their overhangs.
	multi.custom_aabb = bounds.grow(0.1)
	var node := MultiMeshInstance3D.new()
	node.name = ("Solid_" if solid else "Scenery_") + kind
	node.position = group.origin
	node.multimesh = multi
	node.material_override = materials[group.material]
	# Dummy/headless RenderingServer does not retain MultiMesh transforms. Keep
	# this small bounded CPU mirror for collision/cull-contract diagnostics.
	node.set_meta("instance_transforms", group.transforms.duplicate())
	# Never range-hide physical cover or guidance. Only distant small scenery
	# fades; chunk-local origins make range culling meaningful across this map.
	if not solid and kind in ["tree", "crag", "fern"]:
		node.visibility_range_end = 140.0 if kind == "fern" else 650.0
		node.visibility_range_end_margin = 25.0
	add_child(node)
	art_batches += 1
	art_instances += multi.instance_count

func _prop_mesh(kind: String) -> Mesh:
	if kind == "box": return BoxMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind == "tree":
		_prism(st, Vector3(0, 0, 0), Vector3(0.025, 0.72, 0), 0.075, 0.035, 6, Color("645241"))
		# Asymmetric interlocking faceted crowns, not identical cone trees.
		_prism(st, Vector3(-0.13, 0.36, 0.03), Vector3(-0.18, 0.80, 0.05), 0.33, 0.12, 7, Color("496d48"))
		_prism(st, Vector3(0.15, 0.46, -0.07), Vector3(0.19, 0.88, -0.09), 0.32, 0.10, 7, Color("668752"))
		_prism(st, Vector3(0.02, 0.62, 0), Vector3(0, 1, 0), 0.29, 0.045, 7, Color("78945e"))
	elif kind == "fern":
		var color := Color("527842") if int(recipe.campaign.index) in [0, 3] else Color("93805d")
		for i: int in 9:
			var angle := float(i)*2.399
			var tip := Vector3(cos(angle)*0.5, 0.2+float(i%3)*0.2, sin(angle)*0.5)
			var side := Vector3(-sin(angle), 0, cos(angle))*0.085
			var mid := tip*0.55 + Vector3(0, 0.25, 0)
			_tri(st, Vector3.ZERO, mid+side, tip, color)
			_tri(st, Vector3.ZERO, tip, mid-side, color)
			_tri(st, Vector3.ZERO, tip, mid+side, color)
			_tri(st, Vector3.ZERO, mid-side, tip, color)
	elif kind == "dish":
		_prism(st, Vector3.ZERO, Vector3(0, 0.3, 0), 0.065, 0.09, 8, Color.WHITE)
		# Open segmented receiver bowl: a legible skyline silhouette.
		for i: int in 12:
			var a := float(i)*TAU/12.0
			var b := float(i+1)*TAU/12.0
			var inner_a := Vector3(cos(a)*0.09, 0.32, sin(a)*0.09)
			var inner_b := Vector3(cos(b)*0.09, 0.32, sin(b)*0.09)
			var outer_a := Vector3(cos(a)*0.5, 0.70, sin(a)*0.5)
			var outer_b := Vector3(cos(b)*0.5, 0.70, sin(b)*0.5)
			_tri(st, inner_a, outer_b, outer_a, Color.WHITE)
			_tri(st, inner_a, inner_b, outer_b, Color.WHITE)
			_tri(st, inner_a, outer_a, outer_b, Color.WHITE)
			_tri(st, inner_a, outer_b, inner_b, Color.WHITE)
		_prism(st, Vector3(0, 0.3, 0), Vector3(0, 1, 0), 0.018, 0.008, 6, Color.WHITE)
	elif kind == "fallen-relay":
		# Tumbled lattice mast, authored above the fallen relay's solid housing.
		for i: int in 8:
			var x := -0.5+float(i)/7.0
			_prism(st, Vector3(x, 0, -0.25), Vector3(x+0.03, 0.8, 0.25), 0.015, 0.015, 4, Color.WHITE)
		_prism(st, Vector3(-0.5, 0, -0.25), Vector3(0.5, 0.25, -0.25), 0.025, 0.025, 4, Color.WHITE)
		_prism(st, Vector3(-0.5, 0.8, 0.25), Vector3(0.5, 1, 0.25), 0.025, 0.025, 4, Color.WHITE)
	elif kind == "beacon":
		_prism(st, Vector3.ZERO, Vector3(0, 1, 0), 0.5, 0.35, 4, Color.WHITE)
	else:
		_prism(st, Vector3.ZERO, Vector3(0.12, 1, -0.04), 0.5, 0.28, 6, Color.WHITE)
	return st.commit()

func _prism(st: SurfaceTool, low: Vector3, high: Vector3, lower: float, upper: float, sides: int, color: Color) -> void:
	for i: int in sides:
		var angle := float(i)*TAU/sides
		var next := float(i+1)*TAU/sides
		var a := low + Vector3(cos(angle)*lower, 0, sin(angle)*lower)
		var b := low + Vector3(cos(next)*lower, 0, sin(next)*lower)
		var c := high + Vector3(cos(next)*upper, 0, sin(next)*upper)
		var d := high + Vector3(cos(angle)*upper, 0, sin(angle)*upper)
		_tri(st, a, d, b, color)
		_tri(st, b, d, c, color)
		_tri(st, high, c, d, color)
		_tri(st, low, a, b, color)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b-a).cross(c-a).normalized()
	for p: Vector3 in [a, c, b]:
		st.set_normal(normal)
		st.set_color(color)
		st.add_vertex(p)

func visible_cost() -> Dictionary:
	return {"terrain_chunks":terrain_chunks, "art_batches":art_batches, "art_instances":art_instances}
