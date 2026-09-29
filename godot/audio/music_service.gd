extends Node
## Source-derived D minor adaptive score. Explicit tick(delta) is owned by the
## presentation loop; no autoplay and no unbounded work after focus loss.
## Based on game/music.mjs HALO_THEME, HALO_PROGRESSIONS / QUALITIES,
## COCS_MOTIF, HALO_ARRANGEMENTS, FORM_BARS and MUSIC_PALETTES.
const ROOT_MIDI := 38 # D2 = 73.416 Hz
const SCALE := [0, 2, 3, 5, 7, 8, 10]
const MOTIF := [0, 2, 4, 3, 2, 4, 6, 4, 5, 4, 3, 2, 1, 2, 0, 0]
const PROGRESSIONS := {
 "menu": [0, 5, 2, 6, 0, 5, 3, 4],
 "explore": [0, 5, 3, 4, 0, 6, 5, 4],
 "combat": [0, 5, 2, 6, 3, 4, 4, 0],
 "results": [0, 5, 2, 3, 4, 0, 4, 0]
}
const QUALITIES := {
 "menu": [0, 1, 1, 1, 0, 1, 0, 0],
 "explore": [0, 1, 0, 0, 0, 1, 1, 0],
 "combat": [0, 1, 1, 1, 0, 0, 1, 0],
 "results": [0, 1, 1, 1, 1, 0, 1, 1]
}
const BPM := {"menu":62.0,"explore":72.0,"combat":96.0,"results":84.0}
const PALETTES := {
 "default":[0,0,0,1.0], "deathmatch":[0,0,1,2.0], "teamdeathmatch":[1,0,0,2.0],
 "instagib":[1,0,0,4.0], "rockets":[0,1,0,0.5], "arsenal":[1,0,1,2.0],
 "armsrace":[1,1,0,4.0], "team-elimination":[1,1,0,0.5], "combined-arms":[1,1,1,0.5],
 "ctf":[1,0,0,2.0], "koth":[1,0,1,2.0], "domination":[0,1,0,2.0],
 "assault":[0,0,1,2.0], "payload":[1,1,0,0.5], "holdout":[0,1,1,0.5],
 "uplink":[1,0,0,4.0], "vip-escort":[1,0,0,2.0],
 "horde":[0,1,1,0.5], "juggernaut":[0,1,0,0.5], "campaign":[0,0,1,2.0],
 "cocs":[1,0,1,2.0], "cocs-coop":[1,1,1,0.5],
 "puma-race":[1,0,1,2.0], "puma-soccer":[1,0,1,0.5],
 "storm":[1,1,0,2.0], "night":[1,0,0,0.5], "cold":[0,0,1,2.0], "hot":[0,1,0,0.5]
} # source MUSIC_PALETTES keys/shaker/pluck/rotation (sample timbre rearranged)
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

func _ready() -> void:
 _load_manifests()
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
 if BPM.has(value):
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
 if muted or not announcer_enabled or announcer_volume <= 0.0: announcer_player.stop()

func set_focus(value: bool) -> void:
 focused = value
 if not focused: reset()

func reset() -> void:
 accumulator = 0.0
 running = false
 for player: AudioStreamPlayer in players: player.stop()
 if announcer_player != null: announcer_player.stop()

func start() -> void:
 if focused and error.is_empty(): running = true

func tick(delta: float) -> void:
 if not running or not focused or not music_enabled or music_volume <= 0.0 or muted or error != "": return
 if not is_finite(delta) or delta < 0.0: return
 var step_seconds: float = 60.0 / float(BPM[scene]) / 4.0
 # A suspended frame is discarded rather than replaying minutes of music.
 if delta > 0.3: accumulator = 0.0
 else: accumulator += delta
 var count := 0
 while accumulator >= step_seconds and count < 3:
  accumulator -= step_seconds
  _step_music()
  count += 1
 if count == 3: accumulator = 0.0

func _degree(n: int) -> int:
 return int(SCALE[posmod(n, 7)]) + 12 * int(floor(float(n) / 7.0))

func _hash(n: int) -> int:
 # Deterministic per-bar ornaments: no global RNG / frame-rate dependency.
 var x: int = seed_value ^ (form_bar * 214013) ^ (variation * 2531011) ^ n
 x = (x ^ (x >> 16)) * 1103515245
 return (x ^ (x >> 15)) & 0x7fffffff

func _section() -> String:
 # 8 intro + 8 build + 8 climax + 4 transition + 4 outro.
 var length: int = [32,24,16,8][escalation]
 var position := posmod(form_bar, length)
 var scaled := float(position) * 32.0 / float(length)
 if scaled < 8.0: return "intro"
 if scaled < 16.0: return "build"
 if scaled < 24.0: return "climax"
 if scaled < 28.0: return "transition"
 return "outro"

func _palette() -> Array:
 var result: Array = PALETTES.get(mode_theme, PALETTES.default).duplicate()
 if PALETTES.has(biome):
  var overlay: Array = PALETTES[biome]
  for i in range(3): result[i] = maxi(int(result[i]), int(overlay[i]))
  result[3] = overlay[3]
 return result

func _step_music() -> void:
 var section := _section()
 var chord_index := posmod(form_bar, 8)
 var root: int = ROOT_MIDI + _degree(int(PROGRESSIONS[scene][chord_index]))
 var major: bool = QUALITIES[scene][chord_index] == 1
 var palette := _palette()
 var strong := section == "climax" or intensity > 0.62
 var beat: int = step / 4
 # Chord quality changes the actual third, including borrowed V and Picardy I.
 if step == 0:
  _note("strings-pad", root + 12, 2.6, 0.13, strong)
  _note("strings-pad", root + (4 if major else 3) + 12, 2.2, 0.08, false)
  _note("low-brass", root, 1.9, 0.12, strong)
  if section != "intro": _note("timpani", root, 0.55, 0.13, strong)
  if section == "climax" and form_bar % 4 == 0: _note("cymbal-crash", 60, 1.2, 0.12, true)
  if form_bar % 8 == 0: _note("gong", 60, 1.8, 0.06, false)
 if step == 8:
  _note("strings-pad", root + 19, 1.5, 0.07, false)
  if scene != "menu": _note("taiko", 36, 0.55, 0.15, strong)
 var race := mode_theme == "puma-race" and scene in ["explore", "combat"]
 var soccer := mode_theme == "puma-soccer" and scene in ["explore", "combat"]
 var drum_steps := [0,4,8,12] if race else ([0,8,15] if soccer else ([0,10] if scene == "menu" else [0,6,10] if scene == "explore" else [0,3,8,11]))
 if step in drum_steps:
  if section != "intro" or step == 0: _note("taiko", 36 if step == 0 else 41, 0.4, 0.12, strong)
 if scene == "combat" and (step == 4 or step == 12) and section != "intro":
  _note("low-strings-stacc", root + 12, 0.3, 0.11, strong)
 if section == "climax" and step % 4 == 0:
  _note("brass-stacc", root + (7 if step == 12 else 0), 0.4, 0.10, strong)
 if step % 2 == 0 and section != "intro":
  var arp := [0,2,4,2,3,5,4,2]
  var arp_degree: int = arp[step / 2]
  if step >= 12 and form_bar % 4 == 3: arp_degree = [5,4,2,0][(step-12)/2]
  if _hash(53) % 4 == 0: arp_degree += 7
  var register := 0 if float(palette[3]) <= 0.5 else (24 if float(palette[3]) >= 4.0 else 12)
  _note("harp" if int(palette[2]) > 0 or scene == "menu" else ("bells" if int(palette[0]) > 0 else "strings-pad"), root + _degree(arp_degree) + register, 0.42, 0.05, false)
 if step % 4 == 0 and (section != "intro" or scene == "menu"):
  var index := posmod(form_bar * 4 + beat, 16)
  if scene == "menu": index = posmod(int(floor(float(form_bar * 4 + beat) / 2.0)), 16)
  var degree_value: int = MOTIF[index]
  if form_bar % 8 >= 4: degree_value += 2
  if scene == "combat" and form_bar % 8 >= 4: degree_value = 8 - MOTIF[index]
  if _hash(31) % 5 == 0 and beat == 3: degree_value += 1
  var note: int = root + _degree(degree_value) + 12
  if scene == "results" and posmod(degree_value,7) == 2: note += 1
  _note("trumpet-pad" if strong else "strings-pad", note, 0.7, 0.12, strong)
 if step == 12 and (section == "transition" or section == "outro"):
  _note("tubular-bells", root + 24, 1.0, 0.10, false)
 if step % 2 == 1 and (int(palette[1]) == 1 or race) and section != "intro":
  _note("taiko", 50, 0.18, 0.035, false)
 if step % 4 == 2 and tension > 0.5 and scene == "combat":
  _note("low-strings-stacc", root + 12, 0.2, 0.07 * tension, true)
 step += 1
 if step == 16:
  step = 0
  form_bar += 1

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
  "active_voices":players.filter(func(p: AudioStreamPlayer) -> bool: return p.playing).size(),"announcer_active":announcer_player != null and announcer_player.playing,
  "dropped_notes":dropped_notes,"dropped_cues":dropped_cues,"last_cue_id":last_cue,"last_response":last_response,"outcome":outcome,"error":error}
