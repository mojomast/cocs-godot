extends Node3D
## One reusable expected-gate marker. Accepted snapshots select it; never scores.
## game/race.mjs crossRaceGates: swept centre, forward normal, y in [-.25, 3].
const MIN_Y := -0.25
const MAX_Y := 3.0
var gate_index := -1
var bars: Array[MeshInstance3D] = []
var caption := Label3D.new()

func _init() -> void:
	add_child(caption)

func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.25, 1, 0.85)
	for i in range(7):
		var bar := MeshInstance3D.new()
		bar.mesh = BoxMesh.new()
		bar.material_override = material
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bar)
		bars.append(bar)
	caption.position.y = 4.1
	caption.font_size = 48
	caption.pixel_size = 0.018
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.modulate = Color(0.65, 1, 0.9)
	reset()

func reset() -> void:
	hide()
	gate_index = -1
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	caption.text = ""

static func expected(race: Dictionary, actor_id: int) -> Dictionary:
	var gates: Variant = race.get("gates")
	if not gates is Array or gates.is_empty(): return {}
	for row: Dictionary in race.get("standings", []):
		if row.get("actorId", -2) != actor_id or row.get("finishTime") != null: continue
		var index: Variant = row.get("nextGate")
		if not (index is float or index is int) or not is_finite(float(index)) or float(index) != floorf(float(index)) or index < 0 or index >= gates.size(): return {}
		var gate: Variant = gates[int(index)]
		if not gate is Dictionary: return {}
		for field in ["x", "z", "nx", "nz", "halfWidth"]:
			var n: Variant = gate.get(field)
			if not (n is float or n is int) or not is_finite(float(n)): return {}
		if float(gate.halfWidth) <= 0 or absf(Vector2(gate.nx, gate.nz).length() - 1) > 0.01: return {}
		return {"index":int(index), "count":gates.size(), "gate":gate}
	return {}

func bar(index: int, centre: Vector3, dimensions: Vector3, yaw: float = 0) -> void:
	bars[index].position = centre
	bars[index].scale = dimensions
	bars[index].rotation.y = yaw

func apply(race: Dictionary, actor_id: int, active: bool) -> void:
	var target := expected(race, actor_id) if active else {}
	if target.is_empty():
		reset()
		return
	var gate: Dictionary = target.gate
	gate_index = target.index
	position = Vector3(gate.x, 0, gate.z)
	rotation.y = atan2(float(gate.nx), float(gate.nz))
	var half: float = gate.halfWidth
	bar(0, Vector3(-half, (MAX_Y+MIN_Y)/2, 0), Vector3(0.16, MAX_Y-MIN_Y, 0.16))
	bar(1, Vector3(half, (MAX_Y+MIN_Y)/2, 0), Vector3(0.16, MAX_Y-MIN_Y, 0.16))
	bar(2, Vector3(0, MAX_Y, 0), Vector3(half*2, 0.12, 0.12))
	bar(3, Vector3(0, 0.06, 0), Vector3(half*2, 0.08, 0.22))
	# A ground arrow points through the gate along the source forward normal.
	bar(4, Vector3(0, 0.08, -2), Vector3(0.25, 0.1, 4))
	bar(5, Vector3(-0.7, 0.08, -0.7), Vector3(0.25, 0.1, 2), PI/4)
	bar(6, Vector3(0.7, 0.08, -0.7), Vector3(0.25, 0.1, 2), -PI/4)
	caption.text = "NEXT %d / %d" % [gate_index+1, target.count]
	show()

static func describe(race: Dictionary, actor_id: int, vehicle: Dictionary) -> String:
	var target := expected(race, actor_id)
	if target.is_empty() or vehicle.is_empty(): return ""
	var gate: Dictionary = target.gate
	var offset := Vector2(float(gate.x)-float(vehicle.x), float(gate.z)-float(vehicle.z))
	var yaw := float(vehicle.yaw)
	# Chase looks along (sin(yaw), 0, cos(yaw)); screen-right is (-cos, 0, sin).
	var bearing := atan2(offset.dot(Vector2(-cos(yaw), sin(yaw))), offset.dot(Vector2(sin(yaw), cos(yaw))))
	var direction := "Ahead" if absf(bearing) < 0.22 else ("Right" if bearing > 0 else "Left")
	if absf(bearing) > 2.4: direction = "Behind"
	return "Next gate %d · %s · %.0f m · Follow the mint arrow through" % [target.index+1, direction, offset.length()]
