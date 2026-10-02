extends "res://horde_maps/cinderwake.gd"
## Collisions come from the exact source recipe; visible station props never
## determine gameplay. Blender GLB adds structure to the authored shared mesh.
const ID := "blackwater-reclamation"
const PATH := "res://horde_maps/generated/blackwater-reclamation.json"
const ART := "res://horde_maps/art/blackwater-reclamation.glb"
var station_signs: Dictionary = {}
var station_zones: Dictionary = {}
const MissionGuidance = preload("res://horde/mission_guidance.gd")

func height_at(x: float, z: float) -> float:
	for center: float in [-170.0, -82.0, 0.0, 82.0, 170.0]:
		if absf(x - center) <= 4.0:
			if z >= -36.0 and z < -16.0: return (z + 36.0) * 0.25
			if z > -8.0 and z <= 12.0: return (12.0 - z) * 0.25
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
	for row: Array in [["north-feeder", -170, 78, "NORTH FEEDER"], ["south-feeder", -82, -78, "SOUTH FEEDER"], ["switch-pump", 0, 78, "SWITCH PUMP"], ["relief-valve", 170, -82, "RELIEF VALVE"]]:
		var sign := _sign(str(row[3]), Vector3(float(row[1]), 3.5, float(row[2])), Color("9bd7de"))
		sign.name = "Station_" + str(row[0])
		sign.visible = false # Only received director state can activate a station.
		station_signs[str(row[0])] = sign
		var zone := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 6.35
		ring.outer_radius = 6.5
		ring.rings = 32
		ring.ring_segments = 8
		zone.mesh = ring
		zone.position = Vector3(float(row[1]), 0.12, float(row[2]))
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		zone.material_override = material
		zone.visible = false
		add_child(zone)
		station_zones[str(row[0])] = zone
	if not gray and ResourceLoader.exists(ART):
		var authored: PackedScene = load(ART)
		var art: Node = authored.instantiate()
		art.name = "BlenderStructures"
		add_child(art)
	built = true
	return true

func apply_station_state(mission: Dictionary) -> void:
	var completed: Array = mission.get("completed", [])
	var active: String = str(mission.get("active", ""))
	for value: Variant in mission.get("stations", []):
		if not value is Dictionary: continue
		var id: String = str(value.get("id", ""))
		if not station_signs.has(id): continue
		var sign: Label3D = station_signs[id]
		var done := id in completed
		var available := bool(value.get("available", false))
		sign.visible = true
		var title: String = str(MissionGuidance.NAMES.get(id, id))
		if done:
			sign.text = title + "\nRESTORED · SYSTEM ONLINE"
			sign.modulate = Color("78ddaa")
		elif id == active:
			sign.text = "%s\nDEFEND · %.1f / %.1fs" % [title, float(value.get("progress", 0.0)), float(value.get("required", 1.0))]
			sign.modulate = Color("ffd381")
		elif available:
			sign.text = title + "\nAVAILABLE · [E] WITHIN 5m"
			sign.modulate = Color("9bd7de")
		else:
			sign.text = title + "\nLOCKED · " + MissionGuidance.lock_reason(id, completed, int(mission.get("wave", 0)))
			sign.modulate = Color("a4acb4")
		var zone: MeshInstance3D = station_zones.get(id)
		if zone != null:
			zone.visible = available and not done
			var material: StandardMaterial3D = zone.material_override
			material.albedo_color = sign.modulate

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
