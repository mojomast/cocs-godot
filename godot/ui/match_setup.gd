extends PanelContainer

# Native capability subset; the locked semantic catalog remains the identity authority.
# This surface is popup-free: map/mode use the shared inline choice row, so no
# OptionButton/PopupMenu window can stay open over the match or fight the game view.
# Escape or "Close setup" dismisses it; Enter or a click on the hint reopens it.
signal start_requested(map_id: String, mode: String)
const Choice = preload("res://ui/lobby_choice.gd")
const MAPS := ["meridian-exchange", "verdant-reliquary", "ember-crucible"]
const MODES := ["deathmatch", "teamdeathmatch", "instagib", "rockets"]
const MODE_NAMES := {"deathmatch":"Deathmatch", "teamdeathmatch":"Team Deathmatch", "instagib":"Instagib", "rockets":"Rocket Arena"}
const DEFAULT_MAP := "meridian-exchange"
const DEFAULT_MODE := "deathmatch"
const STANDALONE := {
	"meridian-exchange":{"domination":"zones", "koth":"zones", "armsrace":"arms-race", "horde":"horde"},
	"verdant-reliquary":{"domination":"zones", "koth":"zones", "armsrace":"arms-race", "horde":"horde"},
	"ember-crucible":{"domination":"zones", "koth":"zones", "armsrace":"arms-race", "horde":"horde"},
	"tidal-citadel":{"ctf":"objectives", "domination":"zones"},
	"sunscar-convoy":{"payload":"objectives", "domination":"zones", "combined-arms":"combined-arms"},
	"asterion-relay":{"cocs":"lattice-world", "cocs-coop":"lattice-world"},
	"monsoon-foundry":{"cocs":"lattice-world", "cocs-coop":"lattice-world"},
	"ion-speedway":{"puma-race":"sports"},
	"aurora-stadium":{"puma-soccer":"sports"},
}
const STATUS_WIDTH := 620
var entries: Dictionary = {}
var map_choice := Choice.new()
var mode_choice := Choice.new()
var status := Label.new()
var start := Button.new()
var close := Button.new()
var body: MarginContainer
var hint := Label.new()
var dismissed := false

func _ready() -> void:
	# configure() is also used before attachment by fixtures/scene builders.
	# The viewport only exists after entering the tree.
	get_viewport().size_changed.connect(center_panel)
	resized.connect(center_panel)
	call_deferred("center_panel")

static func validate(maps: Dictionary, map_id: String, mode: String) -> String:
	if not maps.has(map_id): return "Unknown locked map: " + map_id
	if mode not in maps[map_id].get("modes", []):
		return "Mode '%s' is not supported by %s in the locked catalog." % [mode, map_id]
	var route: String = STANDALONE.get(map_id, {}).get(mode, "")
	if not route.is_empty():
		return "Separate demo. Close this window and relaunch with:\n--experience=%s --map=%s --mode=%s" % [route, map_id, mode]
	if mode == "campaign": return "Campaign remake deferred for planning and research."
	if map_id not in MAPS: return "Native gameplay pending for " + map_id
	if mode not in MODES: return "Native mode pending: " + mode
	return ""

static func parse_args(args: PackedStringArray, maps: Dictionary) -> Dictionary:
	var result := {"map":DEFAULT_MAP, "mode":DEFAULT_MODE, "setup":false, "error":""}
	var explicit_mode := false
	var guest := false
	var index := 0
	while index < args.size():
		var arg: String = args[index]
		if arg == "--setup": result.setup = true
		if arg.begins_with("--join-room="): guest = true
		for key: String in ["map", "mode"]:
			if arg == "--" + key or arg.begins_with("--" + key + "="):
				var value := ""
				if arg == "--" + key:
					index += 1
					if index < args.size() and not args[index].begins_with("--"): value = args[index]
				else:
					value = arg.trim_prefix("--" + key + "=")
				if value.is_empty():
					result.error = "--%s requires a locked %s ID." % [key, key]
					return result
				result[key] = value
				if key == "mode": explicit_mode = true
		index += 1
	if guest and (result.setup or explicit_mode):
		result.error = "--setup and --mode are host options; guests may specify --map to match their host."
	elif result.setup and ("--session-smoke" in args or "--lifecycle-smoke" in args):
		result.error = "--setup cannot be combined with automatic smoke controls."
	else:
		result.error = validate(maps, result.map, result.mode)
	return result

func caption(text: String) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", 15)
	item.add_theme_color_override("font_color", Color("a3b7c9"))
	return item

func configure(maps: Dictionary, map_id: String, mode: String) -> void:
	entries = maps
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(680, 460)
	size = custom_minimum_size
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.055, 0.07, 0.09, 1.0)
	add_theme_stylebox_override("panel", background)
	body = MarginContainer.new()
	for edge: String in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + edge, 24)
	add_child(body)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	body.add_child(box)
	var title := Label.new()
	title.text = "COMBAT SETUP"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var description := Label.new()
	description.text = "Original Node rules · 2 bots · Native infantry controls\nChoose a map and mode, then Start to connect."
	box.add_child(description)
	box.add_child(caption("Map"))
	box.add_child(map_choice)
	for id: String in entries:
		var suffix := "" if id in MAPS else (" — separate demo" if STANDALONE.has(id) else " — pending")
		map_choice.add_item(entries[id].name + suffix)
		map_choice.set_item_metadata(map_choice.item_count - 1, id)
		if id == map_id: map_choice.select(map_choice.item_count - 1)
	box.add_child(caption("Mode"))
	box.add_child(mode_choice)
	box.add_child(status)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(STATUS_WIDTH, 70)
	# An autowrap Label shapes its minimum height at its current width. Pin the
	# content width before the first message, otherwise the initial 1 px wrap can
	# inflate this panel far past the viewport (and over the whole game view).
	status.size = Vector2(STATUS_WIDTH, 70)
	var pending := Label.new()
	pending.text = "Combat: Deathmatch, Team Deathmatch, Instagib and Rocket Arena.\nOther experiences: select an entry for its separate launcher options."
	box.add_child(pending)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	close.text = "Close setup"
	close.custom_minimum_size = Vector2(132, 44)
	close.pressed.connect(func() -> void: dismiss())
	start.text = "Start"
	start.custom_minimum_size.y = 44
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(close)
	actions.add_child(start)
	box.add_child(actions)
	hint.text = "Combat setup closed  ·  Enter or click here to reopen  ·  --map/--mode starts directly"
	hint.add_theme_color_override("font_color", Color("a3b7c9"))
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	hint.hide()
	map_choice.item_selected.connect(func(_index: int) -> void: populate_modes())
	mode_choice.item_selected.connect(func(_index: int) -> void: update_status())
	start.pressed.connect(func() -> void:
		if validate(entries, selected_map(), selected_mode()).is_empty():
			start_requested.emit(selected_map(), selected_mode()))
	populate_modes(mode)
	if is_inside_tree(): call_deferred("settle")

func settle() -> void:
	# Re-fit to the real content after text changes and recenter. Keeps the surface
	# inside the viewport instead of letting a stale measurement dominate it.
	status.size.x = STATUS_WIDTH
	reset_size()
	center_panel()

func dismiss() -> void:
	if dismissed: return
	dismissed = true
	for control: Control in [map_choice, mode_choice, start, close]:
		control.release_focus()
	map_choice.cancel_browse()
	mode_choice.cancel_browse()
	body.hide()
	hint.show()
	# The strip is only a hint: let its click and the world underneath through.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ZERO
	reset_size()
	center_panel()

func reopen() -> void:
	if not dismissed: return
	dismissed = false
	hint.hide()
	body.show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(680, 460)
	settle()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if dismissed:
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER] or event.physical_keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]):
			reopen()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and hint.get_global_rect().has_point(event.position):
			reopen()
			get_viewport().set_input_as_handled()
		return
	if release_key(event): dismiss()

static func release_key(event: InputEvent) -> bool:
	if not event is InputEventKey or event.echo or not event.pressed: return false
	return event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE

func center_panel() -> void:
	if not is_inside_tree(): return
	position = ((get_viewport_rect().size - size) * 0.5).max(Vector2(16, 16))

func selected_map() -> String:
	return str(map_choice.get_selected_metadata())

func selected_mode() -> String:
	return str(mode_choice.get_selected_metadata())

func populate_modes(preferred: String = DEFAULT_MODE) -> void:
	mode_choice.clear()
	for mode: String in entries[selected_map()].modes:
		var pending := selected_map() not in MAPS or mode not in MODES
		var suffix := ""
		if pending:
			suffix = " — separate demo" if STANDALONE.get(selected_map(), {}).has(mode) else (" — deferred" if mode == "campaign" else " — pending")
		mode_choice.add_item(MODE_NAMES.get(mode, mode.capitalize()) + suffix)
		mode_choice.set_item_metadata(mode_choice.item_count - 1, mode)
		if mode == preferred: mode_choice.select(mode_choice.item_count - 1)
	update_status()

func update_status() -> void:
	var problem := validate(entries, selected_map(), selected_mode())
	start.disabled = not problem.is_empty()
	status.text = problem if start.disabled else "Ready: %s / %s\nClick to capture in-game; Esc releases the pointer." % [entries[selected_map()].name, MODE_NAMES.get(selected_mode(), selected_mode())]
	if not start.disabled and selected_mode() == "teamdeathmatch":
		status.text += "\nRed vs Blue · Shared team score · Friendly fire off · Tab: scores"
	if not start.disabled and selected_mode() == "rockets":
		status.text += "\nFree for all · Rocket Launcher · Unlimited ammo · Health / armor supplies"
	if is_inside_tree(): call_deferred("settle")
