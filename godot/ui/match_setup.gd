extends PanelContainer

# Native capability subset; the locked semantic catalog remains the identity authority.
signal start_requested(map_id: String, mode: String)
const MAPS := ["meridian-exchange", "verdant-reliquary", "ember-crucible"]
const MODES := ["deathmatch", "teamdeathmatch", "instagib", "rockets"]
const MODE_NAMES := {"deathmatch":"Deathmatch", "teamdeathmatch":"Team Deathmatch", "instagib":"Instagib", "rockets":"Rocket Arena"}
const DEFAULT_MAP := "meridian-exchange"
const DEFAULT_MODE := "deathmatch"
const STANDALONE := {
	"meridian-exchange":{"domination":"zones", "koth":"zones"},
	"verdant-reliquary":{"domination":"zones", "koth":"zones"},
	"ember-crucible":{"domination":"zones", "koth":"zones"},
	"tidal-citadel":{"ctf":"objectives", "domination":"zones"},
	"sunscar-convoy":{"payload":"objectives", "domination":"zones", "combined-arms":"combined-arms"},
	"asterion-relay":{"cocs":"lattice-world", "cocs-coop":"lattice-world"},
	"monsoon-foundry":{"cocs":"lattice-world", "cocs-coop":"lattice-world"},
	"ion-speedway":{"puma-race":"sports"},
	"aurora-stadium":{"puma-soccer":"sports"},
}
var entries: Dictionary = {}
var map_choice := OptionButton.new()
var mode_choice := OptionButton.new()
var status := Label.new()
var start := Button.new()

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

func configure(maps: Dictionary, map_id: String, mode: String) -> void:
	entries = maps
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(680, 460)
	size = custom_minimum_size
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.055, 0.07, 0.09, 1.0)
	add_theme_stylebox_override("panel", background)
	var margin := MarginContainer.new()
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var title := Label.new()
	title.text = "COMBAT SETUP"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var description := Label.new()
	description.text = "Original Node rules · 2 bots · Native infantry controls\nChoose a map and mode, then Start to connect."
	box.add_child(description)
	box.add_child(map_choice)
	for id: String in entries:
		var suffix := "" if id in MAPS else (" — separate demo" if STANDALONE.has(id) else " — pending")
		map_choice.add_item(entries[id].name + suffix)
		map_choice.set_item_metadata(map_choice.item_count - 1, id)
		if id == map_id: map_choice.select(map_choice.item_count - 1)
	box.add_child(mode_choice)
	box.add_child(status)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(620, 70)
	var pending := Label.new()
	pending.text = "Combat: Deathmatch, Team Deathmatch, Instagib and Rocket Arena.\nOther experiences: select an entry for its separate launcher options."
	box.add_child(pending)
	start.text = "Start"
	start.custom_minimum_size.y = 44
	box.add_child(start)
	map_choice.item_selected.connect(func(_index: int) -> void: populate_modes())
	mode_choice.item_selected.connect(func(_index: int) -> void: update_status())
	start.pressed.connect(func() -> void:
		if validate(entries, selected_map(), selected_mode()).is_empty():
			start_requested.emit(selected_map(), selected_mode()))
	populate_modes(mode)
	if is_inside_tree(): call_deferred("center_panel")

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
