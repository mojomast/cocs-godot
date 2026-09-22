extends RefCounted
## Material language: named families built from the baked Moth asset set.
##
## Public interface (frozen; the applying lane codes against these signatures):
##   families() -> PackedStringArray
##   describe(family) -> Dictionary
##   material(family, options) -> Material
##   apply_to(node, family, options) -> int
##   normal_map(key) -> Texture2D
##   derived(key) -> Texture2D
##   coverage() -> Dictionary
##   budget() -> Dictionary
##   DEFAULT_FAMILIES: PackedStringArray
##
## Materials are shared: every call with the same family + canonical options
## returns the same ShaderMaterial from a bounded cache. Callers never receive a
## private instance, so N surfaces cost one material and one material_override /
## surface override per mesh. Returned dictionaries are caller-owned snapshots.

const Moth = preload("res://moth/library.gd")
const Families = preload("res://material_language/families.gd")
const FAMILY_SHADER = preload("res://material_language/family.gdshader")

const MAX_MATERIALS := 96
const MAX_TIME := 3600.0
const DEFAULT_TINT := Color(1, 1, 1, 1)
const DERIVED_PREFIXES := ["data--", "normal--", "mask--"]
const FLOW_KEY := "flow-field"

# Recognised option keys and their bounds. Every externally supplied number
# passes this table; anything else is ignored, never forwarded to the shader.
const BOUNDS := {
	"tiles_per_metre": [0.05, 4.0, 0.5],
	"texture_strength": [0.0, 1.0, 0.68],
	"texture_saturation": [0.0, 1.0, 0.5],
	"albedo_gain": [0.0, 12.0, 1.5],
	"normal_strength": [0.0, 1.0, 0.28],
	"detail_strength": [0.0, 1.0, 0.35],
	"ao_strength": [0.0, 1.0, 0.5],
	"detail_fade": [2.0, 200.0, 26.0],
	"roughness": [0.0, 1.0, 0.8],
	"roughness_variation": [0.0, 1.0, 0.25],
	"metallic": [0.0, 1.0, 0.0],
	"specular_strength": [0.0, 1.0, 0.4],
	"lut_phase": [0.0, 1.0, 0.35],
	"lut_gain": [0.0, 4.0, 0.0],
	"lut_t_gain": [0.0, 4.0, 0.0],
	"lut_fresnel_bias": [-1.0, 1.0, 0.0],
	"lut_fresnel_power": [0.3, 6.0, 3.0],
	"accent_mask_strength": [0.0, 1.0, 0.0],
	"accent_crease_strength": [0.0, 1.0, 0.0],
	"pulse_speed": [0.0, 2.0, 0.0],
	"pulse_depth": [0.0, 1.0, 0.0],
}

# Effects consumed by other lanes today (recorded, not measured here). Kept in
# coverage() so "unused" stays honest about the whole manifest, not just us.
const EFFECT_CONSUMERS := {
	"spark-impact": ["graphics_fx/moth_world.gd"],
	"effect-explosion": ["graphics_fx/moth_world.gd"],
	"effect-teleport": ["graphics_fx/moth_world.gd"],
	"effect-heal": ["graphics_fx/moth_world.gd"],
	"effect-shield": ["shader_lab/factory.gd"],
}

# Stable family ids. A static var (not a const) because GDScript cannot resolve a
# PackedStringArray const across scripts at parse time; never reassigned.
static var DEFAULT_FAMILIES := PackedStringArray([
	"pearl-ceramic", "enamel-glaze", "brushed-alloy", "oxidised-copper",
	"bioluminescent-membrane", "regolith", "polar-ice", "hazard-industrial",
])

static var _cache: Dictionary = {}
# -1 means "follow the engine clock": a family with a pulse keeps living even if
# the caller never drives time. set_clock() takes over for deterministic capture.
static var _clock := -1.0
static var _misses := 0
static var _rejected := 0
static var _budget_cache: Dictionary = {}

# ---------------------------------------------------------------- families ---

static func families() -> PackedStringArray:
	return DEFAULT_FAMILIES.duplicate()

static func has_family(family: String) -> bool:
	return Families.TABLE.has(family)

static func variants(family: String) -> PackedStringArray:
	var result := PackedStringArray(["default"])
	if not has_family(family): return result
	var table: Dictionary = Families.TABLE[family].get("variants", {})
	var keys: Array = table.keys()
	keys.sort()
	for key: String in keys: result.append(key)
	return result

static func describe(family: String) -> Dictionary:
	if not has_family(family): return {}
	var record: Dictionary = Families.TABLE[family]
	var shape := _shape(family, {}, BOUNDS)
	var bases: Array[String] = [shape.albedo_key]
	var normals: Array[Dictionary] = [{"key": shape.normal_key, "source": shape.normal_source, "variant": "default"}]
	for variant: String in variants(family):
		if variant == "default": continue
		var other := _shape(family, {"variant": variant}, BOUNDS)
		if not bases.has(other.albedo_key): bases.append(other.albedo_key)
		normals.append({"key": other.normal_key, "source": other.normal_source, "variant": variant})
	return {
		"id": family,
		"label": record.get("label", family),
		"story": record.get("story", ""),
		"roles": record.get("roles", []).duplicate(),
		"palette": record.get("palette", []).duplicate(),
		"variants": variants(family),
		"base_textures": bases,
		"normal": {
			"key": shape.normal_key, "source": shape.normal_source, "samplers": 1,
			"resolved": ("derived:normal--" + shape.normal_key) if shape.normal_source == "derived" else ("baked:" + shape.normal_key),
			"variants": normals,
		},
		"emissive": {
			"lut": record.get("accent", {}).get("lut", ""),
			"phase": float(record.get("accent", {}).get("phase", 0.0)),
			"gain": float(record.get("accent", {}).get("gain", 0.0)),
			"behaviour": record.get("accent", {}).get("behavior", ""),
			"color": shape.accent_color.to_html(false),
			"driven_by": "baked LUT R plane sampled at (fresnel, phase) as a monochrome spatial mask; the accent colour is the family palette value",
			"t_plane": "all five baked T planes are black in this bake; the sampler stays bound at zero gain",
		},
		"density": {
			"mode": "world-space triplanar, no UV or tangent input",
			"tile_px": int(record.get("texel", 0)),
			"tiles_per_metre": float(shape.params.tiles_per_metre),
			"px_per_metre": roundi(float(record.get("texel", 0)) * float(shape.params.tiles_per_metre)),
			"detail_fade_metres": float(shape.params.detail_fade),
		},
		"tint": shape.tint.to_html(false),
		"response": {
			"roughness": float(shape.params.roughness),
			"roughness_variation": float(shape.params.roughness_variation),
			"metallic": float(shape.params.metallic),
			"specular_strength": float(shape.params.specular_strength),
		},
		"budget": _family_budget(family),
		"samplers_per_material": _sampler_count(shape),
	}

# --------------------------------------------------------------- materials ---

static func material(family: String, options: Dictionary = {}) -> Material:
	var signature := _signature(family, options)
	if signature.is_empty(): return null
	if _cache.has(signature): return _cache[signature]
	if _cache.size() >= MAX_MATERIALS:
		# Fail closed without log spam: the caller sees null and can fall back to
		# an existing family. The rejection is counted for budget accounting.
		_rejected += 1
		return null
	var shape := _shape(family, options, BOUNDS)
	var material := ShaderMaterial.new()
	material.shader = FAMILY_SHADER
	material.set_shader_parameter("tint", shape.tint)
	material.set_shader_parameter("accent_color", shape.accent_color)
	material.set_shader_parameter("has_albedo", shape.albedo != null)
	material.set_shader_parameter("has_data", shape.data != null)
	material.set_shader_parameter("has_normal", shape.normal != null)
	material.set_shader_parameter("has_mask", shape.mask != null)
	material.set_shader_parameter("has_lut", not shape.lut.is_empty())
	material.set_shader_parameter("has_flow", shape.flow != null)
	material.set_shader_parameter("albedo_is_linear", shape.albedo_is_linear)
	if shape.albedo != null:
		material.set_shader_parameter("linear_map" if shape.albedo_is_linear else "albedo_map", shape.albedo)
	if shape.data != null: material.set_shader_parameter("data_map", shape.data)
	if shape.normal != null: material.set_shader_parameter("normal_map", shape.normal)
	if shape.mask != null: material.set_shader_parameter("mask_map", shape.mask)
	if shape.flow != null: material.set_shader_parameter("flow_map", shape.flow)
	if not shape.lut.is_empty():
		material.set_shader_parameter("lut_r", shape.lut.r)
		material.set_shader_parameter("lut_t", shape.lut.t)
	for key: String in BOUNDS:
		material.set_shader_parameter(key, shape.params[key])
	material.set_shader_parameter("glow", 1.0 if shape.glow else 0.0)
	material.set_shader_parameter("clock_override", _clock if _clock >= 0.0 else -1.0)
	_cache[signature] = material
	_budget_cache.clear()
	return material

static func apply_to(node: Node, family: String, options: Dictionary = {}) -> int:
	## Assigns the shared family material to every surface slot in the subtree.
	## Returns the number of surface slots assigned (instance count is not
	## multiplied in: a MultiMesh batch is one material binding).
	if node == null or not has_family(family): return 0
	var shared := material(family, options)
	if shared == null: return 0
	return _assign(node, shared)

static func _assign(node: Node, material: Material) -> int:
	var count := 0
	if node is MultiMeshInstance3D:
		var batch := node as MultiMeshInstance3D
		batch.material_override = material
		if batch.multimesh != null and batch.multimesh.mesh != null:
			count += maxi(1, batch.multimesh.mesh.get_surface_count())
		else:
			count += 1
	elif node is MeshInstance3D:
		# Surface overrides keep whatever the mesh already had and count exactly
		# what was assigned.
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			for index in instance.mesh.get_surface_count():
				instance.set_surface_override_material(index, material)
				count += 1
	for child: Node in node.get_children(): count += _assign(child, material)
	return count

static func set_clock(seconds: Variant) -> bool:
	if not _finite(seconds): return false
	_clock = clampf(float(seconds), 0.0, MAX_TIME)
	for material: ShaderMaterial in _cache.values():
		material.set_shader_parameter("clock_override", _clock)
	return true

static func set_glow(enabled: bool) -> int:
	var changed := 0
	for material: ShaderMaterial in _cache.values():
		material.set_shader_parameter("glow", 1.0 if enabled else 0.0)
		changed += 1
	return changed

static func reset() -> void:
	_cache.clear()
	_budget_cache.clear()
	_clock = -1.0
	_misses = 0
	_rejected = 0

static func cache_stats() -> Dictionary:
	return {"materials": _cache.size(), "limit": MAX_MATERIALS, "clock": _clock, "engine_clock": _clock < 0.0, "misses": _misses, "rejected": _rejected}

static func clock_follows_engine() -> bool:
	return _clock < 0.0

# ------------------------------------------------------------ moth lookups ---

static func normal_map(key: String) -> Texture2D:
	## Baked manifest normal first; a derived normal when the bake has none.
	if key.begins_with("derived:"): return derived(key.trim_prefix("derived:"))
	if key.begins_with("baked:"): return Moth.normal(key.trim_prefix("baked:"))
	var baked := Moth.normal(key)
	if baked != null: return baked
	return derived("normal--" + key)

static func derived(key: String) -> Texture2D:
	## Derived-bucket lookup. Exact key first, then the data/normal/mask
	## prefixes, so both "data--sand" and "sand" resolve.
	var texture := Moth.derived_texture(key.trim_prefix("derived:") if key.begins_with("derived:") else key)
	if texture != null: return texture
	for prefix: String in DERIVED_PREFIXES:
		texture = Moth.derived_texture(prefix + key)
		if texture != null: return texture
	return null

# --------------------------------------------------------------- reporting ---

static func coverage() -> Dictionary:
	var keys: Dictionary = {}
	var derived_keys: Dictionary = {}
	for family: String in DEFAULT_FAMILIES:
		for variant: String in variants(family):
			var shape := _shape(family, {"variant": variant}, BOUNDS)
			var consumer := "%s/%s" % [family, shape.variant]
			if shape.albedo_key != "":
				_consume(keys, "textures/" + shape.albedo_key, consumer)
				_consume(derived_keys, "data--" + shape.albedo_key, consumer)
			if shape.normal_key != "":
				if shape.normal_source == "derived": _consume(derived_keys, "normal--" + shape.normal_key, consumer)
				else: _consume(keys, "normals/" + shape.normal_key, consumer)
			if shape.lut_key != "": _consume(keys, "materials/" + shape.lut_key, consumer)
			if shape.mask_key != "": _consume(derived_keys, shape.mask_key, consumer)
	_consume(keys, "textures/" + FLOW_KEY, "pulse")
	var manifest := Moth.manifest()
	var unused: Dictionary = {}
	for bucket: String in ["textures", "normals", "materials", "effects"]:
		var remaining: Array[String] = []
		for key: String in manifest.get(bucket, {}):
			if keys.has(bucket + "/" + key): continue
			if bucket == "effects" and EFFECT_CONSUMERS.has(key): continue
			remaining.append(key)
		unused[bucket] = remaining
	return {
		"families": DEFAULT_FAMILIES.duplicate(),
		"keys": keys,
		"derived_keys": derived_keys,
		"unused": unused,
		"effects_consumed_elsewhere": EFFECT_CONSUMERS.duplicate(true),
		"counts": {
			"families": DEFAULT_FAMILIES.size(),
			"textures": _bucket_used(keys, "textures/"),
			"normals": _bucket_used(keys, "normals/"),
			"materials": _bucket_used(keys, "materials/"),
			"derived": derived_keys.size(),
			"unused_total": unused.textures.size() + unused.normals.size() + unused.materials.size() + unused.effects.size(),
		},
	}

static func budget() -> Dictionary:
	if not _budget_cache.is_empty(): return _budget_cache.duplicate(true)
	var per_family: Dictionary = {}
	var total_bytes := 0
	var total_vram := 0
	var unique: Dictionary = {}
	for family: String in DEFAULT_FAMILIES:
		var entry := _family_budget(family)
		per_family[family] = entry
		total_bytes += int(entry.bytes)
		total_vram += int(entry.vram_bytes)
		for path: String in entry.paths: unique[path] = true
	var payload := {
		"families": DEFAULT_FAMILIES.size(),
		"variants": _variant_count(),
		"materials_cached": _cache.size(),
		"material_cap": MAX_MATERIALS,
		"shaders": 1,
		"samplers_per_material": 7,
		"unique_textures": unique.size(),
		"draw_calls_added": 0,
		"shared_materials_only": true,
		"bytes_measurement": "PNG length on disk; vram is IHDR RGBA8 plus a third for mipmaps",
		"per_family": per_family,
		"total_bytes": total_bytes,
		"total_vram_bytes": total_vram,
		"moth_cache": Moth.cache_stats(),
		"derived_cache": Moth.derived_cache_stats(),
	}
	_budget_cache = payload
	return payload.duplicate(true)

static func _family_budget(family: String) -> Dictionary:
	if not has_family(family): return {}
	var paths: Array[String] = []
	var bytes := 0
	var vram := 0
	var bases: Array[String] = []
	for variant: String in variants(family):
		var shape := _shape(family, {"variant": variant}, BOUNDS)
		for path: String in shape.paths:
			if path in paths: continue
			paths.append(path)
			bytes += _file_bytes(path)
			vram += _vram_bytes(path)
		if not bases.has(shape.albedo_key): bases.append(shape.albedo_key)
	return {
		"bases": bases,
		"variants": variants(family).size(),
		"unique_textures": paths.size(),
		"bytes": bytes,
		"vram_bytes": vram,
		"paths": paths,
	}

# -------------------------------------------------------------- internals ---

static func _consume(bucket_map: Dictionary, key: String, consumer: String) -> void:
	if not bucket_map.has(key): bucket_map[key] = []
	if not bucket_map[key].has(consumer): bucket_map[key].append(consumer)

static func _bucket_used(keys: Dictionary, prefix: String) -> int:
	var count := 0
	for key: String in keys:
		if key.begins_with(prefix): count += 1
	return count

static func _variant_count() -> int:
	var count := 0
	for family: String in DEFAULT_FAMILIES:
		count += (Families.TABLE[family].get("variants", {}) as Dictionary).size()
	return count

static func _finite(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _file_bytes(path: String) -> int:
	if not path.begins_with("res://") or not path.ends_with(".png") or ".." in path: return 0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return 0
	var length := file.get_length()
	file.close()
	return length

static func _vram_bytes(path: String) -> int:
	# IHDR is always the first chunk: width and height are big-endian at 16..24.
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return 0
	var header := file.get_buffer(24)
	file.close()
	if header.size() < 24: return 0
	var width := (header[16] << 24) | (header[17] << 16) | (header[18] << 8) | header[19]
	var height := (header[20] << 24) | (header[21] << 16) | (header[22] << 8) | header[23]
	return int(round(float(width) * float(height) * 4.0 * 4.0 / 3.0))

static func _signature(family: String, options: Dictionary) -> String:
	if not has_family(family) or not options is Dictionary: return ""
	var variant := "default"
	if options.get("variant") is String and variants(family).has(options.variant): variant = options.variant
	var parts: Array[String] = [family, variant]
	for key: String in BOUNDS:
		if options.has(key) and _finite(options[key]):
			var bounds: Array = BOUNDS[key]
			parts.append("%s=%.4f" % [key, clampf(float(options[key]), bounds[0], bounds[1])])
	if options.get("tint") is Color:
		var tint: Color = options.tint
		if _finite(tint.r) and _finite(tint.g) and _finite(tint.b):
			parts.append("tint=%.3f_%.3f_%.3f" % [tint.r, tint.g, tint.b])
	if options.get("glow") is bool:
		parts.append("glow=%s" % str(options.glow))
	return "|".join(parts)

static func _shape(family: String, options: Dictionary, bounds: Dictionary) -> Dictionary:
	# Resolve family + variant + options into one concrete surface description.
	var record: Dictionary = Families.TABLE[family]
	var variant := "default"
	if options.get("variant") is String and variants(family).has(options.variant): variant = options.variant
	var entry: Dictionary = record.get("variants", {}).get(variant, {})
	var accent: Dictionary = record.get("accent", {})
	var palette: Array = record.get("palette", [])
	var params: Dictionary = {}
	for key: String in BOUNDS: params[key] = float(BOUNDS[key][2])
	# The family's primary palette slot is the albedo multiplier, so a family is
	# its palette, not just its texture. Accent phase/gain live in the accent
	# record only, so describe() and the shader can never disagree.
	params["tint"] = palette[0] if not palette.is_empty() else DEFAULT_TINT
	params["lut_phase"] = float(accent.get("phase", params.lut_phase))
	params["lut_gain"] = float(accent.get("gain", params.lut_gain))
	for key: Variant in (record.get("params", {}) as Dictionary).keys(): params[key] = record.params[key]
	for key: Variant in (entry.get("params", {}) as Dictionary).keys(): params[key] = entry.params[key]
	if options.get("tint") is Color and _finite(options.tint.r) and _finite(options.tint.g) and _finite(options.tint.b):
		params["tint"] = options.tint
	for key: String in bounds:
		if options.has(key) and _finite(options[key]):
			var limits: Array = bounds[key]
			params[key] = clampf(float(options[key]), limits[0], limits[1])
	var glow := true
	if options.get("glow") is bool: glow = options.glow
	var albedo_key: String = entry.get("base", record.default.base)
	var normal_key: String = entry.get("normal", record.default.normal)
	var normal_source: String = entry.get("normal_source", record.default.get("normal_source", "baked"))
	var mask_key: String = entry.get("mask", record.default.get("mask", ""))
	if mask_key != "" and not params.has("accent_mask_strength"):
		params["accent_mask_strength"] = 0.0
	if mask_key != "":
		params["accent_mask_strength"] = clampf(float(entry.get("mask_strength", record.default.get("mask_strength", params.accent_mask_strength))), 0.0, 1.0)
	if options.has("accent_mask_strength") and _finite(options.accent_mask_strength):
		params["accent_mask_strength"] = clampf(float(options.accent_mask_strength), 0.0, 1.0)
	var albedo := Moth.texture(albedo_key)
	var normal := Moth.derived_texture("normal--" + normal_key) if normal_source == "derived" else Moth.normal(normal_key)
	var data := Moth.derived_texture("data--" + albedo_key)
	var mask := Moth.derived_texture(mask_key) if mask_key != "" else null
	var lut := Moth.material_lut(record.get("accent", {}).get("lut", ""))
	var accent_color: Color = accent.get("color", palette[0] if not palette.is_empty() else Color.WHITE)
	var flow: Texture2D = null
	if float(params.pulse_speed) > 0.0 or float(params.pulse_depth) > 0.0:
		flow = Moth.texture(FLOW_KEY)
	var paths: Array[String] = []
	if albedo != null: paths.append(albedo.resource_path)
	if data != null: paths.append(data.resource_path)
	if normal != null: paths.append(normal.resource_path)
	if mask != null: paths.append(mask.resource_path)
	if flow != null: paths.append(flow.resource_path)
	if not lut.is_empty():
		paths.append(lut.r.resource_path)
		paths.append(lut.t.resource_path)
	return {
		"family": family, "variant": variant, "albedo": albedo, "albedo_key": albedo_key,
		"albedo_is_linear": bool(entry.get("linear_base", false)),
		"normal": normal, "normal_key": normal_key, "normal_source": normal_source,
		"data": data, "mask": mask, "mask_key": mask_key,
		"lut": lut, "lut_key": record.get("accent", {}).get("lut", ""),
		"flow": flow, "accent_color": accent_color, "glow": glow, "paths": paths,
		"params": params, "tint": params.tint,
	}

static func _sampler_count(shape: Dictionary) -> int:
	var count := 1 # albedo (or the linear data sampler)
	if shape.data != null: count += 1
	if shape.normal != null: count += 1
	if shape.mask != null: count += 1
	count += 1 if shape.flow != null else 0
	count += 2 if not shape.lut.is_empty() else 0
	return count
