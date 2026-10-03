extends SceneTree
## Actual imported production assets and production weather binder, no authority.
const Pack = preload("res://biomes/expansion/scenery_pack.gd")
const Weather = preload("res://ambience/weather_look.gd")
var palette: Dictionary
var checked_textures := {}
class Host extends Node3D:
	var recipe: Dictionary

func materials(node: Node, result: Array) -> void:
	if node is MeshInstance3D:
		for surface: int in node.mesh.get_surface_count():
			var material: StandardMaterial3D=node.get_active_material(surface)
			assert(material!=null and material.albedo_texture!=null)
			if material.normal_texture!=null:
				var arrays: Array=node.mesh.surface_get_arrays(surface)
				assert(material.normal_enabled and arrays[Mesh.ARRAY_TANGENT].size()==arrays[Mesh.ARRAY_VERTEX].size()*4,"Missing imported tangent normal basis")
			if not checked_textures.has(material.albedo_texture):
				var image: Image=material.albedo_texture.get_image()
				assert(image!=null and not image.is_empty())
				if image.is_compressed(): assert(image.decompress()==OK)
				var sum := Vector3.ZERO
				for y: int in image.get_height():
					for x: int in image.get_width():
						var color := image.get_pixel(x,y)
						sum+=Vector3(color.r,color.g,color.b)
				var mean := sum/float(image.get_width()*image.get_height())
				var role := material.resource_name.trim_prefix("biome4_")
				assert(palette.has(role))
				var wanted := Color(str(palette[role][0]))
				assert(absf(mean.x-wanted.r)<12.0/255 and absf(mean.y-wanted.g)<12.0/255 and absf(mean.z-wanted.b)<12.0/255,"Imported texture color transfer: "+role)
				checked_textures[material.albedo_texture]=true
			result.append({"node":weakref(node),"surface":surface,"material":material,"roughness":material.roughness,"metallic":material.metallic,"albedo":material.albedo_texture,"normal":material.normal_texture,"color":material.albedo_color})
	for child: Node in node.get_children(): materials(child,result)

func unchanged(rows: Array) -> void:
	for row: Dictionary in rows:
		var material: StandardMaterial3D=row.material
		assert(material.roughness==row.roughness and material.metallic==row.metallic)
		assert(material.albedo_texture==row.albedo and material.normal_texture==row.normal and material.albedo_color==row.color)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	palette=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tools/godot-biomes/expansion/meshes.json"))).palette
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Pack.CATALOG))
	for id: String in catalog.chapters:
		var host := Host.new()
		host.recipe=JSON.parse_string(FileAccess.get_file_as_string("res://campaign/generated/"+id+".json"))
		root.add_child(host)
		var a := Pack.new()
		var b := Pack.new()
		host.add_child(a);host.add_child(b)
		assert(a.build(host,true) and b.build(host,true))
		var original: Array=[]
		var siblings: Array=[]
		materials(a,original);materials(b,siblings)
		assert(original.size()==siblings.size() and original.size()>0)
		for i: int in original.size(): assert(original[i].material!=siblings[i].material)
		var environment := WorldEnvironment.new()
		environment.environment=Environment.new()
		host.add_child(environment)
		var base := environment.environment
		var weather := Weather.new()
		weather.bind(a,environment,null)
		assert(not weather.capped)
		weather.apply("rain",1.0,true)
		assert(weather.wetness>0)
		unchanged(original);unchanged(siblings)
		for row: Dictionary in original:
			var mesh: MeshInstance3D=row.node.get_ref()
			assert(mesh.get_active_material(row.surface)!=row.material)
		weather.clear();weather.clear()
		assert(environment.environment==base)
		for row: Dictionary in original:
			var mesh: MeshInstance3D=row.node.get_ref()
			assert(mesh.get_active_material(row.surface)==row.material)
		unchanged(original)
		weather.bind(a,environment,null)
		weather.apply("rain",1.0,true)
		a.clear()
		weather.clear()
		assert(original.all(func(row: Dictionary) -> bool: return row.node.get_ref()==null))
		assert(a.build(host,true))
		unchanged(siblings)
		print("SCENERY_IMPORTED_MATERIAL_LIFECYCLE_OK ",id," surfaces=",original.size())
		host.free()
	quit()
