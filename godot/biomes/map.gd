extends Node3D
## Exact authoritative terrain, with batched procedural plants and scenery.
const SURFACE = preload("res://biomes/surface.gdshader")
const FOLIAGE = preload("res://biomes/foliage.gdshader")
const Geometry = preload("res://native_arenas/maps/geometry.gd")
var recipe: Dictionary = {}
var materials: Dictionary = {}
var heights: Dictionary = {}
var built := false
var forest := true
var foliage_batches := 0
var plant_count := 0

func get_arena_id() -> String:
	return str(recipe.get("id", ""))

func get_spawn_points() -> Array:
	return recipe.get("arena", {}).get("spawns", [])

func build(id := "canopy-divide") -> bool:
	if built: return get_arena_id() == id
	if id not in ["canopy-divide", "basalt-reach"]: return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://identity_maps/generated/" + id + ".json"))
	if not data is Dictionary: return false
	recipe = data
	forest = id == "canopy-divide"
	_make_materials()
	for surface: Dictionary in recipe.arena.terrain.surfaces:
		for v: Array in surface.vertices: heights[Vector2i(int(v[0]), int(v[2]))] = float(v[1])
		_surface(surface, true)
	for surface: Dictionary in recipe.art: _surface(surface, false)
	for block: Dictionary in recipe.arena.blocks:
		var size := Vector3(block.w, block.h - block.baseY, block.d)
		var center := Vector3(block.x, (block.h + block.baseY) * 0.5, block.z)
		Geometry.box(self, str(block.id), center, size, materials[block.material])
		if str(block.id).begins_with("tree-"): continue
		# Insets and crowns read as built architecture; cover stays the exact box.
		var cornice := MeshInstance3D.new()
		cornice.mesh = BoxMesh.new()
		cornice.mesh.size = Vector3(size.x * 0.96, 0.12, size.z * 0.96)
		cornice.position = Vector3(block.x, block.h + 0.03, block.z)
		cornice.material_override = materials.metal if not forest else materials.moss
		add_child(cornice)
		if str(block.id).contains("relay"):
			var beacon := MeshInstance3D.new()
			beacon.mesh = BoxMesh.new()
			beacon.mesh.size = Vector3(0.08, size.y * 0.65, 0.04)
			beacon.position = center + Vector3(size.x * 0.25, 0, -size.z * 0.5 - 0.025)
			beacon.material_override = materials.light
			add_child(beacon)
	_build_plants()
	_build_vistas()
	built = true
	return true

func _make_materials() -> void:
	var palette := {"soil":"6a7150", "moss":"557546", "gravel":"88918a", "sand":"cba77a", "rock":"6b7773" if forest else "967159", "stone":"b3b19a" if forest else "66676a", "metal":"526978", "bark":"69503a"}
	for key: String in palette:
		var mat := ShaderMaterial.new()
		mat.shader = SURFACE
		mat.set_shader_parameter("base_color", Color(palette[key]))
		mat.set_shader_parameter("grain_scale", 5.0 if key in ["sand","gravel"] else 2.4)
		mat.set_shader_parameter("metal", 0.65 if key == "metal" else 0.0)
		materials[key] = mat
	var light := StandardMaterial3D.new()
	light.albedo_color = Color("94d6ba" if forest else "7edee4")
	light.emission_enabled = true
	light.emission = light.albedo_color
	light.emission_energy_multiplier = 0.7
	materials.light = light

func _surface(surface: Dictionary, collide: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for triangle: Array in surface.triangles:
		var a := _v(surface.vertices[triangle[0]])
		var b := _v(surface.vertices[triangle[1]])
		var c := _v(surface.vertices[triangle[2]])
		var normal := (b-a).cross(c-a).normalized()
		# Godot front faces are clockwise; source support winding points upward.
		for p: Vector3 in [a,c,b]:
			st.set_normal(normal)
			st.add_vertex(p)
		faces.append_array(PackedVector3Array([a,b,c]))
	var mesh := MeshInstance3D.new()
	mesh.name = str(surface.id)
	mesh.mesh = st.commit()
	mesh.material_override = materials[surface.material]
	add_child(mesh)
	if collide:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		collision.shape = shape
		body.add_child(collision)
		add_child(body)

func _height(x: float, z: float) -> float:
	var ix := clampi(floori(x/2)*2,-48,46)
	var iz := clampi(floori(z/2)*2,-40,38)
	var u := clampf((x-ix)/2.0,0,1)
	var v := clampf((z-iz)/2.0,0,1)
	var a: float = heights[Vector2i(ix,iz)]
	var b: float = heights[Vector2i(ix,iz+2)]
	var c: float = heights[Vector2i(ix+2,iz+2)]
	var d: float = heights[Vector2i(ix+2,iz)]
	return a+(c-b)*u+(b-a)*v if v >= u else a+(d-a)*u+(c-d)*v

static func _v(p: Array) -> Vector3:
	return Vector3(p[0],p[1],p[2])

func _clear_lane(x: float, z: float, radius := 2.5) -> bool:
	var point := Vector2(x,z)
	for route: Dictionary in recipe.routes:
		for i in range(1,route.points.size()):
			var a := Vector2(route.points[i-1].x,route.points[i-1].z)
			var b := Vector2(route.points[i].x,route.points[i].z)
			var t := clampf((point-a).dot(b-a)/(b-a).length_squared(),0,1)
			if point.distance_to(a+(b-a)*t) < radius: return false
	for block: Dictionary in recipe.arena.blocks:
		if absf(x-block.x) < block.w*0.5+radius and absf(z-block.z) < block.d*0.5+radius: return false
	return true

func _batch(mesh: Mesh, transforms: Array[Transform3D], label: String) -> void:
	if transforms.is_empty(): return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i,transforms[i])
		multi.set_instance_custom_data(i,Color(float(i%7)/6.0,0,0,1))
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	var mat := ShaderMaterial.new()
	mat.shader = FOLIAGE
	node.material_override = mat
	node.visibility_range_end = 160.0
	add_child(node)
	foliage_batches += 1
	plant_count += transforms.size()

# Shared organic asset meshes. Asymmetric branches and lobed leaf masses avoid
# identical cone-tree silhouettes; seeded placement is stable across launches.
func _tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube(st,Vector3.ZERO,Vector3(0.18,5.4,0.1),0.43,0.13,Color(0.30,0.23,0.15,0))
	for i in 7:
		var angle := i*2.399
		var start := Vector3(0.1,2.7+i*0.35,0.08)
		var end := start+Vector3(cos(angle)*1.6,1.2,sin(angle)*1.6)
		_tube(st,start,end,0.13,0.025,Color(0.33,0.26,0.17,0))
		_lobe(st,end,Vector3(1.6,1.2,1.4),Color(0.23+i*0.013,0.39+i*0.016,0.19,1))
	_lobe(st,Vector3(0.2,6.1,0.1),Vector3(1.5,1.3,1.4),Color(0.32,0.48,0.23,1))
	return st.commit()

func _plant_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 9:
		var angle := i*2.399
		var reach := 0.45+float(i%3)*0.15
		var end := Vector3(cos(angle)*reach,0.25+float(i%4)*0.13,sin(angle)*reach)
		var right := Vector3(-sin(angle),0,cos(angle))*0.09
		var middle := end*0.65+Vector3(0,0.18,0)
		var color := Color(0.28,0.44+float(i%3)*0.06,0.19,1) if forest else Color(0.48,0.49,0.28,1)
		_tri(st,Vector3.ZERO,middle+right,end,color)
		_tri(st,Vector3.ZERO,end,middle-right,color)
	return st.commit()

func _tube(st: SurfaceTool, start: Vector3, end: Vector3, lower: float, upper: float, color: Color) -> void:
	var axis := (end-start).normalized()
	var side := axis.cross(Vector3.FORWARD).normalized()
	var other := axis.cross(side)
	for i in 8:
		var a := (side*cos(i*TAU/8)+other*sin(i*TAU/8))
		var b := (side*cos((i+1)*TAU/8)+other*sin((i+1)*TAU/8))
		_tri(st,start+a*lower,end+b*upper,end+a*upper,color)
		_tri(st,start+a*lower,start+b*lower,end+b*upper,color)

func _lobe(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	for ring in 5:
		for side in 10:
			var a := _sphere(ring,side)*size+center
			var b := _sphere(ring+1,side)*size+center
			var c := _sphere(ring+1,side+1)*size+center
			var d := _sphere(ring,side+1)*size+center
			if ring > 0: _tri(st,a,d,b,color)
			if ring < 4: _tri(st,d,c,b,color)

static func _sphere(ring: int, side: int) -> Vector3:
	var phi := ring*PI/5.0
	var theta := side*TAU/10.0
	var ripple := 1.0+0.09*sin(theta*3.0+phi*2.0)
	return Vector3(sin(phi)*cos(theta)*ripple,cos(phi),sin(phi)*sin(theta)*ripple)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b-a).cross(c-a).normalized()
	for p: Vector3 in [a,c,b]:
		st.set_normal(normal)
		st.set_color(color)
		st.add_vertex(p)

func _build_plants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41071 if forest else 72013
	var trees: Array[Transform3D] = []
	if forest:
		for b: Dictionary in recipe.arena.blocks:
			if not str(b.id).begins_with("tree-"): continue
			trees.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU),Vector3(b.x,_height(b.x,b.z),b.z)))
		# Dense forest beyond playable bounds gives the ravine a natural horizon.
		for i in 100:
			var angle := rng.randf()*TAU
			var x := cos(angle)*rng.randf_range(52,72)
			var z := sin(angle)*rng.randf_range(46,65)
			if absf(x)<49 and absf(z)<41: continue
			var scale_value := rng.randf_range(0.9,1.55)
			trees.append(Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*scale_value),Vector3(x,_height(x,z),z)))
		_batch(_tree_mesh(),trees,"CanopyTrees")
	var plants: Array[Transform3D] = []
	for i in (1700 if forest else 650):
		var x := rng.randf_range(-47,47)
		var z := rng.randf_range(-39,39)
		if not _clear_lane(x,z,1.6): continue
		var scale_value := rng.randf_range(0.55,1.3)
		plants.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value),Vector3(x,_height(x,z)+0.02,z)))
	_batch(_plant_mesh(),plants,"Understory" if forest else "DryScrub")

func _build_vistas() -> void:
	# Silhouette-only scenery sits outside the bounded combat field.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-92,92,4):
		for z in range(-84,84,4):
			if x >= -48 and x < 48 and z >= -40 and z < 40: continue
			var a := Vector3(x,_height(x,z),z)
			var b := Vector3(x,_height(x,z+4),z+4)
			var c := Vector3(x+4,_height(x+4,z+4),z+4)
			var d := Vector3(x+4,_height(x+4,z),z)
			_tri(st,a,b,c,Color.WHITE)
			_tri(st,a,c,d,Color.WHITE)
	var skirt := MeshInstance3D.new()
	skirt.name = "DistantTerrain"
	skirt.mesh = st.commit()
	skirt.material_override = materials.moss if forest else materials.sand
	add_child(skirt)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9017
	for i in 24:
		var angle := i*TAU/24
		var center := Vector3(cos(angle)*rng.randf_range(64,90),1,sin(angle)*rng.randf_range(57,77))
		var mesh := MeshInstance3D.new()
		var radius := rng.randf_range(7,12)
		var height := rng.randf_range(12,24) if forest else rng.randf_range(19,34)
		mesh.mesh = _cliff_mesh(radius,height,i*0.7)
		mesh.position = center-Vector3(0,5,0)
		mesh.rotation.y = rng.randf()*TAU
		mesh.material_override = materials.rock
		add_child(mesh)

func _cliff_mesh(radius: float, height: float, phase: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for ring in 7:
		var points: Array[Vector3] = []
		for i in 16:
			var angle := i*TAU/16.0
			var taper: float = [1.2,1.05,1.08,0.88,0.92,0.72,0.58][ring]
			var r := radius*taper*(1.0+0.19*sin(angle*3.0+phase)+0.11*cos(angle*5.0+ring))
			var y := height*ring/6.0+(sin(angle*3.0+phase)*0.08*height if ring > 0 else 0.0)
			points.append(Vector3(cos(angle)*r,y,sin(angle)*r))
		rings.append(points)
	for ring in 6:
		for i in 16:
			var j := (i+1)%16
			_tri(st,rings[ring][i],rings[ring][j],rings[ring+1][i],Color.WHITE)
			_tri(st,rings[ring][j],rings[ring+1][j],rings[ring+1][i],Color.WHITE)
	for i in 16:
		_tri(st,Vector3(0,height,0),rings[6][(i+1)%16],rings[6][i],Color.WHITE)
	return st.commit()
