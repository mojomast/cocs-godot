extends Node3D
## Campaign terrain is the same single-sheet triangles consumed by source Match.
## Heights are feet heights. Scenery has no gameplay collision; blocks do.
const IDS := ["rootfall-verge", "siltwake-crossing", "emberline-ascent", "crown-array"]
const CELL := 4.0
var cell_size := 4.0
const CHUNK := 32.0
const BiomeVisual = preload("res://biomes/map.gd")
const SURFACE = preload("res://biomes/surface.gdshader")
const FOLIAGE = preload("res://biomes/foliage.gdshader")
const StructureArt = preload("res://campaign/structure_art.gd")
const EnvironmentArt = preload("res://campaign/environment_art.gd")
var recipe: Dictionary = {}
var materials: Dictionary = {}
var heights: Dictionary = {}
var terrain_normals: Dictionary = {}
var trail_distances: Dictionary = {}
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
	var first: Array = data.arena.terrain.surfaces[0].vertices
	var decoded_cell := float(first[1][2])-float(first[0][2])
	if decoded_cell not in [2.0,4.0]: return false
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	recipe = data
	cell_size = decoded_cell
	heights.clear()
	terrain_normals.clear()
	trail_distances.clear()
	materials.clear()
	_meshes.clear()
	terrain_chunks = 0
	art_batches = 0
	art_instances = 0
	horizon_chunks = 0
	_make_materials()
	for surface: Dictionary in recipe.arena.terrain.surfaces:
		for v: Array in surface.vertices: heights[Vector2i(roundi(v[0]), roundi(v[2]))] = float(v[1])
	# Shared vertex normals prevent a diagonal broad slope from reading as an
	# alternating row of triangular teeth. Geometry/collision stay unchanged;
	# the separately authored boulders, shelves and machinery retain flat facets.
	var bounds: Dictionary = recipe.arena.bounds
	for key: Vector2i in heights:
		var left := maxf(bounds.minX, key.x-CELL)
		var right := minf(bounds.maxX, key.x+CELL)
		var back := maxf(bounds.minZ, key.y-CELL)
		var front := minf(bounds.maxZ, key.y+CELL)
		terrain_normals[key] = Vector3(-(height_at(right,key.y)-height_at(left,key.y))/(right-left), 1, -(height_at(key.x,front)-height_at(key.x,back))/(front-back)).normalized()
	var path: Array = recipe.campaign.criticalPath
	for i: int in range(1,path.size()):
		var a := Vector2(path[i-1].x,path[i-1].z)
		var b := Vector2(path[i].x,path[i].z)
		var axis := b-a
		for x: int in range(floori((minf(a.x,b.x)-7)/cell_size)*int(cell_size),ceili((maxf(a.x,b.x)+7)/cell_size)*int(cell_size)+1,int(cell_size)):
			for z: int in range(floori((minf(a.y,b.y)-7)/cell_size)*int(cell_size),ceili((maxf(a.y,b.y)+7)/cell_size)*int(cell_size)+1,int(cell_size)):
				var key := Vector2i(x,z)
				if not heights.has(key): continue
				var p := Vector2(x,z)
				var t := clampf((p-a).dot(axis)/axis.length_squared(),0,1)
				var distance := p.distance_to(a+axis*t)
				trail_distances[key] = minf(trail_distances.get(key,INF),distance)
	for surface: Dictionary in recipe.arena.terrain.surfaces:
		_surface(surface)
	_build_blocks()
	var structures := StructureArt.new()
	structures.name = "StructureArt"
	add_child(structures)
	structures.build(self)
	_build_art()
	_build_horizon()
	var biome_art := EnvironmentArt.new()
	biome_art.name = "CampaignEnvironmentArt"
	add_child(biome_art)
	biome_art.build(self)
	return true

func height_at(x: float, z: float) -> float:
	if recipe.is_empty() or not is_finite(x) or not is_finite(z): return NAN
	var bounds: Dictionary = recipe.arena.bounds
	if x < bounds.minX or x > bounds.maxX or z < bounds.minZ or z > bounds.maxZ: return NAN
	var ix := mini(floori((x - float(bounds.minX)) / cell_size) * int(cell_size) + int(bounds.minX), int(bounds.maxX) - int(cell_size))
	var iz := mini(floori((z - float(bounds.minZ)) / cell_size) * int(cell_size) + int(bounds.minZ), int(bounds.maxZ) - int(cell_size))
	var u := (x - ix) / cell_size
	var v := (z - iz) / cell_size
	var a: float = heights[Vector2i(ix, iz)]
	var b: float = heights[Vector2i(ix, iz + int(cell_size))]
	var c: float = heights[Vector2i(ix + int(cell_size), iz + int(cell_size))]
	var d: float = heights[Vector2i(ix + int(cell_size), iz)]
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
	# Keep the original biome grain/seam shader, but interpolate ecological
	# material transitions per vertex. Whole-cell material labels otherwise draw
	# a row of bright triangular "teeth" even on a geometrically smooth slope.
	var terrain_shader := Shader.new()
	terrain_shader.code = SURFACE.code.replace("uniform float grain_scale", "uniform vec4 trail_color : source_color;\nuniform vec4 rock_color : source_color;\nvarying vec2 terrain_blend;\nuniform float grain_scale").replace("void vertex() {", "void vertex() { terrain_blend = COLOR.rg;").replace("ALBEDO = base_color.rgb *", "ALBEDO = mix(mix(base_color.rgb,trail_color.rgb,terrain_blend.x),rock_color.rgb,terrain_blend.y) *")
	var terrain_material := ShaderMaterial.new()
	terrain_material.shader = terrain_shader
	terrain_material.set_shader_parameter("base_color",Color(str(recipe.palette[0])))
	terrain_material.set_shader_parameter("trail_color",Color(str(recipe.palette[1])))
	terrain_material.set_shader_parameter("rock_color",Color(str(recipe.palette[2])))
	terrain_material.set_shader_parameter("grain_scale",3.5)
	materials.terrain = terrain_material

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
			var world_point := p+origin
			var key := Vector2i(roundi(world_point.x),roundi(world_point.z))
			var vertex_normal: Vector3 = terrain_normals[key] if collide else normal
			st.set_normal(vertex_normal)
			var trail := 1.0-smoothstep(2.0,6.0,float(trail_distances.get(key,INF))) if collide else 0.0
			var rock := 1.0-smoothstep(0.58,0.90,vertex_normal.y)
			st.set_color(Color(trail,rock,0,1))
			st.add_vertex(p)
		faces.append_array(PackedVector3Array([a, b, c]))
	var mesh := MeshInstance3D.new()
	mesh.name = str(surface.id)
	mesh.position = origin
	mesh.mesh = st.commit()
	mesh.material_override = materials.terrain if collide and surface.material in ["ground","trail","rock"] else materials[surface.material]
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
		if block.material == "rock": _group(groups, "box", str(block.material), center, size)
	for group: Dictionary in groups.values(): _batch(group, true)

func _group(groups: Dictionary, kind: String, material: String, at: Vector3, size: Vector3) -> void:
	var rock := kind in ["crag", "mountain"]
	var seed_value := int(absf(sin(at.x*0.071+at.z*0.053))*1000.0)
	var preferred: int = [0,1,2,0][int(recipe.campaign.index)]
	var variant := preferred if seed_value%5 < 3 else seed_value%4
	var asset_kind := kind + "-%d" % variant if rock else kind
	var cell := Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK))
	var key := "%s/%s/%d/%d" % [asset_kind, material, cell.x, cell.y]
	if not groups.has(key):
		groups[key] = {"kind":asset_kind, "material":material, "origin":Vector3(cell.x*CHUNK, 0, cell.y*CHUNK), "transforms":[]}
	var group: Dictionary = groups[key]
	var origin: Vector3 = group.origin
	var basis := Basis(Vector3.UP, fposmod(at.x*0.217+at.z*0.139,TAU)).scaled(size) if rock else Basis.from_scale(size)
	var transform := Transform3D(basis, at - origin)
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
	if not solid and (kind in ["tree", "fern"] or kind.begins_with("crag-")):
		node.visibility_range_end = 140.0 if kind == "fern" else 650.0
		node.visibility_range_end_margin = 25.0
	add_child(node)
	art_batches += 1
	art_instances += multi.instance_count

func _prop_mesh(kind: String) -> Mesh:
	if kind in ["box", "water"]: return BoxMesh.new()
	if kind.begins_with("crag-") or kind.begins_with("mountain-"): return _rock_mesh(int(kind.get_slice("-",1)))
	if kind in ["tree", "fern"]:
		# Reuse the actual Canopy/Basalt authored branching/lobed assets, not a
		# cone-tree approximation. Normalize once so recipe scales stay metres.
		var original := BiomeVisual.new()
		original.forest = int(recipe.campaign.index) in [0, 3]
		var mesh: ArrayMesh = original._tree_mesh() if kind == "tree" else original._plant_mesh()
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

func _rock_mesh(variant: int) -> ArrayMesh:
	# Four geological solids, not recoloured copies of one pointed prism:
	# weathered boulder, layered mesa, massive basalt slab, leaning broken spur.
	var levels: Array = [[0.0,0.16,0.64,0.94],[0.0,0.16,0.23,0.64,0.71,1.0],[0.0,0.14,0.76,1.0],[0.0,0.12,0.45,0.80,1.0]][variant]
	var radii: Array = [[0.30,0.54,0.48,0.26],[0.43,0.48,0.54,0.43,0.48,0.37],[0.50,0.53,0.47,0.38],[0.43,0.54,0.43,0.31,0.18]][variant]
	var sides := 5 if variant == 2 else 7 if variant == 0 else 6
	var rings: Array = []
	for ring: int in levels.size():
		var points: Array[Vector3] = []
		for side: int in sides:
			var angle := float(side)*TAU/sides
			var radius: float = radii[ring]*(1.0+0.09*cos(angle*2.0+variant))
			var shift := float(levels[ring])*(0.19 if variant == 3 else -0.07)
			points.append(Vector3(cos(angle)*radius+shift, levels[ring], sin(angle)*radius))
		rings.append(points)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring: int in range(rings.size()-1):
		for side: int in sides:
			var next := (side+1)%sides
			_tri(st,rings[ring][side],rings[ring+1][side],rings[ring][next],Color.WHITE)
			_tri(st,rings[ring][next],rings[ring+1][side],rings[ring+1][next],Color.WHITE)
	for side: int in range(1,sides-1):
		_tri(st,rings.back()[0],rings.back()[side+1],rings.back()[side],Color.WHITE)
		_tri(st,rings.front()[0],rings.front()[side],rings.front()[side+1],Color.WHITE)
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
	var mountain := base + 8.0
	# Unequal, low-frequency surrounding landforms, with genuinely quiet gaps.
	# No periodic sine-grid hill pattern and no uniformly spaced cliff ring.
	var index: int = recipe.campaign.index
	var masses := [Vector4(-0.9,-0.65,95,25),Vector4(0.7,-1.1,140,38),Vector4(1.3,0.4,85,19),Vector4(-0.3,1.2,170,12)]
	for i: int in masses.size():
		var m: Vector4 = masses[(i+index)%masses.size()]
		var dx := (x-m.x*(float(b.maxX)+110.0))/m.z
		var dz := (z-m.y*(float(b.maxZ)+100.0))/(m.z*0.75)
		var shape := 1.0-smoothstep(0.35,1.15,maxf(absf(dx),absf(dz))) if index == 2 else 1.0-smoothstep(0.35,1.1,sqrt(dx*dx+dz*dz)) if index == 1 else exp(-(dx*dx+dz*dz)*1.8)
		mountain += m.w*shape
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
	var index: int = recipe.campaign.index
	var angles: Array = [[12,31,118,206,218],[7,29,54,176,188,272],[45,58,151,239],[16,102,121,244]][index]
	for cluster: int in angles.size():
		var angle := deg_to_rad(float(angles[cluster]))
		var direction := Vector2(cos(angle),sin(angle))
		var edge := minf(float(b.maxX)/maxf(absf(direction.x),0.01),float(b.maxZ)/maxf(absf(direction.y),0.01))
		var center := direction*(edge+rng.randf_range(105,140))
		var count := 2+cluster%3
		for i: int in count:
			var x := center.x+rng.randf_range(-27,27)
			var z := center.y+rng.randf_range(-25,25)
			var width := rng.randf_range(24,65)
			var height := rng.randf_range(7,23) if index == 0 else rng.randf_range(16,43)
			if index == 3 and cluster%2 == 1: height *= 0.45
			var depth := rng.randf_range(18,48)
			var base := _horizon_height(x,z)
			var radius := maxf(width,depth)*0.6
			for sample: int in 8: base = minf(base,_horizon_height(x+cos(sample*TAU/8.0)*radius,z+sin(sample*TAU/8.0)*radius))
			_group(scenery,"mountain","rock",Vector3(x,base-0.5,z),Vector3(width,height,depth))
		if index in [0,3]:
			for i: int in 14+cluster*3:
				var x := center.x+rng.randf_range(-50,50)
				var z := center.y+rng.randf_range(-42,42)
				if x > b.minX-15 and x < b.maxX+15 and z > b.minZ-15 and z < b.maxZ+15: continue
				_group(scenery,"tree","foliage",Vector3(x,_horizon_height(x,z)-0.3,z),Vector3(7,rng.randf_range(9,17),7))
	for group: Dictionary in scenery.values(): _batch(group, false)
