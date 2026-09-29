extends Node3D
## Eventless, opt-in cosmetic layer. Host owns lifecycle and calls bind/tick.
## Existing combat_particles ambient fields and Moth scenery motes must be
## suppressed by the host before acknowledging precipitation ownership.
const Profile = preload("res://ambience/weather_profile.gd")
const MAX_PARTICLES := 130
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
	_particles.custom_aabb = AABB(Vector3(-16, -5, -16), Vector3(32, 22, 32))
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
	_snapshot_weather = ""
	_snapshot_time = {}
	_strike_window = -1
	_audio_state = Profile.u32(seed) if Profile.u32(seed) != 0 else 1
	_audio_frames = 0
	_refresh()

## Explicit handoff: only true after the native ambient weather emitters are
## disabled for this viewer. False immediately releases the extra field.
func set_native_weather_suppressed(acknowledged: bool) -> void:
	_suppressed = acknowledged
	if not acknowledged: _mesh.visible_instance_count = 0

func apply_settings(settings: Dictionary) -> void:
	_muted = settings.get("muted", _muted) == true
	_reduced = settings.get("reduced_motion", _reduced) == true
	var volume: Variant = settings.get("ambient_volume", _volume)
	if (volume is float or volume is int) and is_finite(float(volume)):
		_volume = clampf(float(volume), 0.0, 1.0)
	_refresh()

func set_focus(focused: bool) -> void:
	_focused = focused
	if not focused:
		_mesh.visible_instance_count = 0
		_active_particles = 0
		_flash.light_energy = 0.0
	_audio.volume_db = -80.0 if not focused or _muted else linear_to_db(maxf(_volume, 0.0001))

## Read weather/timeOfDay exclusively from the single-player snapshot object.
## A missing or invalid field falls back to the locally selected pure profile.
func apply_snapshot(frame: Dictionary) -> void:
	var single: Variant = frame.get("singlePlayer", {})
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
	_elapsed += minf(delta, 0.1)
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
	if _reduced: next = "clear"
	if next != _weather:
		_weather = next
		_strike_window = -1
	_audio.volume_db = -80.0 if _muted or not _focused else linear_to_db(maxf(_volume, 0.0001))

func _update_particles() -> void:
	_active_particles = 0
	if not _suppressed or _reduced or not is_instance_valid(_camera) or not _weather in ["rain", "snow", "ash", "storm"]:
		_mesh.visible_instance_count = 0
		return
	var count: int = Profile.KINDS[_weather].particles
	var color := Color("aebccb" if _weather == "rain" else ("eef6ff" if _weather == "snow" else ("8f8880" if _weather == "ash" else "9fb0c2")))
	var gust := Profile.gust(_elapsed, _seed, float(Profile.KINDS[_weather].wind))
	var speed := 2.4 if _weather == "snow" else (0.9 if _weather == "ash" else (19.0 if _weather == "rain" else 15.0))
	var origin := _camera.global_position
	_particles.global_position = origin
	_flash.global_position = origin + Vector3(0, 10, 0)
	for i in count:
		var salt := i * 131 + _seed * 17
		var x := (Profile.hash_unit(salt, 1) - 0.5) * 18.0
		var z := (Profile.hash_unit(salt, 2) - 0.5) * 18.0
		var phase := Profile.hash_unit(salt, 3)
		var y := 11.0 - fposmod(phase * 15.0 + _elapsed * speed * (0.85 + Profile.hash_unit(salt, 5) * 0.3), 15.0)
		var drift := (_elapsed * gust * (Profile.hash_unit(salt, 7) - 0.5) * 0.25)
		_mesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x + drift, y, z)))
		_mesh.set_instance_color(i, color)
	_mesh.visible_instance_count = count
	_active_particles = count

func _update_lightning() -> void:
	_flash.light_energy = 0.0
	if _reduced or not _suppressed or not _weather in ["storm", "rain", "overcast"]: return
	var window := floori(_elapsed / 60.0)
	if window != _strike_window:
		_strike_window = window
		_strikes = Profile.lightning(Profile.u32(_seed + window), 60.0, 12, _weather)
	for strike: Dictionary in _strikes:
		var offset: float = _elapsed - 60.0 * window - float(strike.time)
		if offset >= 0.0 and offset < 0.12:
			_flash.light_energy = float(strike.intensity) * (1.0 - offset / 0.12) * 2.0
			_flash_count += 1
			break

func _fill_audio() -> void:
	if _playback == null or _muted: return
	# Bounded stereo procedural air bed; no playback events or asset dependency.
	var n := mini(_playback.get_frames_available(), 1024)
	var amplitude := 0.025 if _weather in ["clear", "snow", "ash"] else 0.065
	for i in n:
		_audio_state = Profile.u32(_audio_state * 1664525 + 1013904223)
		var noise := float(_audio_state) / 2147483648.0 - 1.0
		var wind := sin(float(_audio_frames) * TAU * 75.0 / AUDIO_RATE) * 0.12
		var sample := (noise * 0.35 + wind) * amplitude
		_playback.push_frame(Vector2(sample, sample))
		_audio_frames += 1

func diagnostics() -> Dictionary:
	return {"biome": Profile.biome(_arena), "weather": _weather, "time": _time.duplicate(true), "seed": _seed, "wind": Profile.gust(_elapsed, _seed), "particles": _active_particles, "particle_limit": MAX_PARTICLES, "native_weather_suppressed": _suppressed, "lightning_flashes": _flash_count, "muted": _muted, "focused": _focused, "reduced_motion": _reduced, "audio_frames": _audio_frames}
