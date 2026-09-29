extends RefCounted
## Godot's dynamic buses remain children of Master; no independent master gain.
static func ensure() -> void:
	for name: String in ["Effects", "Score", "Ambience", "Announcer"]:
		if AudioServer.get_bus_index(name) >= 0: continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, name)
		AudioServer.set_bus_send(index, "Master")

static func apply(settings: Dictionary) -> void:
	ensure()
	var forced_mute := "--mute" in OS.get_cmdline_user_args() or "--mute-capture" in OS.get_cmdline_user_args()
	for row: Array in [["Effects", "effects_volume", true], ["Score", "music_volume", settings.get("music_enabled", true)],
		["Ambience", "ambience_volume", settings.get("ambience_enabled", true)], ["Announcer", "announcer_volume", settings.get("announcer_enabled", false)]]:
		var index := AudioServer.get_bus_index(str(row[0]))
		var value: Variant = settings.get(row[1], 100)
		var level := clampf(float(value) / 100.0, 0.0, 1.0) if value is int or value is float else 1.0
		# Player-local gain owns new services; only the legacy combat pool needs
		# this bus gain. Never apply its slider twice to the new players.
		AudioServer.set_bus_volume_linear(index, level if row[0] == "Effects" else 1.0)
		AudioServer.set_bus_mute(index, forced_mute or settings.get("mute", false) == true or row[2] != true or level <= 0.0)
