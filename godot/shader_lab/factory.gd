extends RefCounted
## Main-thread, caller-clocked presentation materials. Shared immutable shaders /
## Moth images, independent ShaderMaterials, weak bounded instance bookkeeping.
const Moth = preload("res://moth/library.gd")
const SHADERS := {
	"shield": preload("res://shader_lab/shield.gdshader"),
	"conduit": preload("res://shader_lab/conduit.gdshader"),
	"phase": preload("res://shader_lab/phase.gdshader"),
}
const MATERIALS := {
	"holographic_grid": ["holographic_grid", "holographic_grid", 2.2],
	"brushed_metal": ["brushed_metal", "metal", 2.2],
	"circuit_board": ["circuit_board-etch", "metal", 2.4],
	"riveted_armor": ["riveted_armor", "metal", 2.0],
	"hex_paneling": ["hex_paneling", "hex_paneling", 2.2],
}
const PALETTES := {
	"ion": [Color("4cdff5"), Color("9d72fa"), Color("a6bcca")],
	"solar": [Color("ffc76a"), Color("50bfe9"), Color("94a8bb")],
	"orchid": [Color("e797ff"), Color("55e5d0"), Color("bbc3d0")],
}
const DEFAULTS := {
	"shield": {"material": "holographic_grid", "palette": "ion", "lut": "entanglement-arcane"},
	"conduit": {"material": "brushed_metal", "palette": "solar", "lut": "entanglement-ember"},
	"phase": {"material": "riveted_armor", "palette": "orchid", "lut": "entanglement-arcane", "normal_strength": 0.38},
}
# low, high, default; every externally set numeric uniform passes this table.
const BOUNDS := {
	"intensity": [0.0, 2.5, 1.0], "opacity": [0.0, 0.8, 0.68],
	"texture_scale": [0.1, 4.0, 1.0], "normal_strength": [0.0, 0.65, 0.2],
	"texture_saturation": [0.0, 1.0, 0.28],
	"field_strength": [0.0, 1.0, 1.0], "lut_strength": [0.0, 2.0, 0.65],
	"lut_phase": [0.0, 1.0, 0.8], "dissolve": [0.0, 1.0, 0.43],
	"edge_width": [0.015, 0.2, 0.065], "height_span": [0.1, 20.0, 2.4],
}
const MAX_MATERIALS := 64
const MAX_TIME := 3600.0
var _instances: Dictionary = {}
var _time := 0.0

static func finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _prune() -> void:
	for id: int in _instances.keys():
		if _instances[id].weak.get_ref() == null: _instances.erase(id)

func create_material(effect: String, options: Dictionary = {}) -> ShaderMaterial:
	_prune()
	if not SHADERS.has(effect) or _instances.size() >= MAX_MATERIALS: return null
	var chosen := _sanitize(effect, options)
	var material := ShaderMaterial.new()
	material.shader = SHADERS[effect]
	var record := {"weak": weakref(material), "effect": effect, "initial": chosen.duplicate(true), "options": chosen}
	_instances[material.get_instance_id()] = record
	_apply(material, record)
	return material

func _sanitize(effect: String, options: Dictionary) -> Dictionary:
	var result: Dictionary = DEFAULTS[effect].duplicate(true)
	for key: String in ["material", "palette"]:
		var choices: Dictionary = MATERIALS if key == "material" else PALETTES
		if options.get(key) is String and choices.has(options[key]): result[key] = options[key]
	if options.get("lut") in ["entanglement", "entanglement-arcane", "entanglement-ember", "entanglement-ceramic", "entanglement-void"]:
		result.lut = options.lut
	for key: String in BOUNDS:
		var bounds: Array = BOUNDS[key]
		var value: Variant = options.get(key, result.get(key, bounds[2]))
		result[key] = clampf(float(value), bounds[0], bounds[1]) if finite_number(value) else float(bounds[2])
	result.effect_enabled = options.get("effect_enabled", true) if options.get("effect_enabled", true) is bool else true
	return result

func _apply(material: ShaderMaterial, record: Dictionary) -> void:
	var options: Dictionary = record.options
	var source: Array = MATERIALS[options.material]
	material.set_shader_parameter("base_map", Moth.texture(source[0]))
	material.set_shader_parameter("normal_map", Moth.normal(source[1]))
	material.set_shader_parameter("texture_gain", source[2])
	material.set_shader_parameter("field_map", Moth.texture("macro-organic" if record.effect == "phase" else "flow-field"))
	var lut := Moth.material_lut(options.lut)
	material.set_shader_parameter("lut_r", lut.get("r"))
	material.set_shader_parameter("lut_t", lut.get("t"))
	if record.effect == "shield":
		var frames: Array = Moth.effect("effect-shield").get("frames", [])
		material.set_shader_parameter("motif_map", frames[0] if not frames.is_empty() else null)
	var palette: Array = PALETTES[options.palette]
	material.set_shader_parameter("accent", palette[0])
	material.set_shader_parameter("secondary", palette[1])
	material.set_shader_parameter("body_color", palette[2])
	for key: String in BOUNDS:
		if key == "opacity" and record.effect != "shield": continue
		if key in ["dissolve", "edge_width", "height_span"] and record.effect != "phase": continue
		material.set_shader_parameter(key, options[key])
	material.set_shader_parameter("effect_enabled", options.effect_enabled)
	material.set_shader_parameter("effect_time", _time)

func configure(material: ShaderMaterial, changes: Dictionary) -> bool:
	if material == null or not _instances.has(material.get_instance_id()): return false
	var record: Dictionary = _instances[material.get_instance_id()]
	var merged: Dictionary = record.options.duplicate(true)
	merged.merge(changes, true)
	var chosen := _sanitize(record.effect, merged)
	var resources_changed := false
	for key: String in ["material", "palette", "lut"]:
		if chosen[key] != record.options[key]: resources_changed = true
	var previous: Dictionary = record.options
	record.options = chosen
	if resources_changed:
		_apply(material, record)
	else:
		for key: String in chosen:
			if chosen[key] != previous[key]: material.set_shader_parameter(key, chosen[key])
	return true

func update_time(seconds: Variant) -> bool:
	# Absolute seconds, saturating at one hour (no hidden clock or wrap discontinuity).
	# Invalid input preserves the previous clock. Replay can seek backwards exactly.
	if not finite_number(seconds): return false
	_time = clampf(float(seconds), 0.0, MAX_TIME)
	_prune()
	for record: Dictionary in _instances.values():
		var material: ShaderMaterial = record.weak.get_ref()
		material.set_shader_parameter("effect_time", _time)
	return true

func material_state(material: ShaderMaterial) -> Dictionary:
	if material == null or not _instances.has(material.get_instance_id()): return {}
	var record: Dictionary = _instances[material.get_instance_id()]
	return {"effect": record.effect, "time": _time, "options": record.options.duplicate(true)}

func state() -> Dictionary:
	_prune()
	return {"time": _time, "materials": _instances.size(), "limit": MAX_MATERIALS,
		"shared_shaders": SHADERS.size(), "moth_cache": Moth.cache_stats()}

func reset() -> void:
	_prune()
	_time = 0.0
	for record: Dictionary in _instances.values():
		record.options = record.initial.duplicate(true)
		_apply(record.weak.get_ref(), record)

func release(material: ShaderMaterial) -> void:
	if material != null: _instances.erase(material.get_instance_id())

func clear() -> void:
	# Existing caller-owned materials remain valid and freeze at their last state.
	_instances.clear()
	_time = 0.0
