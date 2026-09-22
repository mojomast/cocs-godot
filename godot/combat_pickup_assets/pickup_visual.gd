extends Node3D
## Root pose/visibility belong exclusively to PortPickups and the public snapshot.
## Four fixed render nodes, four draws, zero particles, no labels or colliders.
const Catalog = preload("res://combat_pickup_assets/catalog.gd")
const Moth = preload("res://moth/library.gd")
const Energy = preload("res://combat_pickup_assets/energy.gdshader")
var kind := ""
var built := false
var parts: Array[MeshInstance3D] = []
var energy: ShaderMaterial
var halo: ShaderMaterial
var effect_time := 0.0

func _init() -> void:
	visibility_changed.connect(_visibility_changed)
	set_process(false)

func _material(hologram: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Energy
	material.set_shader_parameter("base_map", Moth.texture("brushed_metal"))
	material.set_shader_parameter("field_map", Moth.texture("flow-field"))
	var lut := Moth.material_lut("entanglement-arcane")
	material.set_shader_parameter("lut_r", lut.get("r"))
	material.set_shader_parameter("lut_t", lut.get("t"))
	material.set_shader_parameter("body_color", Color("618899"))
	material.set_shader_parameter("hologram", hologram)
	return material

func apply_kind(value: String) -> void:
	if built and kind == value: return
	kind = value
	if not built:
		energy = _material(false)
		halo = _material(true)
		for title in ["Housing", "EnergyCore", "IdentityIcon", "HolographicRing"]:
			var node := MeshInstance3D.new()
			node.name = title
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visibility_range_end = 45.0
			add_child(node)
			parts.append(node)
		parts[0].material_override = Catalog.solid_material(false)
		parts[1].material_override = energy
		parts[2].material_override = Catalog.solid_material(true)
		parts[3].material_override = halo
		parts[3].mesh = Catalog.ring()
		parts[3].position.y = -0.38
		built = true
	var canonical := Catalog.canonical(kind)
	var meshes := Catalog.meshes(canonical)
	for i in range(3): parts[i].mesh = meshes[i]
	for material in [energy, halo]: material.set_shader_parameter("accent", Color(Catalog.COLORS[canonical]))
	set_meta("kind", kind)
	reset_presentation()
	set_process(visible)

func reset_presentation() -> void:
	effect_time = 0.0
	if not built: return
	for i in range(3):
		parts[i].position = Vector3.ZERO
		parts[i].rotation = Vector3.ZERO
	energy.set_shader_parameter("effect_time", 0.0)
	halo.set_shader_parameter("effect_time", 0.0)

func _visibility_changed() -> void:
	reset_presentation()
	set_process(visible and built)

func _process(delta: float) -> void:
	if not visible or not built or not is_finite(delta) or delta < 0.0: return
	effect_time = fmod(effect_time + minf(delta, 0.1), 120.0)
	for i in range(3):
		parts[i].position.y = sin(effect_time * 1.8) * 0.025
		parts[i].rotation.y = sin(effect_time * 0.65) * 0.28
	energy.set_shader_parameter("effect_time", effect_time)
	halo.set_shader_parameter("effect_time", effect_time)
