extends HBoxContainer
# Lobby-only inline choice. No popup windows or engine Popup signal lifecycle.
signal item_selected(index: int)

var previous := Button.new()
var current_label := Label.new()
var next := Button.new()
var items: Array[Dictionary] = []
var _selected := -1
var selected: int:
	get: return _selected
	set(value): select(value)
var item_count: int:
	get: return items.size()
var text: String:
	get: return get_item_text(_selected)
var disabled := false:
	set(value):
		disabled = value
		refresh()

func _init() -> void:
	custom_minimum_size.y = 36
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	previous.text = "‹ Previous"
	next.text = "Next ›"
	current_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	current_label.clip_text = true
	current_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	current_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Control in [previous, current_label, next]: add_child(child)
	previous.pressed.connect(func() -> void: cycle(-1))
	next.pressed.connect(func() -> void: cycle(1))
	for button: Button in [previous, next]:
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventKey: _gui_input(event))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	tooltip_text = "Previous / Next or Left / Right to choose. Tab moves focus."
	refresh()

func _draw() -> void:
	if has_focus(): draw_style_box(get_theme_stylebox("focus", "Button"), Rect2(Vector2.ZERO, size))

func _gui_input(event: InputEvent) -> void:
	if disabled or items.size() < 2: return
	if event.is_action_pressed("ui_left"):
		cycle(-1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		cycle(1)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()

func cycle(direction: int) -> void:
	if disabled or items.size() < 2: return
	select(posmod(_selected + direction, items.size()))
	item_selected.emit(_selected)

func refresh() -> void:
	var interactive := not disabled and items.size() > 1
	focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	for button: Button in [previous, next]:
		button.disabled = not interactive
		button.focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	current_label.text = "%s  (%d/%d)" % [text, _selected + 1, items.size()] if _selected >= 0 else "No choices"
	current_label.modulate = Color(1,1,1,0.5) if disabled else Color.WHITE
	current_label.tooltip_text = text
	previous.tooltip_text = "Previous choice · Left arrow"
	next.tooltip_text = "Next choice · Right arrow"
	queue_redraw()

func clear() -> void:
	items.clear()
	_selected = -1
	refresh()

func add_item(label: String) -> void:
	items.append({"text":label,"metadata":null})
	if _selected < 0: _selected = 0
	refresh()

func select(index: int) -> void:
	if index < -1 or index >= items.size(): return
	_selected = index
	refresh() # Programmatic selection, like OptionButton.select, emits no signal.

func get_item_text(index: int) -> String:
	return str(items[index].text) if index >= 0 and index < items.size() else ""

func set_item_metadata(index: int, value: Variant) -> void:
	if index >= 0 and index < items.size(): items[index].metadata = value

func get_item_metadata(index: int) -> Variant:
	return items[index].metadata if index >= 0 and index < items.size() else null

func get_selected_metadata() -> Variant:
	return get_item_metadata(_selected)
