extends SceneTree
const Settings = preload("res://ui/local_settings.gd")

func _initialize() -> void:
	var old := Settings.normalize({"master_volume":77,"mouse_sensitivity":120,"ui_scale":90,"mute":false})
	assert(old.master_volume == 77 and old.music_enabled and old.ambience_enabled)
	assert(not old.announcer_enabled, "opt-in recorded voice")
	var wrong := Settings.normalize({"music_volume":INF,"effects_volume":-10,"announcer_volume":300,"weather_quality":"high","weather_enabled":"yes","reduced_motion":true})
	assert(wrong.music_volume == 100 and wrong.effects_volume == 0 and wrong.announcer_volume == 100)
	assert(wrong.weather_quality == 100 and wrong.weather_enabled and wrong.reduced_motion)
	var settings := Settings.new()
	root.add_child(settings)
	assert(settings.rows.has("music_volume") and settings.rows.has("weather_quality") and settings.rows.has("lightning_flashes"))
	assert(settings.panel.find_child("SettingsBack", true, false) != null)
	settings.free()
	print("AUDIO_SETTINGS_OK")
	quit()
