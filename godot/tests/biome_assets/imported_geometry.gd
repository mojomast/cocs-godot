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
		var faces: PackedVector3Array = node.mesh.get_faces()
		for i: int in range(0,faces.size(),3):
			var k := key([transform*faces[i],transform*faces[i+1],transform*faces[i+2]])
			triangles[k] = int(triangles.get(k,0)) + 1
	for child: Node in node.get_children(): collect(child,transform,triangles,counts)

func run() -> void:
	var recipe_path := ProjectSettings.globalize_path("res://../tools/godot-biomes/expansion/meshes.json")
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(recipe_path))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Pack.CATALOG))
	assert(FileAccess.get_sha256(recipe_path) == str(catalog.recipeSha256))
	var total := 0
	for asset: Dictionary in recipe.assets:
		for lod: int in 2:
			var expected: Dictionary = {}
			for part: Dictionary in asset.parts:
				if lod == 1 and bool(part.detail): continue
				for triangle: Array in part.triangles:
					var k := key([Pack.vector(part.vertices[int(triangle[0])]),Pack.vector(part.vertices[int(triangle[1])]),Pack.vector(part.vertices[int(triangle[2])])])
					expected[k] = int(expected.get(k,0)) + 1
			var scene: PackedScene = load(Pack.ART + str(asset.id) + "-%d.glb" % lod)
			assert(scene != null)
			var instance := scene.instantiate()
			var actual: Dictionary = {}
			var counts := {"meshes":0,"surfaces":0}
			collect(instance,Transform3D.IDENTITY,actual,counts)
			assert(actual == expected, "Imported triangles differ from recipe: " + str(asset.id))
			assert(counts.meshes == 1 and counts.surfaces <= 4)
			print("BIOME4_IMPORT ",asset.id," LOD",lod," ",counts," triangleKeys=",actual.size())
			instance.free()
			total += 1
	assert(total == 24)
	quit()
