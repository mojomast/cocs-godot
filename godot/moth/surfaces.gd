extends RefCounted
const Library = preload("res://moth/library.gd")
const SURFACE = preload("res://moth/surface.gdshader")
const NORMAL_FAMILY := {
	"weathered_concrete-worn": "weathered_concrete", "weathered_concrete-damp": "weathered_concrete",
	"metal-oxide": "metal", "riveted_armor-scorched": "metal", "riveted_armor": "metal",
	"hex_paneling-mottle": "hex_paneling", "rock-moss": "rock", "ice-cracked": "ice",
	"rough_stucco-weathered": "rough_stucco", "brushed_metal": "metal",
}

static func create_surface(key: String, color: Color, vertex_tint: bool = false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter("tint", color if _finite_color(color) else Color.WHITE)
	material.set_shader_parameter("vertex_tint", vertex_tint)
	var albedo := Library.texture(key)
	var normal := Library.normal(NORMAL_FAMILY.get(key, key))
	material.set_shader_parameter("has_albedo", albedo != null)
	material.set_shader_parameter("has_normal", normal != null)
	var linear_data := key in ["macro-organic", "dust-field", "flow-field"]
	material.set_shader_parameter("albedo_is_linear", linear_data)
	if albedo != null: material.set_shader_parameter("data_map" if linear_data else "albedo_map", albedo)
	if normal != null: material.set_shader_parameter("normal_map", normal)
	material.set_shader_parameter("repeat_scale", 0.5)
	material.set_shader_parameter("normal_strength", 0.24)
	material.set_shader_parameter("albedo_gain", 1.5)
	if key == "rock": material.set_shader_parameter("albedo_gain", 8.0)
	elif key == "ice": material.set_shader_parameter("albedo_gain", 4.5)
	elif key in ["brushed_metal", "hex_paneling-mottle"]: material.set_shader_parameter("albedo_gain", 2.2)
	if key in ["metal", "brushed_metal", "diamond_plate", "corrugated_metal", "riveted_armor", "metal_grating"]:
		material.set_shader_parameter("roughness", 0.56)
		material.set_shader_parameter("metallic", 0.3)
	elif key in ["ice", "ice-cracked"]:
		material.set_shader_parameter("roughness", 0.35)
	return material

static func apply_lut(material: ShaderMaterial, key: String, intensity: float = 0.15, phase: float = 0.35) -> void:
	var lut := Library.material_lut(key)
	material.set_shader_parameter("has_lut", not lut.is_empty())
	material.set_shader_parameter("lut_intensity", clampf(intensity, 0.0, 2.0) if is_finite(intensity) else 0.0)
	material.set_shader_parameter("lut_phase", fposmod(phase, 1.0) if is_finite(phase) else 0.35)
	if not lut.is_empty():
		material.set_shader_parameter("lut_r", lut.r)
		material.set_shader_parameter("lut_t", lut.t)

static func _finite_color(color: Color) -> bool:
	return is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)
