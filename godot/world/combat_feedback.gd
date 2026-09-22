class_name PortCombatFeedback
extends Node3D

# Diagnostic feedback only. Damage/shot confirmation comes from server events.
const MAX_TRACERS: int = 128
const TRACER_SECONDS: float = 0.12
var tracers: Array[Dictionary] = []
var shots: int = 0
var hits: int = 0
var hurts: int = 0
var hit_remaining: float = 0.0
var hurt_remaining: float = 0.0
const Overlay = preload("res://world/combat_overlay.gd")
var overlay: Control

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	overlay = Overlay.new()
	overlay.visible = false
	layer.add_child(overlay)

func point(value: Variant) -> Variant:
	if not value is Dictionary: return null
	for key: String in ["x", "y", "z"]:
		if not (value.get(key) is float or value.get(key) is int): return null
		if not is_finite(float(value[key])): return null
	return Vector3(value.x, value.y, value.z)

func apply_events(items: Array, local_id: int) -> void:
	for item: Dictionary in items:
		match item.get("type", ""):
			"shot":
				var from: Variant = point(item.get("from"))
				var to: Variant = point(item.get("to"))
				if from == null or to == null: continue
				shots += 1
				if tracers.size() >= MAX_TRACERS: remove_tracer(0)
				var mesh := ImmediateMesh.new()
				var material := StandardMaterial3D.new()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.albedo_color = Color(1.0, 0.85, 0.25)
				mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
				mesh.surface_add_vertex(from)
				mesh.surface_add_vertex(to)
				mesh.surface_end()
				var node := MeshInstance3D.new()
				node.mesh = mesh
				add_child(node)
				tracers.append({"node":node,"remaining":TRACER_SECONDS})
			"damage":
				if float(item.get("amount", 0)) <= 0: continue
				var victim: int = int(item.get("actor", -1))
				# JSON null is environmental damage, never actor zero.
				var source: Variant = item.get("source")
				if local_id >= 0 and victim == local_id:
					hurts += 1
					hurt_remaining = 0.35
				if local_id >= 0 and source != null and int(source) == local_id and victim != local_id:
					hits += 1
					hit_remaining = 0.2

func remove_tracer(index: int) -> void:
	var node: Node = tracers[index].node
	remove_child(node)
	node.free()
	tracers.remove_at(index)

func advance(delta: float) -> void:
	hit_remaining = maxf(0.0, hit_remaining - maxf(delta, 0.0))
	hurt_remaining = maxf(0.0, hurt_remaining - maxf(delta, 0.0))
	for index: int in range(tracers.size() - 1, -1, -1):
		tracers[index].remaining -= maxf(delta, 0.0)
		if tracers[index].remaining <= 0: remove_tracer(index)

func _process(delta: float) -> void:
	advance(delta)
	if is_instance_valid(overlay):
		var session := get_parent()
		var aiming: bool = session != null and session.has_method("can_capture_pointer") and session.can_capture_pointer() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		overlay.update_feedback(aiming, hit_remaining, hurt_remaining)

func text() -> String:
	return ("HIT CONFIRMED " if hit_remaining > 0 else "") + ("TAKING DAMAGE" if hurt_remaining > 0 else "")

func clear_round() -> void:
	while not tracers.is_empty(): remove_tracer(0)
	shots = 0
	hits = 0
	hurts = 0
	hit_remaining = 0.0
	hurt_remaining = 0.0
	if is_instance_valid(overlay): overlay.update_feedback(false, 0.0, 0.0)
