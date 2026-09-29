extends Node3D
## Eventless, opt-in cosmetic layer. Host owns lifecycle and calls bind/tick.
## Host suppresses only overlapping falling fields before acknowledging handoff.
const Profile = preload("res://ambience/weather_profile.gd")
const MAX_PARTICLES := 48
const MAX_EMITS_PER_TICK := 44
const AUDIO_RATE := 22050
var _arena: Dictionary = {}
var _camera: Camera3D
var _seed := 1
var _mode := "playing"
var _elapsed := 0.0
var _weather := "clear"
var _time: Dictionary = {}
var _snapshot_weather := ""
var _snapshot_time: Dictionary = {}
var _focused := true
var _muted := false
var _reduced := false
var _enabled := true
var _lightning_enabled := true
var _quality := 1.0
var _volume := 0.25
var _suppressed := false
var _mesh := MultiMesh.new()
var _particles := MultiMeshInstance3D.new()
var _flash := OmniLight3D.new()
var _audio := AudioStreamPlayer.new()
var _playback: AudioStreamGeneratorPlayback
var _audio_state := 1
var _audio_frames := 0
var _strikes: Array[Dictionary] = []
var _strike_window := -1
var _active_particles := 0
var _flash_count := 0
var _thunder_until := -1.0
var _thunder_gain := 0.0
var _thunder_count := 0
var _lightning_claimed: Dictionary = {}
var _authoritative_time := false
var _spawn_serial := -1
var _spawn_cursor := 0
var _live: Array[Dictionary] = []

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.20)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	_mesh.mesh = quad
	_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_mesh.use_colors = true
	_mesh.instance_count = MAX_PARTICLES
	_mesh.visible_instance_count = 0
	_particles.multimesh = _mesh
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particles.custom_aabb = AABB(Vector3(-16, -24, -16), Vector3(32, 42, 32))
	add_child(_particles)
	_flash.light_energy = 0.0
	_flash.omni_range = 45.0
	_flash.shadow_enabled = false
	_flash.light_color = Color("cbd9ff")
	add_child(_flash)
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = AUDIO_RATE
	stream.buffer_length = 0.2
	_audio.stream = stream
	_audio.bus = &"Ambience"
	add_child(_audio)
	_audio.play()
	_playback = _audio.get_stream_playback() as AudioStreamGeneratorPlayback

## Source arena metadata only. No synthesized geometry or map parameters.
func bind(arena: Dictionary, camera: Camera3D, mode: String = "playing", seed: int = 1) -> void:
	_arena = arena.duplicate(true)
	_camera = camera
	_mode = mode
	_seed = seed
	_elapsed = 0.0
	_authoritative_time = false
	_spawn_serial = -1
	_spawn_cursor = 0
	_live.clear()
	_mesh.visible_instance_count = 0
	_active_particles = 0
	_snapshot_weather = ""
	_snapshot_time = {}
	_strike_window = -1
	_lightning_claimed.clear()
	_thunder_until = -1.0
	_thunder_gain = 0.0
	_audio_state = Profile.u32(seed) if Profile.u32(seed) != 0 else 1
	_audio_frames = 0
	_refresh()

## Explicit handoff: only true after the native ambient weather emitters are
## disabled for this viewer. False immediately releases the extra field.
func set_native_weather_suppressed(acknowledged: bool) -> void:
	_suppressed = acknowledged
	if not acknowledged:
		_mesh.visible_instance_count = 0
		_active_particles = 0
		_flash.light_energy = 0.0
		_thunder_until = -1.0
		_thunder_gain = 0.0
		_live.clear()

## The host calls this before changing native ownership and again after settings
## or snapshot changes. An overcast sky has no falling particles to hand off.
func wants_precipitation_handoff() -> bool:
	return _enabled and not _reduced and _quality > 0.0 and _weather in ["rain", "snow", "ash", "storm"]

func apply_settings(settings: Dictionary) -> void:
	_muted = settings.get("mute", settings.get("muted", _muted)) == true or settings.get("ambience_enabled", true) == false or settings.get("ambience_volume", 100) == 0
	_reduced = settings.get("reduced_motion", _reduced) == true
	_enabled = settings.get("weather_enabled", _enabled) == true
	_lightning_enabled = settings.get("lightning_flashes", _lightning_enabled) == true
	var quality: Variant = settings.get("weather_quality", _quality * 100.0)
	if (quality is float or quality is int) and is_finite(float(quality)): _quality = clampf(float(quality) / 100.0, 0.0, 1.0)
	var volume: Variant = settings.get("ambience_volume", _volume * 100.0)
	if (volume is float or volume is int) and is_finite(float(volume)):
		_volume = clampf(float(volume) / 100.0, 0.0, 1.0) * 0.25
	if _muted and _playback != null: _playback.clear_buffer()
	if not _enabled or _reduced or _quality <= 0.0:
		_mesh.visible_instance_count = 0
		_active_particles = 0
		_flash.light_energy = 0.0
	if not _enabled and _playback != null: _playback.clear_buffer()
	_refresh()

func set_focus(focused: bool) -> void:
	_focused = focused
	if not focused:
		_mesh.visible_instance_count = 0
		_active_particles = 0
		_flash.light_energy = 0.0
		_thunder_until = -1.0
	_audio.volume_db = -80.0 if not focused or _muted or not _enabled else linear_to_db(maxf(_volume, 0.0001))

## Read weather/timeOfDay exclusively from the single-player snapshot object.
## A missing or invalid field falls back to the locally selected pure profile.
func apply_snapshot(frame: Dictionary) -> void:
	var timestamp: Variant = frame.get("time")
	if (timestamp is float or timestamp is int) and is_finite(float(timestamp)) and float(timestamp) >= 0.0:
		if _authoritative_time and float(timestamp) < _elapsed:
			_spawn_serial = -1
			_live.clear()
			_strike_window = -1
		_elapsed = float(timestamp)
		_authoritative_time = true
	# game/core.mjs snapshot() serializes the authored object as `singleplayer`
	# (lowercase), not page-side `singlePlayer` or top-level weather.
	var single: Variant = frame.get("singleplayer", {})
	_snapshot_weather = ""
	_snapshot_time = {}
	if single is Dictionary:
		var kind: Variant = single.get("weather")
		if kind is String and Profile.KINDS.has(kind): _snapshot_weather = kind
		var day: Variant = single.get("timeOfDay")
		if day is Dictionary: _snapshot_time = day.duplicate(true)
		elif day is String and day in ["day", "dusk", "night"]: _snapshot_time = {"phase": day, "cycle": day, "t": 0.0}
	_refresh()

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or not _focused: return
	if not _authoritative_time: _elapsed += minf(delta, 0.1)
	_refresh()
	_update_lightning()
	_update_particles()
	_fill_audio()

func _refresh() -> void:
	_time = Profile.time_at(_arena, _elapsed, _mode)
	if _snapshot_time.has("phase") and str(_snapshot_time.phase) in ["day", "dusk", "night"]: _time = _snapshot_time.duplicate(true)
	if _reduced:
		var still: Dictionary = _arena.duplicate()
		still["reducedMotion"] = true
		_time = Profile.time_at(still, _elapsed, _mode)
	var next: String = _snapshot_weather if not _snapshot_weather.is_empty() else Profile.select(_arena, _time, _seed, _reduced)
	if _reduced or not _enabled: next = "clear"
	if next != _weather:
		_weather = next
		_strike_window = -1
		_spawn_serial = -1
		_live.clear()
		_mesh.visible_instance_count = 0
	_audio.volume_db = -80.0 if _muted or not _focused or not _enabled else linear_to_db(maxf(_volume, 0.0001))

func _update_particles() -> void:
	_active_particles = 0
	if not _suppressed or not wants_precipitation_handoff() or not is_instance_valid(_camera):
		_mesh.visible_instance_count = 0
		return
	var preset: Dictionary = Profile.KINDS[_weather]
	var count: int = mini(MAX_EMITS_PER_TICK, roundi(float(preset.particles) / 6.0 * _quality))
	var serial := floori(_elapsed * 60.0)
	var origin := _camera.global_position
	_particles.global_position = origin
	_flash.global_position = origin + Vector3(0, 10, 0)
	if serial != _spawn_serial:
		_spawn_serial = serial
		for i in count:
			# Source precipParticleAdds: salt=serial*17+i*131, radial sqrt
			# distribution, fall/life/size jitter and deterministic drift.
			var salt := serial * 17 + i * 131
			var angle := Profile.hash_unit(salt, 1) * TAU
			var distance := sqrt(Profile.hash_unit(salt, 2)) * 9.0
			var life: float = preset.life * (0.8 + Profile.hash_unit(salt, 4) * 0.4)
			var fall: float = preset.fall * (0.85 + Profile.hash_unit(salt, 5) * 0.3)
			var size: float = preset.size * (0.8 + Profile.hash_unit(salt, 6) * 0.5)
			var pos := origin + Vector3(cos(angle) * distance, 4.0 + Profile.hash_unit(salt, 3) * 6.0, sin(angle) * distance)
			var velocity := Vector3((Profile.hash_unit(salt, 7) - 0.5) * preset.drift, -fall, (Profile.hash_unit(salt, 8) - 0.5) * preset.drift)
			var particle := {"pos": pos, "velocity": velocity, "born": _elapsed, "life": life, "size": size}
			if _live.size() < MAX_PARTICLES: _live.append(particle)
			else:
				_live[_spawn_cursor] = particle
				_spawn_cursor = (_spawn_cursor + 1) % MAX_PARTICLES
	var visible := 0
	var gust := Profile.gust(_elapsed, _seed, float(preset.wind))
	for particle: Dictionary in _live:
		var age: float = _elapsed - float(particle.born)
		if age < 0.0 or age >= float(particle.life): continue
		var position: Vector3 = particle.pos + Vector3(particle.velocity.x * gust, particle.velocity.y, particle.velocity.z * gust) * age
		var size: float = particle.size
		var ratio: float = preset.streakRatio
		_mesh.set_instance_transform(visible, Transform3D(Basis.IDENTITY.scaled(Vector3(size / 0.035, size * ratio / 0.20, 1.0)), position - origin))
		_mesh.set_instance_color(visible, Color(preset.color))
		visible += 1
	_mesh.visible_instance_count = visible
	_active_particles = visible

func _update_lightning() -> void:
	_flash.light_energy = 0.0
	if _reduced or not _enabled or not _lightning_enabled or not _weather in ["storm", "rain", "overcast"]: return
	if _weather != "overcast" and not _suppressed: return
	var window := floori(_elapsed / 60.0)
	if window != _strike_window:
		_strike_window = window
		_strikes = Profile.lightning(Profile.u32(_seed + window), 60.0, 4, _weather)
		_lightning_claimed.clear()
	for index in _strikes.size():
		var strike: Dictionary = _strikes[index]
		var offset: float = _elapsed - 60.0 * window - float(strike.time)
		if offset >= 0.0 and offset < 0.12:
			_flash.light_energy = float(strike.intensity) * (1.0 - offset / 0.12) * 2.0
			if not _lightning_claimed.has(index):
				_lightning_claimed[index] = true
				_flash_count += 1
			break
		if offset >= float(strike.thunderDelay) and not _lightning_claimed.has("thunder:%d" % index):
			_lightning_claimed["thunder:%d" % index] = true
			_thunder_until = _elapsed + 1.6
			_thunder_gain = float(strike.thunderGain)
			_thunder_count += 1

func _fill_audio() -> void:
	if _playback == null or _muted or not _enabled or not _focused: return
	# Bounded stereo procedural air bed; no playback events or asset dependency.
	var n := mini(_playback.get_frames_available(), 1024)
	var amplitude := 0.025 if _weather in ["clear", "snow", "ash"] else 0.065
	var thunder := _thunder_gain * clampf((_thunder_until - _elapsed) / 1.6, 0.0, 1.0) if _thunder_until > _elapsed else 0.0
	for i in n:
		_audio_state = Profile.u32(_audio_state * 1664525 + 1013904223)
		var noise := float(_audio_state) / 2147483648.0 - 1.0
		var wind := sin(float(_audio_frames) * TAU * 75.0 / AUDIO_RATE) * 0.12
		var sample := (noise * 0.35 + wind) * amplitude + (noise * 0.17 + sin(float(_audio_frames) * TAU * 63.0 / AUDIO_RATE) * 0.1) * thunder
		_playback.push_frame(Vector2(sample, sample))
		_audio_frames += 1

func diagnostics() -> Dictionary:
	return {"biome": Profile.biome(_arena), "weather": _weather, "time": _time.duplicate(true), "elapsed": _elapsed, "authoritative_time": _authoritative_time, "seed": _seed, "wind": Profile.gust(_elapsed, _seed), "particles": _active_particles, "particle_limit": MAX_PARTICLES, "emits_per_tick_limit": MAX_EMITS_PER_TICK, "native_weather_suppressed": _suppressed, "wants_precipitation_handoff": wants_precipitation_handoff(), "lightning_flashes": _flash_count, "thunder_count": _thunder_count, "muted": _muted, "enabled": _enabled, "focused": _focused, "reduced_motion": _reduced, "audio_frames": _audio_frames}
