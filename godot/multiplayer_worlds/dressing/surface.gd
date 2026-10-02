extends RefCounted
## Private family instances. Packed baked data drives wear; stable spatial blending
## decorrelates organic grain. Shared Moth assets and materials remain immutable.
const Language = preload("res://material_language/library.gd")
const Families = preload("res://material_language/families.gd")
const Profile = preload("res://multiplayer_worlds/dressing/profile.gd")
const Moth = preload("res://moth/library.gd")
const PrivateShader = preload("res://multiplayer_worlds/dressing/surface.gdshader")

static func build(entry: Dictionary, root: Node3D) -> Dictionary:
	var options: Dictionary = entry.get("options", {}).duplicate(true)
	if options.has("tint"): options.tint = Color(options.tint)
	var family: String = entry.family
	var record: Dictionary = Families.TABLE[family]
	var variant: Dictionary = record.get("variants", {}).get(options.get("variant", "default"), {})
	var base: String = variant.get("base", record.default.base)
	var normal: String = variant.get("normal", record.default.normal)
	var source: String = variant.get("normal_source", record.default.get("normal_source", "baked"))
	var mask: String = variant.get("mask", record.default.get("mask", ""))
	var lut: String = record.get("accent", {}).get("lut", "")
	var textures: Array = [Moth.texture(base), Moth.derived_texture("data--" + base), Language.normal_map(source + ":" + ("normal--" if source == "derived" else "") + normal)]
	if mask != "": textures.append(Moth.derived_texture(mask))
	if lut != "":
		var planes := Moth.material_lut(lut)
		if planes.is_empty(): return {"error": "unresolved LUT " + lut}
		textures.append_array([planes.r, planes.t])
	var params: Dictionary = record.get("params", {}).duplicate()
	params.merge(variant.get("params", {}), true)
	params.merge(options, true)
	if float(params.get("pulse_speed", 0)) > 0 or float(params.get("pulse_depth", 0)) > 0: textures.append(Moth.texture("flow-field"))
	var paths: Array[String] = []
	for texture: Variant in textures:
		if texture == null: return {"error": "unresolved family texture/normal/data " + family + "/" + str(options.get("variant", "default"))}
		paths.append(texture.resource_path)
	var shared := Language.material(family, options) as ShaderMaterial
	if shared == null: return {"error": "material-language cache refused " + family}
	# Never set a parameter on the cached material or mutate its shader.
	var material := shared.duplicate() as ShaderMaterial
	var variation_active: bool = options.get("variation_mode", "none") != "none" and float(options.get("variation_strength", 0)) > 0.0
	if float(options.get("macro_strength", 0)) > 0 or float(options.get("wear_strength", 0)) > 0 or variation_active:
		material.shader = PrivateShader
		# Preserve every verified family sampler/response across shader assignment.
		for uniform: Dictionary in shared.shader.get_shader_uniform_list():
			material.set_shader_parameter(str(uniform.name), shared.get_shader_parameter(str(uniform.name)))
		material.set_shader_parameter("map_inverse", root.global_transform.affine_inverse())
		for key: String in Profile.WEAR_BOUNDS:
			if options.has(key): material.set_shader_parameter(key, options[key])
		if options.has("wear_tint"): material.set_shader_parameter("wear_tint", Color(options.wear_tint))
		material.set_shader_parameter("variation_mode", Profile.VARIATION_MODES.find(options.get("variation_mode", "none")))
		material.set_shader_parameter("variation_seed", int(options.get("variation_seed", 0)))
		for key: String in Profile.VARIATION_BOUNDS:
			if options.has(key): material.set_shader_parameter(key, options[key])
	return {"material": material, "resources": paths}
