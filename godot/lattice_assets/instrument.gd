extends Node3D
const Recipes = preload("res://lattice_assets/recipes.gd")
const MeshBuilder = preload("res://player_models/builder.gd")
var owner_material: StandardMaterial3D
var owner_marks: Array[MeshInstance3D] = []
var contest_marks: Array[MeshInstance3D] = []
var neutral_mark: MeshInstance3D
var state_key := ""
static var materials: Dictionary = {}

static func material(map_id: String, role: String) -> StandardMaterial3D:
	var key := map_id + ":" + role
	if materials.has(key): return materials[key]
	var palette: Dictionary = Recipes.PALETTES[map_id]
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(palette.get(role, Recipes.STATE_COLORS.get(role,"6d7882")))
	result.roughness = palette.roughness
	result.metallic = palette.metallic if role in ["armor","trim"] else 0.0
	result.emission_enabled = role in ["identity","contest"]
	result.emission = result.albedo_color
	result.emission_energy_multiplier = 0.12
	materials[key] = result
	return result

func build(kind: String, map_id: String) -> void:
	owner_material = material(map_id,"unknown").duplicate()
	for spec: Dictionary in Recipes.parts(kind):
		var mesh := MeshInstance3D.new()
		mesh.name = spec.name
		mesh.mesh = MeshBuilder.mesh_for(spec)
		mesh.position = MeshBuilder.vector(spec.position)
		mesh.rotation.y = spec.yaw
		mesh.material_override = owner_material if spec.material == "owner" else material(map_id,spec.material)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visibility_range_end = 115.0
		add_child(mesh)
		if spec.material == "owner": owner_marks.append(mesh)
		if spec.material == "contest": contest_marks.append(mesh)
		if spec.material == "neutral": neutral_mark = mesh
	apply_recipient({})

static func recipient_state(node: Dictionary) -> String:
	# Explicit null means neutral; a missing/invalid field means unknown.
	if not node.has("owner"): return "unknown"
	if node.owner == null: return "neutral"
	if (node.owner is int or node.owner is float) and node.owner == 0: return "red"
	if (node.owner is int or node.owner is float) and node.owner == 1: return "blue"
	return "unknown"

func apply_recipient(node: Dictionary) -> void:
	var state := recipient_state(node)
	var contest: bool = node.get("contested") is bool and node.get("contested") == true
	var key := state + str(contest)
	if key == state_key: return
	state_key = key
	owner_material.albedo_color = Color(Recipes.STATE_COLORS[state])
	for i: int in range(owner_marks.size()):
		owner_marks[i].visible = state in ["red","blue"] and (i == 0 or state == "blue")
	if is_instance_valid(neutral_mark): neutral_mark.visible = state == "neutral"
	for mesh: MeshInstance3D in contest_marks: mesh.visible = contest
	set_meta("recipient_owner",state)
	set_meta("recipient_contested",contest)
