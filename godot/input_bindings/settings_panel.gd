extends VBoxContainer
const Model = preload("res://input_bindings/model.gd")
const Access = preload("res://input_bindings/access.gd")
var choices: Dictionary = {}
var rows: Dictionary = {}
var search: LineEdit
var search_status: Label
var changes_summary: Label
var note: Label

func _ready() -> void:
	name = "KeyboardMouseBindings"
	var title := Label.new()
	title.text = "KEYBOARD / MOUSE BINDINGS"
	add_child(title)
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.accessibility_live = DisplayServer.LIVE_POLITE
	note.text = "Live combat and sports controls. Physical keys; modifiers are held actions, not shortcut chords. Choosing an occupied input swaps the two actions. C and middle mouse remain alternate crouch / alt fire. Escape, F3, F12, chat, weapon selection, spectator and mode menus keep their controls."
	add_child(note)
	var search_row := HBoxContainer.new()
	search = LineEdit.new()
	search.name = "BindingSearch"
	search.placeholder_text = "Search actions or current bindings"
	search.clear_button_enabled = true
	search.accessibility_name = "Search keyboard and mouse bindings"
	search.accessibility_description = "Filters the editable actions by action name, stable action ID, or current key/button. Typing does not change bindings."
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(_filter_rows)
	search_row.add_child(search)
	var clear_search := Button.new()
	clear_search.name = "ClearBindingSearch"
	clear_search.text = "Clear"
	clear_search.accessibility_description = "Clear binding search"
	clear_search.pressed.connect(func() -> void: search.clear(); search.grab_focus())
	search_row.add_child(clear_search)
	add_child(search_row)
	search_status = Label.new()
	search_status.accessibility_live = DisplayServer.LIVE_POLITE
	add_child(search_status)
	changes_summary = Label.new()
	changes_summary.name = "BindingChangesSummary"
	changes_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	changes_summary.accessibility_live = DisplayServer.LIVE_POLITE
	add_child(changes_summary)
	for action: String in Model.LABELS:
		var row := VBoxContainer.new()
		row.name = "BindingRow_" + action
		var caption := Label.new()
		caption.text = Model.LABELS[action]
		caption.name = "BindingLabel_" + action
		row.add_child(caption)
		var choice := OptionButton.new()
		choice.name = "Binding_" + action
		choice.focus_mode = Control.FOCUS_ALL
		choice.accessibility_name = caption.text
		choice.custom_minimum_size.y = 36
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.tooltip_text = caption.text + ": physical keyboard key or mouse button"
		for code: String in Model.editable_options():
			choice.add_item(Model.label(code))
			choice.set_item_metadata(choice.item_count - 1, code)
		choice.item_selected.connect(func(index: int) -> void: _apply_choice(action, choice, index))
		choices[action] = choice
		rows[action] = row
		row.add_child(choice)
		add_child(row)
	var reset := Button.new()
	reset.name = "ResetInputBindings"
	reset.text = "Reset all keyboard / mouse bindings"
	reset.custom_minimum_size.y = 40
	reset.tooltip_text = "Restore every keyboard / mouse action to its default, including command, cursor, and voice controls not shown on this page."
	reset.accessibility_description = reset.tooltip_text
	reset.pressed.connect(func() -> void:
		var service := Access.service()
		if service != null:
			note.text = "All keyboard / mouse bindings restored and saved." if service.reset_defaults() else "All defaults applied; could not save preferences."
		refresh())
	add_child(reset)
	var binding_service := Access.service()
	if binding_service != null: binding_service.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var bindings := Access.values()
	var changed_rows: Array[String] = []
	for action: String in choices:
		var choice: OptionButton = choices[action]
		var code: String = bindings[action]
		var changed: bool = code != Model.DEFAULTS[action]
		choice.accessibility_description = "Current binding: " + Model.label(code) + (". Changed from default " + Model.label(Model.DEFAULTS[action]) if changed else ". Default binding") + ". Choosing an occupied input swaps actions."
		if changed: changed_rows.append(Model.LABELS[action] + " (" + action + "): " + Model.label(code) + " · default " + Model.label(Model.DEFAULTS[action]))
		var found := false
		for index in choice.item_count:
			if choice.get_item_metadata(index) == code:
				choice.select(index)
				found = true
				break
		if not found:
			choice.add_item(Model.label(code))
			choice.set_item_metadata(choice.item_count - 1, code)
			choice.select(choice.item_count - 1)
	changes_summary.text = "Modified from defaults: %d of %d editable bindings." % [changed_rows.size(), choices.size()]
	if not changed_rows.is_empty(): changes_summary.text += "\n" + "\n".join(changed_rows)
	_filter_rows(search.text)

func _filter_rows(query: String) -> void:
	var normalized := query.strip_edges().to_lower()
	var shown := 0
	for action: String in rows:
		var searchable := (Model.LABELS[action] + " " + action + " " + Model.label(str(Access.values().get(action, Model.DEFAULTS[action])))).to_lower()
		var matches := normalized.is_empty() or searchable.contains(normalized)
		rows[action].visible = matches
		if matches: shown += 1
	search_status.text = "%d of %d editable actions" % [shown, rows.size()] if normalized.is_empty() or shown > 0 else "No matching bindings. Clear search to show all actions."

func _apply_choice(action: String, choice: OptionButton, index: int) -> void:
	var service := Access.service()
	if service != null:
		var code: String = choice.get_item_metadata(index)
		var swapped := ""
		for other: String in Model.DEFAULTS:
			if other != action and service.values.get(other) == code:
				var other_label: String = Model.LABELS.get(other, "Other profile action ‘" + other + "’ (not editable here)")
				swapped = " Swapped with " + other_label + "."
				break
		var saved: bool = service.set_binding(action, code)
		note.text = ("Binding applied and saved." if saved else "Binding applied for this session; could not save preferences.") + swapped + " Release held inputs before resuming."
	refresh()
	choice.call_deferred("grab_focus")
