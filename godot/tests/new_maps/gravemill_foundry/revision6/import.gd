extends SceneTree
const Stage = preload("res://tests/new_maps/gravemill_foundry/revision6/staged.gd")
const OUT := "res://../tools/godot-multiplayer/new-maps/gravemill-foundry/revision6/evidence/W/"
func _initialize() -> void:
	var start := Time.get_ticks_usec()
	var packed: PackedScene = load(Stage.ART)
	var art := packed.instantiate()
	var loaded := Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"pixels"))
	var stream := FileAccess.open(OUT+"native-streams.bin",FileAccess.WRITE)
	var report := {"godot":Engine.get_version_info(),"artHash":FileAccess.get_sha256(Stage.ART),"loadInstantiateMicroseconds":loaded-start,"surfaces":[],"materials":{},"triangles":0,"meshNodes":0,"staticMemoryBytes":OS.get_static_memory_usage()}
	for node: Node in art.find_children("*","MeshInstance3D",true,false):
		report.meshNodes += 1
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var tangent: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			assert(v.size()==n.size() and uv.size()==v.size() and tangent.size()==v.size()*4)
			var mat: StandardMaterial3D = node.mesh.surface_get_material(surface)
			report.surfaces.append({"node":node.name,"surface":surface,"material":mat.resource_name,"offset":stream.get_position(),"vertices":v.size(),"indices":indices.size()})
			for bytes: PackedByteArray in [v.to_byte_array(),n.to_byte_array(),uv.to_byte_array(),tangent.to_byte_array(),indices.to_byte_array()]: stream.store_buffer(bytes)
			report.triangles += indices.size()/3
			if report.materials.has(mat.resource_name): continue
			var row := {"albedo":mat.albedo_color,"metallic":mat.metallic,"roughness":mat.roughness,"normalScale":mat.normal_scale,"roughnessChannel":mat.roughness_texture_channel,"emissionEnabled":mat.emission_enabled,"emission":mat.emission,"emissionEnergy":mat.emission_energy_multiplier,"images":{}}
			if mat.resource_name != "GM / orange":
				assert(mat.roughness_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_GREEN)
				for channel in ["albedo","normal","roughness"]:
					var texture: Texture2D = mat.get(channel+"_texture")
					assert(texture != null)
					var image := texture.get_image()
					assert(image != null and not image.is_empty())
					var path: String = OUT+"pixels/"+mat.resource_name.replace(" / ","-")+"-"+channel+".png"
					assert(image.save_png(path)==OK)
					row.images[channel]={"path":path,"sha256":FileAccess.get_sha256(path),"width":image.get_width(),"height":image.get_height()}
			report.materials[mat.resource_name]=row
	stream.close()
	assert(report.meshNodes==16 and report.triangles==87566 and report.surfaces.size()==32 and report.materials.size()==18)
	art.free()
	var file := FileAccess.open(OUT+"native-import.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	print("R6_NATIVE_IMPORT ",report.triangles," triangles ",report.surfaces.size()," surfaces")
	quit()
