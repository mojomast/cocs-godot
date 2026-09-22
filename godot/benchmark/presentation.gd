extends CanvasLayer
## Popup-free benchmark presentation: one label, no input handling, no HUD
## ownership. Progress is shown while the scripted plan runs and the saved result
## stays visible long enough to read the artifact name.
var text := Label.new()

func _ready() -> void:
	layer = 7
	add_child(text)
	# Below the game's own top-left map/mode line and the F7/F9/F10 quality hint,
	# above the combat feedback labels, so no existing HUD text is covered.
	text.position = Vector2(20, 112)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_color_override("font_color", Color("ffe6a6"))
	text.add_theme_color_override("font_shadow_color", Color.BLACK)
	text.add_theme_constant_override("shadow_offset_x", 2)
	text.add_theme_constant_override("shadow_offset_y", 2)
	text.add_theme_font_size_override("font_size", 15)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.hide()

func _layout() -> void:
	var viewport := get_viewport()
	if viewport == null: return
	var rect := viewport.get_visible_rect().size
	text.size = Vector2(maxf(240, rect.x - 40), 120)
	text.clip_text = true

func message(value: String) -> void:
	_layout()
	text.text = value
	text.show()

func progress(index: int, count: int, name: String, remaining: float, level: String) -> void:
	message("BENCHMARK %d/%d %s · %.1fs left · effects %s\nF7 benchmark · F9 quality · F10 metrics" % [index + 1, count, name, maxf(remaining, 0.0), level])

func result(summary: Dictionary) -> void:
	message(str(summary.get("text", "BENCHMARK complete")))

func hide_text() -> void:
	text.hide()
