extends Control
## Unified main menu, built entirely in code from res://ui/routes.json
## (schema 1). Popup-free like ui/match_setup.gd: categories, routes and
## options are plain Buttons, the shared ui/lobby_choice.gd row and HSliders —
## no OptionButton/PopupMenu window can outlive a launched route.
## Supervisor markers (run.mjs reads these from the piped child stdout):
##   MENU_READY {"version":1,"routes":22,"categories":5,"debug":false}
##   MENU_ROUTE {"args":["--experience=native-dm","--map=prism-foundry",...]}
##   MENU_QUIT
## --smoke in the user args prints MENU_READY and quits one frame later.

const RouteRegistry = preload("res://ui/route_registry.gd")
const Choice = preload("res://ui/lobby_choice.gd")
const CAPTION := Color("a3b7c9")
const ERROR_INK := Color("e08282")
const PANEL_BG := Color(0.055, 0.07, 0.09, 1.0)
const LABEL_WIDTH := 150

var registry := RouteRegistry.new()
var registry_error := ""
var current_category := ""
var current_route: Dictionary = {}
var selections: Dictionary = {}
var category_buttons: Dictionary = {}
var route_buttons: Dictionary = {}
var choice_rows: Dictionary = {}
var slider_rows: Dictionary = {}
var value_labels: Dictionary = {}
var quitting := false
var categories_box := VBoxContainer.new()
var routes_box := VBoxContainer.new()
var params_box := VBoxContainer.new()
var category_description := Label.new()
var detail_description := Label.new()
var status := Label.new()
var start := Button.new()
var quit_button := Button.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_ui()
	if registry.open():
		populate()
	else:
		push_error("Main menu: " + registry.error)
		registry_error = "Registry unavailable: " + registry.error
		detail_description.text = registry_error
	refresh_status()
	# The supervisor greps this line; it is printed on every path (SPEC §7).
	var payload := {"version": registry.version, "routes": registry.routes.size(),
		"categories": registry.categories.size(), "debug": OS.get_environment("COCS_DEBUG") == "1"}
	print("MENU_READY ", JSON.stringify(payload))
	if "--smoke" in OS.get_cmdline_user_args():
		# One frame of event loop so the marker flushes on headless runs too.
		get_tree().call_deferred("quit", 0)
	if not current_category.is_empty():
		category_buttons[current_category].call_deferred("grab_focus")

func caption(text: String) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", 15)
	item.add_theme_color_override("font_color", CAPTION)
	return item

func build_ui() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = PANEL_BG
	var shell := PanelContainer.new()
	shell.name = "Shell"
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_stylebox_override("panel", background)
	add_child(shell)
	var margins := MarginContainer.new()
	for edge: String in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 24)
	shell.add_child(margins)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margins.add_child(stack)
	var title := Label.new()
	title.name = "Title"
	title.text = "COCS: DESTINATIONS"
	title.add_theme_font_size_override("font_size", 26)
	stack.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.add_theme_constant_override("separation", 28)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)
	var left := VBoxContainer.new()
	left.name = "CategoryColumn"
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size.x = 240
	columns.add_child(left)
	left.add_child(caption("CATEGORIES"))
	left.add_child(categories_box)
	categories_box.add_theme_constant_override("separation", 8)
	category_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	category_description.custom_minimum_size = Vector2(240, 56)
	left.add_child(category_description)
	var right := VBoxContainer.new()
	right.name = "RouteColumn"
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(caption("ROUTES"))
	right.add_child(routes_box)
	routes_box.add_theme_constant_override("separation", 6)
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_description.custom_minimum_size = Vector2(0, 44)
	right.add_child(detail_description)
	right.add_child(caption("OPTIONS"))
	right.add_child(params_box)
	params_box.add_theme_constant_override("separation", 10)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(0, 36)
	right.add_child(status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	start.name = "Start"
	start.text = "START"
	start.custom_minimum_size.y = 44
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.add_theme_font_size_override("font_size", 18)
	start.pressed.connect(func() -> void: on_start())
	quit_button.name = "Quit"
	quit_button.text = "QUIT"
	quit_button.custom_minimum_size = Vector2(150, 44)
	quit_button.add_theme_font_size_override("font_size", 18)
	quit_button.pressed.connect(func() -> void: quit_menu())
	actions.add_child(start)
	actions.add_child(quit_button)
	right.add_child(actions)
	stack.add_child(caption("Tab moves focus · Left/Right or Enter browses a choice · Enter on START launches · Esc quits"))

func populate() -> void:
	for category: Dictionary in registry.categories:
		var id := str(category.get("id", ""))
		var button := Button.new()
		button.name = "Category_" + id
		button.text = str(category.get("label", ""))
		button.toggle_mode = true
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: select_category(id))
		categories_box.add_child(button)
		category_buttons[id] = button
	for route: Dictionary in registry.routes:
		var id := str(route.get("id", ""))
		var button := Button.new()
		button.name = "Route_" + id
		button.text = str(route.get("label", ""))
		button.toggle_mode = true
		button.custom_minimum_size.y = 40
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: select_route(id))
		routes_box.add_child(button)
		route_buttons[id] = button
	if registry.categories.is_empty(): return
	select_category(str(registry.categories[0].get("id", "")))

## Left column pick: show only this category's route buttons (cheats stays
## visible — every declared category is always rendered) and select its first
## route unless the current selection already lives here.
func select_category(id: String) -> void:
	current_category = id
	for key: String in category_buttons:
		category_buttons[key].set_pressed_no_signal(key == id)
	var category: Dictionary = registry.category_by_id(id)
	category_description.text = str(category.get("description", ""))
	for route: Dictionary in registry.routes:
		route_buttons[str(route.get("id", ""))].visible = str(route.get("category", "")) == id
	if not current_route.is_empty() and str(current_route.get("category", "")) == id:
		refresh_status()
		return
	var visible_routes := registry.routes_in_category(id)
	if visible_routes.is_empty():
		clear_route()
		return
	select_route(str(visible_routes[0].get("id", "")))

func select_route(id: String) -> void:
	var route: Dictionary = registry.route_by_id(id)
	if route.is_empty():
		clear_route()
		return
	current_route = route
	for key: String in route_buttons:
		route_buttons[key].set_pressed_no_signal(key == id)
	detail_description.text = str(route.get("description", ""))
	apply_defaults()
	rebuild_params()
	refresh_status()

func clear_route() -> void:
	current_route = {}
	selections = {}
	detail_description.text = ""
	rebuild_params()
	refresh_status()

## Schema defaults: plain choices and ranges first, then everything that
## depends on the map selection (values_by_map choices, max_by_map bounds).
func apply_defaults() -> void:
	selections = {}
	var params := registry.params_of(current_route)
	for param: Dictionary in params:
		var key := str(param.get("key", ""))
		if str(param.get("kind", "")) == "range":
			selections[key] = int(param.get("default", param.get("min", 0)))
		elif not param.get("values_by_map") is Dictionary:
			selections[key] = registry.choice_default(param, "")
	var map_id := str(selections.get(registry.map_param_key(current_route), ""))
	for param: Dictionary in params:
		var key := str(param.get("key", ""))
		if param.get("values_by_map") is Dictionary:
			selections[key] = registry.choice_default(param, map_id)
		elif str(param.get("kind", "")) == "range":
			selections[key] = clampi(int(selections[key]), int(param.get("min", 0)), registry.range_max(param, map_id))
	for toggle: Dictionary in registry.toggles_of(current_route):
		selections[str(toggle.get("key", ""))] = bool(toggle.get("default", false))

func rebuild_params() -> void:
	choice_rows = {}
	slider_rows = {}
	value_labels = {}
	for child: Node in params_box.get_children():
		params_box.remove_child(child)
		child.queue_free()
	if current_route.is_empty(): return
	for param: Dictionary in registry.params_of(current_route):
		if str(param.get("kind", "")) == "choice":
			params_box.add_child(build_choice_row(param))
		else:
			params_box.add_child(build_range_row(param))
	for toggle: Dictionary in registry.toggles_of(current_route):
		var key := str(toggle.get("key", ""))
		var button := CheckButton.new()
		button.text = str(toggle.get("label", key))
		button.button_pressed = bool(selections.get(key, false))
		button.toggled.connect(func(on: bool) -> void:
			selections[key] = on
			refresh_status())
		params_box.add_child(button)

## Popup-free choice row on the shared lobby_choice.gd browse semantics.
func build_choice_row(param: Dictionary) -> Control:
	var key := str(param.get("key", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := caption(str(param.get("label", key)))
	label.custom_minimum_size.x = LABEL_WIDTH
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var picker := Choice.new()
	var map_id := str(selections.get(registry.map_param_key(current_route), ""))
	var values := registry.choice_values(param, map_id)
	for value: Variant in values:
		picker.add_item(registry.display_value(str(value)))
		picker.set_item_metadata(picker.item_count - 1, str(value))
	picker.select(values.find(selections.get(key, "")))
	picker.item_selected.connect(func(index: int) -> void:
		selections[key] = str(picker.get_item_metadata(index))
		if key == "operator" and selections[key] == "claude" and str(current_route.get("id", "")).contains("horde"):
			# The pinned source locks Claude to Claude Code. Select the legal
			# harness in the menu rather than launching an invalid local session.
			selections["harness"] = "claudecode"
			var harness_picker: Variant = choice_rows.get("harness")
			if harness_picker != null:
				for item in harness_picker.item_count:
					if harness_picker.get_item_metadata(item) == "claudecode":
						harness_picker.select(item)
						break
		if key == registry.map_param_key(current_route): rederive_for_map()
		refresh_status())
	row.add_child(picker)
	choice_rows[key] = picker
	return row

## HSlider with an integer snap plus a live value label, honouring min/max/
## step and the map's max_by_map bound.
func build_range_row(param: Dictionary) -> Control:
	var key := str(param.get("key", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := caption(str(param.get("label", key)))
	label.custom_minimum_size.x = LABEL_WIDTH
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var slider := HSlider.new()
	var map_id := str(selections.get(registry.map_param_key(current_route), ""))
	slider.min_value = int(param.get("min", 0))
	slider.max_value = registry.range_max(param, map_id)
	slider.step = maxi(1, int(param.get("step", 1)))
	slider.value = float(int(selections.get(key, int(param.get("min", 0)))))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(200, 24)
	var value_label := Label.new()
	value_label.text = str(int(slider.value))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value_label.custom_minimum_size.x = 56
	value_label.add_theme_color_override("font_color", CAPTION)
	slider.value_changed.connect(func(value: float) -> void:
		selections[key] = int(round(value))
		value_label.text = str(int(round(value)))
		refresh_status())
	row.add_child(slider)
	row.add_child(value_label)
	slider_rows[key] = slider
	value_labels[key] = value_label
	return row

## The map changed: re-derive every values_by_map choice (SPEC re-selects the
## mode) and re-clamp every max_by_map slider to the new bound.
func rederive_for_map() -> void:
	var map_key := registry.map_param_key(current_route)
	var map_id := str(selections.get(map_key, ""))
	for param: Dictionary in registry.params_of(current_route):
		var key := str(param.get("key", ""))
		if key == map_key: continue
		if str(param.get("kind", "")) == "choice" and param.get("values_by_map") is Dictionary:
			var picker: Variant = choice_rows.get(key)
			if picker == null: continue
			var values := registry.choice_values(param, map_id)
			picker.clear()
			for value: Variant in values:
				picker.add_item(registry.display_value(str(value)))
				picker.set_item_metadata(picker.item_count - 1, str(value))
			# Re-selects to the fresh list's entry (allowed[0] on untouched rows).
			var pick := registry.choice_default(param, map_id)
			selections[key] = pick
			picker.select(values.find(pick))
		elif str(param.get("kind", "")) == "range" and param.get("max_by_map") is Dictionary:
			var slider: Variant = slider_rows.get(key)
			if slider == null: continue
			var low := int(param.get("min", 0))
			var high := registry.range_max(param, map_id)
			var clamped := clampi(int(selections.get(key, low)), low, high)
			slider.max_value = high
			slider.value = clamped
			selections[key] = clamped
			var value_label: Variant = value_labels.get(key)
			if value_label != null: value_label.text = str(clamped)
	refresh_status()

## Defense in depth: START stays disabled while any selection sits outside
## the JSON bounds.
func refresh_status() -> void:
	if not registry_error.is_empty():
		start.disabled = true
		status.text = registry_error
		status.add_theme_color_override("font_color", ERROR_INK)
		return
	if current_route.is_empty():
		start.disabled = true
		status.text = "Select a destination to see its options."
		status.add_theme_color_override("font_color", CAPTION)
		return
	var problem := registry.validate_route(current_route, selections)
	start.disabled = not problem.is_empty()
	if problem.is_empty():
		status.text = "Ready · START launches with every option above."
		status.add_theme_color_override("font_color", CAPTION)
	else:
		status.text = problem
		status.add_theme_color_override("font_color", ERROR_INK)

func on_start() -> void:
	if start.disabled or quitting: return
	var problem := registry.validate_route(current_route, selections)
	if not problem.is_empty():
		refresh_status()
		return
	var args := registry.assemble_args(current_route, selections)
	print("MENU_ROUTE ", JSON.stringify({"args": args}))
	get_tree().call_deferred("quit", 0)

func quit_menu() -> void:
	if quitting: return
	quitting = true
	print("MENU_QUIT")
	# Deferred like START so the marker line flushes before the pipe closes.
	get_tree().call_deferred("quit", 0)

func _unhandled_input(event: InputEvent) -> void:
	if quitting: return
	if release_key(event):
		quit_menu()
		get_viewport().set_input_as_handled()

static func release_key(event: InputEvent) -> bool:
	if not event is InputEventKey or event.echo or not event.pressed: return false
	return event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE
