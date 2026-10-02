extends RefCounted
## Visual-only source weather response. Bind only the static map subtree.
## Each shared material is duplicated once per binding; source assets stay dry.
const Profile = preload("res://ambience/weather_profile.gd")
const MATERIAL_CAP := 256
const NODE_CAP := 16384
const BINDING_CAP := 16384
const SHADERS := ["res://moth/surface.gdshader", "res://material_language/family.gdshader"]
const CAMPAIGN_GROUND := "res://campaign/materials/ground.gdshader"
var _environment: WorldEnvironment
var _sun: DirectionalLight3D
var _original: Environment
var _owned: Environment
var _base := {}
var _materials: Dictionary = {}
var _shader_defaults: Dictionary = {}
var _bindings: Array[Dictionary] = []
var wetness := 0.0
var visited := 0
var capped := false
var writes := 0
var _applied := -1.0
var _kind := ""

func bind(world: Node3D, environment: WorldEnvironment, sun: DirectionalLight3D) -> void:
	clear()
	if not is_instance_valid(world) or not is_instance_valid(environment) or environment.environment == null: return
	_environment = environment
	_sun = sun
	_original = environment.environment
	_owned = _original.duplicate() as Environment
	_environment.environment = _owned
	_base = {"fog": _original.fog_light_color, "density": _original.fog_density,
		"exposure": _original.tonemap_exposure, "fill": _original.ambient_light_energy,
		"fill_color": _original.ambient_light_color}
	if is_instance_valid(sun):
		_base["key"] = sun.light_energy
		_base["key_color"] = sun.light_color
	var pending: Array[Node] = [world]
	while not pending.is_empty() and visited < NODE_CAP:
		var node: Node = pending.pop_back()
		visited += 1
		if node is GeometryInstance3D:
			var geometry := node as GeometryInstance3D
			if geometry.material_override != null:
				_bind_material(geometry, -1, geometry.material_override)
			elif node is MeshInstance3D and node.mesh != null:
				var count := mini(node.mesh.get_surface_count(), BINDING_CAP - _bindings.size())
				capped = capped or count < node.mesh.get_surface_count()
				for index in count:
					_bind_material(geometry, index, node.get_active_material(index))
			elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
				# MultiMesh uses one override; preserve multi-surface meshes verbatim.
				if node.multimesh.mesh.get_surface_count() == 1:
					_bind_material(geometry, -1, node.multimesh.mesh.surface_get_material(0))
		for child: Node in node.get_children():
			if pending.size() + visited >= NODE_CAP:
				capped = true
				break
			pending.append(child)
	capped = capped or not pending.is_empty()

func _bind_material(node: GeometryInstance3D, surface: int, original: Material) -> void:
	if original == null: return
	if _bindings.size() >= BINDING_CAP:
		capped = true
		return
	var roughness := 0.0
	var metallic := 0.0
	var ground := false
	if original is StandardMaterial3D:
		if original.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: return
		roughness = original.roughness
		metallic = original.metallic
	elif original is ShaderMaterial and original.shader != null and original.shader.resource_path == CAMPAIGN_GROUND:
		ground = true
	elif original is ShaderMaterial and original.shader != null and original.shader.resource_path in SHADERS:
		var r: Variant = original.get_shader_parameter("roughness")
		var m: Variant = original.get_shader_parameter("metallic")
		# An unset override is not an absent uniform. Terrain commonly relies on
		# shader-declared defaults; headless's dummy renderer cannot report them.
		if r == null: r = _scalar_default(original.shader, "roughness")
		if m == null: m = _scalar_default(original.shader, "metallic")
		if not (r is float or r is int) or not (m is float or m is int): return
		roughness = float(r)
		metallic = float(m)
	else: return
	if not _materials.has(original):
		if _materials.size() >= MATERIAL_CAP:
			capped = true
			return
		_materials[original] = {"material": original.duplicate(), "roughness": roughness, "metallic": metallic, "ground": ground}
	var copy: Material = _materials[original].material
	var prior: Material = node.material_override if surface < 0 else (node as MeshInstance3D).get_surface_override_material(surface)
	_bindings.append({"node": weakref(node), "surface": surface, "prior": prior, "copy": copy})
	if surface < 0: node.material_override = copy
	else: (node as MeshInstance3D).set_surface_override_material(surface, copy)

func _scalar_default(shader: Shader, uniform_name: String) -> Variant:
	var key := shader.resource_path + "/" + uniform_name
	if not _shader_defaults.has(key):
		# Only the two allowlisted shaders and their literal scalar defaults enter
		# here. No expression evaluation, arbitrary shader support or file reads.
		var expression := RegEx.create_from_string("uniform\\s+float\\s+" + uniform_name + "\\s*(?::[^=;]+)?=\\s*([0-9]+(?:\\.[0-9]+)?)\\s*;")
		var found := expression.search(shader.code)
		_shader_defaults[key] = float(found.get_string(1)) if found != null else null
	return _shader_defaults[key]

func apply(kind: String, delta: float, immediate: bool = false) -> void:
	if _owned == null or not is_instance_valid(_environment) or _environment.environment != _owned: return
	var p: Array = Profile.LOOKS.get(kind, Profile.LOOKS.clear)
	wetness = float(p[3]) if immediate else Profile.wet_step(wetness, float(p[3]), delta)
	# Source applies in wetness bands, with an exact dry restore at disable/reset.
	if not immediate and kind == _kind and absf(wetness - _applied) < 0.002: return
	_kind = kind
	_applied = wetness
	var dark := float(p[4])
	var tint := Color(p[2])
	_owned.fog_density = float(_base.density) * float(p[0])
	_owned.fog_light_color = _linear_mix(_base.fog, tint, wetness * 0.5 + dark * 0.5)
	_owned.tonemap_exposure = float(_base.exposure) * (1.0 + (float(p[1]) - 1.0) * 0.85)
	_owned.ambient_light_energy = float(_base.fill) * (1.0 - dark * 0.22)
	_owned.ambient_light_color = _linear_mix(_base.fill_color, Color.BLACK, wetness * 0.2 + dark * 0.3)
	if is_instance_valid(_sun):
		_sun.light_energy = float(_base.key) * (1.0 - dark * 0.5)
		_sun.light_color = _linear_mix(_base.key_color, Color.BLACK, wetness * 0.3 + dark * 0.55)
	var look := Profile.wet_sheen(wetness)
	for entry: Dictionary in _materials.values():
		if entry.ground:
			entry.material.set_shader_parameter("weather_wetness", wetness)
			writes += 1
			continue
		var roughness := clampf(float(entry.roughness) * float(look.roughness), 0.0, 1.0)
		var metallic := clampf(float(entry.metallic) + float(look.metalness), 0.0, 1.0)
		if entry.material is StandardMaterial3D:
			entry.material.roughness = roughness
			entry.material.metallic = metallic
		else:
			entry.material.set_shader_parameter("roughness", roughness)
			entry.material.set_shader_parameter("metallic", metallic)
		writes += 2

static func _linear_mix(a: Color, b: Color, weight: float) -> Color:
	if weight <= 0.0: return a
	return a.srgb_to_linear().lerp(b.srgb_to_linear(), weight).linear_to_srgb()

func clear() -> void:
	for binding: Dictionary in _bindings:
		var node: GeometryInstance3D = binding.node.get_ref()
		if not is_instance_valid(node): continue
		if binding.surface < 0:
			if node.material_override == binding.copy: node.material_override = binding.prior
		elif (node as MeshInstance3D).get_surface_override_material(binding.surface) == binding.copy:
			(node as MeshInstance3D).set_surface_override_material(binding.surface, binding.prior)
	if is_instance_valid(_environment) and _environment.environment == _owned:
		_environment.environment = _original
		if is_instance_valid(_sun) and _base.has("key"):
			_sun.light_energy = _base.key
			_sun.light_color = _base.key_color
	_bindings.clear()
	_materials.clear()
	_shader_defaults.clear()
	_base.clear()
	_owned = null
	_original = null
	wetness = 0.0
	_applied = -1.0
	_kind = ""
	visited = 0
	capped = false
	writes = 0

func diagnostics() -> Dictionary:
	return {"wetness": wetness, "materials": _materials.size(), "material_cap": MATERIAL_CAP,
		"bindings": _bindings.size(), "binding_cap": BINDING_CAP,
		"visited": visited, "node_cap": NODE_CAP, "capped": capped, "uniform_writes": writes,
		"additional_geometry_nodes": 0, "additional_colliders": 0}
