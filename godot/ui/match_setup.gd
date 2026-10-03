extends PanelContainer

# Native capability subset; the locked semantic catalog remains the identity authority.
# This surface is popup-free: map/mode use the shared inline choice row, so no
# OptionButton/PopupMenu window can stay open over the match or fight the game view.
# Escape or "Close setup" dismisses it; Enter or a click on the hint reopens it.
signal start_requested(map_id: String, mode: String)
signal loadout_changed(character: String, harness: String)
const Choice = preload("res://ui/lobby_choice.gd")
const Loadout = preload("res://ui/loadout.gd")
const MAPS := ["meridian-exchange", "verdant-reliquary", "ember-crucible"]
const MODES := ["deathmatch", "teamdeathmatch", "instagib", "rockets"]
const MODE_NAMES := {"deathmatch":"Deathmatch", "teamdeathmatch":"Team Deathmatch", "instagib":"Instagib", "rockets":"Rocket Arena"}
const DEFAULT_MAP := "meridian-exchange"
const DEFAULT_MODE := "deathmatch"
const STANDALONE := {
	"meridian-exchange":{"arsenal":"mode-expansion", "juggernaut":"mode-expansion", "domination":"zones", "koth":"zones", "uplink":"zones", "holdout":"zones", "armsrace":"arms-race", "horde":"horde"},
	"verdant-reliquary":{"arsenal":"mode-expansion", "juggernaut":"mode-expansion", "domination":"zones", "koth":"zones", "uplink":"zones", "holdout":"zones", "armsrace":"arms-race", "horde":"horde"},
	"ember-crucible":{"arsenal":"mode-expansion", "juggernaut":"mode-expansion", "domination":"zones", "koth":"zones", "uplink":"zones", "holdout":"zones", "armsrace":"arms-race", "horde":"horde"},
	"tidal-citadel":{"team-elimination":"mode-expansion", "ctf":"objectives", "domination":"zones", "assault":"assault"},
	"sunscar-convoy":{"vip-escort":"mode-expansion", "payload":"objectives", "domination":"zones", "assault":"assault", "combined-arms":"combined-arms"},
	"asterion-relay":{"cocs":"lattice-world", "cocs-coop":"lattice-world"},
	"monsoon-foundry":{"cocs":"lattice-world", "cocs-coop":"lattice-world"},
	"ion-speedway":{"puma-race":"sports"},
	"aurora-stadium":{"puma-soccer":"sports"},
}
const STATUS_WIDTH := 620
var entries: Dictionary = {}
var map_choice := Choice.new()
var mode_choice := Choice.new()
var operator_choice := Choice.new()
var harness_choice := Choice.new()
var status := Label.new()
var start := Button.new()
var close := Button.new()
var body: MarginContainer
var hint := Label.new()
var dismissed := false
# Original locked-catalog failure text when the owner has one, so an empty
# registry reports the real reason instead of a generic guess.
var catalog_error := ""
# Fingerprint of the read-only catalog projection last rendered into the map
# row. A same-size replacement that changes ids/names/modes still differs here.
var catalog_fingerprint := ""

func _ready() -> void:
	# configure() is also used before attachment by fixtures/scene builders.
	# The viewport only exists after entering the tree.
	get_viewport().size_changed.connect(center_panel)
	resized.connect(center_panel)
	call_deferred("center_panel")

static func validate(maps: Dictionary, map_id: String, mode: String) -> String:
	if not maps.has(map_id): return "Unknown locked map: " + map_id
	var entry: Variant = maps[map_id]
	if not entry is Dictionary: return "Malformed locked catalog entry: " + map_id
	if mode not in valid_modes(entry):
		return "Mode '%s' is not supported by %s in the locked catalog." % [mode, map_id]
	var route: String = STANDALONE.get(map_id, {}).get(mode, "")
	if not route.is_empty():
		return "Separate demo. Close this window and relaunch with:\n--experience=%s --map=%s --mode=%s" % [route, map_id, mode]
	if mode == "campaign": return "Play The Quiet Relay from the main menu: four linked campaign chapters."
	if map_id not in MAPS: return "Native gameplay pending for " + map_id
	if mode not in MODES: return "Native mode pending: " + mode
	return ""

# The mode ids the locked catalog actually advertises for one entry. Non-string,
# empty, over-long or control-bearing elements are dropped, duplicates collapse
# and order is preserved. This is a read-only projection: a malformed `modes`
# value never invents a mode and never raises an invalid-dictionary error, and
# the shared catalog is never mutated.
static func valid_modes(entry: Variant) -> Array:
	var result: Array = []
	if not entry is Dictionary: return result
	var raw: Variant = entry.get("modes", [])
	if not raw is Array: return result
	for value: Variant in raw:
		if not value is String: continue
		var mode := str(value).strip_edges()
		if mode.is_empty() or mode.length() > 64: continue
		var control := false
		for index: int in mode.length():
			var code: int = mode.unicode_at(index)
			if code <= 0x1f or code == 0x7f:
				control = true
				break
		if control or mode in result: continue
		result.append(mode)
	return result

static func parse_args(args: PackedStringArray, maps: Dictionary) -> Dictionary:
	var result := {"map":DEFAULT_MAP, "mode":DEFAULT_MODE, "operator":Loadout.DEFAULT_CHARACTER, "harness":Loadout.DEFAULT_HARNESS, "bots":2, "setup":false, "error":""}
	var explicit_mode := false
	var explicit_harness := false
	var explicit_bots := false
	var guest := false
	var index := 0
	while index < args.size():
		var arg: String = args[index]
		if arg == "--setup": result.setup = true
		if arg.begins_with("--join-room="): guest = true
		if arg == "--bots" or arg.begins_with("--bots="):
			var count := arg.trim_prefix("--bots=") if arg.begins_with("--bots=") else ""
			if explicit_bots or not count.is_valid_int() or count.to_int() < 0 or count.to_int() > 8:
				result.error = "--bots requires one local count from 0..8."
				return result
			result.bots = count.to_int()
			explicit_bots = true
		for key: String in ["map", "mode", "operator", "harness"]:
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
				if key == "harness": explicit_harness = true
		index += 1
	# The documented claude lock is resolution, not user error; an explicitly
	# conflicting pair is still rejected. Unknown ids always fail loudly.
	if not explicit_harness and result.operator == Loadout.LOCKED_CHARACTER:
		result.harness = Loadout.LOCKED_HARNESS
	var loadout_problem := Loadout.problem(result.operator, result.harness)
	if not loadout_problem.is_empty():
		result.error = "Operator/harness selection rejected: " + loadout_problem
		return result
	var pair: Dictionary = Loadout.resolve(result.operator, result.harness)
	result.operator = pair.character
	result.harness = pair.harness
	if explicit_bots and (guest or "--lobby-menu" in args):
		result.error = "Bot count is only set for an owned local Combat match."
	elif guest and (result.setup or explicit_mode):
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

func configure(maps: Dictionary, map_id: String, mode: String, character: String = "", harness: String = "", bots: int = 2, catalog_error_text: String = "") -> void:
	entries = maps
	catalog_error = catalog_error_text
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
	box.add_theme_constant_override("separation", 11)
	body.add_child(box)
	var title := Label.new()
	title.text = "COMBAT SETUP"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var description := Label.new()
	description.text = "Original Node rules · %d bots · Native infantry controls\nChoose a map and mode, then Start to connect." % bots
	box.add_child(description)
	# Operator/harness stay on the shared popup-free inline row, side by side to
	# keep the panel inside the 960x640 viewport.
	box.add_child(caption("Operator / harness"))
	var loadout_columns := HBoxContainer.new()
	loadout_columns.add_theme_constant_override("separation", 12)
	loadout_columns.add_child(operator_choice)
	loadout_columns.add_child(harness_choice)
	box.add_child(loadout_columns)
	build_loadout_rows()
	box.add_child(caption("Map"))
	box.add_child(map_choice)
	rebuild_map_choices(map_id)
	catalog_fingerprint = catalog_signature()
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
		if entries.is_empty(): return
		if validate(entries, selected_map(), selected_mode()).is_empty():
			start_requested.emit(selected_map(), selected_mode()))
	populate_modes(mode)
	# The pair is applied last: both rows and the map/mode rows must exist before
	# any status text is shaped.
	var chosen: Dictionary = Loadout.resolve(character, harness)
	select_operator(chosen.character)
	if not harness_choice.disabled: select_harness(chosen.harness)
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
	for control: Control in [map_choice, mode_choice, operator_choice, harness_choice, start, close]:
		control.release_focus()
	map_choice.cancel_browse()
	mode_choice.cancel_browse()
	operator_choice.cancel_browse()
	harness_choice.cancel_browse()
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

# Total catalog access: a missing id, a non-dictionary entry or an absent
# `modes` array yields an empty value instead of an invalid-dictionary error.
# These are read-only projections; the shared catalog is never mutated.
func map_entry(map_id: String) -> Dictionary:
	if map_id.is_empty() or not entries.has(map_id): return {}
	var entry: Variant = entries[map_id]
	return entry if entry is Dictionary else {}

func offered_modes(map_id: String) -> Array:
	return valid_modes(map_entry(map_id))

func map_index(id: String) -> int:
	for index: int in map_choice.item_count:
		if str(map_choice.get_item_metadata(index)) == id: return index
	return -1

func first_valid_map() -> String:
	for raw: Variant in entries.keys():
		var id := str(raw)
		if not offered_modes(id).is_empty(): return id
	return ""

func catalog_problem() -> String:
	if catalog_error.is_empty():
		return "The locked map catalog is empty; there is nothing to start."
	return "Locked catalog unavailable: " + catalog_error

# Read-only projection of the catalog content the map row depends on: sorted
# ids plus each entry's name and validated modes. Same-size replacements that
# change other ids, names or a map's modes still produce a different string.
func catalog_signature() -> String:
	var ids: Array = entries.keys()
	ids.sort()
	var parts := PackedStringArray()
	for raw: Variant in ids:
		var id := str(raw)
		parts.append("%s\u001f%s\u001f%s" % [id, str(map_entry(id).get("name", "")), "\u001e".join(PackedStringArray(offered_modes(str(id))))])
	return "\u001d".join(parts)

# Rebuild the map rows from the live catalog, keeping the current selection by
# metadata and falling back to the first surviving startable map. Rebuilding is
# what makes a newly added key (absent from the old rows) selectable again.
func rebuild_map_choices(preferred: String = "") -> void:
	var previous := preferred if not preferred.is_empty() else selected_map()
	map_choice.clear()
	for raw: Variant in entries.keys():
		var id := str(raw)
		var entry := map_entry(id)
		var suffix := "" if id in MAPS else (" — separate demo" if STANDALONE.has(id) else " — pending")
		map_choice.add_item(str(entry.get("name", id)) + suffix)
		map_choice.set_item_metadata(map_choice.item_count - 1, id)
	if not previous.is_empty() and map_index(previous) >= 0:
		map_choice.select(map_index(previous))
	else:
		var fallback := first_valid_map()
		if not fallback.is_empty() and map_index(fallback) >= 0:
			map_choice.select(map_index(fallback))

# Rebuild the map row only when the catalog content actually changed; a stable
# frame does no work and a pure modes change for the selected map is picked up.
func sync_catalog() -> void:
	var signature := catalog_signature()
	if signature == catalog_fingerprint: return
	catalog_fingerprint = signature
	rebuild_map_choices()

# Operator/harness selection. Every row entry carries the source ID as metadata;
# the source lock (claude -> claudecode) is applied to the row, never bypassed.
func build_loadout_rows() -> void:
	for entry: Dictionary in Loadout.CHARACTERS:
		operator_choice.add_item(str(entry.name))
		operator_choice.set_item_metadata(operator_choice.item_count - 1, str(entry.id))
	for entry: Dictionary in Loadout.HARNESSES:
		harness_choice.add_item(str(entry.name))
		harness_choice.set_item_metadata(harness_choice.item_count - 1, str(entry.id))
	operator_choice.item_selected.connect(on_operator_selected)
	harness_choice.item_selected.connect(on_harness_selected)

func selected_character() -> String:
	return str(operator_choice.get_selected_metadata())

func selected_harness() -> String:
	return str(harness_choice.get_selected_metadata())

func operator_index(id: String) -> int:
	for index: int in operator_choice.item_count:
		if str(operator_choice.get_item_metadata(index)) == id: return index
	return -1

func harness_index(id: String) -> int:
	for index: int in harness_choice.item_count:
		if str(harness_choice.get_item_metadata(index)) == id: return index
	return -1

func select_pair(character: String, harness: String) -> void:
	select_operator(character)
	if not harness_choice.disabled: select_harness(harness)

func select_operator(id: String) -> void:
	var index := operator_index(id)
	if index < 0: return
	operator_choice.select(index)
	apply_harness_lock()
	update_status()

func select_harness(id: String) -> void:
	if harness_choice.disabled: return
	var index := harness_index(id)
	if index < 0: return
	if not Loadout.valid(selected_character(), id): return
	harness_choice.select(index)
	update_status()

func apply_harness_lock() -> void:
	var locked := Loadout.locked_harness(selected_character())
	if locked.is_empty():
		harness_choice.disabled = false
		if not Loadout.valid(selected_character(), selected_harness()):
			select_harness_index(harness_index(Loadout.DEFAULT_HARNESS))
		return
	select_harness_index(harness_index(locked))
	harness_choice.disabled = true

func select_harness_index(index: int) -> void:
	if index >= 0 and index < harness_choice.item_count: harness_choice.select(index)

func on_operator_selected(_index: int) -> void:
	apply_harness_lock()
	update_status()
	loadout_changed.emit(selected_character(), selected_harness())

func on_harness_selected(_index: int) -> void:
	update_status()
	loadout_changed.emit(selected_character(), selected_harness())

func populate_modes(preferred: String = DEFAULT_MODE) -> void:
	# A reopened/failed catalog can replace ids, names or modes without changing
	# the size; sync_catalog() notices and rebuilds the map rows first.
	sync_catalog()
	mode_choice.clear()
	var map_id := selected_map()
	var offered := offered_modes(map_id)
	for mode: String in offered:
		var pending := map_id not in MAPS or mode not in MODES
		var suffix := ""
		if pending:
			suffix = " — separate demo" if STANDALONE.get(map_id, {}).has(mode) else (" — main menu" if mode == "campaign" else " — pending")
		mode_choice.add_item(MODE_NAMES.get(mode, mode.capitalize()) + suffix)
		mode_choice.set_item_metadata(mode_choice.item_count - 1, mode)
		if mode == preferred: mode_choice.select(mode_choice.item_count - 1)
	mode_choice.disabled = offered.is_empty()
	update_status()

func update_status() -> void:
	# No usable catalog: state an honest reason and disable Start, but leave the
	# Close setup path fully usable so the player is never trapped.
	if entries.is_empty():
		start.disabled = true
		status.text = catalog_problem()
		if is_inside_tree(): call_deferred("settle")
		return
	var map_id := selected_map()
	var entry := map_entry(map_id)
	if entry.is_empty():
		start.disabled = true
		status.text = "The selected map is no longer in the locked catalog. Close and reopen setup to choose another."
		if is_inside_tree(): call_deferred("settle")
		return
	if offered_modes(map_id).is_empty():
		start.disabled = true
		status.text = "No playable modes are registered for %s in the locked catalog." % str(entry.get("name", map_id))
		if is_inside_tree(): call_deferred("settle")
		return
	var problem := validate(entries, map_id, selected_mode())
	start.disabled = not problem.is_empty()
	status.text = problem if start.disabled else "Ready: %s / %s · %s\nClick to capture in-game; Esc releases the pointer." % [str(entry.get("name", map_id)), MODE_NAMES.get(selected_mode(), selected_mode()), Loadout.label(selected_character(), selected_harness())]
	if not start.disabled and selected_mode() == "teamdeathmatch":
		status.text += "\nRed vs Blue · Shared team score · Friendly fire off · Tab: scores"
	if not start.disabled and selected_mode() == "rockets":
		status.text += "\nFree for all · Rocket Launcher · Unlimited ammo · Health / armor supplies"
	if is_inside_tree(): call_deferred("settle")
