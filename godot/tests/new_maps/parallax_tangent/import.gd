extends SceneTree
# Future isolated stage only. Requires explicit exclusive heavy grant; never autostarts.
const ART := "res://tests/new_maps/parallax_tangent/candidate.glb"
const OUT := "res://tests/new_maps/parallax_tangent/evidence/"
func _initialize() -> void:
 assert(FileAccess.file_exists(ART))
 var scene: PackedScene = load(ART)
 assert(scene != null)
 var art := scene.instantiate()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "pixels"))
 var file := FileAccess.open(OUT + "native-streams.bin", FileAccess.WRITE)
 assert(file != null)
 var report := {"artHash":FileAccess.get_sha256(ART),"godot":Engine.get_version_info(),"meshNodes":0,"triangles":0,"surfaces":[],"materials":{}}
 for node: Node in art.find_children("*", "MeshInstance3D", true, false):
  report.meshNodes += 1
  for surface in node.mesh.get_surface_count():
   var arrays: Array = node.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
   var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
   var tangent: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
   assert(vertices.size() == normals.size() and vertices.size() == uv.size() and tangent.size() == vertices.size() * 4)
   assert(indices.size() % 3 == 0)
   var mat: StandardMaterial3D = node.mesh.surface_get_material(surface)
   assert(mat != null)
   report.surfaces.append({"node":node.name,"surface":surface,"material":mat.resource_name,"offset":file.get_position(),"vertices":vertices.size(),"indices":indices.size()})
   for raw: PackedByteArray in [vertices.to_byte_array(),normals.to_byte_array(),uv.to_byte_array(),tangent.to_byte_array(),indices.to_byte_array()]:
    file.store_buffer(raw)
   report.triangles += indices.size() / 3
   if report.materials.has(mat.resource_name): continue
   var row := {"albedo":mat.albedo_color,"metallic":mat.metallic,"roughness":mat.roughness,"normalScale":mat.normal_scale,"roughnessChannel":mat.roughness_texture_channel,"emissionEnabled":mat.emission_enabled,"emission":mat.emission,"emissionEnergy":mat.emission_energy_multiplier,"images":{}}
   for channel in ["albedo","normal","roughness"]:
    var texture: Texture2D = mat.get(channel + "_texture")
    if texture == null: continue
    var image := texture.get_image()
    assert(image != null and not image.is_empty())
    var name := mat.resource_name.replace("/", "-").replace(" ", "-").replace(".", "-")
    var path := OUT + "pixels/" + name + "-" + channel + ".png"
    assert(image.save_png(path) == OK)
    row.images[channel] = {"path":path,"sha256":FileAccess.get_sha256(path),"width":image.get_width(),"height":image.get_height()}
   report.materials[mat.resource_name] = row
 file.close()
 assert(report.meshNodes == 39 and report.surfaces.size() == 39 and report.triangles == 155553 and report.materials.size() == 14)
 art.free()
 var result := FileAccess.open(OUT + "native-import.json", FileAccess.WRITE)
 assert(result != null)
 result.store_string(JSON.stringify(report, "  ") + "\n")
 quit()
