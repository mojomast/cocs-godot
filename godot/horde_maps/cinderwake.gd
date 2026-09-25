extends "res://identity_maps/map.gd"
## Reuses only the generic geometry batching primitives, never an identity recipe.
## Gates are standalone bodies driven exclusively by received source snapshots.
const RECIPE_PATH := "res://horde_maps/generated/cinderwake-drydock.json"
var gate_bodies: Array[StaticBody3D] = []
var stage_signs: Dictionary = {}
var received_revision := -1
var received_round := ""

func _make_materials() -> void:
	var roles := {"floor": "floor-built", "shell": "riveted", "cut": "grating", "enamel": "wall-panel", "accent": "pipe", "trim": "rail"}
	var colors := {"floor": "b7b6ad", "shell": "6c7377", "cut": "545e65", "enamel": "182c38", "accent": "ed7437", "trim": "242d35"}
	for key: String in roles:
		materials[key] = EnvironmentStyle.role_material(roles[key], Color(colors[key]), {"tiles_per_metre": 0.55}, "cinderwake-drydock")

func build(id: String = "cinderwake-drydock", gray: bool = false) -> bool:
	if built: return get_arena_id() == id
	if id != "cinderwake-drydock": return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECIPE_PATH))
	if not parsed is Dictionary or parsed.get("id") != id: return false
	recipe = parsed
	graybox = gray
	_make_materials()
	for block: Dictionary in recipe.arena.blocks:
		_solid(block, false)
	for surface: Dictionary in recipe.arena.terrain.surfaces:
		_surface(surface, "floor", true)
	_flush()
	for gate: Dictionary in recipe.arena.hordeStagePlan.gates:
		gate_bodies.append(_solid(gate, true))
	for row: Array in [["B", Vector3(0, 5.5, 48)], ["C", Vector3(0, 6.5, 13)], ["D", Vector3(0, 7.5, -34)]]:
		var sign := _sign(str(recipe.presentation.stages[row[0]]), row[1], Color.WHITE)
		stage_signs[row[0]] = sign
	for z: float in [56.0, 46.0, 6.0, -36.0]:
		_sign("E · LIFEBOAT PASSAGE\n↕ ALWAYS OPEN", Vector3(-37, 3.5, z), Color("71d8ef"))
	if not graybox: _ship_silhouette()
	built = true
	return true

func _solid(block: Dictionary, gate: bool) -> StaticBody3D:
	var size := Vector3(block.w, block.h - block.baseY, block.d)
	var center := Vector3(block.x, (block.h + block.baseY) * 0.5, block.z)
	var mesh := BoxMesh.new()
	mesh.size = size
	var body := StaticBody3D.new()
	body.name = str(block.id)
	body.position = center
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	if gate:
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = materials.accent
		body.add_child(visual)
		_sign("BULKHEAD " + ("02" if block.id == "G_BC" else "03"), center + Vector3(0, 3.3, 0), Color.WHITE)
	else:
		_append_arrays(mesh.get_mesh_arrays(), center, str(block.material))
	add_child(body)
	return body

func _sign(text: String, at: Vector3, color: Color) -> Label3D:
	var sign := Label3D.new()
	sign.text = text
	sign.position = at
	sign.font_size = 64
	sign.pixel_size = 0.009
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = color
	add_child(sign)
	return sign

func _decoration(size: Vector3, at: Vector3, angle: float = 0.0) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	instance.rotation.z = angle
	instance.material_override = materials.accent
	add_child(instance)

func _ship_silhouette() -> void:
	# Suspended keel and ribs are render-only, well above the playable deck.
	_decoration(Vector3(6, 3, 54), Vector3(0, 19, -11))
	for z: float in [-30.0, -20.0, -10.0, 0.0, 10.0]:
		for side: float in [-1.0, 1.0]:
			_decoration(Vector3(2, 11, 1.5), Vector3(side * 9, 16, z), side * 0.55)
	for angle: float in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		_decoration(Vector3(3, 12, 1.0), Vector3(sin(angle) * 5, 16 + cos(angle) * 5, -48), -angle)

func apply_source_stage(stage: Dictionary, round_id: String) -> void:
	if stage.is_empty(): return
	var revision := int(stage.get("geometryRevision", -1))
	if round_id != received_round:
		received_round = round_id
		received_revision = -1
	if revision < received_revision: return
	received_revision = revision
	var mask := int(stage.get("gateMask", 0))
	for i: int in gate_bodies.size():
		var opened := (mask & (1 << i)) != 0
		var body := gate_bodies[i]
		body.visible = not opened
		body.collision_layer = 0 if opened else 1
		body.collision_mask = 0 if opened else 1
	var transit: Variant = stage.get("transit")
	for id: String in stage_signs:
		var sign: Label3D = stage_signs[id]
		var destination := transit is Dictionary and str(transit.get("to", "")) == id
		sign.modulate = Color("ffd166") if destination else Color("71d8ef") if id == str(stage.get("stageId", "")) else Color.WHITE
		sign.text = str(recipe.presentation.stages[id]) + ("\nMOVE HERE · HOLD 0.5s" if destination else "")
