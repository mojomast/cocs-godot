extends RefCounted
## Articulated, bevelled armor overlays. Shared finite meshes, no physics or
## changes to source anatomy, joint anchors, teams, weapons or hit geometry.
const Builder = preload("res://player_models/builder.gd")
const SurfaceDetail = preload("res://source_operators/surface_detail.gd")
static var materials: Dictionary = {}
const COLORS := {"chatgpt":"69d6bb","claude":"dd9978","grok":"aebeca","meta":"64b6f1","gemini":"99a9f1","deepseek":"61c5dc","mistral":"e8b563","kimi":"e7a4c3","qwen":"b2a0e3"}

static func build(joints: Dictionary, character: String, team_armor: Material) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var color := Color(COLORS.get(character,"b8cbd7"))
	var ceramic := _material(color.darkened(0.12),0.28,0.48)
	var metal := _material(Color("97a8ad"),0.75,0.34)
	var black := _material(Color("202a31"),0.1,0.78)
	var visor := _material(color,0.4,0.24)
	visor.emission_enabled = true
	visor.emission = color
	visor.emission_energy_multiplier = 0.32
	var width := 1.12 if character in ["grok","deepseek","meta"] else 0.94
	var plate: Material = team_armor if team_armor != null else ceramic
	for side in [-1,1]:
		var suffix := "L" if side < 0 else "R"
		var x: float = side*0.12*width
		_add(result,joints.chest,"Breastplate"+suffix,Vector3(x,0.04,-0.16),Vector3(0.23*width,0.24,0.105),plate,0.08*side)
		_add(result,joints.torso,"RibGuard"+suffix,Vector3(side*0.14,-0.025,-0.13),Vector3(0.15,0.20,0.075),black,0.07*side)
		_add(result,joints["armUpper"+suffix],"Pauldron"+suffix,Vector3(side*0.03,-0.045,0),Vector3(0.26*width,0.18,0.28),plate,0.13*side)
		_add(result,joints["armUpper"+suffix],"ShoulderInlay"+suffix,Vector3(side*0.04,0.05,-0.07),Vector3(0.17,0.035,0.09),ceramic,0.13*side)
		_add(result,joints["forearm"+suffix],"Bracer"+suffix,Vector3(0,-0.13,-0.07),Vector3(0.15,0.19,0.085),ceramic)
		_add(result,joints["legUpper"+suffix],"ThighPlate"+suffix,Vector3(0,-0.17,-0.095),Vector3(0.18,0.24,0.075),plate)
		_add(result,joints["legLower"+suffix],"KneeShell"+suffix,Vector3(0,-0.025,-0.105),Vector3(0.19,0.13,0.105),metal)
		_add(result,joints["legLower"+suffix],"ShinPlate"+suffix,Vector3(0,-0.19,-0.08),Vector3(0.14,0.22,0.07),ceramic)
		_add(result,joints["foot"+suffix],"ToeCap"+suffix,Vector3(0,0.025,-0.09),Vector3(0.16,0.08,0.22),metal)
		_add(result,joints.hips,"BeltPouch"+suffix,Vector3(side*0.21,0.01,0.035),Vector3(0.115,0.135,0.115),black)
		_add(result,joints.head,"Temple"+suffix,Vector3(side*0.155,0.025,0.005),Vector3(0.07,0.135,0.15),ceramic)
	_add(result,joints.head,"VisorBrow",Vector3(0,0.087,-0.145),Vector3(0.29,0.045,0.075),metal)
	_add(result,joints.head,"VisorLens",Vector3(0,0.025,-0.17),Vector3(0.255,0.065,0.045),visor)
	_add(result,joints.head,"FaceGuard",Vector3(0,-0.068,-0.137),Vector3(0.19,0.085,0.065),black)
	_add(result,joints.chest,"Sternum",Vector3(0,0.03,-0.217),Vector3(0.028,0.18,0.018),visor)
	_add(result,joints.backpack,"Radiator",Vector3(0,0.03,0.05),Vector3(0.26,0.29,0.14),black)
	for i in 4:
		_add(result,joints.backpack,"Vent%d" % i,Vector3(0,0.11-i*0.052,0.13),Vector3(0.20,0.022,0.045),metal)
	# Distinct sensor silhouettes: a paired aerial, a crest, or a side optic.
	if character in ["grok","meta","deepseek"]:
		for side in [-1,1]: _add(result,joints.backpack,"Aerial%d" % (side+1),Vector3(side*0.14,0.28,0.055),Vector3(0.025,0.27,0.035),metal)
	elif character in ["claude","mistral","kimi"]:
		_add(result,joints.head,"HelmetCrest",Vector3(0,0.145,0.01),Vector3(0.10,0.055,0.24),ceramic)
	else:
		_add(result,joints.head,"SideOptic",Vector3(-0.19,0.06,-0.095),Vector3(0.075,0.07,0.075),visor)
	return result

static func apply_team(details: Array[MeshInstance3D], base: StandardMaterial3D) -> void:
	SurfaceDetail.apply_team(details,base)

static func _add(result: Array[MeshInstance3D], parent: Node3D, label: String, position: Vector3, size: Vector3, material: Material, roll := 0.0) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = Builder.mesh_for({"size":[size.x,size.y,size.z],"lower":0.8,"upper":1.0,"bevel":0.14})
	mesh.material_override = material
	var style := SurfaceDetail.style_for(label)
	if not style.is_empty():
		mesh.mesh = SurfaceDetail.mesh_for(size)
		mesh.material_override = SurfaceDetail.material_for(material as StandardMaterial3D,style)
		mesh.set_meta("detail_style",style)
		mesh.set_meta("undetailed_material",material)
		if label.begins_with("Breastplate") or label.begins_with("Pauldron") or label.begins_with("ThighPlate"):
			mesh.set_meta("team_detail",true)
	mesh.position = position
	mesh.rotation.z = roll
	parent.add_child(mesh)
	result.append(mesh)

static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var key := "%s:%s:%s" % [color.to_html(),metallic,roughness]
	if materials.has(key): return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	materials[key] = material
	return material
