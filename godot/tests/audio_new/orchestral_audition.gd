extends SceneTree
## Actual engine output, 72 seconds. Run with a REAL audio driver (not Dummy).
## --output=/absolute/path.wav [--legacy=/absolute/old_music_service.gd]
const Buses = preload("res://audio/buses.gd")
var score: Node
var recording: AudioEffectCapture
var captured := PackedVector2Array()
var elapsed := 0.0
var stage := -1
var output := "/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/orchestral-score/after.wav"
var legacy := ""
var checkpoints := []

func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
  if arg.begins_with("--legacy="): legacy = arg.trim_prefix("--legacy=")
 call_deferred("begin")

func begin() -> void:
 Buses.ensure()
 if AudioServer.get_driver_name() == "Dummy":
  push_error("Use a real, paced audio driver for audition")
  quit(1)
  return
 var script: Script = load(legacy if not legacy.is_empty() else "res://audio/music_service.gd")
 score = script.new()
 root.add_child(score)
 if not score.error.is_empty():
  push_error(score.error)
  quit(1)
  return
 score.set_settings({"music_volume":100,"music_enabled":true,"announcer_enabled":false,"mute":false})
 score.set_mode_theme("campaign")
 score.set_seed(42)
 score.set_scene("explore")
 recording = AudioEffectCapture.new()
 recording.buffer_length = 1.0
 AudioServer.add_bus_effect(AudioServer.get_bus_index("Score"), recording)
 score.start()

func _process(delta: float) -> bool:
 if score == null: return false
 elapsed += delta
 var target_frames := int(72.0 * AudioServer.get_mix_rate())
 var available := mini(recording.get_frames_available(), target_frames - captured.size())
 if available > 0: captured.append_array(recording.get_buffer(available))
 var audio_seconds := float(captured.size()) / AudioServer.get_mix_rate()
 # An ALSA null sink can run unpaced: never record unbounded wall-time PCM or
 # present that accelerated scheduling as an audition. Parent must use a paced
 # PipeWire/PulseAudio/ALSA output for both takes.
 if audio_seconds > elapsed * 1.2 + 0.5 or recording.get_discarded_frames() > 0 or elapsed > 80.0:
  push_error("Audition needs paced, lossless audio output; captured=%f wall=%f" % [audio_seconds, elapsed])
  score.reset()
  quit(1)
  return false
 var next_stage := 0 if elapsed < 18.0 else (1 if elapsed < 36.0 else (2 if elapsed < 54.0 else (3 if elapsed < 66.0 else 4)))
 if next_stage != stage:
  stage = next_stage
  score.set_scene("explore" if stage == 0 else "combat")
  score.set_intensity([0.0, 0.8, 1.0, 1.0, 0.0][stage])
  score.set_tension([0.0, 0.6, 0.9, 1.0, 0.0][stage])
  score.set_escalation([0, 1, 2, 3, 0][stage])
  if score.has_method("set_boss_phase"): score.set_boss_phase([0, 0, 1, 3, 0][stage])
  if stage == 4: score.set_outcome("victory")
  checkpoints.append({"seconds":elapsed,"stage":["exploration","combat","warden","finale","victory"][stage]})
 score.tick(delta)
 if captured.size() == target_frames:
  var pcm := PackedByteArray()
  pcm.resize(captured.size() * 4)
  for i in range(captured.size()):
   pcm.encode_s16(i * 4, roundi(clampf(captured[i].x, -1.0, 1.0) * 32767.0))
   pcm.encode_s16(i * 4 + 2, roundi(clampf(captured[i].y, -1.0, 1.0) * 32767.0))
  var wav := AudioStreamWAV.new()
  wav.format = AudioStreamWAV.FORMAT_16_BITS
  wav.mix_rate = int(AudioServer.get_mix_rate())
  wav.stereo = true
  wav.data = pcm
  DirAccess.make_dir_recursive_absolute(output.get_base_dir())
  assert(wav.save_to_wav(output) == OK)
  var report := FileAccess.open(output + ".json", FileAccess.WRITE)
  report.store_string(JSON.stringify({"legacy":legacy,"seconds":elapsed,"checkpoints":checkpoints,"status":score.status()}, "  "))
  score.reset()
  score.queue_free()
  score = null
  print("ORCHESTRAL_AUDITION_SAVED ", output)
  quit(0)
 return false
