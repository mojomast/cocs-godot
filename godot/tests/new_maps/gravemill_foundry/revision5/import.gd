extends SceneTree
const Stage = preload("res://tests/new_maps/gravemill_foundry/revision5/staged.gd")
func _initialize() -> void:
	var packed: PackedScene = load(Stage.ART)
	var art: Node = packed.instantiate()
	var report := {"godot":Engine.get_version_info(),"art":Stage.ART,"meshNodes":0,"triangles":0,"materials":{},"texturedSurfaces":0,"errors":[]}
	for node: Node in art.find_children("*","MeshInstance3D",true,false):
		report.meshNodes += 1
		for index in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normal: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var tangent: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			assert(vertices.size()==normal.size() and uv.size()==vertices.size() and tangent.size()==vertices.size()*4)
			report.triangles += indices.size()/3
			var mat: StandardMaterial3D = node.mesh.surface_get_material(index)
			report.materials[mat.resource_name] = int(report.materials.get(mat.resource_name,0))+1
			if mat.resource_name != "GM / orange":
				assert(mat.albedo_texture != null and mat.normal_texture != null and mat.roughness_texture != null)
				assert(mat.roughness_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_GREEN)
				assert(mat.albedo_texture.get_width()>0 and mat.normal_texture.get_width()>0)
				report.texturedSurfaces += 1
	assert(report.meshNodes==16 and report.triangles==87566 and report.materials.size()==11)
	art.free()
	var file := FileAccess.open(Stage.DIR+"import-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	print("R5_NATIVE_IMPORT ",JSON.stringify(report))
	quit()
