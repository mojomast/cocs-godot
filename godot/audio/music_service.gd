extends Node
## Original Relay / Warden orchestral score. Explicit tick(delta) is owned by
## presentation; synchronized PCM stems replace the old frame-timed arranger.
## Existing bounded sample voices serve short presentation cues only.
const SCENES := ["menu", "explore", "combat", "results"]
const CUES := ["capture","flag-pickup","flag-return","goal","killstreak","spree","multikill","victory","defeat","score","boss","objective"]
const VOICES := 20 # Includes a single dedicated, never-stolen announcer player.

var scene := "menu"
var mode_theme := "default"
var biome := "default"
var seed_value := 42
var variation := 0
var escalation := 0
var tension := 0.0
var intensity := 0.0
var master_volume := 1.0
var music_volume := 0.7
var announcer_volume := 1.0
var muted := false
var music_enabled := true
var announcer_enabled := false
var focused := true
var running := false
var form_bar := 0
var step := 0
var accumulator := 0.0
var last_cue := ""
var last_cue_at := -100000
var cue_ordinal := {}
var manifest := {}
var samples := {}
var takes := {}
var streams := {}
var players := []
var expires := []
var announcer_player: AudioStreamPlayer
var host_ref: WeakRef
var error := ""
var dropped_notes := 0
var dropped_cues := 0
var load_failures := 0
var asset_bytes := 0
var last_response := ""
var response_at := -100000
var outcome := ""
var boss_phase := 0
var orchestra: Node

func _ready() -> void:
 _load_manifests()
 orchestra = preload("res://audio/orchestral_score.gd").new()
 add_child(orchestra)
 if not orchestra.error.is_empty(): error = orchestra.error
 for i in range(VOICES - 1):
  var player := AudioStreamPlayer.new()
  player.name = "ScoreVoice%d" % i
  player.bus = &"Score"
  add_child(player)
  players.append(player)
  expires.append(0.0)
 announcer_player = AudioStreamPlayer.new()
 announcer_player.name = "AnnouncerVoice"
 announcer_player.bus = &"Announcer"
 add_child(announcer_player)

func bind(host: Node = null) -> void:
 host_ref = weakref(host) if host != null else null

func _exit_tree() -> void:
 running = false
 for player: AudioStreamPlayer in players:
  preload("res://audio/playback_cleanup.gd").release(player)
 preload("res://audio/playback_cleanup.gd").release(announcer_player)
 streams.clear()
 preload("res://audio/playback_cleanup.gd").drain()

func _load_manifests() -> void:
 var music_file := FileAccess.open("res://audio/music/manifest.json", FileAccess.READ)
 var voice_file := FileAccess.open("res://audio/announcer/manifest.json", FileAccess.READ)
 if music_file == null or voice_file == null:
  error = "Audio manifests missing"
  return
 var music_data: Variant = JSON.parse_string(music_file.get_as_text())
 var voice_data: Variant = JSON.parse_string(voice_file.get_as_text())
 if not music_data is Dictionary or not voice_data is Dictionary:
  error = "Audio manifests invalid"
  return
 manifest = music_data
 for entry in music_data.get("samples", []):
  if entry is Dictionary: samples[entry.get("id", "")] = entry
 for entry in voice_data.get("clips", []):
  if entry is Dictionary:
   var cue: String = str(entry.get("cue", ""))
   if not takes.has(cue): takes[cue] = []
   takes[cue].append(entry)
 # Local-only assets are loaded before live dispatch. Never import/fetch on an
 # event path where a late response would replay a stale beat.
 for entry: Dictionary in samples.values(): _stream("music/" + str(entry.get("file", "")))
 for group: Array in takes.values():
  for entry: Dictionary in group: _stream("announcer/" + str(entry.get("file", "")))

func set_scene(value: String) -> void:
 if value in SCENES:
  if scene == "results" and value != "results" and not outcome.is_empty(): return
  scene = value

func set_outcome(value: String) -> void:
 if value in ["victory", "defeat", "neutral"]:
  outcome = value
  scene = "results"
  if value in ["victory", "defeat"]: cue(value)
 elif value.is_empty(): outcome = ""

func set_mode_theme(value: String) -> void:
 mode_theme = value

func set_biome(value: String) -> void:
 biome = value

func set_variation(value: int) -> void:
 variation = value

func set_seed(value: int) -> void:
 seed_value = value

func set_tension(value: float) -> void:
 tension = clampf(value, 0.0, 1.0)

func set_intensity(value: float) -> void:
 intensity = clampf(value, 0.0, 1.0)

func set_escalation(value: int) -> void:
 escalation = clampi(value, 0, 3)

func set_boss_phase(value: int) -> void:
 boss_phase = clampi(value, 0, 3)

func set_settings(options: Dictionary) -> void:
 # Master is controlled only by LocalSettings' Master bus; never multiply it
 # again here. Legacy normalized options remain supported for detached tests.
 if options.has("music_volume"): music_volume = clampf(float(options.music_volume) / 100.0, 0.0, 1.0)
 elif options.has("music"): music_volume = clampf(float(options.music), 0.0, 1.0)
 if options.has("announcer_volume"): announcer_volume = clampf(float(options.announcer_volume) / (100.0 if options.has("music_volume") else 1.0), 0.0, 1.0)
 if options.has("mute"): muted = options.mute == true
 elif options.has("muted"): muted = options.muted == true
 if options.has("music_enabled"): music_enabled = options.music_enabled == true
 if options.has("announcer_enabled"): announcer_enabled = options.announcer_enabled == true
 if muted or not music_enabled or music_volume <= 0.0:
  for player: AudioStreamPlayer in players: player.stop()
  if orchestra != null: orchestra.stop()
 if muted or not announcer_enabled or announcer_volume <= 0.0: announcer_player.stop()

func set_focus(value: bool) -> void:
 focused = value
 if not focused: reset()

func reset() -> void:
 accumulator = 0.0
 running = false
 form_bar = 0
 step = 0
 if orchestra != null: orchestra.stop()
 for player: AudioStreamPlayer in players: player.stop()
 if announcer_player != null: announcer_player.stop()

func start() -> void:
 if focused and error.is_empty(): running = true

func tick(delta: float) -> void:
 if not running or not focused or not music_enabled or music_volume <= 0.0 or muted or error != "": return
 if not is_finite(delta) or delta < 0.0: return
 orchestra.tick(delta, scene, intensity, tension, escalation, boss_phase, outcome, music_volume)
 form_bar = int(orchestra.phase / 3.0)
 step = int(fposmod(orchestra.phase, 3.0) / 0.1875)

func _section() -> String:
 if form_bar < 4: return "statement"
 if form_bar < 8: return "answer"
 if form_bar < 12: return "development"
 return "cadence"

func _stream(path: String) -> AudioStream:
 if streams.has(path): return streams[path]
 var loaded: Resource = load("res://audio/" + path)
 if loaded is AudioStream:
  streams[path] = loaded
  var file := FileAccess.open("res://audio/" + path, FileAccess.READ)
  if file != null: asset_bytes += file.get_length()
  return loaded
 load_failures += 1
 return null

func _note(instrument: String, midi: int, duration: float, gain: float, loud: bool) -> void:
 if not music_enabled or music_volume <= 0.0 or muted or not focused: return
 var nearest: Dictionary = {}
 var distance := 999
 for entry: Dictionary in samples.values():
  if entry.get("instrument") != instrument: continue
  var d: int = abs(int(entry.get("midi",0)) - midi) * 3 + (0 if int(entry.get("velocity",1)) == (2 if loud else 1) else 1)
  if d < distance:
   distance = d
   nearest = entry
 if nearest.is_empty(): return
 var stream := _stream("music/" + str(nearest.file))
 if stream == null: return
 var now := Time.get_ticks_msec() / 1000.0
 var slot := -1
 for i in range(players.size()):
  if expires[i] < now or not players[i].playing:
   slot = i
   break
 if slot < 0:
  dropped_notes += 1
  return # bounded polyphony, never steal the announcer
 var player: AudioStreamPlayer = players[slot]
 player.stop()
 player.stream = stream
 player.pitch_scale = clampf(pow(2.0, float(midi - int(nearest.midi)) / 12.0), 0.5, 2.0)
 player.volume_db = linear_to_db(maxf(0.001, gain * float(nearest.get("gain",1.0)) * music_volume))
 # Ogg streams are one-shots here; attack/loop offsets require sampler playback
 # controls unavailable on imported Godot streams. Re-articulation stays bounded.
 player.play()
 expires[slot] = now + duration

func cue(name: String) -> bool:
 if not CUES.has(name) or not announcer_enabled or announcer_volume <= 0.0 or muted or not focused or error != "":
  dropped_cues += 1
  return false
 var now := Time.get_ticks_msec()
 if name == last_cue and now - last_cue_at < 1800: dropped_cues += 1; return false
 if now - last_cue_at < 1200 and name not in ["goal", "victory", "defeat"]: dropped_cues += 1; return false
 if announcer_player.playing and name not in ["goal","victory","defeat"]: dropped_cues += 1; return false
 var options: Array = takes.get(name, [])
 if options.is_empty(): return false
 var ordinal: int = int(cue_ordinal.get(name,0))
 var clip: Dictionary = options[posmod(seed_value + ordinal, options.size())]
 var stream := _stream("announcer/" + str(clip.file))
 if stream == null: return false
 cue_ordinal[name] = ordinal + 1
 last_cue = name
 last_cue_at = now
 announcer_player.stop()
 announcer_player.stream = stream
 announcer_player.volume_db = linear_to_db(maxf(0.001, announcer_volume * 0.82))
 announcer_player.play()
 # Source score responds harmonically without queuing past events.
 if name in ["goal","capture","victory","score"]:
  _note("tubular-bells", 60, 1.0, 0.10, true)
 elif name in ["boss","defeat","flag-pickup"]:
  _note("gong", 60, 1.0, 0.08, true)
 return true

func response(kind: String) -> bool:
 if not kind in ["capture", "loss", "accent", "final", "award"] or muted or not music_enabled or music_volume <= 0.0 or not running: return false
 var now := Time.get_ticks_msec()
 if now - response_at < 250: return false
 response_at = now
 last_response = kind
 var pitch: int = {"capture":62,"loss":50,"accent":74,"final":69,"award":81}[kind]
 _note("tubular-bells" if kind in ["capture", "award", "final"] else "low-brass", pitch, 0.65, 0.09, true)
 return true

func countdown_beep(beat: int) -> bool:
 if beat not in [0, 1, 2, 3] or not running or muted or not focused: return false
 _note("bells", 84 if beat == 0 else 76, 0.3 if beat == 0 else 0.16, 0.15 if beat == 0 else 0.09, true)
 return true

func status() -> Dictionary:
 return {"state":"running" if running and focused else "stopped", "scene":scene,
  "mode":mode_theme,"bar":form_bar,"step":step,"section":_section(),
  "escalation":escalation,"tension":tension,"variation":variation,
  "samples":samples.size(),"takes":takes.size(),"loaded_streams":streams.size(),"asset_bytes":asset_bytes,"loaded_failures":load_failures,
   "active_voices":players.filter(func(p: AudioStreamPlayer) -> bool: return p.playing).size() + (4 if orchestra != null and orchestra.player.playing else 0),"announcer_active":announcer_player != null and announcer_player.playing,
   "dropped_notes":dropped_notes,"dropped_cues":dropped_cues,"last_cue_id":last_cue,"last_response":last_response,"outcome":outcome,
   "orchestra":orchestra.status() if orchestra != null else {},"boss_phase":boss_phase,"error":error}
