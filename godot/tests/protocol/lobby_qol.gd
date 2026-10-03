extends SceneTree
# Lobby QoL fixture (source-authored, native execution pending under K).
#
# Focused on the audited defects and the parent-review follow-ups:
#   1. room_browser: all_rooms non-empty + filter matched nothing used to clear
#      the note, leaving a silent blank list. It must say so truthfully, offer a
#      focusable clear-filters path that never auto-joins / re-emits, preserve
#      the typed query until cleared, and update the chosen-room marker in place
#      (focus preserved, no rebuild).
#   2. lobby_choice / lobby_menu: per-frame refresh re-ran the disabled setter
#      (queue_redraw, tooltips, focus mode) every frame. The setter, selection
#      and each disabled property now have a single writer per refresh; an
#      observer counter proves idle guest and empty-catalog frames do not churn.
#   3. lobby_menu / match_setup: populate_modes indexed entries[selected].modes
#      directly. Both surfaces must tolerate a missing/empty/malformed entry,
#      detect same-size catalog replacements (ids/names/modes), rebuild rows so a
#      newly added key is selectable, disable the launch path honestly and keep
#      back/retry/close usable, then restore choices from a valid catalog.
#   4. malformed mode arrays (null/dict/number/duplicate/control) are filtered to
#      valid strings with no invalid-dictionary error and no invented mode.
#
# Offline and synthetic (no network, no authority): the session doubles mirror
# the proven lobby_social fixture. No generated content assets are required.
const LobbyMenu = preload("res://ui/lobby_menu.gd")
const RoomBrowser = preload("res://social/room_browser.gd")
const Choice = preload("res://ui/lobby_choice.gd")
const Setup = preload("res://ui/match_setup.gd")
const Catalog = preload("res://world/catalog.gd")
const Network = preload("res://net/client.gd")

class QolSession extends Node:
	var catalog := Catalog.new()
	var endpoint := "ws://127.0.0.1:9"
	var current_id := "meridian-exchange"
	var selected_mode := "deathmatch"
	var phase := -3
	var client := Network.new()
	var label := Label.new()
	var calls: Array = []
	var host_allowed := false
	func seed_catalog(entries: Dictionary) -> void:
		for id: Variant in entries:
			catalog.entries[str(id)] = entries[id]
	func _ready() -> void:
		add_child(client)
		client.set_process(false)
		add_child(label)
	func lobby_host_allowed() -> bool: return host_allowed
	func lobby_connect(_url: String, _name: String, _room: String, _map: String, _mode: String, _guest: bool, _character: String = "", _harness: String = "") -> void:
		calls.append({"call": "lobby_connect"})
	func lobby_start() -> void: calls.append({"call": "lobby_start"})
	func lobby_leave() -> void: calls.append({"call": "lobby_leave"})
	func request_restart() -> void: pass
	func spectator_status() -> String: return "Read-only fixed view"

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LOBBY_QOL " + message)

func _initialize() -> void: call_deferred("run")

func settle() -> void: await create_timer(0.08).timeout

func config() -> Dictionary:
	return {
		"meridian-exchange": {"name": "Meridian Exchange", "modes": ["deathmatch", "teamdeathmatch"]},
		"verdant-reliquary": {"name": "Verdant Reliquary", "modes": ["deathmatch"]},
	}

func room_rows() -> Array:
	return [
		{"roomId": "AB12", "name": "Alpha", "mapId": "meridian-exchange", "players": 2, "started": false, "config": {"mode": "teamdeathmatch"}},
		{"roomId": "CD34", "name": "Bravo", "mapId": "verdant-reliquary", "players": 1, "started": true, "config": {"mode": "deathmatch"}},
		{"roomId": "EF56", "name": "Echo", "mapId": "meridian-exchange", "players": 3, "started": false, "config": {"mode": "deathmatch"}},
	]

func detail_of(row: Node) -> String:
	return (row.get_child(1) as Label).text if row.get_child_count() > 1 else ""

func code_of(row: Node) -> String:
	return (row.get_child(0) as Button).text if row.get_child_count() > 0 else ""

func row_for(list: Node, code: String) -> Node:
	for child: Node in list.get_children():
		if code_of(child) == code: return child
	return null

func counts_of(choices: Array) -> Array:
	var counts: Array = []
	for choice: Choice in choices: counts.append(choice.update_count)
	return counts

func stable(choices: Array, before: Array) -> bool:
	for index: int in choices.size():
		if choices[index].update_count != before[index]: return false
	return true

func run() -> void:
	root.size = Vector2i(960, 640)

	# --- Finding 1: room browser truthful empty-filter + clear path ----------
	var browser: Node = RoomBrowser.new()
	root.add_child(browser)
	await settle()
	browser.sync(false)
	browser.sync(true)
	var selected_events: Array = []
	browser.room_selected.connect(func(record: Dictionary) -> void: selected_events.append(record))
	browser.accept(room_rows())
	browser.rebuild()
	check(browser.list_box.get_child_count() == 3, "three advertised rooms render before filtering")
	check(not browser.filter_active() and not browser.clear_filters_button.visible, "no clear path while the list is unfiltered")

	# Press the row: the marker updates in place, focus is kept, nothing rebuilds.
	var alpha_row: Node = row_for(browser.list_box, "AB12")
	var alpha_button := alpha_row.get_child(0) as Button
	alpha_button.grab_focus()
	await settle()
	alpha_button.pressed.emit()
	check(browser.selected_room_id == "AB12" and selected_events.size() == 1, "selecting a room records it and emits once")
	check(detail_of(alpha_row).begins_with("▸ "), "the selected row is marked immediately, without a rebuild")
	check(alpha_button.has_focus(), "the pressed row keeps focus through the in-place mark")
	check(not browser.dirty, "an in-place mark never queues a rebuild")

	# A query that matches nothing must say so instead of blanking the note.
	browser.search.text = "no-such-room"
	browser.rebuild()
	check(browser.list_box.get_child_count() == 0, "a non-matching query lists no rows")
	check(browser.empty_note.text == "No rooms match the current filters.", "filtered-to-empty states the truth, not a blank note: '" + browser.empty_note.text + "'")
	check(browser.filter_active() and browser.clear_filters_button.visible, "the clear path appears when a filter hides everything")
	check(browser.clear_filters_button.focus_mode == Control.FOCUS_ALL, "the clear path is keyboard reachable")
	check(browser.search.text == "no-such-room", "filtering never silently clears the typed query")
	check(browser.selected_room_id == "AB12" and selected_events.size() == 1, "filtering preserves the selection and never re-announces it")

	# The clear path restores the full list and hides itself.
	browser.clear_filters()
	browser.rebuild()
	check(browser.search.text == "" and not browser.hide_started.button_pressed, "clear filters resets the query and the in-progress toggle")
	check(browser.list_box.get_child_count() == 3, "clear filters restores every advertised room")
	check(not browser.clear_filters_button.visible, "the clear path hides once nothing is filtered")
	check(detail_of(row_for(browser.list_box, "AB12")).begins_with("▸ "), "the selection survives the clear path")
	check(browser.selected_room_id == "AB12" and selected_events.size() == 1, "the clear path never auto-joins the marked room")

	# The in-progress toggle is its own filter with the same truthful empty state.
	browser.hide_started.set_pressed_no_signal(true)
	browser.rebuild()
	check(browser.list_box.get_child_count() == 2 and row_for(browser.list_box, "CD34") == null, "hiding in-progress rooms drops only started rooms")
	browser.search.text = "CD34"
	browser.rebuild()
	check(browser.empty_note.text == "No rooms match the current filters.", "search plus hide-then-empty is still worded truthfully")
	browser.clear_filters()
	browser.rebuild()

	# A server that advertises nothing is distinct from a filter that matched nothing.
	browser.accept([])
	browser.rebuild()
	check(browser.empty_note.text == "No rooms to show.", "an empty advertised list keeps its own honest wording")
	browser.queue_free()
	await settle()

	# --- Finding 2: idempotent choice setters (observer counter) -------------
	var probe := Choice.new()
	root.add_child(probe)
	probe.add_item("One")
	probe.add_item("Two")
	var baseline: int = probe.update_count
	probe.disabled = true
	var after_first: int = probe.update_count
	check(after_first > baseline, "an actual disabled change renders once")
	probe.disabled = true
	probe.disabled = true
	check(probe.update_count == after_first, "repeated disabled assignment does not render again")
	var stable_count: int = probe.update_count
	for _i: int in 6:
		probe.refresh()
	check(probe.update_count == stable_count, "a stable refresh call performs no work")
	var selected_before: int = probe.update_count
	probe.select(probe.selected)
	check(probe.update_count == selected_before, "selecting the active entry is idempotent")
	probe.disabled = false
	check(probe.update_count == selected_before + 1, "re-enabling renders exactly once")
	probe.select(1)
	check(probe.update_count == selected_before + 2, "selecting a new entry renders exactly once")
	probe.queue_free()
	await settle()

	# Host idle: five per-frame refreshes must leave every row untouched.
	var live := QolSession.new()
	live.seed_catalog(config())
	root.add_child(live)
	await settle()
	var menu: Node = LobbyMenu.new()
	live.add_child(menu)
	await settle()
	var rows: Array = [menu.role, menu.maps, menu.modes, menu.operator, menu.harness]
	var host_before: Array = counts_of(rows)
	for _i: int in 5:
		menu.refresh()
	await settle()
	check(stable(rows, host_before), "five refreshes plus real frames leave a host menu untouched: " + str(host_before))

	# Guest idle: the mode row must settle ONCE to disabled, then never toggle.
	menu.role.select(1)
	await settle()
	check(menu.modes.disabled, "guest mode row is disabled")
	var guest_before: Array = counts_of(rows)
	for _i: int in 5:
		menu.refresh()
	await settle()
	check(stable(rows, guest_before), "five refreshes plus real frames leave a guest menu untouched (no false<->true toggle): " + str(guest_before))
	menu.role.select(0)
	await settle()
	live.free()
	await settle()

	# Empty catalog idle: the disabled launch state is written once, then stable.
	var empty := QolSession.new()
	empty.catalog.error = "Missing/empty or unsupported manifest. Run semantic exporter."
	root.add_child(empty)
	await settle()
	var empty_menu: Node = LobbyMenu.new()
	empty.add_child(empty_menu)
	await settle()
	check(empty_menu.catalog_ready() == false, "an unseeded catalog is reported empty")
	check(empty_menu.maps.item_count == 0 and empty_menu.modes.item_count == 0, "an empty catalog builds no map/mode entries")
	check(empty_menu.connect_button.disabled, "host/join is disabled with no catalog")
	check(empty_menu.modes.disabled, "mode choice is disabled with no catalog")
	check(empty_menu.status.text.contains("Missing/empty or unsupported manifest"), "the catalog's own error is surfaced, not replaced: '" + empty_menu.status.text + "'")
	check(not empty_menu.back_button.disabled and not empty_menu.reconnect_button.disabled, "back/retry stay usable with no catalog")
	var empty_rows: Array = [empty_menu.role, empty_menu.maps, empty_menu.modes, empty_menu.operator, empty_menu.harness]
	var empty_before: Array = counts_of(empty_rows)
	for _i: int in 5:
		empty_menu.refresh()
	await settle()
	check(stable(empty_rows, empty_before), "five refreshes plus real frames leave an empty-catalog menu untouched: " + str(empty_before))
	check(empty_menu.connect_button.disabled and empty_menu.status.text.contains("Missing/empty"), "a repeated refresh does not resurrect the launch path")

	# Reopening the same live dictionary restores the rows and the launch path.
	empty.catalog.error = ""
	for id: Variant in config():
		empty.catalog.entries[str(id)] = config()[id]
	empty_menu.refresh()
	check(empty_menu.catalog_ready() and empty_menu.maps.item_count == 2, "a recovered catalog restores the map entries")
	check(empty_menu.modes.item_count >= 1 and not empty_menu.modes.disabled, "a recovered catalog restores interactive modes")
	check(not empty_menu.connect_button.disabled, "a recovered catalog re-enables host/join")
	empty.free()
	await settle()

	# --- Finding 3: same-size catalog replacement is detected ----------------
	var content := QolSession.new()
	content.seed_catalog(config())
	root.add_child(content)
	await settle()
	var content_menu: Node = LobbyMenu.new()
	content.add_child(content_menu)
	await settle()
	check(str(content_menu.maps.get_selected_metadata()) == "meridian-exchange", "content menu starts on the session map")

	# Same size, changed name: the row label must update, selection preserved.
	content.catalog.entries["meridian-exchange"]["name"] = "Renamed Exchange"
	content_menu.refresh()
	var renamed_index: int = content_menu.map_index("meridian-exchange")
	check(renamed_index >= 0 and str(content_menu.maps.get_item_text(renamed_index)).contains("Renamed Exchange"), "a same-size name replacement updates the map row")
	check(str(content_menu.maps.get_selected_metadata()) == "meridian-exchange", "a same-size replacement preserves the selection")

	# Same size, changed modes for the selected map: modes must refresh.
	content.catalog.entries["meridian-exchange"]["modes"] = ["rockets", "instagib"]
	content_menu.refresh()
	check(content_menu.mode_index("rockets") >= 0 and content_menu.mode_index("deathmatch") < 0, "a same-size modes replacement refreshes the selected map's modes")
	check(str(content_menu.maps.get_selected_metadata()) == "meridian-exchange", "a modes-only replacement keeps the selected map")

	# Removed selected map plus a brand new key: the new key must be selectable.
	content.catalog.entries.erase("meridian-exchange")
	content.catalog.entries["new-arena"] = {"name": "New Arena", "modes": ["deathmatch"]}
	content_menu.refresh()
	check(content_menu.map_index("new-arena") >= 0, "a newly added catalog key is rebuilt into the map row")
	check(str(content_menu.maps.get_selected_metadata()) != "meridian-exchange", "a removed selected map is not left dangling")
	check(content_menu.modes.item_count >= 1, "the fallback map still has selectable modes")
	content.free()
	await settle()

	# A malformed mode array is filtered, never turned into a fake mode.
	var malformed := QolSession.new()
	malformed.catalog.entries["meridian-exchange"] = {"name": "Meridian Exchange", "modes": [null, 7, {"x": 1}, "deathmatch", "deathmatch", "", "bad\u0007mode"]}
	root.add_child(malformed)
	await settle()
	var malformed_menu: Node = LobbyMenu.new()
	malformed.add_child(malformed_menu)
	await settle()
	check(malformed_menu.modes.item_count == 1 and malformed_menu.mode_index("deathmatch") == 0, "malformed mode arrays keep only valid unique strings")
	check(not malformed_menu.modes.disabled, "a map with one valid mode stays selectable")
	malformed.free()
	await settle()

	# --- Finding 3b/4: match_setup empty / replacement / malformed -----------
	check(Setup.valid_modes(null).is_empty(), "valid_modes rejects a null entry")
	check(Setup.valid_modes({"modes": "nope"}).is_empty(), "valid_modes rejects a non-array modes value")
	check(Setup.valid_modes({"modes": [null, 2, {}, "ok", "ok", "  spaced  ", "bad\u0007mode"]}) == ["ok", "spaced"], "valid_modes drops non-strings/controls/duplicates and trims")

	var setup := Setup.new()
	root.add_child(setup)
	setup.configure({}, "", "")
	await settle()
	check(setup.start.disabled, "setup disables Start with an empty catalog")
	check(setup.mode_choice.item_count == 0 and setup.mode_choice.disabled, "setup leaves no interactive mode row with an empty catalog")
	check(not setup.status.text.is_empty(), "setup states an honest reason with an empty catalog")
	check(not setup.close.disabled, "Close setup stays usable with an empty catalog")
	var started: Array = []
	setup.start_requested.connect(func(map_id: String, mode: String) -> void: started.append([map_id, mode]))
	setup.start.pressed.emit()
	check(started.is_empty(), "setup never emits start_requested from an empty catalog")

	var good := Setup.new()
	root.add_child(good)
	good.configure(config(), "meridian-exchange", "deathmatch")
	await settle()
	check(good.map_choice.item_count == 2, "setup restores map choices from a valid catalog")
	check(good.mode_choice.item_count == 2 and not good.mode_choice.disabled, "setup restores an interactive mode row from a valid catalog")
	check(not good.start.disabled, "setup enables Start from a valid catalog")

	# Same size, changed name and modes: rows refresh, selection preserved.
	good.entries["meridian-exchange"]["name"] = "Renamed Exchange"
	good.entries["meridian-exchange"]["modes"] = ["rockets", "instagib"]
	good.populate_modes()
	check(good.map_index("meridian-exchange") >= 0 and str(good.map_choice.get_item_text(good.map_index("meridian-exchange"))).contains("Renamed Exchange"), "setup detects a same-size name replacement")
	check(good.mode_choice.item_count == 2 and good.mode_choice.get_item_metadata(0) == "rockets", "setup detects a same-size modes replacement")
	check(good.selected_map() == "meridian-exchange", "setup keeps the selected map across a same-size replacement")

	# New key added after configure: absent from the old rows, now rebuildable.
	good.entries["new-arena"] = {"name": "New Arena", "modes": ["deathmatch"]}
	good.populate_modes()
	check(good.map_choice.item_count == 3 and good.map_index("new-arena") >= 0, "setup rebuilds a newly added map into the row")
	check(good.selected_map() == "meridian-exchange", "setup keeps the selection when a new map is added")

	# Removed selected map: must recover onto a rebuilt surviving row.
	good.entries.erase("meridian-exchange")
	good.populate_modes()
	check(good.selected_map() == "verdant-reliquary", "setup recovers onto a surviving map when the selected is removed")
	check(not good.start.disabled, "setup keeps Start usable on the recovered map")

	var broken := Setup.new()
	root.add_child(broken)
	broken.configure({"meridian-exchange": {"name": "Meridian Exchange", "modes": [null, 3, "deathmatch", "deathmatch"]}}, "meridian-exchange", "deathmatch")
	await settle()
	check(broken.mode_choice.item_count == 1 and not broken.mode_choice.disabled, "setup filters a malformed mode array to one interactive mode")
	check(not broken.start.disabled, "setup keeps Start usable with a recovered malformed mode array")

	var malformed_entry := Setup.new()
	root.add_child(malformed_entry)
	malformed_entry.configure({"weird": "not-a-dictionary"}, "weird", "deathmatch")
	await settle()
	check(malformed_entry.start.disabled, "setup disables Start for a malformed catalog entry")
	check(not malformed_entry.status.text.is_empty(), "setup words the malformed catalog entry honestly")

	print("PORT_LOBBY_QOL_OK checks=", checks, " failures=", failures, " native_execution_pending=true")
	quit(1 if failures else 0)
