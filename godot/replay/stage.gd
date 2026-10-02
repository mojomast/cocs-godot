extends "res://world/viewer.gd"
## Presentation-only scene: intentionally no client/net, session, input or career object.
const Presentation = preload("res://world/presentation.gd")
const Pickups = preload("res://world/pickups.gd")
const Combat = preload("res://world/combat_feedback.gd")
const ADMISSION_PATH := "res://replay/admission.json"
var read_only_context := true
var presentation := Presentation.new()
var pickups := Pickups.new()
var combat := Combat.new()
var generation := -1
var map_error := ""
var follow_id := -1
var state: Dictionary = {}

func _ready() -> void:
	# Do not invoke viewer._ready(): it selects a fallback map and exposes selectors.
	add_child(camera)
	add_child(environment)
	add_child(sun)
	# Viewer helpers still write these controls; retain ownership without showing UI.
	add_child(label)
	add_child(selector)
	label.hide()
	selector.hide()
	add_child(presentation)
	add_child(pickups)
	add_child(combat)
	# Reuse projectile bodies but disable their live visual dead reckoning: source
	# DemoPlayer has already interpolated pos; replay pause must freeze exactly.
	if is_instance_valid(combat.projectiles): combat.projectiles.set_process(false)
	camera.current = true
	camera.far = 2000
	presentation.interpolate_remote = false # Source DemoPlayer already interpolated.

func ensure_map(id: String) -> bool:
	if current_id == id: return true
	var admission: Variant = JSON.parse_string(FileAccess.get_file_as_string(ADMISSION_PATH))
	if not admission is Dictionary or not admission.maps.has(id):
		map_error = "Unsupported replay map: " + id
		return false
	if not catalog.open(): map_error = catalog.error; return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/generated/manifest.json"))
	if not manifest is Dictionary or manifest.get("source_derivative_commit", admission.derivativeCommit) != admission.derivativeCommit:
		map_error = "Replay derivative provenance mismatch"
		return false
	if catalog.source_commit != admission.sourceCommit or not catalog.entries.has(id):
		map_error = "Replay map source provenance mismatch"
		return false
	var entry: Dictionary = catalog.entries[id]
	if entry.sha256 != admission.maps[id].semanticSha256:
		map_error = "Replay geometry differs from the admitted catalog"
		return false
	ids = [id]
	selector.add_item(id)
	if not load_map(id): map_error = catalog.error; return false
	world.get_node("StaticPickupMarkers").hide()
	return true

func apply_sample(value: Dictionary) -> bool:
	var incoming: Dictionary = value.state
	if not ensure_map(str(incoming.mapId)): return false
	if value.get("clear", false) or int(value.generation) != generation:
		clear_cues()
		presentation.clear_round()
		pickups.clear_round()
	generation = int(value.generation)
	state = incoming
	presentation.apply_state(state, -1)
	pickups.apply_state(state)
	if is_instance_valid(combat.projectiles): combat.projectiles.apply_state(state)
	# Every cue was selected by source eventsBetween with its absolute time offset.
	for event: Dictionary in value.get("events", []):
		combat.apply_events([event], -1)
		if event.get("type") in ["shot", "launch"] and is_instance_valid(combat.audio_feedback):
			combat.audio_feedback.apply_events([event], int(event.get("actor", -1)))
	update_camera()
	return true

func clear_cues() -> void:
	combat.clear_round()

func cycle_subject() -> void:
	var actors: Array = state.get("actors", [])
	if actors.is_empty(): return
	var at := -1
	for i: int in actors.size():
		if int(actors[i].id) == follow_id: at = i
	follow_id = int(actors[(at + 1) % actors.size()].id)
	update_camera()

func update_camera() -> void:
	var actors: Array = state.get("actors", [])
	if actors.is_empty():
		camera.position = Vector3(65, 48, 70)
		camera.look_at(Vector3(0, 2, 0))
		return
	var subject: Dictionary = actors[0]
	for actor: Dictionary in actors:
		if int(actor.id) == follow_id: subject = actor
	follow_id = int(subject.id)
	var target := Vector3(subject.x, subject.y + 1.0, subject.z)
	var yaw := float(subject.get("yaw", 0))
	camera.position = target + Vector3(sin(yaw) * 7.0, 4.0, cos(yaw) * 7.0)
	camera.look_at(target)

func _process(_delta: float) -> void:
	pass # No viewer free-flight controls, no local physics or predicted clock.

func _unhandled_input(_event: InputEvent) -> void:
	pass

func _exit_tree() -> void:
	clear_cues()
