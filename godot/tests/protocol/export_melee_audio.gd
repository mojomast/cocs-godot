extends SceneTree
## Export the exact cached dry PCM for human audition; no renderer or game fixture.
## Run only when an engine slot is available. Files go to Godot's user directory.
const Audio = preload("res://world/audio_feedback.gd")

func _initialize() -> void:
	var synth := Audio.new()
	for impact: bool in [false, true]:
		var path := "user://melee-%s.wav" % ("impact" if impact else "whoosh")
		var error := synth.melee_sound(impact).save_to_wav(path)
		if error != OK:
			push_error("Melee WAV export failed: %s" % error)
			synth.free()
			quit(1)
			return
		print(ProjectSettings.globalize_path(path))
	synth.free()
	quit(0)
