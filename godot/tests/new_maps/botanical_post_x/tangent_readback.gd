extends SceneTree
## FUTURE GRANT ONLY. Records actual imported per-corner basis; no auto-repair.
const EXPECTED := [Vector3(68.77897644042969,24,-66.25537872314453),Vector3(35.5203971862793,24,-84.05670928955078),Vector3(35.5,24,-84.06217956542969)]
const SOURCE_SHA := "6356cf895c65cec181e1c6c077118b98f3ee80cb567955b37835433971342422"

func _initialize() -> void:
	call_deferred("run")
	create_timer(55).timeout.connect(func() -> void: quit(2))

func run() -> void:
	var version := Engine.get_version_info()
	assert(version.major==4 and version.minor==5 and version.patch==2, "Pinned Godot 4.5.2 required")
	var source := ""
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source="): source = arg.trim_prefix("--source=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(source.begins_with("res://tests/new_maps/botanical_post_x/"))
	assert(output.begins_with("res://tests/new_maps/botanical_post_x/"))
	assert(not FileAccess.file_exists(output))
	assert(FileAccess.get_sha256(source)==SOURCE_SHA)
	var packed: PackedScene = load(source)
	assert(packed != null)
	var art := packed.instantiate()
	root.add_child(art)
	var found: Array = []
	for node: MeshInstance3D in art.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			var arrays := node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var tangent: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for face in range(0,indices.size(),3):
				var match_indices: Array = []
				for expected: Vector3 in EXPECTED:
					for corner in range(3):
						var index := indices[face+corner]
						if (node.global_transform*vertices[index]).distance_to(expected)<.0001: match_indices.append(index)
				if match_indices.size()!=3: continue
				assert(tangent.size()==vertices.size()*4 and normals.size()==vertices.size() and uv.size()==vertices.size())
				var corners: Array = []
				for index: int in match_indices:
					corners.append({"index":index,"position":vertices[index],"normal":normals[index],"uv":uv[index],
						"tangent":[tangent[4*index],tangent[4*index+1],tangent[4*index+2],tangent[4*index+3]]})
				var material: StandardMaterial3D = node.mesh.surface_get_material(surface)
				found.append({"node":node.name,"surface":surface,"face":face/3,"transform":node.global_transform,"corners":corners,
					"material":material.resource_name,"normalEnabled":material.normal_enabled,"normalScale":material.normal_scale})
	assert(found.size()==1,"Expected exactly one real imported incident triangle")
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"sourceSha256":SOURCE_SHA,"godot":Engine.get_version_info(),"triangles":found,
		"scope":"actual imported arrays; supplied zero fallback and handedness must be reviewed against renderer BINORMAL convention; array presence is not proof of a repaired basis"},"\t")+"\n")
	file.close()
	quit(0)
