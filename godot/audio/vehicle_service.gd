extends Node
## Mounted-only audio, separate from PortAudioFeedback's ordinary combat pool.
const RATE := 22050
const KINDS := {"puma":58.0,"hornet":74.0,"titan":42.0,"scout":88.0,"transport":48.0}
var engine := AudioStreamPlayer.new()
var skid := AudioStreamPlayer.new()
var report := AudioStreamPlayer.new()
var hull := AudioStreamPlayer.new()
var buffers: Dictionary = {}
var enabled := true
var volume := 1.0
var focused := true
var dropped := 0

func _ready() -> void:
	for player: AudioStreamPlayer in [engine, skid, report, hull]:
		player.bus = &"Effects"
		add_child(player)
	for kind: String in KINDS:
		buffers[kind] = _wave(float(KINDS[kind]), 0.4, 0.22, true)
	buffers["skid"] = _wave(320.0, 0.25, 0.085, true)
	buffers["report"] = _wave(145.0, 0.24, 0.42, false)
	buffers["hull"] = _wave(108.0, 0.26, 0.32, false)

func _wave(frequency: float, duration: float, gain: float, looped: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(roundi(duration * RATE) * 2)
	for i in range(data.size() / 2):
		var phase := float(i) * frequency / RATE
		var transient := exp(-float(i) / (RATE * 0.025))
		var envelope := 1.0 if looped else pow(maxf(0.0, 1.0 - float(i) / (data.size() / 2.0)), 1.6)
		var sample := clampf((sin(TAU * phase) * 0.6 + sin(TAU * phase * 0.5) * 0.25 + sin(TAU * phase * 3.0) * transient * 0.15) * envelope * gain, -0.65, 0.65)
		var word := int(sample * 32767.0) & 0xffff
		data[i * 2] = word & 255
		data[i * 2 + 1] = (word >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = data.size() / 2
	return stream

func apply_settings(settings: Dictionary) -> void:
	var v: Variant = settings.get("effects_volume", 100)
	volume = clampf(float(v) / 100.0, 0.0, 1.0) if v is int or v is float else 1.0
	enabled = settings.get("mute", false) != true and volume > 0.0
	if not enabled: stop_all()
	else:
		for player: AudioStreamPlayer in [engine, skid, report, hull]: player.volume_db = 0.0

func set_focus(value: bool) -> void:
	focused = value
	if not focused: stop_all()

func stop_all() -> void:
	for player: AudioStreamPlayer in [engine, skid, report, hull]: player.stop()

func apply_vehicle(vehicle: Dictionary, actor: Dictionary) -> void:
	if not enabled or not focused or vehicle.is_empty() or actor.get("vehicleId") != vehicle.get("id") or float(actor.get("health", 0)) <= 0:
		engine.stop()
		skid.stop()
		return
	var kind := str(vehicle.get("kind", "puma"))
	if not buffers.has(kind): kind = "puma"
	var vx := float(vehicle.get("vx", 0.0))
	var vz := float(vehicle.get("vz", 0.0))
	var speed := clampf(Vector2(vx, vz).length() / 20.0, 0.0, 1.0)
	var boosting := vehicle.get("boosting", false) == true
	if engine.stream != buffers[kind]: engine.stop(); engine.stream = buffers[kind]
	engine.pitch_scale = clampf((1.0 + speed * 1.4) * (1.35 if boosting else 1.0), 0.5, 3.0)
	engine.volume_db = linear_to_db(maxf(0.001, 0.25 + speed * 0.4))
	if not engine.playing: engine.play()
	var yaw := float(vehicle.get("yaw", vehicle.get("heading", 0.0)))
	var slip := absf(vx * cos(yaw) - vz * sin(yaw))
	if kind == "puma" and slip > 1.1:
		skid.stream = buffers["skid"]
		skid.pitch_scale = 1.0 + minf(slip, 12.0) * 0.12
		skid.volume_db = linear_to_db(maxf(0.001, minf(slip * 0.03, 0.35)))
		if not skid.playing: skid.play()
	else: skid.stop()

func event_plan(plan: Dictionary) -> void:
	if not enabled or not focused: dropped += 1; return
	match plan.get("type", ""):
		"vehicle-shot":
			if report.playing: dropped += 1; return
			report.stream = buffers["report"]
			report.play()
		"vehicle-damage":
			if hull.playing: dropped += 1; return
			hull.stream = buffers["hull"]
			hull.pitch_scale = 0.8 + clampf(float(plan.get("strength", 0)), 0.0, 1.0) * 0.5
			hull.play()

func status() -> Dictionary:
	return {"voices":int(engine.playing) + int(skid.playing) + int(report.playing) + int(hull.playing), "voice_limit":4,
		"allocated_pcm_bytes":buffers.size() * RATE, "dropped":dropped, "engine":engine.playing, "skid":skid.playing}
