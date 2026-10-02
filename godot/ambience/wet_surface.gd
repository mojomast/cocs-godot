extends RefCounted
## game/textures.mjs wetSheenTexture. Bounded map-local data; no frame noise work.
const SIZE := 128
# Explicit final roughness anchors in the three reviewed production shaders.
# Fail closed if their implementation changes; never infer uniform names.
const TARGETS := {
	"res://moth/surface.gdshader": "\tROUGHNESS = roughness;",
	"res://material_language/family.gdshader": "\tROUGHNESS = clamp(mix(roughness, derived_roughness, roughness_variation), 0.03, 1.0);",
	"res://campaign/materials/ground.gdshader": " ROUGHNESS=clamp(.92-moisture*.14-rock*.10+grains*.03,.65,1.)*(1.-weather_wetness*.55);",
}
var texture: ImageTexture
var shaders: Dictionary = {}
var seed := 14

static func _imul(a: int, b: int) -> int:
	return (((a & 65535) * (b & 65535)) + ((((a >> 16) * (b & 65535) + (b >> 16) * (a & 65535)) & 65535) << 16)) & 0xffffffff

static func _hash(x: int, y: int, s: int) -> float:
	var h := (_imul(x, 374761393) + _imul(y, 668265263) + _imul(s, 2246822519)) & 0xffffffff
	h = _imul(h ^ (h >> 13), 1274126177)
	h = (h ^ (h >> 16)) & 0xffffffff
	return float(h) / 4294967295.0

static func _noise(x: float, y: float, s: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var xf := x - xi
	var yf := y - yi
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := yf * yf * (3.0 - 2.0 * yf)
	return (_hash(xi, yi, s) * (1.0-u) + _hash(xi+1, yi, s)*u)*(1.0-v) + (_hash(xi, yi+1, s)*(1.0-u)+_hash(xi+1, yi+1, s)*u)*v

static func _fbm(x: float, y: float, s: int, octaves: int) -> float:
	var total := 0.0
	var amp := 0.5
	var frequency := 1.0
	var norm := 0.0
	for i in octaves:
		total += _noise(x*frequency, y*frequency, s+i*131)*amp
		norm += amp
		amp *= 0.5
		frequency *= 2.0
	return total / norm

static func _byte(value: float) -> int:
	# Uint8ClampedArray uses ties-to-even, not Godot's round-away-from-zero.
	var low := floori(value)
	if value-low == 0.5: return low + (low & 1)
	return clampi(roundi(value), 0, 255)

static func pixels(s: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(SIZE*SIZE*4)
	for y in SIZE:
		for x in SIZE:
			var u := float(x)/SIZE*3.1
			var v := float(y)/SIZE*3.1
			var n := clampf((_fbm(u,v,s+411,4)*0.75+_fbm(u*2.7,v*2.7,s+913,3)*0.25-0.4)*1.7,0.0,1.0)
			var i := (y*SIZE+x)*4
			var shade := _byte(255.0*(1.0-n*0.18))
			data[i] = shade
			data[i+1] = shade
			data[i+2] = shade
			data[i+3] = _byte(n*210.0)
	return data

func get_texture() -> ImageTexture:
	if texture == null:
		var image := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, pixels(seed))
		image.generate_mipmaps()
		texture = ImageTexture.create_from_image(image)
	return texture

func lease_shader(original: Shader) -> Shader:
	if shaders.has(original): return shaders[original]
	var anchor: String = TARGETS.get(original.resource_path, "")
	if anchor.is_empty() or original.code.count(anchor) != 1: return null
	var position := "world_pos" if original.resource_path.ends_with("ground.gdshader") else "world_position"
	var leased := Shader.new()
	# Native terrain lacks source UVs. One eight-metre world-space tile preserves
	# continuous patches across chunks; authored normals/AO/colour stay intact.
	leased.code = original.code.replace("shader_type spatial;", "shader_type spatial;\nuniform sampler2D weather_roughness_map : filter_linear_mipmap_anisotropic, repeat_enable;\nuniform bool weather_has_roughness = false;")\
		.replace(anchor, anchor + "\n if (weather_has_roughness) { ROUGHNESS *= texture(weather_roughness_map, " + position + ".xz * 0.125).g; }")
	shaders[original] = leased
	return leased

func clear() -> void:
	texture = null
	shaders.clear()
