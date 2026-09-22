extends RefCounted
# Only approved, finite data recipes reach the bounded mesh cache.
const PATH := "res://player_models/recipes.json"
static var recipes: Dictionary = {}
static var meshes: Dictionary = {}

static func validate(data: Variant) -> String:
	if not data is Dictionary: return "root must be dictionary"
	if not keys_exact(data, ["version","generator","seed","variants"]): return "root fields"
	if not numeric(data.version) or not numeric(data.seed): return "numeric header"
	if data.version != 1 or data.generator != "faceted-operator-1" or data.seed != 0: return "version/generator/seed"
	if not data.variants is Dictionary or not keys_exact(data.variants,["claude","grok","meta"]): return "variants"
	var names: Array = []
	for variant: String in ["claude","grok","meta"]:
		var parts: Variant = data.variants[variant]
		if not parts is Array or parts.size() < 1 or parts.size() > 64: return "part count"
		var seen: Array = []
		for part: Variant in parts:
			if not part is Dictionary or not keys_exact(part,["name","op","position","size","material","lower","upper","bevel","yaw"]): return "part fields"
			if not part.name is String or not part.name.is_valid_identifier() or part.name.length() > 40 or part.name in seen: return "part name"
			seen.append(part.name)
			if part.op != "prism" or not part.material in ["dark","trim","armor","identity"]: return "operation/material"
			for field: String in ["position","size"]:
				if not part[field] is Array or part[field].size() != 3: return "vector shape"
				for value: Variant in part[field]:
					if not numeric(value) or absf(float(value)) > 1.0: return "finite vector bounds"
					if field == "size" and float(value) < 0.005: return "positive size"
			if not numeric(part.yaw) or absf(float(part.yaw)) > PI: return "yaw bounds"
			for field: String in ["lower","upper","bevel"]:
				if not numeric(part[field]): return "finite shape"
				var lo: float = 0.01 if field == "bevel" else 0.35
				var hi: float = 0.25 if field == "bevel" else 1.0
				if float(part[field]) < lo or float(part[field]) > hi: return "shape bounds"
		for required: String in ["Helmet","Muzzle","TeamStripe0","TeamStripe1","Weapon","WeaponGrip","HandL","HandR"]:
			if not required in seen: return "missing semantic part"
		if names.is_empty(): names = seen
		elif seen != names: return "semantic part mismatch"
	return ""

static func keys_exact(data: Dictionary, wanted: Array) -> bool:
	if data.size() != wanted.size(): return false
	for key: Variant in wanted:
		if not data.has(key): return false
	return true

static func numeric(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func load_recipes() -> bool:
	if not recipes.is_empty(): return true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var error := validate(parsed)
	if not error.is_empty():
		push_error("PLAYER_MODEL_RECIPE: " + error)
		return false
	recipes = parsed
	return true

static func vector(data: Array) -> Vector3:
	return Vector3(data[0],data[1],data[2])

static func mesh_for(part: Dictionary) -> ArrayMesh:
	var key := JSON.stringify([part.size,part.lower,part.upper,part.bevel])
	if meshes.has(key): return meshes[key]
	var size := vector(part.size)
	var outline: Array[Vector2] = [Vector2(-0.7,-1),Vector2(0.7,-1),Vector2(1,-0.7),Vector2(1,0.7),Vector2(0.7,1),Vector2(-0.7,1),Vector2(-1,0.7),Vector2(-1,-0.7)]
	var rings: Array = []
	for row: int in range(4):
		var y: float = [-0.5,-0.5+float(part.bevel),0.5-float(part.bevel),0.5][row]
		var taper: float = lerpf(float(part.lower),float(part.upper),y+0.5)
		var rim: float = 1.0-float(part.bevel) if row in [0,3] else 1.0
		var ring: Array[Vector3] = []
		for point: Vector2 in outline:
			ring.append(Vector3(point.x*size.x*0.5*taper*rim,y*size.y,point.y*size.z*0.5*rim))
		rings.append(ring)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	# Emit CW faces. Geometric cross points inward, normals point out.
	for row: int in range(3):
		for i: int in range(8):
			var j := (i+1)%8
			triangle(vertices,normals,rings[row][i],rings[row+1][i],rings[row][j])
			triangle(vertices,normals,rings[row][j],rings[row+1][i],rings[row+1][j])
	for i: int in range(1,7):
		triangle(vertices,normals,rings[0][0],rings[0][i],rings[0][i+1])
		triangle(vertices,normals,rings[3][0],rings[3][i+1],rings[3][i])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	meshes[key] = result
	return result

static func triangle(vertices: PackedVector3Array,normals: PackedVector3Array,a: Vector3,b: Vector3,c: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	vertices.append_array(PackedVector3Array([a,c,b]))
	normals.append_array(PackedVector3Array([normal,normal,normal]))
