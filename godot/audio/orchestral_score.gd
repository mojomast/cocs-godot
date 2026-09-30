extends Node
## Four PCM stems share ONE audio clock. No per-frame note scheduling, decoding,
## randomized harmony or independent loop players. All gain targets are <= 1.
const LAYERS := ["strings", "motion", "brass", "warden"]
const RATE := 32000
const FRAMES := 1536000
const BAR_SECONDS := 3.0
const LENGTH := 48.0
var player: AudioStreamPlayer
var synchronized: AudioStreamSynchronized
var gains := [0.0, 0.0, 0.0, 0.0]
var targets := [0.0, 0.0, 0.0, 0.0]
var bytes := 0
var error := ""
var last_bar := -1
var phase := 0.0

func _ready() -> void:
 player = AudioStreamPlayer.new()
 player.name = "OrchestralScore"
 player.bus = &"Score"
 add_child(player)
 synchronized = AudioStreamSynchronized.new()
 synchronized.stream_count = LAYERS.size()
 for i in range(LAYERS.size()):
  var path := "res://audio/music/orchestral/%s.wav" % LAYERS[i]
  if not ResourceLoader.exists(path):
   error = "Orchestral stems missing: run tools/godot-audiovisual/orchestral_score.py"
   return
  var stream: AudioStreamWAV = load(path) as AudioStreamWAV
  if stream == null or stream.mix_rate != RATE or not stream.stereo or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.data.size() != FRAMES * 4:
   error = "Orchestral stem format/phase mismatch: " + path
   return
  stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
  stream.loop_begin = 0
  stream.loop_end = FRAMES
  bytes += stream.data.size()
  synchronized.set_sync_stream(i, stream)
  synchronized.set_sync_stream_volume(i, -80.0)
 player.stream = synchronized

func stop() -> void:
 if player != null: player.stop()
 gains = [0.0, 0.0, 0.0, 0.0]
 targets = [0.0, 0.0, 0.0, 0.0]
 last_bar = -1
 phase = 0.0

func _exit_tree() -> void:
 preload("res://audio/playback_cleanup.gd").release(player)
 synchronized = null

func mix_targets(scene: String, intensity: float, tension: float, escalation: int, boss_phase: int, outcome: String) -> Array:
 if scene == "results":
  return [0.65, 0.0, 0.18 if outcome == "defeat" else 0.65, 0.0]
 if scene == "menu": return [0.85, 0.0, 0.35, 0.0]
 var battle := scene == "combat" or boss_phase > 0
 var drive := clampf(maxf(intensity, tension * 0.65), 0.0, 1.0)
 if not battle: return [0.72, 0.0, 0.0, 0.0]
 var finale := clampf(float(boss_phase) / 3.0, 0.0, 1.0)
 if escalation >= 3: finale = maxf(finale, 0.65)
 return [0.95, 0.60 + drive * 0.40, 0.70 + drive * 0.30, finale]

func tick(delta: float, scene: String, intensity: float, tension: float, escalation: int, boss_phase: int, outcome: String, volume: float) -> void:
 if not error.is_empty() or not is_finite(delta) or delta < 0.0: return
 if not player.playing:
  # Install all gains before playback; resume starts a fresh phrase together.
  targets = mix_targets(scene, intensity, tension, escalation, boss_phase, outcome)
  for i in range(LAYERS.size()): synchronized.set_sync_stream_volume(i, -80.0)
  player.volume_db = linear_to_db(maxf(volume, 0.0001))
  player.play()
 phase = fposmod(player.get_playback_position(), LENGTH)
 var bar := int(phase / BAR_SECONDS)
 # Gameplay changes enter on the next bar, <=3s latency. Releases take two
 # beats; attacking combat layers take one beat. No tempo/phase reset.
 if bar != last_bar:
  targets = mix_targets(scene, intensity, tension, escalation, boss_phase, outcome)
  last_bar = bar
 for i in range(LAYERS.size()):
  var seconds := 0.75 if targets[i] > gains[i] else 1.5
  gains[i] = move_toward(float(gains[i]), float(targets[i]), minf(delta, 0.1) / seconds)
  synchronized.set_sync_stream_volume(i, linear_to_db(maxf(float(gains[i]), 0.0001)))
 player.volume_db = linear_to_db(maxf(volume, 0.0001))

func status() -> Dictionary:
 return {"playing":player != null and player.playing, "phase":phase,
  "bar":int(phase / BAR_SECONDS), "gains":gains.duplicate(),
  "targets":targets.duplicate(), "pcm_bytes":bytes, "error":error}
