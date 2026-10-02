extends VBoxContainer
const Model = preload("res://input_bindings/model.gd")
const Access = preload("res://input_bindings/access.gd")
var choices: Dictionary = {}
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
	for action: String in Model.LABELS:
		var caption := Label.new()
		caption.text = Model.LABELS[action]
		add_child(caption)
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
		choice.item_selected.connect(func(index: int) -> void:
			var service := Access.service()
			if service != null:
				var code: String = choice.get_item_metadata(index)
				var swapped := ""
				for other: String in Model.LABELS:
					if other != action and service.values[other] == code: swapped = " Swapped with " + Model.LABELS[other] + "."
				var saved: bool = service.set_binding(action, code)
				note.text = ("Binding applied and saved." if saved else "Binding applied for this session; could not save preferences.") + swapped + " Release held inputs before resuming."
			refresh())
		choices[action] = choice
		add_child(choice)
	var reset := Button.new()
	reset.name = "ResetInputBindings"
	reset.text = "Reset keyboard / mouse defaults"
	reset.custom_minimum_size.y = 40
	reset.pressed.connect(func() -> void:
		var service := Access.service()
		if service != null:
			note.text = "Default bindings saved." if service.reset_defaults() else "Defaults applied; could not save preferences."
		refresh())
	add_child(reset)
	var binding_service := Access.service()
	if binding_service != null: binding_service.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var bindings := Access.values()
	for action: String in choices:
		var choice: OptionButton = choices[action]
		var code: String = bindings[action]
		choice.accessibility_description = "Current binding: " + Model.label(code) + ". Choosing an occupied input swaps actions."
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
