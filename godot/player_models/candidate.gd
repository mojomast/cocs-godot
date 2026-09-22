extends Node3D
const Builder = preload("res://player_models/builder.gd")
const CHARACTER_COLORS := {
	"chatgpt":"57e6cd", "claude":"f29d71", "grok":"b5c5d4",
	"meta":"57b9ff", "gemini":"6fa8ff", "deepseek":"56c5f2",
	"mistral":"ffbd59", "kimi":"ff82b2", "qwen":"b797ff",
}
var armor := material(Color("57e6cd"))
var identity := material(Color("57e6cd"),true)
var dark := material(Color("303c4c"))
var trim := material(Color("bdc9cd"))
var team_marks: Array[MeshInstance3D] = []
var identity_key := ""
var variant := ""

func _init() -> void:
	if not Builder.load_recipes(): return
	# Prewarm three finite approved variants; reuse resources, never generate on a snapshot.
	for id: String in ["claude","grok","meta"]:
		for part: Dictionary in Builder.recipes.variants[id]: Builder.mesh_for(part)
	for part: Dictionary in Builder.recipes.variants.claude:
		var node := MeshInstance3D.new()
		node.name = part.name
		node.material_override = {"armor":armor,"identity":identity,"dark":dark,"trim":trim}[part.material]
		add_child(node)
		if part.name.begins_with("TeamStripe"): team_marks.append(node)
	set_variant("claude")
	apply_identity({})

func set_variant(id: String) -> void:
	if id == variant: return
	variant = id
	for part: Dictionary in Builder.recipes.variants[id]:
		var node: MeshInstance3D = get_node(part.name)
		node.mesh = Builder.mesh_for(part)
		node.position = Builder.vector(part.position)
		node.rotation.y = float(part.yaw)

func apply_identity(actor: Dictionary) -> void:
	var character := str(actor.get("character","unknown"))
	var team := str(actor.get("team",""))
	if team == "0.0": team = "0"
	elif team == "1.0": team = "1"
	var key := character + ":" + team
	if key == identity_key: return
	identity_key = key
	set_variant(character if character in ["grok","meta"] else "claude")
	var color := Color(CHARACTER_COLORS.get(character,"d4dfeb"))
	var red: bool = team in ["0","red"]
	var blue: bool = team in ["1","blue"]
	armor.albedo_color = Color("f05c58") if red else (Color("4d9fff") if blue else color)
	identity.albedo_color = color
	identity.emission = color
	team_marks[0].visible = red or blue
	team_marks[1].visible = blue
	set_meta("character",character)
	set_meta("team",team)

static func material(color: Color,luminous: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.7
	result.emission_enabled = luminous
	result.emission = color
	result.emission_energy_multiplier = 0.12
	return result
