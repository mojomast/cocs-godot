extends SceneTree
## Export the actual production cached/synthesized dry cues, never substitute audio.
const Audio = preload("res://world/audio_feedback.gd")

func _initialize() -> void:
 var output := OS.get_environment("TRAILER_SFX_OUTPUT")
 if output.is_empty():
  push_error("TRAILER_SFX_OUTPUT required")
  quit(1)
  return
 DirAccess.make_dir_recursive_absolute(output)
 var synth := Audio.new()
 var sounds := {"melee-impact":synth.melee_sound(true), "melee-whoosh":synth.melee_sound(false)}
 sounds["pulse-shot"] = synth._make_sound("shot", synth._cue_seconds("shot", 0), 0)
 sounds["pulse-hit"] = synth._make_sound("hit", synth._cue_seconds("hit", 0), 0)
 sounds["explosion"] = synth._make_sound("explosion", 0.42)
 for name_: String in sounds:
  var error: int = sounds[name_].save_to_wav(output.path_join(name_ + ".wav"))
  if error != OK:
   push_error("SFX export failed: " + name_)
   synth.free()
   quit(1)
   return
  print("TRAILER_PRODUCTION_SFX ", name_)
 synth.free()
 quit(0)
