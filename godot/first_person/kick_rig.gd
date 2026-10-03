extends Node3D
## Camera-space articulated leg. All geometry/materials are allocated once.
const Catalog = preload("res://source_operators/generated/catalog.gd")
const PROFILES := {
	"chatgpt":Vector3(1.0, 1.0, 1.0), "claude":Vector3(0.96, 1.02, 0.96),
	"grok":Vector3(1.10, 0.98, 1.08), "meta":Vector3(1.04, 1.0, 1.02),
	"gemini":Vector3(0.95, 1.04, 0.98), "deepseek":Vector3(0.98, 1.02, 1.0),
	"mistral":Vector3(1.06, 0.98, 1.04), "kimi":Vector3(0.92, 1.02, 0.95),
	"qwen":Vector3(1.0, 1.03, 1.02)}
var hip: Node3D
var knee: Node3D
var ankle: Node3D
var toe: Node3D
var armor: StandardMaterial3D
var identity_key := ""

func build() -> void:
	name = "MeleeKickLeg"
	var fabric := material(Color("30424d"), 0.92)
	var rubber := material(Color("17232b"), 0.97)
	var leather := material(Color("354b56"), 0.78)
	var edge := material(Color("7e9aaa"), 0.53, 0.35)
	armor = material(Color("506168"), 0.48, 0.45)
	hip = joint(self, "Hip", Vector3.ZERO)
	# Sections use elliptical rings with softened/chamfered shoulders, not boxes.
	section(hip, "ThighFabric", Vector3(0,-0.18,0), Vector3(0.115,0.19,0.105), fabric)
	section(hip, "ThighPlate", Vector3(0,-0.16,-0.081), Vector3(0.096,0.13,0.045), armor)
	for side: int in [-1, 1]:
		section(hip, "TrouserSeam%d" % side, Vector3(side*0.108,-0.18,0), Vector3(0.006,0.155,0.014), edge)
	knee = joint(hip, "Knee", Vector3(0,-0.37,0))
	section(knee, "KneeGasket", Vector3.ZERO, Vector3(0.092,0.08,0.086), rubber)
	section(knee, "KneePad", Vector3(0,-0.012,-0.075), Vector3(0.108,0.095,0.046), armor)
	section(knee, "KneeInset", Vector3(0,-0.012,-0.113), Vector3(0.069,0.052,0.012), edge)
	section(knee, "Calf", Vector3(0,-0.18,0.015), Vector3(0.09,0.18,0.092), fabric)
	section(knee, "ShinArmor", Vector3(0,-0.19,-0.074), Vector3(0.077,0.135,0.033), armor)
	for i: int in 3:
		section(knee, "ShinVent%d" % i, Vector3(0,-0.11-i*0.055,-0.102), Vector3(0.047,0.006,0.006), rubber)
	for i: int in 2:
		section(knee, "CalfStrap%d" % i, Vector3(0,-0.09-i*0.18,0.012), Vector3(0.095,0.016,0.097), leather)
		section(knee, "StrapBuckle%d" % i, Vector3(0.093,-0.09-i*0.18,-0.01), Vector3(0.012,0.021,0.025), edge)
	ankle = joint(knee, "Ankle", Vector3(0,-0.355,0))
	section(ankle, "BootCuff", Vector3(0,-0.015,0), Vector3(0.09,0.087,0.09), leather)
	for i: int in 3:
		section(ankle, "AnkleBellows%d" % i, Vector3(0,0.012+i*0.022,-0.005), Vector3(0.092,0.007,0.092), rubber)
	section(ankle, "BootUpper", Vector3(0,-0.083,-0.067), Vector3(0.102,0.072,0.173), leather)
	section(ankle, "HeelCounter", Vector3(0,-0.09,0.071), Vector3(0.106,0.062,0.047), armor)
	section(ankle, "SoleWelt", Vector3(0,-0.145,-0.061), Vector3(0.114,0.022,0.186), edge)
	section(ankle, "Outsole", Vector3(0,-0.167,-0.061), Vector3(0.116,0.019,0.19), rubber)
	for i: int in 6:
		for side: int in [-1, 1]:
			var tread := section(ankle, "Tread%d_%d" % [i,side], Vector3(side*0.057,-0.188,0.08-i*0.056), Vector3(0.049,0.012,0.016), rubber)
			tread.rotation.y = side * 0.25
	for i: int in 4:
		section(ankle, "LaceBridge%d" % i, Vector3(0,-0.024,-0.04-i*0.033), Vector3(0.058,0.006,0.009), edge)
	toe = joint(ankle, "Toe", Vector3(0,-0.08,-0.16))
	section(toe, "ToeCap", Vector3(0,0,-0.044), Vector3(0.109,0.06,0.083), armor)
	section(toe, "ToeScuff", Vector3(0,-0.007,-0.115), Vector3(0.072,0.032,0.009), edge)
	hide()

func apply_identity(actor: Dictionary) -> void:
	var key := str(actor.get("character", "chatgpt"))
	if not PROFILES.has(key): key = "chatgpt"
	if identity_key == key: return
	identity_key = key
	hip.scale = PROFILES[key]
	var color: Array = Catalog.OPERATORS[key].materials[0].color
	armor.albedo_color = Color(float(color[0]), float(color[1]), float(color[2])).linear_to_srgb()

func apply_pose(pose: Dictionary) -> void:
	visible = pose.visible
	position = pose.root
	hip.rotation = pose.hip
	knee.rotation = pose.knee
	ankle.rotation = pose.ankle
	toe.rotation = pose.toe

static func material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic = metallic
	return result

static func joint(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var result := Node3D.new()
	result.name = label
	result.position = at
	parent.add_child(result)
	return result

static func section(parent: Node3D, label: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Rounded eight-ring elliptical shell. Smooth radial normals retain plate highlights.
	var rings := [Vector2(-1,0.60), Vector2(-0.88,0.90), Vector2(-0.65,1), Vector2(0.55,1), Vector2(0.85,0.87), Vector2(1,0.55)]
	var count := 12
	for row: int in range(rings.size()-1):
		for col: int in count:
			for corner: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var ring: Vector2 = rings[row+corner.y]
				var angle := TAU * float(col+corner.x)/count
				surface.add_vertex(Vector3(cos(angle)*size.x*ring.y, ring.x*size.y, sin(angle)*size.z*ring.y))
	for end: int in [0, rings.size()-1]:
		var ring: Vector2 = rings[end]
		for col: int in count:
			for vertex: int in [-1, col if end == 0 else col+1, col+1 if end == 0 else col]:
				var angle := TAU*float(vertex)/count
				surface.add_vertex(Vector3(0,ring.x*size.y,0) if vertex == -1 else Vector3(cos(angle)*size.x*ring.y,ring.x*size.y,sin(angle)*size.z*ring.y))
	surface.generate_normals()
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = surface.commit()
	result.material_override = mat
	result.position = at
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(result)
	return result
