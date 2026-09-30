extends RefCounted
## Native-only authored texture layer; never part of the source GLB export.
## Rigid face UVs are baked once into cached overlay meshes, never world projected.
const Builder = preload("res://player_models/builder.gd")
const PANEL = preload("res://source_operators/textures/armor_panel.svg")
const BOARD = preload("res://source_operators/textures/service_board.svg")
const VENT = preload("res://source_operators/textures/vent_panel.svg")
const ROUGHNESS = preload("res://source_operators/textures/panel_roughness.svg")
static var meshes: Dictionary = {}
static var materials: Dictionary = {}

static func mesh_for(size: Vector3) -> ArrayMesh:
	var key := str(size)
	if meshes.has(key): return meshes[key]
	var original := Builder.mesh_for({"size":[size.x,size.y,size.z],"lower":0.8,"upper":1.0,"bevel":0.14})
	var arrays := original.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv := PackedVector2Array()
	for i in vertices.size():
		var p := vertices[i] / size
		# Front/back receive a fitted panel. Bevels/top/sides sample bare paint;
		# no stretching circuitry around a corner or across an animated joint.
		var taper := lerpf(0.8,1.0,p.y + 0.5)
		uv.append(Vector2(p.x / (0.7*taper) + 0.5,0.5 - p.y/0.72) if absf(normals[i].z) > 0.99 else Vector2(0.015,0.015))
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	meshes[key] = mesh
	return mesh

static func material_for(base: StandardMaterial3D, style: String) -> StandardMaterial3D:
	var key := "%s:%s:%s:%s" % [style,base.albedo_color.to_html(),base.metallic,base.roughness]
	if materials.has(key): return materials[key]
	var material: StandardMaterial3D = base.duplicate()
	material.resource_name = "NativeDetail_" + style
	material.albedo_texture = BOARD if style == "board" else (VENT if style == "vent" else PANEL)
	material.roughness_texture = ROUGHNESS
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Board traces are passive copper. Only existing visor/sensors emit.
	materials[key] = material
	return material

static func style_for(label: String) -> String:
	if label.begins_with("Bracer") or label.begins_with("BeltPouch"): return "board"
	if label.begins_with("RibGuard") or label in ["Radiator","FaceGuard"]: return "vent"
	if label.begins_with("Breastplate") or label.begins_with("Pauldron") or label.begins_with("ThighPlate") or label.begins_with("ShinPlate") or label.begins_with("KneeShell") or label.begins_with("BeltPouch"): return "panel"
	return ""

static func apply_team(details: Array[MeshInstance3D], base: StandardMaterial3D) -> void:
	if base == null: return
	for mesh in details:
		if mesh.has_meta("team_detail"):
			mesh.material_override = material_for(base,str(mesh.get_meta("detail_style")))
