extends HBoxContainer
# Shared inline choice for the lobby and the combat setup. It never creates an
# OptionButton, PopupMenu or popup Window, so no engine popup lifecycle can stay
# open after the surface that owns it is hidden or a match starts.
#
# Keys: Left/Right cycle and select while the row or either button has focus.
# Space/Enter on the row opens a window-free browse, Up/Down move the highlighted
# entry, Enter/Space confirms and Escape cancels. Tab/Shift-Tab keep normal focus
# traversal. Programmatic selection stays silent.
signal item_selected(index: int)

var previous := Button.new()
var current_label := Label.new()
var next := Button.new()
var items: Array[Dictionary] = []
var _selected := -1
var _disabled := false
var browse := false
var browse_index := -1
# Diagnostic/observer counter: increments only when refresh() actually applies a
# new visual state. Repeated no-op assignments (same disabled, same selection)
# leave it untouched, so a per-frame owner can assign freely without churn.
var update_count := 0
var _rendered_state := ""
var selected: int:
	get: return _selected
	set(value): select(value)
var item_count: int:
	get: return items.size()
var text: String:
	get: return get_item_text(_selected)
# Idempotent property: assigning the value it already holds performs no work.
var disabled: bool:
	get: return _disabled
	set(value):
		if value == _disabled: return
		_disabled = value
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
	focus_exited.connect(_on_focus_exited)
	refresh()

func _on_focus_exited() -> void:
	cancel_browse()
	queue_redraw()

func _draw() -> void:
	if has_focus(): draw_style_box(get_theme_stylebox("focus", "Button"), Rect2(Vector2.ZERO, size))

func _gui_input(event: InputEvent) -> void:
	if disabled or items.size() < 2: return
	# Key events also arrive here forwarded from the focused Previous/Next button;
	# only the row itself owns the browse keys so buttons keep their activation.
	var row_focused := has_focus()
	if event.is_action_pressed("ui_left"):
		cancel_browse()
		cycle(-1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		cancel_browse()
		cycle(1)
		accept_event()
	elif row_focused and event.is_action_pressed("ui_accept"):
		if browse: confirm_browse()
		else: begin_browse()
		accept_event()
	elif row_focused and (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down")):
		if browse:
			move_browse(-1 if event.is_action_pressed("ui_up") else 1)
			accept_event()
	elif row_focused and event.is_action_pressed("ui_cancel"):
		cancel_browse()
		# The focused inline chooser owns Cancel even outside browse mode.
		# Letting it bubble opens the global settings overlay and loses focus.
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cancel_browse()
		grab_focus()

func begin_browse() -> void:
	browse = true
	browse_index = maxi(_selected, 0)
	refresh()

func move_browse(step: int) -> void:
	browse_index = posmod(browse_index + step, items.size())
	refresh()

func confirm_browse() -> void:
	var index := browse_index
	cancel_browse()
	select(index)
	item_selected.emit(index)

func cancel_browse() -> void:
	if not browse: return
	browse = false
	browse_index = -1
	refresh()

func cycle(direction: int) -> void:
	if disabled or items.size() < 2: return
	select(posmod(_selected + direction, items.size()))
	item_selected.emit(_selected)

func refresh() -> void:
	var interactive := not _disabled and items.size() > 1
	var index: int = browse_index if browse else _selected
	# Single value-of-record for everything refresh() draws. When it is unchanged
	# the whole body is skipped, so a per-frame caller cannot repaint, rebuild
	# tooltips or steal focus while the user is typing or navigating.
	var label_text := "No choices"
	if index >= 0:
		label_text = "%s%s  (%d/%d)" % ["▸ " if browse else "", get_item_text(index), index + 1, items.size()]
	var state := "%d:%d:%d:%d:%s" % [int(_disabled), int(interactive), index, int(browse), label_text]
	if state == _rendered_state:
		return
	_rendered_state = state
	update_count += 1
	focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	for button: Button in [previous, next]:
		button.disabled = not interactive
		button.focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	current_label.text = label_text
	current_label.modulate = Color(1,1,1,0.5) if _disabled else Color.WHITE
	current_label.tooltip_text = get_item_text(index)
	previous.tooltip_text = "Previous choice · Left arrow"
	next.tooltip_text = "Next choice · Right arrow"
	tooltip_text = "Up / Down choose · Enter confirms · Escape cancels" if browse else "Previous / Next or Left / Right to choose. Tab moves focus."
	queue_redraw()

func clear() -> void:
	items.clear()
	_selected = -1
	cancel_browse()
	refresh()

func add_item(label: String) -> void:
	items.append({"text":label,"metadata":null})
	if _selected < 0: _selected = 0
	refresh()

func select(index: int) -> void:
	if index < -1 or index >= items.size(): return
	# Selecting the already-active entry with no browse open changes nothing;
	# skip the render so a per-frame owner can re-assert the same index safely.
	if _selected == index and not browse: return
	_selected = index
	browse = false
	browse_index = -1
	refresh() # Programmatic selection, like OptionButton.select, emits no signal.

func get_item_text(index: int) -> String:
	return str(items[index].text) if index >= 0 and index < items.size() else ""

func set_item_metadata(index: int, value: Variant) -> void:
	if index >= 0 and index < items.size(): items[index].metadata = value

func get_item_metadata(index: int) -> Variant:
	return items[index].metadata if index >= 0 and index < items.size() else null

func get_selected_metadata() -> Variant:
	return get_item_metadata(_selected)
