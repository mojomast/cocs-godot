extends Node
## Source enemy windup motifs. Four fixed spatial voices, no delayed event queue.
const Policy = preload("res://audio/threat_policy.gd")
var players: Array[AudioStreamPlayer3D] = []
var weights: Array = [0.0, 0.0, 0.0, 0.0]
var starts: Array = [0.0, 0.0, 0.0, 0.0]
var streams: Dictionary = {}
var manifest: Dictionary = {}
var mode_root := -1
var muted := false
var focused := true
var accepted := 0
var dropped := 0
var stolen := 0
var last_id := -1
var last_kind := ""
var load_failures := 0

func _ready() -> void:
	var file := FileAccess.open("res://audio/telegraphs/manifest.json", FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary: manifest = parsed
	for i in Policy.VOICES:
		var player := AudioStreamPlayer3D.new()
		player.name = "ThreatVoice%d" % i
		player.bus = &"Effects"
		# Source linear XZ falloff is applied once, below. Native spatial panning
		# replaces WebAudio StereoPanner; there is no second distance filter.
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		player.attenuation_filter_cutoff_hz = 20500.0
		player.panning_strength = 0.9
		player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(player)
		players.append(player)
	set_mode("default")

func set_mode(mode: String) -> void:
	var roots: Dictionary = manifest.get("roots", {})
	var next := int(roots.get(mode, 58))
	if next == mode_root: return
	stop_all()
	streams.clear()
	mode_root = next
	for kind: String in manifest.get("cues", {}):
		var stream: Resource = load("res://audio/telegraphs/%d-%s.wav" % [mode_root, kind])
		if stream is AudioStreamWAV: streams[kind] = stream
		else: load_failures += 1

func apply_settings(settings: Dictionary) -> void:
	var level: Variant = settings.get("effects_volume", 100)
	muted = settings.get("mute", false) == true or (Policy.number(level) and float(level) <= 0.0)
	# Effects bus exclusively owns volume; do not multiply it a second time.
	if muted: stop_all()

func set_focus(value: bool) -> void:
	focused = value
	if not value: stop_all()

func stop_all() -> void:
	for player: AudioStreamPlayer3D in players:
		player.stop()
		player.stream = null

func event_plan(plan: Dictionary, listener: Dictionary, snapshot_time: float) -> bool:
	if muted or not focused or plan.get("type") != "enemy-telegraph":
		dropped += 1
		return false
	var point: Variant = plan.get("from")
	var stamp: Variant = plan.get("time")
	var duration: Variant = plan.get("duration")
	# Do not replay already-expired windups after delivery stalls. No invented
	# cooldown: every distinct, still-current authority event may spend a voice.
	if not Policy.position(point) or not Policy.number(stamp) or not Policy.number(duration) or float(duration) <= 0.0 or snapshot_time - float(stamp) >= float(duration):
		dropped += 1
		return false
	var gain := Policy.gain_at(point, listener)
	if gain <= Policy.AUDIBLE:
		dropped += 1
		return false
	var kind := str(plan.get("kind", "generic"))
	if not streams.has(kind): kind = "generic"
	if not streams.has(kind):
		dropped += 1
		return false
	var now := Time.get_ticks_msec() / 1000.0
	var weight := Policy.priority(kind, gain)
	var active: Array = players.map(func(p: AudioStreamPlayer3D) -> bool: return p.playing)
	var index := Policy.slot(active, weights, starts, weight, now)
	if index < 0:
		dropped += 1
		return false
	var player := players[index]
	if player.playing: stolen += 1
	player.stop()
	player.stream = streams[kind]
	var height := float(listener.get("y", 0.0)) + 1.6 if Policy.number(listener.get("y", 0.0)) else 1.6
	player.global_position = Vector3(float(point.x), height, float(point.z))
	player.volume_db = linear_to_db(gain)
	weights[index] = weight
	starts[index] = now
	player.play()
	accepted += 1
	last_id = int(plan.get("id", -1))
	last_kind = kind
	return true

func status() -> Dictionary:
	return {"voices":players.filter(func(p: AudioStreamPlayer3D) -> bool: return p.playing).size(),
		"voice_limit":Policy.VOICES, "streams":streams.size(), "root":mode_root,
		"accepted":accepted, "dropped":dropped, "stolen":stolen, "last_id":last_id,
		"last_kind":last_kind, "load_failures":load_failures}

func _exit_tree() -> void:
	stop_all()
	streams.clear()
	preload("res://audio/playback_cleanup.gd").drain()
