extends SceneTree
const Library = preload("res://moth/library.gd")
const Surfaces = preload("res://moth/surfaces.gd")
var failures: Array[String] = []
var planes := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func check_plane(texture: Texture2D, record: Dictionary) -> void:
	check(texture != null, "Missing " + record.path)
	if texture == null: return
	var image := texture.get_image()
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGB8 if int(record.channels) == 3 else Image.FORMAT_RGBA8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	check(hash.finish().hex_encode() == record.pixel_sha256, "Imported bytes differ: " + record.path)
	planes += 1

func _initialize() -> void:
	var manifest := Library.manifest()
	for bucket in ["textures", "normals", "sky"]:
		for key in manifest[bucket]:
			var tex: Texture2D
			match bucket:
				"textures": tex = Library.texture(key)
				"normals": tex = Library.normal(key)
				"sky": tex = Library.sky(key)
			check_plane(tex, manifest[bucket][key])
	for key in manifest.materials:
		var lut := Library.material_lut(key)
		check_plane(lut.r, manifest.materials[key].r)
		check_plane(lut.t, manifest.materials[key].t)
	for key in manifest.effects:
		var effect := Library.effect(key)
		check(effect.frames is Array[Texture2D], "Effect typed frames")
		check(effect.fps == float(manifest.effects[key].fps), "Effect timing")
		for index in effect.frames.size(): check_plane(effect.frames[index], manifest.effects[key].frames[index])
	check(planes == 101, "Expected 101 planes")
	check(Library.texture("rock") == Library.texture("rock"), "Repeated lookup must share resource")
	check(Library.normal("rock") != Library.texture("rock"), "Normal/albedo caches must be distinct")
	var effect := Library.effect("qrc-glyphs")
	effect.frames.clear()
	check(Library.effect("qrc-glyphs").frames.size() == 16, "Caller mutation must not corrupt effect registry")
	manifest.textures.clear()
	check(Library.manifest().textures.size() == 31, "Caller mutation must not corrupt manifest")
	for i in 500:
		check(Library.texture("missing-%d" % i) == null, "Missing key fallback")
	check(Library.effect("missing").is_empty(), "Missing effect")
	check(Library.material_lut("missing").is_empty(), "Missing LUT")
	check(Library.cache_stats().textures == 101, "Unknown names must not grow shared cache")
	check(Library.cache_stats().textures <= Library.cache_stats().limit, "Bounded cache")
	var a := Surfaces.create_surface("rock", Color.WHITE, true)
	var b := Surfaces.create_surface("rock", Color.WHITE, true)
	check(a != b and a.shader == b.shader, "Caller-owned materials, shared shader")
	a.set_shader_parameter("normal_strength", 0.8)
	check(is_equal_approx(float(b.get_shader_parameter("normal_strength")), 0.24), "Material mutation must not leak")
	check(b.get_shader_parameter("vertex_tint") == true, "Semantic vertex tint")
	var missing := Surfaces.create_surface("missing", Color(NAN, 0.0, 0.0))
	check(missing.get_shader_parameter("tint") == Color.WHITE, "Finite color fallback")
	check(missing.get_shader_parameter("has_albedo") == false, "Missing texture is plain surface")
	var linear := Surfaces.create_surface("macro-organic", Color.WHITE)
	check(linear.get_shader_parameter("albedo_is_linear") == true and linear.get_shader_parameter("data_map") != null, "Macro data must bypass sRGB sampler")
	Surfaces.apply_lut(a, "entanglement", NAN, INF)
	check(a.get_shader_parameter("lut_intensity") == 0.0, "Finite LUT intensity")
	check(is_finite(float(a.get_shader_parameter("lut_phase"))), "Finite LUT phase")
	Library.clear_cache()
	check(Library.cache_stats().textures == 0, "Cache releases references")
	check(b.get_shader_parameter("albedo_map") != null, "Live material survives registry clear")
	print("MOTH_VALIDATION ", JSON.stringify({"planes": planes, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
