extends RefCounted
## Instance-owned fitted-UV finish installation. No geometry or animation edits.
const ROOT := "res://source_operators/moth_finish/"
const MAX_TEXTURES := 81
const Catalog = preload("res://source_operators/generated/catalog.gd")
var _slots: Array[Dictionary] = []
var _team: Array[Dictionary] = []
var _textures: Dictionary = {}
var report: Dictionary = {}

func clear() -> void:
	for slot: Dictionary in _slots:
		var mesh: MeshInstance3D = slot.mesh
		if not is_instance_valid(mesh): continue
		if slot.surface < 0:
			if mesh.material_override == slot.applied: mesh.material_override = slot.original
		elif mesh.get_surface_override_material(slot.surface) == slot.applied:
			mesh.set_surface_override_material(slot.surface, slot.original)
	_slots.clear()
	_team.clear()
	_textures.clear()

func bind(root: Node3D, operator_id: String) -> Dictionary:
	clear()
	report = {"operator_id":operator_id, "installed":false, "matched":[], "excluded":[], "unmatched":[], "textures":{}, "errors":[], "fallback":"authored_svg"}
	var profile := _json(ROOT + "profiles/" + operator_id + ".json")
	var manifest := _json(ROOT + "manifest.json")
	if not _validate(profile, manifest, operator_id): return report
	var bindings: Dictionary = {}
	var preserved: Dictionary = {}
	for binding: Dictionary in profile.bindings: bindings[binding.source_material] = binding
	for item: Dictionary in profile.preserve_materials: preserved[item.source_material] = item.reason
	var pending: Array[Dictionary] = []
	var seen: Dictionary = {}
	_collect(root, bindings, preserved, profile.overlay_finishes, manifest.finishes, pending, seen, operator_id)
	for name: String in bindings:
		if not seen.has(name):
			report.unmatched.append({"source_material":name, "reason":"binding_not_found"})
			report.errors.append("binding_not_found:" + name)
	if not report.errors.is_empty():
		_textures.clear()
		return report
	# Commit only after every selected material/resource has been prepared.
	for slot: Dictionary in pending:
		var mesh: MeshInstance3D = slot.mesh
		if slot.surface < 0: mesh.material_override = slot.applied
		else: mesh.set_surface_override_material(slot.surface, slot.applied)
		_slots.append(slot)
		if slot.team: _team.append(slot)
		report.matched.append(slot.coverage)
	report.installed = not pending.is_empty()
	if report.installed: report.fallback = ""
	return report

func set_team_color(color: Color) -> void:
	for slot: Dictionary in _team:
		(slot.applied as StandardMaterial3D).albedo_color = color

func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		report.errors.append("missing:" + path)
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if value is Dictionary: return value
	report.errors.append("invalid_json:" + path)
	return {}

func _validate(profile: Dictionary, manifest: Dictionary, id: String) -> bool:
	if profile.get("version") != 1 or profile.get("operator_id") != id or manifest.get("version") != 1:
		report.errors.append("profile_manifest_identity_or_version")
		return false
	if not profile.get("bindings") is Array or not profile.get("preserve_materials") is Array or not profile.get("overlay_finishes") is Dictionary or not manifest.get("finishes") is Dictionary:
		report.errors.append("invalid_profile_shape")
		return false
	var names: Dictionary = {}
	for item: Variant in profile.preserve_materials:
		if not item is Dictionary or not item.get("source_material") is String or not item.get("reason") is String:
			report.errors.append("invalid_preserve_rule")
			return false
		if names.has(item.source_material):
			report.errors.append("duplicate_material_rule")
			return false
		names[item.source_material] = true
	for item: Variant in profile.bindings:
		if not item is Dictionary or not item.get("source_material") is String or not item.get("role") is String or not item.get("finish") is String:
			report.errors.append("invalid_binding")
			return false
		if names.has(item.source_material):
			report.errors.append("conflicting_material_rule")
			return false
		names[item.source_material] = true
		if not _finish_valid(manifest.finishes.get(item.finish)): return false
	for style: Variant in profile.overlay_finishes:
		if style not in ["panel", "board", "vent"] or not profile.overlay_finishes[style] is String:
			report.errors.append("invalid_overlay_rule")
			return false
		if not _finish_valid(manifest.finishes.get(profile.overlay_finishes[style])): return false
	return report.errors.is_empty()

func _finish_valid(value: Variant) -> bool:
	if not value is Dictionary:
		report.errors.append("missing_finish")
		return false
	if value.get("albedo_mode") != "modulate":
		report.errors.append("unsupported_albedo_mode")
		return false
	for field: String in ["metallic", "roughness_gain", "normal_strength"]:
		var number: Variant = value.get(field)
		if not (number is float or number is int):
			report.errors.append("invalid_scalar:" + field)
			return false
		if not is_finite(float(number)) or float(number) < 0.0 or float(number) > 1.0:
			report.errors.append("scalar_out_of_range:" + field)
			return false
	for field: String in ["albedo", "normal", "roughness"]:
		if field != "albedo" and not value.has(field): continue
		var path: Variant = value.get(field)
		if not path is String or not path.begins_with(ROOT + "assets/") or ".." in path:
			report.errors.append("invalid_texture_path:" + field)
			return false
		if not _textures.has(path):
			if _textures.size() >= MAX_TEXTURES or not ResourceLoader.exists(path):
				report.errors.append("missing_texture_or_cache_bound:" + path)
				return false
			var texture := load(path) as Texture2D
			if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
				report.errors.append("invalid_texture:" + path)
				return false
			_textures[path] = texture
			report.textures[path] = {"width":texture.get_width(), "height":texture.get_height()}
	return true

func _collect(node: Node, bindings: Dictionary, preserved: Dictionary, overlays: Dictionary, finishes: Dictionary, pending: Array[Dictionary], seen: Dictionary, id: String) -> void:
	var label := str(node.name).to_lower()
	if label.begins_with("teambar") or label == "weapon" or label == "gunanchor" or label == "worldweapon":
		report.excluded.append({"node":str(node.get_path()), "reason":"team_marker_or_weapon"})
		return
	if node is MeshInstance3D and node.mesh != null:
		var mesh := node as MeshInstance3D
		var overlay := mesh.has_meta("detail_style")
		for surface: int in range(mesh.mesh.get_surface_count()):
			var base: Material = mesh.get_active_material(surface)
			if overlay: base = mesh.get_meta("undetailed_material") as Material
			var name := base.resource_name if base != null else ""
			var coverage := {"node":str(mesh.get_path()), "surface":surface, "source_material":name}
			if preserved.has(name) and not overlay:
				coverage.reason = preserved[name]
				report.excluded.append(coverage)
				continue
			var finish_id := ""
			if overlay: finish_id = str(overlays.get(str(mesh.get_meta("detail_style")), ""))
			elif bindings.has(name):
				finish_id = bindings[name].finish
				seen[name] = true
			if finish_id.is_empty():
				coverage.reason = "no_finish_rule"
				report.unmatched.append(coverage)
				continue
			if not base is StandardMaterial3D:
				report.errors.append("unsupported_material:" + str(coverage))
				continue
			var standard := base as StandardMaterial3D
			if standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or standard.emission_enabled or standard.albedo_texture != null or standard.normal_enabled or standard.roughness_texture != null or standard.next_pass != null:
				report.errors.append("protected_or_pretextured_material:" + str(coverage))
				continue
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
			var tangents: Variant = arrays[Mesh.ARRAY_TANGENT]
			var finish: Dictionary = finishes[finish_id]
			if not uv is PackedVector2Array or uv.size() != vertices.size() or (finish.has("normal") and (not tangents is PackedFloat32Array or tangents.size() != vertices.size()*4)):
				report.errors.append("missing_uv_or_normal_tangent:" + str(coverage))
				continue
			var material := _material_for(standard, finish)
			var team := bool(mesh.get_meta("team_detail", false)) if overlay else (Catalog.OPERATORS.has(id) and name == str(Catalog.OPERATORS[id].teamArmorMaterial))
			coverage.finish = finish_id
			coverage.team_tint = team
			coverage.traits = {"alpha":standard.albedo_color.a, "cull":standard.cull_mode, "vertex_color":standard.vertex_color_use_as_albedo, "uv_scale":str(standard.uv1_scale), "uv_offset":str(standard.uv1_offset), "render_priority":standard.render_priority, "metallic":material.metallic, "roughness":material.roughness, "normal":material.normal_enabled}
			pending.append({"mesh":mesh, "surface":-1 if overlay else surface, "original":mesh.material_override if overlay else mesh.get_surface_override_material(surface), "applied":material, "team":team, "coverage":coverage})
	for child: Node in node.get_children(): _collect(child, bindings, preserved, overlays, finishes, pending, seen, id)

func _material_for(base: StandardMaterial3D, finish: Dictionary) -> StandardMaterial3D:
	var material := base.duplicate() as StandardMaterial3D
	material.albedo_texture = _textures[finish.albedo]
	# Texture RGB modulates the untouched source/team color once. All render state
	# (including UV transform, alpha, vertex color, emission and culling) survives.
	material.metallic = float(finish.metallic)
	material.roughness = base.roughness * float(finish.roughness_gain)
	if finish.has("roughness"):
		material.roughness_texture = _textures[finish.roughness]
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	if finish.has("normal"):
		material.normal_enabled = true
		material.normal_texture = _textures[finish.normal]
		material.normal_scale = float(finish.normal_strength)
	return material
