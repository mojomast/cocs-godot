extends Node3D
## Campaign terrain is the same single-sheet triangles consumed by source Match.
## Heights are feet heights. Scenery has no gameplay collision; blocks do.
const IDS := ["rootfall-verge", "siltwake-crossing", "emberline-ascent", "crown-array"]
const CELL := 4.0
const CHUNK := 32.0
const BiomeVisual = preload("res://biomes/map.gd")
const SURFACE = preload("res://biomes/surface.gdshader")
const FOLIAGE = preload("res://biomes/foliage.gdshader")
var recipe: Dictionary = {}
var materials: Dictionary = {}
var heights: Dictionary = {}
var terrain_chunks := 0
var art_batches := 0
var art_instances := 0
var horizon_chunks := 0
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
	horizon_chunks = 0
	_make_materials()
	for surface: Dictionary in recipe.arena.terrain.surfaces:
		for v: Array in surface.vertices: heights[Vector2i(roundi(v[0]), roundi(v[2]))] = float(v[1])
		_surface(surface)
	_build_blocks()
	_build_art()
	_build_horizon()
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
		if names[i] == "light":
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(str(recipe.palette[i]))
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 0.7
			materials[names[i]] = mat
		else:
			var mat := ShaderMaterial.new()
			mat.shader = SURFACE
			mat.set_shader_parameter("base_color", Color(str(recipe.palette[i])))
			mat.set_shader_parameter("grain_scale", 5.0 if names[i] == "trail" else 2.4)
			mat.set_shader_parameter("metal", 0.65 if names[i] == "metal" else 0.0)
			materials[names[i]] = mat
	var foliage := ShaderMaterial.new()
	foliage.shader = FOLIAGE
	materials.foliage = foliage
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("386b73")
	water.metallic = 0.35
	water.roughness = 0.22
	materials.water = water

static func _v(p: Array) -> Vector3:
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _surface(surface: Dictionary, collide := true) -> void:
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
	if not collide:
		horizon_chunks += 1
		return
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
	# Original foliage wind displaces local X by <=0.1*local leaf height.
	# These normalized foliage assets/scales stay within a conservative 2m pad.
	multi.custom_aabb = bounds.grow(2.0 if group.material == "foliage" else 0.1)
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
	if kind in ["box", "water"]: return BoxMesh.new()
	if kind in ["tree", "fern", "mountain"]:
		# Reuse the actual Canopy/Basalt authored branching/lobed assets, not a
		# cone-tree approximation. Normalize once so recipe scales stay metres.
		var original := BiomeVisual.new()
		original.forest = int(recipe.campaign.index) in [0, 3]
		var mesh: ArrayMesh = original._tree_mesh() if kind == "tree" else original._plant_mesh() if kind == "fern" else original._cliff_mesh(1.0, 1.0, 0.7)
		original.free()
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var divisor := Vector3(6.4, 7.4, 6.4) if kind == "tree" else Vector3(1.4, 0.8, 1.4) if kind == "fern" else Vector3.ONE
		for i: int in vertices.size():
			vertices[i] /= divisor
			normals[i] = (normals[i]*divisor).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		var result := ArrayMesh.new()
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return result
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind == "pipe":
		_prism(st, Vector3.ZERO, Vector3(0, 1, 0), 0.4, 0.4, 10, Color.WHITE)
		for y: float in [0.1, 0.45, 0.9]: _prism(st, Vector3(0, y, 0), Vector3(0, y+0.045, 0), 0.5, 0.5, 10, Color.WHITE)
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
	return {"terrain_chunks":terrain_chunks, "horizon_chunks":horizon_chunks, "art_batches":art_batches, "art_instances":art_instances}

func _horizon_height(x: float, z: float) -> float:
	var b: Dictionary = recipe.arena.bounds
	var cx := clampf(x, b.minX, b.maxX)
	var cz := clampf(z, b.minZ, b.maxZ)
	var distance := Vector2(x-cx, z-cz).length()
	var blend := smoothstep(0.0, 96.0, distance)
	var base: float = recipe.campaign.anchors.start.y + 12.0
	var mountain := base + 12.0 + 28.0*pow(sin(x*0.017)*cos(z*0.021), 2)
	return lerpf(height_at(cx, cz), mountain, blend)

func _build_horizon() -> void:
	# A 192m stitched scenery collar hides rectangular map edges. Boundary
	# vertices use exact height_at samples; no skirt is gameplay support.
	var b: Dictionary = recipe.arena.bounds
	var groups: Dictionary = {}
	for x: int in range(int(b.minX)-192, int(b.maxX)+192, 4):
		for z: int in range(int(b.minZ)-192, int(b.maxZ)+192, 4):
			if x >= b.minX and x < b.maxX and z >= b.minZ and z < b.maxZ: continue
			var key := "%d-%d" % [floori(float(x)/64.0), floori(float(z)/64.0)]
			if not groups.has(key): groups[key] = {"id":"horizon-"+key, "material":"ground" if int(recipe.campaign.index) in [0,3] else "rock", "vertices":[], "triangles":[]}
			var surface: Dictionary = groups[key]
			var i: int = surface.vertices.size()
			for p: Vector2 in [Vector2(x,z), Vector2(x,z+4), Vector2(x+4,z+4), Vector2(x+4,z)]: surface.vertices.append([p.x,_horizon_height(p.x,p.y),p.y])
			surface.triangles.append([i,i+1,i+2])
			surface.triangles.append([i,i+2,i+3])
	for surface: Dictionary in groups.values(): _surface(surface, false)
	var scenery: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 76312 + int(recipe.campaign.index)
	for i: int in 180:
		var angle := float(i)*2.399
		var x := cos(angle)*(float(b.maxX)+rng.randf_range(28,160))
		var z := sin(angle)*(float(b.maxZ)+rng.randf_range(28,160))
		if x > b.minX-12 and x < b.maxX+12 and z > b.minZ-12 and z < b.maxZ+12: continue
		var wooded := int(recipe.campaign.index) in [0,3] and i%4 != 0
		var size := Vector3(7, rng.randf_range(9,17), 7) if wooded else Vector3(rng.randf_range(12,24), rng.randf_range(20,42), rng.randf_range(12,24))
		_group(scenery, "tree" if wooded else "mountain", "foliage" if wooded else "rock", Vector3(x,_horizon_height(x,z)-1,z), size)
	for group: Dictionary in scenery.values(): _batch(group, false)
