extends CanvasLayer
## Popup-free in-match controls. The effect owners provide actual resource metrics.
signal quality_changed(level: int)
const LEVELS := ["Low", "High", "Extreme"]
var quality := 1
var active := false
var telemetry := false
var remaining := 0.0
var metrics: Dictionary = {}
var text := Label.new()

func _ready() -> void:
	layer = 5
	add_child(text)
	text.position = Vector2(20, 70)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_color_override("font_color", Color("b4e9ff"))
	text.add_theme_color_override("font_shadow_color", Color.BLACK)
	text.add_theme_constant_override("shadow_offset_x", 2)
	text.add_theme_constant_override("shadow_offset_y", 2)
	text.add_theme_font_size_override("font_size", 14)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()

func _layout() -> void:
	# Teardown emits size changes after the layer leaves the tree; a freed window
	# has no viewport and must never raise a script error during cleanup.
	var viewport := get_viewport()
	if viewport == null: return
	text.size.x = maxf(200, viewport.get_visible_rect().size.x - 40)

func set_active(value: bool) -> void:
	if value and not active: remaining = 4.0
	active = value
	_refresh()

func set_metrics(value: Dictionary) -> void:
	metrics = value.duplicate(true)
	_refresh()

func select_quality(value: int) -> void:
	var next := clampi(value, 0, LEVELS.size()-1)
	if next != quality:
		quality = next
		quality_changed.emit(quality)
	remaining = 4.0
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F9:
		select_quality((quality + 1) % LEVELS.size())
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F10:
		telemetry = not telemetry
		_refresh()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	remaining = maxf(0,remaining-delta)
	if remaining == 0 and not telemetry: text.hide()

func _refresh() -> void:
	text.visible = active and (remaining > 0 or telemetry)
	text.text = "Combat effects: %s · F9 quality · F10 metrics" % LEVELS[quality]
	if telemetry:
		for key: String in metrics:
			var value: Variant = metrics[key]
			if value is int or value is float or value is String:
				text.text += "\n%s: %s" % [key, str(value).left(120)]
