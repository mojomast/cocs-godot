extends SceneTree
const Factory = preload("res://shader_lab/factory.gd")
const Moth = preload("res://moth/library.gd")
var checks := 0
var failed := false

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("SHADER_LAB_CONTRACT: " + message)

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var factory := Factory.new()
	check(factory.create_material("unknown") == null, "unknown effect rejected")
	check(factory.state().materials == 0, "unknown does not occupy a slot")
	var a := factory.create_material("shield", {"intensity": 1.3})
	var b := factory.create_material("shield", {"palette": "orchid"})
	check(a != b and a.shader == b.shader, "isolated materials share shader")
	check(a.get_shader_parameter("base_map") == b.get_shader_parameter("base_map"), "immutable texture sharing")
	factory.configure(a, {"intensity": 2.1, "palette": "solar"})
	check(b.get_shader_parameter("intensity") == 1.0, "uniform mutation isolated")
	check(a.get_shader_parameter("accent") != b.get_shader_parameter("accent"), "palette mutation isolated")
	var snapshot := factory.material_state(a)
	snapshot.options.intensity = 0.0
	check(factory.material_state(a).options.intensity == 2.1, "state is caller-owned")
	for bad: Variant in [NAN, INF, -INF, "nan", null, Vector2.ONE, true]:
		factory.configure(a, {"opacity": bad, "intensity": bad, "normal_strength": bad, "lut_phase": bad})
		for key: String in ["opacity", "intensity", "normal_strength", "lut_phase"]:
			check(Factory.finite_number(a.get_shader_parameter(key)), "finite fallback " + key)
	factory.configure(a, {"opacity": 9999, "intensity": -9999, "texture_scale": 0, "lut_phase": -1, "material": "../../absent", "effect_enabled": "false"})
	check(a.get_shader_parameter("opacity") == 0.8 and a.get_shader_parameter("intensity") == 0.0, "opacity/intensity clamps")
	check(a.get_shader_parameter("texture_scale") == 0.1, "scale stays away from zero")
	check(factory.material_state(a).options.material == "holographic_grid", "asset allowlist fallback")
	check(a.get_shader_parameter("effect_enabled") == true, "typed boolean fallback")
	check(factory.update_time(13.25), "valid clock")
	check(a.get_shader_parameter("effect_time") == b.get_shader_parameter("effect_time"), "shared clock")
	for bad: Variant in [NAN, INF, -INF, "5", null, true]:
		check(not factory.update_time(bad) and factory.state().time == 13.25, "invalid clock preserves state")
	factory.update_time(13.25)
	check(a.get_shader_parameter("effect_time") == 13.25, "pause is exact repeated absolute time")
	factory.update_time(4.125)
	check(a.get_shader_parameter("effect_time") == 4.125, "backward replay seek")
	factory.update_time(1e30)
	check(factory.state().time == Factory.MAX_TIME, "large time saturates")
	factory.update_time(-30)
	check(factory.state().time == 0.0, "negative time saturates")
	factory.reset()
	check(a.get_shader_parameter("intensity") == 1.3 and factory.state().time == 0.0, "reset restores creation settings")
	var phase := factory.create_material("phase", {"dissolve": INF, "height_span": -1, "edge_width": 30})
	check(phase.get_shader_parameter("dissolve") == 0.43, "finite phase default")
	check(phase.get_shader_parameter("height_span") == 0.1 and phase.get_shader_parameter("edge_width") == 0.2, "phase bounds")
	for effect: String in Factory.SHADERS:
		check(not "TIME" in Factory.SHADERS[effect].code, "no implicit time in " + effect)
	var motif := Moth.effect("effect-shield").frames[0].get_image() as Image
	var alpha_opaque := true
	for y in range(motif.get_height()):
		for x in range(motif.get_width()):
			if motif.get_pixel(x, y).a < 1.0: alpha_opaque = false
	check(alpha_opaque, "source effect alpha is opaque; shader must synthesize coverage")
	var held_texture: Texture2D = a.get_shader_parameter("base_map")
	Moth.clear_cache()
	check(held_texture == a.get_shader_parameter("base_map"), "registry clear leaves caller material valid")
	var held: Array[ShaderMaterial] = []
	for index in range(Factory.MAX_MATERIALS - 3): held.append(factory.create_material("conduit"))
	check(factory.state().materials == Factory.MAX_MATERIALS, "bounded tracking fills exactly")
	check(factory.create_material("phase") == null, "budget rejects overflow")
	held.clear()
	check(factory.state().materials == 3, "weak ownership releases dead materials")
	for index in range(256):
		var transient := factory.create_material("phase")
		factory.release(transient)
	check(factory.state().materials == 3, "repeated create/release stays bounded")
	check(Moth.cache_stats().textures <= Moth.MAX_TEXTURES, "Moth cache bound")
	factory.release(a)
	factory.update_time(42.0)
	check(a.get_shader_parameter("effect_time") == 0.0, "released material freezes")
	check(not factory.configure(a, {"intensity": 0.0}), "foreign/released material rejected")
	factory.clear()
	check(factory.state().materials == 0 and factory.state().time == 0.0, "clear drops lifecycle state")
	check(b.get_shader_parameter("effect_time") == 42.0, "clear preserves live caller material")
	print("SHADER_LAB_CONTRACT_%s checks=%d shaders=3 cap=64 caller_clock=true" % ["FAIL" if failed else "OK", checks])
	quit(1 if failed else 0)
