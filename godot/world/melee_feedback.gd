extends Node3D
## Passive accepted-melee presentation shared by source combat, Horde and campaign.
## Never reads input or changes actors. `hit` is authority's actual-damage result.
const Wire = preload("res://world/projectiles.gd")
const MAX_RINGS := 12
const MAX_VOICES := 16
const EVENT_WINDOW := 4096
const MAX_DISTANCE := 32.0
var rings: Array[Dictionary] = []
var voices: Array[AudioStreamPlayer3D] = []
var sounds: Array[AudioStreamWAV] = []
var seen: Dictionary = {}
var highest := -1
var quality := 1
var reduced_motion := false
var muted := false
var camera: Camera3D
var counters := {"whoosh":0, "impact":0, "rings":0, "duplicates":0, "dropped":0}

func configure(audio: Node, view: Camera3D = null) -> void:
	camera = view
	if not sounds.is_empty(): return
	sounds.assign([audio.melee_sound(false), audio.melee_sound(true)])
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.88
	mesh.outer_radius = 1.0
	mesh.rings = 32
	mesh.ring_segments = 6
	for index: int in MAX_RINGS:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.86, 0.58, 0.85)
		var node := MeshInstance3D.new()
		node.top_level = true # Contact basis remains world-oriented under any parent.
		node.mesh = mesh
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		add_child(node)
		rings.append({"node":node, "material":material, "remaining":0.0, "life":0.22})
	for index: int in MAX_VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = &"Effects"
		voice.unit_size = 3.0
		voice.max_distance = MAX_DISTANCE
		voice.volume_db = -12.0
		add_child(voice)
		voices.append(voice)

func set_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	# Changing to Low immediately drains excess slots.
	for index: int in range(ring_limit(), rings.size()):
		rings[index].remaining = 0.0
		rings[index].node.hide()

func ring_limit() -> int:
	return 4 if quality == 0 or reduced_motion else MAX_RINGS

func set_reduced_motion(value: bool) -> void:
	if reduced_motion == value: return
	reduced_motion = value
	for slot: Dictionary in rings:
		slot.remaining = 0.0
		slot.node.hide()

func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for voice: AudioStreamPlayer3D in voices:
			voice.stop()
			voice.stream = null

static func confirmed(event: Dictionary) -> bool:
	var actor := Wire.identity(event.get("actor"))
	var hit := Wire.identity(event.get("hit"))
	return actor >= 0 and hit >= 0 and hit != actor and event.get("blocked") != true and event.get("protected") != true

static func contact(event: Dictionary, actors: Array) -> Variant:
	var explicit: Variant = Wire.point(event.get("impact"))
	if explicit != null: return explicit
	for actor: Variant in actors:
		if not actor is Dictionary or Wire.identity(actor.get("id")) != Wire.identity(event.get("hit")): continue
		var centre: Variant = Wire.point(actor)
		if centre != null: return centre + Vector3.UP * 0.9
	return null # Missing legacy actor: do not invent a contact at the kicker.

func consume(events: Array, actors: Array, active: bool = true) -> void:
	for value: Variant in events.slice(0, 512):
		if not value is Dictionary or value.get("type") != "melee": continue
		var event: Dictionary = value
		var id := Wire.identity(event.get("id"))
		var time: Variant = event.get("time")
		if id < 0 or not (time is int or time is float): continue
		if not is_finite(float(time)) or float(time) < 0.0 or Wire.identity(event.get("actor")) < 0: continue
		if seen.has(id) or id <= highest - EVENT_WINDOW:
			counters.duplicates += 1
			continue
		highest = maxi(highest, id)
		seen[id] = true # Muted/suspended events are consumed, never replayed.
		if not active: continue
		var origin: Variant = Wire.point(event.get("pos"))
		if origin == null: continue
		_play(0, origin)
		if not confirmed(event): continue
		var position: Variant = contact(event, actors)
		if position == null: continue
		_play(1, position)
		var direction: Variant = Wire.point(event.get("direction"))
		if direction == null or direction.length_squared() < 0.0001: direction = position - origin
		if direction.length_squared() < 0.0001: direction = Vector3.FORWARD
		_ring(position, direction.normalized())
	for id: int in seen.keys():
		if id <= highest - EVENT_WINDOW: seen.erase(id)

func _play(kind: int, position: Vector3) -> void:
	if muted or sounds.is_empty() or not is_inside_tree(): return
	if is_instance_valid(camera) and camera.global_position.distance_to(position) > MAX_DISTANCE: return
	for voice: AudioStreamPlayer3D in voices:
		if voice.playing: continue
		voice.global_position = position
		voice.stream = sounds[kind]
		voice.play()
		counters["whoosh" if kind == 0 else "impact"] += 1
		return
	counters.dropped += 1

func _ring(position: Vector3, direction: Vector3) -> void:
	if is_instance_valid(camera) and camera.global_position.distance_to(position) > MAX_DISTANCE: return
	for index: int in mini(ring_limit(), rings.size()):
		var slot: Dictionary = rings[index]
		if slot.remaining > 0.0: continue
		slot.life = 0.16 if quality == 0 or reduced_motion else 0.22
		slot.remaining = slot.life
		var node: MeshInstance3D = slot.node
		node.global_position = position - direction * 0.04
		# Torus lies in XZ: its world normal follows the accepted strike, not camera.
		node.quaternion = Quaternion(Vector3.UP, direction)
		node.scale = Vector3.ONE * 0.12
		slot.material.albedo_color = Color(1.0, 0.86, 0.58, 0.85)
		node.show()
		counters.rings += 1
		return
	counters.dropped += 1

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	for slot: Dictionary in rings:
		if slot.remaining <= 0.0: continue
		slot.remaining = maxf(0.0, slot.remaining - delta)
		var progress := 1.0 - float(slot.remaining) / float(slot.life)
		slot.node.scale = Vector3.ONE * lerpf(0.12, 0.55 if quality == 0 or reduced_motion else 0.85, progress)
		slot.material.albedo_color = Color(1.0, 0.86, 0.58, 0.85 * pow(1.0 - progress, 1.4))
		if slot.remaining <= 0.0: slot.node.hide()

func clear_transient() -> void:
	for slot: Dictionary in rings:
		slot.remaining = 0.0
		slot.node.hide()
	for voice: AudioStreamPlayer3D in voices:
		voice.stop()
		voice.stream = null

func clear_round() -> void:
	clear_transient()
	seen.clear()
	highest = -1
	for key: String in counters: counters[key] = 0

func _exit_tree() -> void:
	clear_transient()
