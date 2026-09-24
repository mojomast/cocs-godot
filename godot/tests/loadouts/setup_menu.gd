extends SceneTree
# Combat setup surface: popup-free operator/harness rows, source-locked pairs,
# unchanged 2-argument start_requested signal and 960x640 / 1280x800 geometry.
const Setup = preload("res://ui/match_setup.gd")
const Catalog = preload("res://world/catalog.gd")
const Loadout = preload("res://ui/loadout.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LOADOUT_SETUP " + message)

func _initialize() -> void: call_deferred("run")

func settle() -> void: await create_timer(0.05).timeout

func popup_nodes(node: Node) -> int:
	var count := 0
	for child: Node in node.get_children(true):
		if child is OptionButton or child is PopupMenu or child is Window: count += 1
		count += popup_nodes(child)
	return count

func run() -> void:
	var catalog := Catalog.new()
	check(catalog.open() and catalog.entries.size() == 9, "locked catalog opens")
	var menu := Setup.new()
	root.add_child(menu)
	menu.configure(catalog.entries, "meridian-exchange", "deathmatch")
	await settle()

	# Defaults stay source defaults and both rows expose the full source roster.
	check(menu.selected_character() == "chatgpt" and menu.selected_harness() == "openclaw", "setup defaults chatgpt/openclaw")
	check(menu.operator_choice.item_count == 9, "operator row lists all nine source operators")
	check(menu.harness_choice.item_count == 7, "harness row lists all seven source harnesses")
	check(menu.operator_choice.get_selected_metadata() == "chatgpt", "operator row metadata is the source id")
	check(menu.harness_choice.get_selected_metadata() == "openclaw", "harness row metadata is the source id")
	check(popup_nodes(menu) == 0, "no OptionButton/PopupMenu/Window in the setup surface")
	check(str(menu.operator_choice.get_item_text(0)).begins_with("ChatGPT"), "operator label uses source name")
	check(str(menu.harness_choice.get_item_text(0)).begins_with("OpenClaw"), "harness label uses source name")

	# Programmatic selection is silent, like the shared choice API.
	var events: Array = []
	menu.loadout_changed.connect(func(character: String, harness: String) -> void: events.append([character, harness]))
	menu.select_operator("grok")
	menu.select_harness("cline")
	check(events.is_empty(), "programmatic selection emits no loadout_changed")
	check(menu.selected_character() == "grok" and menu.selected_harness() == "cline", "programmatic pair readable")
	check(menu.operator_choice.get_selected_metadata() == "grok" and menu.harness_choice.get_selected_metadata() == "cline", "rows follow programmatic pair")

	# Claude's source lock: the harness row locks to Claude Code and cannot drift.
	menu.select_operator("claude")
	check(menu.selected_character() == "claude" and menu.selected_harness() == "claudecode", "claude locks the harness row to claudecode")
	check(menu.harness_choice.disabled, "locked harness row is not interactive")
	menu.select_harness("hermes")
	check(menu.selected_harness() == "claudecode", "invalid harness cannot be forced past the lock")
	menu.select_operator("mistral")
	check(not menu.harness_choice.disabled, "harness row unlocks when the operator is free")
	check(menu.selected_harness() == "claudecode", "claudecode stays selectable off claude")
	menu.select_harness("roo")
	check(menu.selected_character() == "mistral" and menu.selected_harness() == "roo", "free pair selectable")

	# Unknown ids never enter the surface.
	menu.select_operator("bogus-model")
	menu.select_harness("bogus-harness")
	check(menu.selected_character() == "mistral" and menu.selected_harness() == "roo", "unknown ids rejected by the rows")

	# The start signal keeps exactly two arguments and reports map/mode only.
	var started: Array = []
	menu.start_requested.connect(func(map_id: String, mode: String) -> void: started.append([map_id, mode]))
	check(not menu.start.disabled, "start enabled for a valid pair and mode")
	menu.start.pressed.emit()
	check(started == [["meridian-exchange", "deathmatch"]], "start_requested still carries map/mode only: " + str(started))
	check(menu.selected_character() == "mistral" and menu.selected_harness() == "roo", "start leaves the selected pair available to the session")

	# User-driven row changes emit once and keep the pair valid.
	var user_events: Array = []
	menu.loadout_changed.connect(func(character: String, harness: String) -> void: user_events.append([character, harness]))
	menu.operator_choice.cycle(1)
	await settle()
	check(user_events.size() == 1 and user_events[0] == [menu.selected_character(), menu.selected_harness()], "row cycle emits the pair once: " + str(user_events))
	check(Loadout.valid(menu.selected_character(), menu.selected_harness()), "row cycle always lands on a valid pair")
	menu.operator_choice.item_selected.emit(menu.operator_choice.selected)
	await settle()
	check(user_events.size() == 2, "explicit row selection emits")

	# Status text names the pair and its harness power from the source table.
	check(menu.status.text.contains(Loadout.harness_name(menu.selected_harness())), "status names the harness")
	check(menu.status.text.contains(Loadout.character_name(menu.selected_character())), "status names the operator")

	# Dismiss/reopen keeps the pair and the panel popup-free.
	menu.dismiss()
	check(menu.dismissed and not menu.body.visible, "dismiss hides the setup body")
	menu.reopen()
	check(not menu.dismissed and menu.body.visible, "reopen restores the setup body")
	check(menu.selected_character() == user_events[1][0] and menu.selected_harness() == user_events[1][1], "dismiss/reopen keeps the pair")
	check(popup_nodes(menu) == 0, "still popup-free after reopen")

	# Geometry: the panel and its loadout rows stay inside both supported sizes.
	for size: Vector2i in [Vector2i(960, 640), Vector2i(1280, 800)]:
		root.size = size
		await settle()
		await settle()
		var viewport := Rect2(Vector2.ZERO, Vector2(size))
		check(viewport.encloses(menu.get_global_rect()), "setup panel inside " + str(size) + " rect=" + str(menu.get_global_rect()))
		check(viewport.encloses(menu.start.get_global_rect()), "start button inside " + str(size))
		check(menu.get_global_rect().encloses(menu.operator_choice.get_global_rect()), "operator row inside the panel at " + str(size))
		check(menu.get_global_rect().encloses(menu.harness_choice.get_global_rect()), "harness row inside the panel at " + str(size))
		print("LOADOUT_SETUP_GEOMETRY ", str(size), " panel=", str(menu.size), " position=", str(menu.position))
	check(menu.size.y <= 604.0, "panel content height fits the 640-high viewport: " + str(menu.size))

	# Argument parsing: explicit pairs, lock resolution and invalid input.
	var defaults := Setup.parse_args([], catalog.entries)
	check(defaults.operator == "chatgpt" and defaults.harness == "openclaw", "parse_args defaults to the source pair")
	check(defaults.bots == 2, "local Combat defaults to two bots")
	for bots in [0, 8]:
		var local := Setup.parse_args(["--bots=%d" % bots], catalog.entries)
		check(local.error.is_empty() and local.bots == bots, "local Combat accepts %d source-supported bots" % bots)
	for invalid in [["--bots=-1"], ["--bots=9"], ["--bots=3", "--bots=4"],
			["--lobby-menu", "--bots=3"], ["--join-room=guest", "--bots=3"]]:
		check(not Setup.parse_args(invalid, catalog.entries).error.is_empty(), "bot count is bounded and local-only: " + str(invalid))
	var chosen := Setup.parse_args(["--operator=grok", "--harness", "cline"], catalog.entries)
	check(chosen.error.is_empty() and chosen.operator == "grok" and chosen.harness == "cline", "parse_args accepts an explicit pair")
	var locked := Setup.parse_args(["--operator=claude"], catalog.entries)
	check(locked.error.is_empty() and locked.operator == "claude" and locked.harness == "claudecode", "parse_args resolves claude to claudecode")
	var conflicting := Setup.parse_args(["--operator=claude", "--harness=hermes"], catalog.entries)
	check(not conflicting.error.is_empty(), "parse_args rejects a conflicting locked pair")
	var bogus := Setup.parse_args(["--operator=bogus"], catalog.entries)
	check(not bogus.error.is_empty(), "parse_args rejects an unknown operator")
	var bogus_harness := Setup.parse_args(["--harness=bogus"], catalog.entries)
	check(not bogus_harness.error.is_empty(), "parse_args rejects an unknown harness")
	var empty := Setup.parse_args(["--harness="], catalog.entries)
	check(not empty.error.is_empty(), "parse_args rejects an empty harness")
	var guest := Setup.parse_args(["--join-room=room", "--operator=deepseek", "--harness=hermes", "--map=verdant-reliquary"], catalog.entries)
	check(guest.error.is_empty() and guest.operator == "deepseek" and guest.harness == "hermes", "guests may choose their own pair")
	var guest_mode := Setup.parse_args(["--join-room=room", "--harness=hermes"], catalog.entries)
	check(guest_mode.error.is_empty(), "guest harness alone is accepted")

	# configure() accepts an explicit starting pair without breaking old callers.
	var second := Setup.new()
	second.configure(catalog.entries, "verdant-reliquary", "instagib", "deepseek", "hermes")
	root.add_child(second)
	await settle()
	check(second.selected_character() == "deepseek" and second.selected_harness() == "hermes", "configure accepts an explicit pair")
	var third := Setup.new()
	third.configure(catalog.entries, "verdant-reliquary", "instagib")
	root.add_child(third)
	await settle()
	check(third.selected_character() == "chatgpt" and third.selected_harness() == "openclaw", "old 3-argument configure call is unchanged")
	var fourth := Setup.new()
	fourth.configure(catalog.entries, "verdant-reliquary", "instagib", "claude", "hermes")
	root.add_child(fourth)
	await settle()
	check(fourth.selected_character() == "claude" and fourth.selected_harness() == "claudecode", "configure resolves a locked pair")
	check(popup_nodes(fourth) == 0, "configure keeps the surface popup-free")

	print("PORT_LOADOUT_SETUP_OK checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
