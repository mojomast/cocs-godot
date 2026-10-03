extends SceneTree
## Granted-slot check: exported GLB geometry must equal the authored triangle
## recipe, including node transforms and both LODs. Not just bounding-box parity.
const Pack = preload("res://biomes/expansion/scenery_pack.gd")

func _initialize() -> void: call_deferred("run")

static func key(triangle: Array) -> String:
	var points: Array[String] = []
	for p: Vector3 in triangle:
		points.append("%d,%d,%d" % [roundi(p.x*10000),roundi(p.y*10000),roundi(p.z*10000)])
	points.sort()
	return "|".join(points)

static func collect(node: Node, transform: Transform3D, triangles: Dictionary, counts: Dictionary) -> void:
	if node is Node3D: transform = transform * node.transform
	assert(not node is CollisionObject3D and not node is CollisionShape3D)
	if node is MeshInstance3D:
		counts.meshes += 1
		counts.surfaces += node.mesh.get_surface_count()
		for surface: int in node.mesh.get_surface_count():
			var material: StandardMaterial3D = node.mesh.surface_get_material(surface)
			assert(material != null and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
			assert(material.resource_name.begins_with("biome4_"))
			assert(material.roughness >= 0.65 and not material.emission_enabled)
		# get_faces() builds TriangleMesh, which welds/snaps vertices. Inspect the
		# actual imported vertex/index streams instead of that collision helper.
		var faces := PackedVector3Array()
		for surface: int in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty(): faces.append_array(vertices)
			else:
				for index: int in indices: faces.append(vertices[index])
		for i: int in range(0,faces.size(),3):
			var triangle := [transform*faces[i],transform*faces[i+1],transform*faces[i+2]]
			if counts.has("triangles"): counts.triangles.append(triangle)
			var k := key(triangle)
			triangles[k] = int(triangles.get(k,0)) + 1
	for child: Node in node.get_children(): collect(child,transform,triangles,counts)

static func same_triangles(actual: Array, expected: Array) -> bool:
	# Source JSON -> Blender float32 -> glTF -> Godot float32 may straddle
	# a decimal rounding boundary. Match every vertex, consuming each triangle.
	if actual.size()!=expected.size():
		print("TRIANGLE_COUNT_MISMATCH ",actual.size()," expected ",expected.size())
		return false
	var buckets := {}
	for triangle: Array in expected:
		var center: Vector3=(triangle[0]+triangle[1]+triangle[2])/3.0
		var cell := Vector3i(floori(center.x*100),floori(center.y*100),floori(center.z*100))
		if not buckets.has(cell): buckets[cell]=[]
		buckets[cell].append(triangle)
	for triangle: Array in actual:
		var center: Vector3=(triangle[0]+triangle[1]+triangle[2])/3.0
		var cell := Vector3i(floori(center.x*100),floori(center.y*100),floori(center.z*100))
		var found := false
		for dx: int in range(-1,2):
			for dy: int in range(-1,2):
				for dz: int in range(-1,2):
					if found: continue
					var candidates: Array=buckets.get(cell+Vector3i(dx,dy,dz),[])
					for i: int in candidates.size():
						var unmatched: Array=candidates[i].duplicate()
						for vertex: Vector3 in triangle:
							for j: int in unmatched.size():
								if vertex.distance_to(unmatched[j])<=0.000001:
									unmatched.remove_at(j)
									break
						if unmatched.is_empty():
							candidates.remove_at(i);found=true;break
		if not found:
			print("UNMATCHED_TRIANGLE ",triangle," cell ",cell)
			var best := INF
			var nearest: Array=[]
			for other: Array in expected:
				var distance := 0.0
				for vertex: Vector3 in triangle:
					var delta := INF
					for point: Vector3 in other: delta=minf(delta,vertex.distance_to(point))
					distance=maxf(distance,delta)
				if distance<best: best=distance;nearest=other
			print("NEAREST ",nearest," delta ",best)
			return false
	return true

func run() -> void:
	var recipe_path := ProjectSettings.globalize_path("res://../tools/godot-biomes/expansion/meshes.json")
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(recipe_path))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Pack.CATALOG))
	assert(FileAccess.get_sha256(recipe_path) == str(catalog.recipeSha256))
	var total := 0
	for asset: Dictionary in recipe.assets:
		for lod: int in 2:
			var expected: Dictionary = {}
			var expected_triangles: Array=[]
			for part: Dictionary in asset.parts:
				if lod == 1 and bool(part.detail): continue
				for triangle: Array in part.triangles:
					var vertices := [Pack.vector(part.vertices[int(triangle[0])]),Pack.vector(part.vertices[int(triangle[1])]),Pack.vector(part.vertices[int(triangle[2])])]
					expected_triangles.append(vertices)
					var k := key(vertices)
					expected[k] = int(expected.get(k,0)) + 1
			var scene: PackedScene = load(Pack.ART + str(asset.id) + "-%d.glb" % lod)
			assert(scene != null)
			var instance := scene.instantiate()
			var actual: Dictionary = {}
			var counts := {"meshes":0,"surfaces":0,"triangles":[]}
			collect(instance,Transform3D.IDENTITY,actual,counts)
			if not same_triangles(counts.triangles,expected_triangles):
				var missing: Array=[]
				var extra: Array=[]
				for k: String in expected:
					if actual.get(k,0)!=expected[k]: missing.append(k)
				for k: String in actual:
					if expected.get(k,0)!=actual[k]: extra.append(k)
				print("GEOMETRY_DIFF ",JSON.stringify({"asset":asset.id,"lod":lod,"missingCount":missing.size(),"extraCount":extra.size(),"missing":missing.slice(0,8),"extra":extra.slice(0,8)}))
				instance.free()
				quit(1)
				return
			counts.erase("triangles")
			assert(counts.meshes == 1 and counts.surfaces <= 4)
			print("BIOME4_IMPORT ",asset.id," LOD",lod," ",counts," triangleKeys=",actual.size())
			instance.free()
			total += 1
	assert(total == 24)
	quit()
