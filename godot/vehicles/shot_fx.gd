extends Node3D
## Source vehicle-shot event endpoints only. Visuals never synthesize fire from heat or input.
const MAX_TRACES := 64
const ID_WINDOW := 4096
const LIFE := 0.12
var traces: Array[Dictionary] = []
var seen: Dictionary = {}
var highest := -1

func point(value: Variant) -> Variant:
	if not value is Dictionary: return null
	for axis: String in ["x", "y", "z"]:
		if not (value.get(axis) is float or value.get(axis) is int) or not is_finite(float(value[axis])): return null
	return Vector3(value.x, value.y, value.z)

func apply_events(items: Array) -> void:
	for raw: Variant in items.slice(0, 512):
		if not raw is Dictionary or raw.get("type") != "vehicle-shot": continue
		var id: Variant = raw.get("id")
		if not (id is int or id is float) or not is_finite(float(id)) or float(id) < 0 or float(id) != floorf(float(id)): continue
		var key := int(id)
		if key <= highest - ID_WINDOW or seen.has(key): continue
		# Consume the ID even when the payload is malformed; never replay it later.
		seen[key] = true
		highest = maxi(highest, key)
		var from: Variant = point(raw.get("from"))
		var to: Variant = point(raw.get("to"))
		if from == null or to == null or from.distance_squared_to(to) < 0.0001: continue
		if traces.size() >= MAX_TRACES: remove_trace(0)
		var line := ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("ffd166")
		line.surface_begin(Mesh.PRIMITIVE_LINES, mat)
		line.surface_add_vertex(from)
		line.surface_add_vertex(to)
		line.surface_end()
		var node := MeshInstance3D.new()
		node.mesh = line
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		traces.append({"node":node, "remaining":LIFE})
	for key: int in seen.keys():
		if key <= highest - ID_WINDOW: seen.erase(key)

func remove_trace(index: int) -> void:
	var node: Node = traces[index].node
	remove_child(node)
	node.queue_free()
	traces.remove_at(index)

func _process(delta: float) -> void:
	for index: int in range(traces.size() - 1, -1, -1):
		traces[index].remaining -= delta
		if traces[index].remaining <= 0: remove_trace(index)

func clear_round() -> void:
	while not traces.is_empty(): remove_trace(0)
	seen.clear()
	highest = -1
