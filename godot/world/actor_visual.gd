extends Node3D

# Original primitive geometry, centered on the presentation anchor (feet = -0.9).
# Forward is -Z, matching authority yaw. No collision or gameplay state here.
const CHARACTER_COLORS := {
	"chatgpt": "57e6cd", "claude": "f29d71", "grok": "b5c5d4",
	"meta": "57b9ff", "gemini": "6fa8ff", "deepseek": "56c5f2",
	"mistral": "ffbd59", "kimi": "ff82b2", "qwen": "b797ff",
}
var armor := _material(Color("57e6cd"))
var identity := _material(Color("57e6cd"), true)
var team_marks: Array[MeshInstance3D] = []
var identity_key: String = ""

func _init() -> void:
	var dark := _material(Color("202e40"))
	var trim := _material(Color("c3d2dc"))
	# Separated boots/legs and shoulder plates read as a person at arena distance.
	for side: float in [-1.0, 1.0]:
		_box("Boot", Vector3(side * 0.16, -0.8, -0.045), Vector3(0.24, 0.2, 0.38), dark)
		_box("Leg", Vector3(side * 0.16, -0.45, 0), Vector3(0.2, 0.5, 0.24), dark)
		_box("Knee", Vector3(side * 0.16, -0.43, -0.14), Vector3(0.19, 0.2, 0.065), armor)
		_box("Shoulder", Vector3(side * 0.275, 0.3, 0), Vector3(0.15, 0.23, 0.32), armor)
		_box("Arm", Vector3(side * 0.28, 0.065, -0.065), Vector3(0.13, 0.27, 0.22), dark)
	_box("Hip", Vector3(0, -0.16, 0), Vector3(0.43, 0.19, 0.28), dark)
	_box("Torso", Vector3(0, 0.15, 0), Vector3(0.44, 0.48, 0.3), armor)
	_box("ChestInset", Vector3(0, 0.21, -0.161), Vector3(0.28, 0.24, 0.035), dark)
	_box("CharacterBadge", Vector3(0, 0.25, -0.187), Vector3(0.18, 0.045, 0.025), identity)
	_box("Backpack", Vector3(0, 0.2, 0.2), Vector3(0.28, 0.3, 0.16), dark)
	_box("Neck", Vector3(0, 0.46, 0), Vector3(0.15, 0.12, 0.17), trim)
	_box("Helmet", Vector3(0, 0.69, 0), Vector3(0.36, 0.42, 0.34), dark)
	_box("Crown", Vector3(0, 0.855, 0), Vector3(0.37, 0.09, 0.35), armor)
	_box("Visor", Vector3(0, 0.73, -0.184), Vector3(0.3, 0.12, 0.04), identity)
	_box("Jaw", Vector3(0, 0.565, -0.155), Vector3(0.24, 0.11, 0.09), trim)
	# A small generic carbine, deliberately independent of the reserved weapon art.
	_box("WeaponGrip", Vector3(0.23, -0.035, -0.24), Vector3(0.095, 0.18, 0.11), dark)
	_box("Weapon", Vector3(0.23, 0.095, -0.3), Vector3(0.15, 0.15, 0.43), dark)
	_box("Muzzle", Vector3(0.23, 0.1, -0.555), Vector3(0.09, 0.09, 0.12), trim)
	_box("WeaponSight", Vector3(0.23, 0.195, -0.31), Vector3(0.05, 0.05, 0.09), identity)
	# One stripe = red; two = blue. Team remains readable without color alone.
	for i: int in range(2):
		team_marks.append(_box("TeamStripe%d" % i, Vector3(-0.07 + i * 0.14, 0.07, -0.185), Vector3(0.07, 0.1, 0.025), trim))

func apply_identity(actor: Dictionary) -> void:
	var character: String = str(actor.get("character", "unknown"))
	var team: String = str(actor.get("team", ""))
	# Godot's JSON decoder represents wire numbers as floats.
	if team == "0.0": team = "0"
	elif team == "1.0": team = "1"
	var key: String = character + ":" + team
	if key == identity_key: return
	identity_key = key
	var character_color := Color(CHARACTER_COLORS.get(character, "d4dfeb"))
	var red: bool = team in ["0", "red"]
	var blue: bool = team in ["1", "blue"]
	armor.albedo_color = Color("f05c58") if red else (Color("4d9fff") if blue else character_color)
	identity.albedo_color = character_color
	identity.emission = character_color
	team_marks[0].visible = red or blue
	team_marks[1].visible = blue
	set_meta("character", character)
	set_meta("team", team)

static func _material(color: Color, luminous: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	mat.emission_enabled = luminous
	mat.emission = color
	mat.emission_energy_multiplier = 0.3
	return mat

func _box(part_name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = mat
	part.position = pos
	add_child(part)
	return part
