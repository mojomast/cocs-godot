class_name PortCombatFeedback
extends Node3D

# Diagnostic feedback only. Damage/shot confirmation comes from server events.
const MAX_TRACERS: int = 128
const TRACER_SECONDS: float = 0.12
var tracers: Array[Dictionary] = []
var shots: int = 0
var launches: int = 0
var local_launches: int = 0
var explosions: int = 0
const Projectiles = preload("res://world/projectiles.gd")
const MothEffects = preload("res://graphics_fx/moth_world.gd")
const MothLibrary = preload("res://moth/library.gd")
var moth_effects: Node3D
var public_actors: Array = []
const MAX_BLASTS := 32
const BLAST_SECONDS := 0.32
var projectiles: Node3D
var blasts: Array[Dictionary] = []
var blast_mesh: SphereMesh
var hits: int = 0
var hurts: int = 0
var hit_remaining: float = 0.0
var hurt_remaining: float = 0.0
const Overlay = preload("res://world/combat_overlay.gd")
const AudioFeedback = preload("res://world/audio_feedback.gd")
var overlay: Control
var audio_feedback: Node

func _init() -> void:
	blast_mesh = SphereMesh.new()
	blast_mesh.radius = 1.0
	blast_mesh.height = 2.0
	blast_mesh.radial_segments = 12
	blast_mesh.rings = 6

func apply_state(state: Dictionary) -> void:
	public_actors = state.get("actors", [])
	if not is_instance_valid(projectiles):
		projectiles = Projectiles.new()
		add_child(projectiles)
	projectiles.apply_state(state)

func _ready() -> void:
	moth_effects = MothEffects.new()
	add_child(moth_effects)
	moth_effects.configure(Callable(MothLibrary, "effect"))
	audio_feedback = AudioFeedback.new()
	add_child(audio_feedback)
	audio_feedback.set_muted("--mute" in OS.get_cmdline_user_args())
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
	if is_instance_valid(moth_effects): moth_effects.consume(items, local_id, public_actors)
	if is_instance_valid(audio_feedback): audio_feedback.apply_events(items, local_id)
	for value: Variant in items:
		if not value is Dictionary: continue
		var item: Dictionary = value
		match item.get("type", ""):
			"launch":
				if Projectiles.point(item.get("pos")) == null or Projectiles.identity(item.get("actor")) < 0 or Projectiles.identity(item.get("weapon")) < 0: continue
				launches += 1
				if Projectiles.identity(item.get("actor")) == local_id: local_launches += 1
			"explosion":
				var pos: Variant = Projectiles.point(item.get("pos"))
				if pos == null: continue
				explosions += 1
				if blasts.size() >= MAX_BLASTS: remove_blast(0)
				var material := StandardMaterial3D.new()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.albedo_color = Color(1.0, 0.48, 0.1, 0.65)
				var node := MeshInstance3D.new()
				node.mesh = blast_mesh
				node.material_override = material
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.position = pos
				node.scale = Vector3.ONE * 0.18
				add_child(node)
				blasts.append({"node":node, "remaining":BLAST_SECONDS})
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
				var amount: Variant = item.get("amount")
				if not (amount is int or amount is float): continue
				if not is_finite(float(amount)) or float(amount) <= 0: continue
				var victim: int = Projectiles.identity(item.get("actor"))
				if victim < 0: continue
				# JSON null is environmental damage, never actor zero.
				var source: Variant = item.get("source")
				if local_id >= 0 and victim == local_id:
					hurts += 1
					hurt_remaining = 0.35
				if local_id >= 0 and Projectiles.identity(source) == local_id and victim != local_id:
					hits += 1
					hit_remaining = 0.2

func remove_tracer(index: int) -> void:
	var node: Node = tracers[index].node
	remove_child(node)
	node.free()
	tracers.remove_at(index)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	hit_remaining = maxf(0.0, hit_remaining - maxf(delta, 0.0))
	hurt_remaining = maxf(0.0, hurt_remaining - maxf(delta, 0.0))
	for index: int in range(tracers.size() - 1, -1, -1):
		tracers[index].remaining -= maxf(delta, 0.0)
		if tracers[index].remaining <= 0: remove_tracer(index)
	for index: int in range(blasts.size() - 1, -1, -1):
		blasts[index].remaining -= delta
		if blasts[index].remaining <= 0:
			remove_blast(index)
			continue
		var progress: float = 1.0 - blasts[index].remaining / BLAST_SECONDS
		var node: MeshInstance3D = blasts[index].node
		node.scale = Vector3.ONE * lerpf(0.18, 0.95, progress)
		node.material_override.albedo_color = Color(1.0, lerpf(0.65, 0.2, progress), 0.08, 0.65 * (1.0 - progress))

func remove_blast(index: int) -> void:
	blasts[index].node.free()
	blasts.remove_at(index)

func _process(delta: float) -> void:
	advance(delta)
	if is_instance_valid(overlay):
		var session := get_parent()
		var aiming: bool = session != null and session.has_method("can_capture_pointer") and session.can_capture_pointer() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		overlay.update_feedback(aiming, hit_remaining, hurt_remaining)

func text() -> String:
	return ("HIT CONFIRMED " if hit_remaining > 0 else "") + ("TAKING DAMAGE" if hurt_remaining > 0 else "")

func clear_round() -> void:
	public_actors = [] # Never mutate the snapshot-owned array.
	if is_instance_valid(moth_effects): moth_effects.reset()
	if is_instance_valid(projectiles): projectiles.clear_round()
	while not blasts.is_empty(): remove_blast(0)
	launches = 0
	local_launches = 0
	explosions = 0
	if is_instance_valid(audio_feedback): audio_feedback.clear_round()
	while not tracers.is_empty(): remove_tracer(0)
	shots = 0
	hits = 0
	hurts = 0
	hit_remaining = 0.0
	hurt_remaining = 0.0
	if is_instance_valid(overlay): overlay.update_feedback(false, 0.0, 0.0)
