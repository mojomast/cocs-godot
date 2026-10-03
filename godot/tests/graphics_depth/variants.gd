extends SceneTree
## Source and material contract for the two Moth depth paths. Raster priority is
## separately exercised by capture.gd under the Compatibility renderer.
const Surfaces = preload("res://moth/surfaces.gd")
const PRIORITY = preload("res://moth/surface.gdshader")
const OPAQUE = preload("res://moth/surface_opaque.gdshader")

func _initialize() -> void:
	var priority_code := PRIORITY.code
	var opaque_code := OPAQUE.code
	var depth_write := "\tDEPTH = FRAGCOORD.z + (vertex_tint ? UV.x * 0.000001 : 0.0);\n"
	var failures: Array[String] = []
	if priority_code.count(depth_write) != 1: failures.append("priority bias changed")
	var depth_assignment := RegEx.create_from_string("\\bDEPTH\\s*=")
	if depth_assignment.search(opaque_code) != null: failures.append("opaque depth write")
	# Compare executable shader statements, not their descriptive comments.
	var priority_lines := PackedStringArray()
	var opaque_lines := PackedStringArray()
	for line in priority_code.split("\n"):
		if not line.strip_edges().begins_with("//") and not line.is_empty() and line != depth_write.strip_edges(false, true):
			priority_lines.append(line)
	for line in opaque_code.split("\n"):
		if not line.strip_edges().begins_with("//") and not line.is_empty(): opaque_lines.append(line)
	if priority_lines != opaque_lines: failures.append("surface shader bodies diverged")
	var tint := Color("a3bfdd")
	var ordinary := Surfaces.create_surface("ice-cracked", tint, true)
	var priority := Surfaces.create_surface("ice-cracked", tint, true, true)
	if ordinary.shader != OPAQUE or priority.shader != PRIORITY: failures.append("shader routing")
	for parameter in ["tint", "vertex_tint", "has_albedo", "has_normal", "albedo_map", "normal_map", "albedo_gain", "roughness", "metallic", "normal_strength"]:
		if ordinary.get_shader_parameter(parameter) != priority.get_shader_parameter(parameter): failures.append("uniform " + parameter)
	Surfaces.apply_lut(ordinary, "entanglement-ceramic", 0.035, 0.7)
	Surfaces.apply_lut(priority, "entanglement-ceramic", 0.035, 0.7)
	for parameter in ["has_lut", "lut_r", "lut_t", "lut_intensity", "lut_phase"]:
		if ordinary.get_shader_parameter(parameter) != priority.get_shader_parameter(parameter): failures.append("LUT " + parameter)
	print("MOTH_DEPTH_VARIANTS ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
