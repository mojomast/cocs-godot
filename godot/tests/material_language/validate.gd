extends SceneTree
## Material-language contracts: family stability, cache reuse, derived-asset
## determinism, budget accounting and unknown-family failure.
##
## Runs headless: godot --headless --path godot --script res://tests/material_language/validate.gd

const Language = preload("res://material_language/library.gd")
const Moth = preload("res://moth/library.gd")
const Families = preload("res://material_language/families.gd")

var checks := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("MATERIAL_LANGUAGE_CONTRACT: " + message)

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	Language.reset()
	_families()
	_material_cache()
	_apply_to()
	_derived_assets()
	_budget()
	_coverage()
	_unknown()
	_caller_safety()
	Language.reset()
	print("MATERIAL_LANGUAGE_CONTRACT_%s checks=%d failures=%d families=%d" % ["FAIL" if not failures.is_empty() else "OK", checks, failures.size(), Language.families().size()])
	quit(0 if failures.is_empty() else 1)

func _families() -> void:
	var ids: PackedStringArray = Language.families()
	check(ids == Language.DEFAULT_FAMILIES, "families() returns the stable default ids")
	check(ids.size() == 8, "eight families")
	var seen_tints := {}
	var seen_luts := {}
	for family: String in ids:
		var description: Dictionary = Language.describe(family)
		check(not description.is_empty(), "describe returns a record for " + family)
		for key: String in ["id", "label", "story", "roles", "palette", "variants", "base_textures", "normal", "emissive", "density", "response", "budget", "samplers_per_material"]:
			check(description.has(key), "describe(%s) has %s" % [family, key])
		check(description.id == family, "describe id matches: " + family)
		check(description.palette.size() >= 2, "palette reads as a family: " + family)
		var tint: Color = description.palette[0]
		check(not seen_tints.has(tint.to_html()), "families do not share a primary palette slot: " + family)
		seen_tints[tint.to_html()] = family
		# One normal map per family, and it must resolve to a real texture.
		var normal: Texture2D = Language.normal_map(description.normal.key) if description.normal.source == "baked" else Language.derived(description.normal.resolved)
		check(normal != null, "family normal resolves: %s/%s" % [family, description.normal.key])
		check(description.normal.samplers == 1, "one normal sampler per family: " + family)
		# Emissive is a baked LUT with a real gain and a phase inside 0..1.
		var emissive: Dictionary = description.emissive
		check(not Moth.material_lut(emissive.lut).is_empty(), "family LUT exists: %s/%s" % [family, emissive.lut])
		seen_luts[emissive.lut] = true
		check(emissive.gain > 0.0, "family accent has a positive gain: " + family)
		check(emissive.phase >= 0.0 and emissive.phase <= 1.0, "family accent phase in range: " + family)
		check(emissive.behaviour.length() > 20, "family accent is documented: " + family)
		# Density is honest and bounded.
		check(int(description.density.px_per_metre) >= 20 and int(description.density.px_per_metre) <= 160, "texel density is documented and sane: " + family)
		check(description.density.mode.begins_with("world-space triplanar"), "triplanar is declared: " + family)
		# Every variant resolves to an existing base texture and a valid variant id.
		var variants: PackedStringArray = description.variants
		check(variants[0] == "default", "default is the first variant: " + family)
		for variant: String in variants:
			var options := {} if variant == "default" else {"variant": variant}
			var material: Material = Language.material(family, options)
			check(material != null, "variant material resolves: %s/%s" % [family, variant])
			if material is ShaderMaterial:
				check(material.get_shader_parameter("has_albedo") == true, "variant base binds: %s/%s" % [family, variant])
				check(material.get_shader_parameter("has_normal") == true, "variant normal binds: %s/%s" % [family, variant])
				check(material.get_shader_parameter("has_data") == true, "variant data map binds: %s/%s" % [family, variant])
				check(float(material.get_shader_parameter("lut_gain")) > 0.0, "variant accent gain positive: %s/%s" % [family, variant])
	check(seen_luts.size() == 5, "all five baked LUTs drive a family, got " + str(seen_luts.size()))

func _material_cache() -> void:
	Language.reset()
	var a := Language.material("pearl-ceramic")
	var b := Language.material("pearl-ceramic")
	check(a != null and a == b, "identical options return the same shared material")
	check(not Language.material("pearl-ceramic", {"variant": "polished"}) == a, "variant is a distinct material")
	var c := Language.material("pearl-ceramic", {"tiles_per_metre": 1.25})
	check(c != a and c != null, "option change is a distinct material")
	check(Language.material("pearl-ceramic", {"tiles_per_metre": 1.2500001}) == c, "options are canonicalised to four decimals")
	Language.material("regolith", {"variant": "scoured"})
	var created: int = Language.cache_stats().materials
	for i in 200: Language.material("regolith", {"variant": "scoured"})
	check(Language.cache_stats().materials == created, "repeated identical requests do not grow the cache")
	check(Language.cache_stats().materials <= Language.cache_stats().limit, "cache stays under its cap")
	# Distinct options across every family, then check the cap holds and overflow
	# fails closed instead of allocating.
	var held: Array = []
	for family: String in Language.families():
		for step in 12:
			held.append(Language.material(family, {"tiles_per_metre": 0.5 + step * 0.05}))
	check(Language.cache_stats().materials <= Language.MAX_MATERIALS, "cache respects MAX_MATERIALS with pressure")
	check(Language.cache_stats().rejected > 0, "overflow is counted, not logged as an error")
	var over := Language.material("regolith", {"variant": "verdant", "lut_phase": 0.123})
	check(over == null or Language.cache_stats().materials <= Language.MAX_MATERIALS, "overflow fails closed")
	# Sharing: two nodes receive the identical material instance.
	check(Language.material("regolith") == Language.material("regolith", {}), "default options are canonical")

func _apply_to() -> void:
	Language.reset()
	var root := Node3D.new()
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	root.add_child(box)
	var sphere := MeshInstance3D.new()
	sphere.mesh = SphereMesh.new()
	root.add_child(sphere)
	var batch := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = QuadMesh.new()
	multi.instance_count = 64
	batch.multimesh = multi
	root.add_child(batch)
	var assigned := Language.apply_to(root, "brushed-alloy")
	check(assigned == 3, "apply_to counts one surface per mesh and one per multimesh batch, got " + str(assigned))
	var shared := Language.material("brushed-alloy")
	check(box.get_surface_override_material(0) == shared, "mesh surface override is the shared material")
	check(sphere.get_surface_override_material(0) == shared, "second mesh shares the same instance")
	check(batch.material_override == shared, "multimesh batch shares the same instance")
	check(Language.apply_to(root, "regolith") == 3, "re-applying swaps the whole subtree")
	check(box.get_surface_override_material(0) == Language.material("regolith"), "swap keeps sharing")
	root.free()
	var empty := Node3D.new()
	check(Language.apply_to(empty, "regolith") == 0, "empty subtree assigns nothing")
	empty.free()

func _derived_assets() -> void:
	var manifest: Dictionary = Moth.derived_manifest()
	var baked_before: int = Moth.cache_stats().textures
	check(manifest.get("version") == 1, "derived manifest version")
	var derived: Dictionary = manifest.get("derived", {})
	check(derived.size() >= 38, "derived bucket is populated, got %d" % derived.size())
	var kinds := {"data": 0, "normal": 0, "mask": 0}
	for key: String in derived:
		var record: Dictionary = derived[key]
		kinds[record.kind] += 1
		check(key.begins_with(record.kind + "--"), "derived key is kind-prefixed: " + key)
		check(record.path.begins_with("res://moth/derived/"), "derived path stays in its bucket: " + key)
		check(record.color_space == "linear", "derived plane is linear: " + key)
		check(record.source is Array and not record.source.is_empty(), "derived file records its source: " + key)
		for source: Dictionary in record.source:
			var plan: Dictionary = Moth.manifest().get(source.bucket, {}).get(source.key, {})
			check(plan.get("pixel_sha256", "") == source.pixel_sha256, "derived source hash matches the bake: " + key)
		check(record.algorithm is String and record.algorithm.length() > 6, "derived file names its algorithm: " + key)
		check(record.parameters is Dictionary and not record.parameters.is_empty(), "derived file records its parameters: " + key)
		check(record.stats is Dictionary and not record.stats.is_empty(), "derived file records measured stats: " + key)
		# Byte-for-byte: the imported texture must hash to the recorded pixel hash.
		var texture: Texture2D = Moth.derived_texture(key)
		check(texture != null, "derived texture loads: " + key)
		if texture == null: continue
		check(texture.get_width() == int(record.width) and texture.get_height() == int(record.height), "derived texture size: " + key)
		var image := texture.get_image()
		image.clear_mipmaps()
		image.convert(Image.FORMAT_RGBA8)
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(image.get_data())
		check(hash.finish().hex_encode() == record.pixel_sha256, "derived bytes are deterministic: " + key)
	check(kinds.data == 24 and kinds.normal == 12 and kinds.mask == 2, "derived inventory by kind: " + str(kinds))
	check(Moth.derived_texture("normal--alien_chitin") == Moth.derived_texture("normal--alien_chitin"), "derived cache shares resources")
	check(Moth.derived_texture("normal--alien_chitin") != Moth.texture("alien_chitin"), "derived and baked caches stay distinct")
	check(Moth.derived_cache_stats().textures <= Moth.MAX_DERIVED_TEXTURES, "derived cache is bounded")
	# The baked inventory is untouched by this bucket.
	check(Moth.manifest().textures.size() == 31 and Moth.manifest().normals.size() == 13, "101-plane inventory unchanged")
	check(Moth.cache_stats().textures == baked_before, "derived lookups do not touch the baked cache")

func _budget() -> void:
	var report: Dictionary = Language.budget()
	check(report.families == 8, "budget reports eight families")
	check(report.shared_materials_only == true, "budget is shared-material only")
	check(report.draw_calls_added == 0, "material swap adds no draw calls")
	check(int(report.total_bytes) > 0, "budget measures real PNG bytes")
	check(int(report.unique_textures) >= 40, "budget counts unique textures, got " + str(report.unique_textures))
	var summed := 0
	for family: String in Language.families():
		var entry: Dictionary = report.per_family[family]
		check(not entry.is_empty(), "budget has a per-family row: " + family)
		check(entry.bases.size() >= 1 and entry.bases.size() <= 4, "family base textures are bounded: " + family)
		check(entry.unique_textures >= 3, "family binds several planes: " + family)
		summed += int(entry.bytes)
	check(summed == int(report.total_bytes), "per-family bytes sum to the total")
	check(Language.budget() == report, "budget is cached and stable")
	check(int(report.per_family["polar-ice"].bytes) > 0 and int(report.per_family["polar-ice"].vram_bytes) > 0, "vram estimate present")

func _coverage() -> void:
	var report: Dictionary = Language.coverage()
	var baked: Dictionary = Moth.manifest()
	for bucket: String in ["textures", "normals", "materials"]:
		var missing: Array[String] = []
		for key: String in baked.get(bucket, {}):
			if not report.keys.has(bucket + "/" + key): missing.append(key)
		if bucket == "normals": check(missing.is_empty(), "every baked normal has a family, uncovered: " + str(missing))
		if bucket == "materials": check(missing.is_empty(), "every baked LUT has a family, uncovered: " + str(missing))
	for key: String in report.keys:
		var parts := key.split("/")
		check(baked.get(parts[0], {}).has(parts[1]), "coverage keys exist in the bake: " + key)
		check(report.keys[key] is Array and not report.keys[key].is_empty(), "coverage records consumers: " + key)
	for key: String in report.derived_keys:
		check(Moth.derived_record(key).size() > 0, "coverage derived keys exist: " + key)
	check(report.counts.normals == 13, "all 13 baked normals are consumed by families, got " + str(report.counts.normals))
	check(report.counts.materials == 5, "all 5 baked LUTs are consumed")
	check(report.counts.textures >= 20, "texture coverage grew, got " + str(report.counts.textures))
	check(report.unused.textures.size() + report.unused.normals.size() + report.unused.materials.size() < 15, "unused list shrank: " + str(report.unused))

func _unknown() -> void:
	check(Language.material("not-a-family") == null, "unknown family returns null")
	check(Language.describe("not-a-family").is_empty(), "unknown family has no description")
	check(Language.normal_map("not-a-normal") == null, "unknown normal returns null")
	check(Language.derived("not-derived") == null, "unknown derived key returns null")
	check(Language.variants("not-a-family") == PackedStringArray(["default"]), "unknown family exposes only default")
	var node := MeshInstance3D.new()
	node.mesh = BoxMesh.new()
	check(Language.apply_to(node, "not-a-family") == 0, "unknown family assigns nothing")
	check(node.get_surface_override_material(0) == null, "unknown family leaves the mesh untouched")
	node.free()
	check(Language.material("pearl-ceramic", {"variant": "../../absent"}) == Language.material("pearl-ceramic"), "unknown variant falls back to default")
	check(Language.material("pearl-ceramic", {"tiles_per_metre": NAN}) == Language.material("pearl-ceramic"), "non-finite option is ignored")
	var tinted := Language.material("pearl-ceramic", {"tint": Color(NAN, 0, 0)})
	check(tinted == Language.material("pearl-ceramic"), "non-finite tint is ignored")

func _caller_safety() -> void:
	Language.reset()
	check(Language.clock_follows_engine(), "families follow the engine clock until a caller takes over")
	var material := Language.material("hazard-industrial")
	check(material.get_shader_parameter("clock_override") == -1.0, "an undriven material samples TIME, not a frozen phase")
	check(material != null, "family material created")
	check(Language.set_clock(4.5) and material.get_shader_parameter("clock_override") == 4.5, "caller clock is applied to live materials")
	check(not Language.set_clock(NAN) and not Language.set_clock(INF), "invalid clock rejected")
	Language.set_clock(1e9)
	check(Language.cache_stats().clock == Language.MAX_TIME, "clock saturates")
	check(Language.set_glow(false) > 0 and material.get_shader_parameter("glow") == 0.0, "glow toggles without a new material")
	check(Language.set_glow(true) == Language.cache_stats().materials, "glow toggle covers every cached material")
	var description: Dictionary = Language.describe("biomolecular-membrane")
	check(description.is_empty(), "unknown describe stays empty under stress")
	var report: Dictionary = Language.coverage()
	report.families.clear()
	check(Language.coverage().families.size() == 8, "coverage snapshots are caller-owned")
	Language.reset()
	check(Language.cache_stats().materials == 0, "reset clears the material cache")
	check(material.get_shader_parameter("albedo_map") != null, "live caller material survives reset")
	check(Families.TABLE.size() == 8, "family table has eight entries")
