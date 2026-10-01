extends "res://horde_maps/cinderwake.gd"
## Collisions come from the exact source recipe; visible station props never
## determine gameplay. Blender GLB adds structure to the authored shared mesh.
const ID := "blackwater-reclamation"
const PATH := "res://horde_maps/generated/blackwater-reclamation.json"
const ART := "res://horde_maps/art/blackwater-reclamation.glb"

func height_at(x: float, z: float) -> float:
	if z >= -16 and z <= -8:
		for center: float in [-170.0, -82.0, 0.0, 82.0, 170.0]:
			var offset := x - center
			if absf(offset) <= 28.0: return 5.0
			if offset >= -48.0 and offset < -28.0: return (offset + 48.0) * 0.25
			if offset > 28.0 and offset <= 48.0: return (48.0 - offset) * 0.25
	return 0.0

func _make_materials() -> void:
	var colors := {"floor":"556d75", "shell":"334e5c", "cut":"828e8a", "enamel":"244452", "accent":"b58852", "trim":"304048"}
	for key: String in colors:
		materials[key] = EnvironmentStyle.role_material("floor-built" if key == "floor" else "riveted", Color(colors[key]), {"tiles_per_metre":0.38}, ID)

func build(id: String = ID, gray: bool = false) -> bool:
	if built: return get_arena_id() == id
	if id != ID: return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary or parsed.get("id") != id: return false
	recipe = parsed
	graybox = gray
	_make_materials()
	for block: Dictionary in recipe.arena.blocks: _solid(block, false)
	for surface: Dictionary in recipe.arena.terrain.surfaces: _surface(surface, str(surface.material), true)
	_flush()
	for gate: Dictionary in recipe.arena.hordeStagePlan.gates: gate_bodies.append(_solid(gate, true))
	for row: Array in [["A", Vector3(-170, 6, 8)], ["B", Vector3(0, 7, 8)], ["C", Vector3(170, 8, 8)]]:
		stage_signs[str(row[0])] = _sign(str(recipe.presentation.stages[row[0]]), row[1], Color("e4d2af"))
	for row: Array in [[-170, 78, "NORTH FEEDER"], [-82, -78, "SOUTH FEEDER"], [0, 78, "SWITCH PUMP"], [170, -82, "RELIEF VALVE"]]:
		_sign("E · " + str(row[2]), Vector3(float(row[0]), 3.5, float(row[1])), Color("9bd7de"))
	if not gray and ResourceLoader.exists(ART):
		var authored: PackedScene = load(ART)
		var art: Node = authored.instantiate()
		art.name = "BlenderStructures"
		add_child(art)
	built = true
	return true

func apply_source_stage(stage: Dictionary, round_id: String) -> void:
	# Source geometryRevision is monotonically increasing within each epoch.
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
		gate_bodies[i].visible = not opened
		gate_bodies[i].collision_layer = 0 if opened else 1
		gate_bodies[i].collision_mask = 0 if opened else 1
	var transit: Variant = stage.get("transit")
	for stage_id: String in stage_signs:
		var sign: Label3D = stage_signs[stage_id]
		sign.modulate = Color("ffd166") if transit is Dictionary and str(transit.get("to", "")) == stage_id else Color("71d8ef") if stage_id == str(stage.get("stageId", "")) else Color.WHITE
