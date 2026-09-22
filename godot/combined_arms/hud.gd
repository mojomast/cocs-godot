extends Control
var title := Label.new()
var info := Label.new()
var help := Label.new()
var prompt := Label.new()
var aim := Label.new()
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label in [title, info, help, prompt, aim]:
		add_child(label)
		label.add_theme_color_override("font_color", Color("f9eed7"))
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.position = Vector2(20, 16)
	title.add_theme_font_size_override("font_size", 24)
	info.position = Vector2(20, 50)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 20
	help.offset_top = -96
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -200
	prompt.offset_right = 200
	prompt.offset_top = -155
	prompt.offset_bottom = -120
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 22)
	aim.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	aim.offset_left = -10
	aim.offset_right = 10
	aim.offset_top = -12
	aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim.text = "+"

func update(a: Dictionary, v: Dictionary, near: Dictionary, engaged: bool, phase: String, age: float, error: String) -> void:
	title.text = "SUNSCAR CONVOY  /  COMBINED ARMS"
	var mounted := not v.is_empty()
	aim.visible = not mounted and engaged
	info.text = "Infantry  •  HP %.0f  •  Team %s" % [a.get("health", 0), a.get("team", "—")]
	if mounted:
		info.text = "%s / %s  •  %.1f m/s  •  Hull %.0f / %.0f  •  Heat %.0f%%" % [str(v.kind).to_upper(), a.get("vehicleSeat", ""), Vector2(v.vx, v.vz).length(), v.health, v.get("maxHealth", 300), float(v.get("heat", 0))*100]
	help.text = "WASD move  •  Mouse look / LMB fire  •  E mount / exit\nSpace %s  •  Shift %s\nEnter capture controls  •  Esc release  •  Fresh Enter + keys after seat change" % ["brake tap" if mounted else "jump", "boost" if mounted else "sprint"]
	if mounted and (v.kind != "puma" or a.get("vehicleSeat") != "driver"):
		help.text = "Preview seat — Puma driver is the supported driving slice\nEnter then E to exit  •  Esc release"
	prompt.text = "E  •  Exit vehicle" if mounted else ("E  •  Board %s" % str(near.kind).to_upper() if not near.is_empty() else "")
	if phase != "active": prompt.text = error if not error.is_empty() else phase.capitalize()
	elif age >= 0.5: prompt.text = "Snapshots stale — controls released"
	elif not engaged: prompt.text = "Enter  •  Capture fresh controls"
