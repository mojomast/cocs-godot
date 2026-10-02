extends Node3D
## Root-owned production dressing. No physics, process loop or shared mutations.
const Profile = preload("res://multiplayer_worlds/dressing/profile.gd")
const Surface = preload("res://multiplayer_worlds/dressing/surface.gd")
const Moth = preload("res://moth/library.gd")
const MoteShader = preload("res://moth_scenery/motes.gdshader")
const PanelShader = preload("res://moth_scenery/panel.gdshader")
const WearPanelShader = preload("res://multiplayer_worlds/dressing/wear_panel.gdshader")
const Language = preload("res://material_language/library.gd")
const OWNER := "new_map_dressing"
enum Detail { OFF, LOW, FULL }
var _profile: Dictionary = {}
var _bindings: Array[Dictionary] = []
var _resources: Dictionary = {}
var _diagnostics: Dictionary = {}
var _detail := -1

static func apply(root: Node3D, map_id: String, geometry_hash: String) -> Dictionary:
	cleanup(root)
	var report := {"map_id": map_id, "status": "ineligible", "errors": [], "matched": [], "unmatched": [], "unused_selectors": [], "preserved": [], "resources": [], "surfaces": 0, "panels": 0, "signs": 0, "motes": 0}
	if not Profile.IDENTITIES.has(map_id): return report
	if geometry_hash != Profile.IDENTITIES[map_id]:
		report.status = "identity_mismatch"
		return report
	var path := "res://multiplayer_worlds/dressing/profiles/" + map_id + ".json"
	if not FileAccess.file_exists(path):
		report.status = "missing_profile"
		return report
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	report.errors = Profile.validate(parsed, map_id, geometry_hash)
	if not report.errors.is_empty():
		report.status = "invalid_profile"
		return report
	var node = load("res://multiplayer_worlds/dressing/binder.gd").new()
	node.name = "NewMapDressing"
	node.set_meta(OWNER, true)
	node._profile = parsed
	node._diagnostics = report
	root.add_child(node)
	node._prepare(root)
	if not report.errors.is_empty():
		report.status = "unresolved_resources"
		node.free()
		return report
	var art := root.get_node_or_null("BlenderArtNoGameplayCollision")
	if art == null:
		report.status = "missing_art"
		node.free()
		return report
	node._collect(art)
	for entry: Dictionary in node._profile.materials:
		if not report.matched.has(entry.source): report.unused_selectors.append(entry.source)
	for selector: String in node._profile.preserve_materials:
		if not report.preserved.has(selector): report.unused_selectors.append(selector)
	report.status = "ready" if report.unmatched.is_empty() and report.unused_selectors.is_empty() else "incomplete_coverage"
	node.set_detail(int(root.get_meta("dressing_detail", Detail.FULL)))
	return node.diagnostics()

static func cleanup(root: Node3D) -> void:
	for child: Node in root.get_children():
		if child.get_meta(OWNER, false) == true:
			child.set_detail(Detail.OFF)
			child.free()

static func set_root_detail(root: Node3D, level: int) -> void:
	root.set_meta("dressing_detail", clampi(level, Detail.OFF, Detail.FULL))
	for child: Node in root.get_children():
		if child.get_meta(OWNER, false) == true: child.set_detail(level)

func diagnostics() -> Dictionary:
	return _diagnostics.duplicate(true)

func _prepare(root: Node3D) -> void:
	for entry: Dictionary in _profile.materials:
		var result := Surface.build(entry, root)
		if result.has("error"):
			_diagnostics.errors.append(result.error)
			continue
		_resources[entry.source] = result.material
		for path: String in result.resources:
			if not _diagnostics.resources.has(path): _diagnostics.resources.append(path)
	for entry: Dictionary in _profile.panels:
		var texture := Moth.texture(entry.texture)
		var normal := Language.normal_map(entry.get("normal", entry.texture))
		var housing := Moth.texture("brushed_metal")
		var mask: Texture2D = Moth.texture(entry.wear_mask) if entry.has("wear_mask") else null
		if entry.has("wear_mask") and mask == null:
			_diagnostics.errors.append("unresolved wear mask " + entry.id)
			continue
		if texture == null or normal == null or housing == null:
			_diagnostics.errors.append("unresolved panel " + entry.id)
			continue
		var material := ShaderMaterial.new()
		material.shader = WearPanelShader if mask != null else PanelShader
		material.set_shader_parameter("baked_tile", texture)
		material.set_shader_parameter("circuit_tile", texture)
		material.set_shader_parameter("housing_tile", housing)
		material.set_shader_parameter("normal_tile", normal)
		material.set_shader_parameter("has_normal", true)
		material.set_shader_parameter("style", 2)
		material.set_shader_parameter("tint", Color(entry.tint))
		material.set_shader_parameter("emission_strength", 0.0)
		if mask != null:
			material.set_shader_parameter("wear_mask", mask)
			material.set_shader_parameter("opacity", entry.get("opacity", 1.0))
			material.set_shader_parameter("feather", entry.get("feather", 0.15))
			var seed_value := int(entry.get("seed", 0))
			material.set_shader_parameter("mask_offset", Vector2(float(seed_value % 997) / 997.0, float(seed_value % 991) / 991.0))
			if not _diagnostics.resources.has(mask.resource_path): _diagnostics.resources.append(mask.resource_path)
		_resources["panel/" + entry.id] = material
		for image: Texture2D in [texture, normal, housing]:
			if not _diagnostics.resources.has(image.resource_path): _diagnostics.resources.append(image.resource_path)
	if not _profile.pockets.is_empty():
		for key: String in ["dust-field", "flow-field"]:
			var texture := Moth.texture(key)
			if texture == null: _diagnostics.errors.append("unresolved pocket texture " + key)
			else:
				_resources[key] = texture
				_diagnostics.resources.append(texture.resource_path)

func _collect(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for index in node.mesh.get_surface_count():
			var source: Material = node.mesh.surface_get_material(index)
			var selector := source.resource_name if source != null else "<null>"
			if _profile.preserve_materials.has(selector):
				if not _diagnostics.preserved.has(selector): _diagnostics.preserved.append(selector)
			elif _resources.has(selector):
				# An instance-wide override would defeat surface bindings. Report it.
				if node.material_override != null:
					_diagnostics.unmatched.append(selector + " (instance override)")
					continue
				_bindings.append({"node": weakref(node), "index": index, "before": node.get_surface_override_material(index), "after": _resources[selector]})
				if not _diagnostics.matched.has(selector): _diagnostics.matched.append(selector)
			else:
				if not _diagnostics.unmatched.has(selector): _diagnostics.unmatched.append(selector)
	for child: Node in node.get_children(): _collect(child)

func set_detail(level: int) -> void:
	level = clampi(level, Detail.OFF, Detail.FULL)
	if _detail == level: return
	_detail = level
	for child: Node in get_children(): child.free()
	for binding: Dictionary in _bindings:
		var instance: Object = binding.node.get_ref()
		if instance != null: instance.set_surface_override_material(binding.index, binding.before if level == Detail.OFF else binding.after)
	_diagnostics.merge({"detail": level, "surfaces": 0 if level == Detail.OFF else _bindings.size(), "panels": 0, "signs": 0, "motes": 0, "batches": 0}, true)
	if level == Detail.OFF: return
	for entry: Dictionary in _profile.panels:
		if level == Detail.LOW and not entry.get("essential", false): continue
		_plate(entry, _resources["panel/" + entry.id])
		_diagnostics.panels += 1
	for entry: Dictionary in _profile.signs:
		if level == Detail.LOW and not entry.get("essential", false): continue
		_sign(entry)
	if level == Detail.FULL:
		for entry: Dictionary in _profile.pockets: _pocket(entry)
	_diagnostics.batches = get_child_count()

func _plate(entry: Dictionary, material: Material) -> MeshInstance3D:
	var plate := MeshInstance3D.new()
	plate.name = entry.id
	var quad := QuadMesh.new()
	quad.size = Vector2(entry.size[0], entry.size[1])
	plate.mesh = quad
	plate.material_override = material
	plate.position = _v(entry.position)
	plate.rotation_degrees = _v(entry.rotation_degrees)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plate)
	return plate

func _sign(entry: Dictionary) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(entry.background)
	material.roughness = 0.92
	var plate := _plate(entry, material)
	var label := Label3D.new()
	label.text = entry.text
	label.font_size = 64
	label.outline_size = 0
	label.modulate = Color(entry.foreground)
	label.no_depth_test = false
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.shaded = false
	label.double_sided = false
	label.position.z = 0.004
	# Fit actual font metrics in both axes with a 12% mounting margin.
	var font := ThemeDB.fallback_font
	label.font = font
	var width := 1.0
	var lines := entry.text.split("\n")
	for line: String in lines: width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x)
	var height := font.get_height(64) * lines.size()
	label.pixel_size = minf(float(entry.size[0]) * 0.88 / width, float(entry.size[1]) * 0.88 / height)
	if label.pixel_size * 64 < 0.08:
		_diagnostics.errors.append("sign text too small to read: " + entry.id)
		plate.free()
		return
	plate.add_child(label)
	_diagnostics.signs += 1

func _pocket(entry: Dictionary) -> void:
	var dimensions := _v(entry.size)
	var material := ShaderMaterial.new()
	material.shader = MoteShader
	material.set_shader_parameter("dust_field", _resources["dust-field"])
	material.set_shader_parameter("flow_field", _resources["flow-field"])
	material.set_shader_parameter("tint", Color(entry.color))
	material.set_shader_parameter("height", dimensions.y * 0.65)
	material.set_shader_parameter("size", 0.07 if entry.kind == "mist" else 0.045)
	material.set_shader_parameter("opacity", 0.14 if entry.kind == "mist" else 0.28)
	material.set_shader_parameter("fall_speed", -0.025 if entry.kind in ["ash", "vent"] else 0.024)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = QuadMesh.new()
	mm.instance_count = int(entry.count)
	for i in mm.instance_count:
		var a := fmod((i + 1) * 0.61803398875, 1.0)
		var b := fmod((i + 1) * 0.41421356237, 1.0)
		var c := fmod((i + 1) * 0.73205080757, 1.0)
		# Shader's vertical excursion uses b-age, so start at -b*height.
		var point := Vector3((a - 0.5) * maxf(dimensions.x - 0.5, 0), dimensions.y * 0.325 - b * dimensions.y * 0.65, (c - 0.5) * maxf(dimensions.z - 0.5, 0))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, point))
		mm.set_instance_custom_data(i, Color(a, b, c, 0))
	var batch := MultiMeshInstance3D.new()
	batch.name = entry.id
	batch.multimesh = mm
	batch.position = _v(entry.position)
	batch.material_override = material
	batch.custom_aabb = AABB(-dimensions * 0.5, dimensions).grow(0.25)
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.visibility_range_end = 55.0
	add_child(batch)
	_diagnostics.motes += mm.instance_count

static func _v(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
