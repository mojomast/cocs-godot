extends RefCounted
## Private family instances. Packed baked data, never procedural noise, drives wear.
const Language = preload("res://material_language/library.gd")
const Families = preload("res://material_language/families.gd")
const Profile = preload("res://multiplayer_worlds/dressing/profile.gd")
const Moth = preload("res://moth/library.gd")
const FamilyShader = preload("res://material_language/family.gdshader")
static var _wear_shader: Shader
const UNIFORMS := """
uniform float macro_tiles_per_metre = 0.06;
uniform float macro_strength = 0.0;
uniform float wear_strength = 0.0;
uniform float wear_height_min = 0.0;
uniform float wear_height_max = 2.0;
uniform float wear_roughness = 0.95;
uniform vec4 wear_tint : source_color = vec4(0.4, 0.35, 0.3, 1.0);
uniform mat4 map_inverse;
"""
const FRAGMENT := """
	// Macro samples the SAME verified packed surface data at a separate scale.
	// Height-bound deposit accumulates in texture creases on selected materials.
	vec3 mp = world_position * macro_tiles_per_metre;
	vec3 macro = texture(data_map, mp.zy).rgb * weights.x
		+ texture(data_map, mp.xz).rgb * weights.y
		+ texture(data_map, mp.xy).rgb * weights.z;
	float local_height = (map_inverse * vec4(world_position, 1.0)).y;
	float band = smoothstep(wear_height_min, wear_height_min + 0.15, local_height)
		* (1.0 - smoothstep(wear_height_max - 0.15, wear_height_max, local_height));
	float deposit = clamp((1.0 - macro.r) * 2.0, 0.0, 1.0) * band * wear_strength;
	if (has_data) {
		ALBEDO *= mix(1.0, 0.65 + macro.b * 0.5, macro_strength);
		ALBEDO = mix(ALBEDO, wear_tint.rgb, deposit);
		ROUGHNESS = mix(ROUGHNESS, wear_roughness, deposit);
	}
"""

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
	if float(options.get("macro_strength", 0)) > 0 or float(options.get("wear_strength", 0)) > 0:
		if _wear_shader == null:
			_wear_shader = Shader.new()
			_wear_shader.code = FamilyShader.code.replace("varying vec3 world_position;", UNIFORMS + "\nvarying vec3 world_position;").replace("\tMETALLIC = metallic;", FRAGMENT + "\n\tMETALLIC = metallic;")
		material.shader = _wear_shader
		material.set_shader_parameter("map_inverse", root.global_transform.affine_inverse())
		for key: String in Profile.WEAR_BOUNDS:
			if options.has(key): material.set_shader_parameter(key, options[key])
		if options.has("wear_tint"): material.set_shader_parameter("wear_tint", Color(options.wear_tint))
	return {"material": material, "resources": paths}
