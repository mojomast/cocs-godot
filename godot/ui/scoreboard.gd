extends CanvasLayer

# Passive native overlay: no input consumption, pointer capture, or authority writes.
# A scene child binds after NativeSession._ready() has installed its client handlers.
const MAX_ACTORS := 64
const MAX_VISIBLE := 12
const ROW_HEIGHT := 30
const INK := Color("e5edf6")
const MUTED := Color("94a8be")
const ACCENT := Color("62deca")

var session: Node
var client: Node
var active := false
var finished := false
var tab_held := false
var guest := false
var round_number := 0
var page := 0
var page_size := 8
var entries: Array[Dictionary] = []
var actor_count := 0
var local_actor_id := -1
var map_mode := ""
var clock_text := ""
var team_score_text := ""
var dirty := true
var last_phase := -999
var panel := PanelContainer.new()
var title: Label
var subtitle: Label
var summary: Label
var footer: Label
var rows_box := VBoxContainer.new()
var rows: Array[Dictionary] = []

func _ready() -> void:
	layer = 8
	build_ui()
	panel.hide()
	get_viewport().size_changed.connect(resize)
	panel.resized.connect(position_panel)
	resize()
	call_deferred("bind_parent")

func bind_parent() -> void:
	var parent := get_parent()
	if parent != null and "client" in parent: bind_session(parent)

func bind_session(target: Node) -> void:
	if is_instance_valid(client): return
	session = target
	client = target.get("client")
	if not is_instance_valid(client): return
	guest = not str(target.get("join_room_id")).is_empty() if "join_room_id" in target else false
	client.started.connect(on_started)
	client.snapshot.connect(on_snapshot)
	client.results.connect(on_results)
	client.connection_error.connect(on_error)
	if "round_starts" in target: round_number = int(target.get("round_starts"))
	if "phase" in target and int(target.get("phase")) < 0: clear_round()

func on_started(_frame: Dictionary) -> void:
	clear_round()
	round_number = int(session.get("round_starts")) if is_instance_valid(session) and "round_starts" in session else round_number + 1
	active = true

func on_snapshot(frame: Dictionary) -> void:
	if not active or finished or not session_allows_panel(): return
	if frame.get("state") is Dictionary:
		apply_state(frame.state, int(client.get("actor_id")))

func on_results(frame: Dictionary) -> void:
	if not session_allows_panel(): return
	if frame.get("state") is Dictionary:
		apply_state(frame.state, int(client.get("actor_id")), true)

func on_error(_message: String) -> void:
	clear_round()

func clear_round() -> void:
	active = false
	finished = false
	tab_held = false
	page = 0
	entries.clear()
	actor_count = 0
	local_actor_id = -1
	map_mode = ""
	clock_text = ""
	team_score_text = ""
	dirty = true
	panel.hide()
	for row: Dictionary in rows: row.node.hide()

func session_allows_panel() -> bool:
	return not is_instance_valid(session) or not "phase" in session or int(session.get("phase")) in [3, 4, 20]

func _process(_delta: float) -> void:
	# Covers local handshake/restart errors, which need not emit client errors.
	if not session_allows_panel():
		if active: clear_round()
		return
	if is_instance_valid(session) and "phase" in session:
		var phase := int(session.get("phase"))
		if phase != last_phase:
			last_phase = phase
			dirty = true
	refresh_visibility()
	if panel.visible and dirty: render()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		tab_held = false
		refresh_visibility()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo: return
	if event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB:
		tab_held = event.pressed and active and session_allows_panel()
		refresh_visibility()
	elif panel.visible and event.pressed:
		if event.keycode == KEY_PAGEDOWN: change_page(1)
		if event.keycode == KEY_PAGEUP: change_page(-1)

func refresh_visibility() -> void:
	panel.visible = active and session_allows_panel() and (finished or tab_held)

func change_page(step: int) -> void:
	var next_page := clampi(page + step, 0, maxi(0, ceili(float(entries.size()) / page_size) - 1))
	if page != next_page: dirty = true
	page = next_page

static func plain(value: Variant, fallback: String = "—", limit: int = 64) -> String:
	if not value is String: return fallback
	var text: String = value.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().left(limit)
	return text if not text.is_empty() else fallback

static func number(value: Variant) -> Variant:
	if (value is int or value is float) and is_finite(float(value)):
		return int(clampf(float(value), -1000000000, 1000000000))
	return null

static func ranked_before(a: Dictionary, b: Dictionary) -> bool:
	if a.frags_sort != b.frags_sort: return a.frags_sort > b.frags_sort
	if a.deaths_sort != b.deaths_sort: return a.deaths_sort < b.deaths_sort
	var name_order: int = a.player_name.naturalnocasecmp_to(b.player_name)
	if name_order != 0: return name_order < 0
	return a.order < b.order

static func team_label(value: Variant) -> String:
	# Wire team IDs are JSON numbers. Do not round malformed fractions into a team.
	if value is int or value is float:
		if value == 0: return "Red"
		if value == 1: return "Blue"
	if value is String:
		if value.to_lower() in ["0", "red"]: return "Red"
		if value.to_lower() in ["1", "blue"]: return "Blue"
	return plain(value, "—", 16)

static func plural(count: int, singular: String, plural_word: String) -> String:
	return "%d %s" % [count, singular if absi(count) == 1 else plural_word]

static func roster_text(total: int, humans: int, bots: int, npcs: int) -> String:
	# The wire roster is not the human roster: bots carry a `bot` object and Horde
	# NPCs carry isNpc. Name each class that was actually counted so a bot or NPC
	# row can never be read as a human player.
	if npcs > 0:
		var parts := PackedStringArray([plural(total, "actor", "actors"), plural(humans, "player", "players")])
		if bots > 0: parts.append(plural(bots, "bot", "bots"))
		parts.append(plural(npcs, "enemy", "enemies"))
		return "  ·  ".join(parts)
	if bots > 0:
		return "%s  ·  %s  ·  %s" % [plural(total, "combatant", "combatants"), plural(humans, "player", "players"), plural(bots, "bot", "bots")]
	return plural(total, "player", "players")

static func team_totals(state: Dictionary) -> String:
	var config: Variant = state.get("config")
	# Source emits teamScores even in FFA. Only expose totals for the enabled team mode.
	if not config is Dictionary or config.get("mode") != "teamdeathmatch": return ""
	var scores: Variant = state.get("teamScores")
	var red: Variant = number(scores.get("0")) if scores is Dictionary else null
	var blue: Variant = number(scores.get("1")) if scores is Dictionary else null
	return "Team totals  ·  Red %s  ·  Blue %s" % [str(red) if red != null else "—", str(blue) if blue != null else "—"]

func apply_state(state: Dictionary, local_id: int, is_results: bool = false) -> void:
	# Keep only presentation scalars, never the large simulation snapshot.
	var next: Array[Dictionary] = []
	var actors: Array = state.get("actors", []) if state.get("actors", []) is Array else []
	if actor_count != actors.size(): dirty = true
	actor_count = actors.size()
	for i: int in range(mini(actors.size(), MAX_ACTORS)):
		if not actors[i] is Dictionary: continue
		var actor: Dictionary = actors[i]
		var frags: Variant = number(actor.get("frags"))
		var deaths: Variant = number(actor.get("deaths"))
		var team_text := team_label(actor.get("team"))
		var id: Variant = number(actor.get("id"))
		next.append({"order":i, "player_name":plain(actor.get("name"), "Player %s" % (str(id) if id != null else "?")),
			"local":id != null and local_id >= 0 and id == local_id, "team":team_text,
			"frags":str(frags) if frags != null else "—", "deaths":str(deaths) if deaths != null else "—",
			"frags_sort":frags if frags != null else 0, "deaths_sort":deaths if deaths != null else 0,
			"npc":actor.get("isNpc") == true,
			"bot":actor.get("isNpc") != true and actor.get("bot") != null})
	next.sort_custom(ranked_before)
	var config: Dictionary = state.get("config", {}) if state.get("config", {}) is Dictionary else {}
	var next_map_mode := "%s  ·  %s" % [plain(state.get("mapName"), plain(state.get("mapId"), "Map unknown")), plain(state.get("modeName"), plain(config.get("mode"), "Mode unknown"))]
	var elapsed: Variant = number(state.get("time"))
	var next_clock := "Elapsed —"
	var next_team_scores := team_totals(state)
	var team_height_changed := team_score_text.is_empty() != next_team_scores.is_empty()
	if elapsed != null:
		var seconds: int = maxi(0, elapsed)
		next_clock = "Elapsed %d:%02d" % [seconds / 60, seconds % 60]
	if entries != next or map_mode != next_map_mode or clock_text != next_clock or team_score_text != next_team_scores or finished != is_results or local_actor_id != local_id:
		dirty = true
	entries = next
	map_mode = next_map_mode
	clock_text = next_clock
	team_score_text = next_team_scores
	local_actor_id = local_id
	active = true
	finished = is_results
	if team_height_changed: resize()
	change_page(0)
	refresh_visibility()

func label(font_size: int, color: Color = INK) -> Label:
	var item := Label.new()
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.focus_mode = Control.FOCUS_NONE
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return item

func build_ui() -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.10, 0.96)
	style.border_color = Color("33596a")
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 5)
	panel.add_child(stack)
	title = label(23, ACCENT)
	subtitle = label(18)
	summary = label(14, MUTED)
	footer = label(14, MUTED)
	for item: Label in [title, subtitle, summary]: stack.add_child(item)
	var header := make_row()
	stack.add_child(header.node)
	set_row(header, ["#", "PLAYER", "TEAM", "FRAGS", "DEATHS"], MUTED)
	rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows_box.add_theme_constant_override("separation", 0)
	stack.add_child(rows_box)
	for i: int in range(MAX_VISIBLE):
		var row := make_row()
		rows_box.add_child(row.node)
		rows.append(row)
		row.node.hide()
	stack.add_child(footer)

func row_cell_widths() -> Array:
	return [28, 0, 80, 58, 64]

func row_separation() -> int:
	return 12

func make_row() -> Dictionary:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size.y = ROW_HEIGHT
	box.add_theme_constant_override("separation", row_separation())
	var cells: Array[Label] = []
	for width: int in row_cell_widths():
		var cell := label(15)
		cell.custom_minimum_size.x = width
		if width == 0: cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if cells.size() >= 2: cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.add_child(cell)
		cells.append(cell)
	return {"node":box, "cells":cells}

func set_row(row: Dictionary, values: Array, color: Color) -> void:
	for i: int in range(values.size()):
		row.cells[i].text = values[i]
		row.cells[i].add_theme_color_override("font_color", color)

func layout_top() -> float:
	# Shared default: reserve the top 224 px for the diagnostic HUD, restart and error text.
	return 224.0

func layout_bottom() -> float:
	# Shared default: 24 px viewport margin plus the historic 190 px panel/help budget.
	return 214.0

func layout_min_rows() -> int:
	return 3

func layout_width() -> float:
	var viewport := get_viewport().get_visible_rect().size
	return minf(760, viewport.x - 48)

func layout_band() -> Rect2:
	var viewport := get_viewport().get_visible_rect().size
	return Rect2(Vector2(16, layout_top()), Vector2(viewport.x - 32, viewport.y - layout_bottom() - layout_top()))

func panel_chrome() -> float:
	# Fixed panel height with the visible rows removed. A specialist that must fit a
	# measured band sizes its page from this real chrome instead of the constant.
	var visible_rows := 0
	for row: Dictionary in rows:
		if row.node.visible: visible_rows += 1
	return maxf(0.0, panel.get_combined_minimum_size().y - float(visible_rows) * ROW_HEIGHT)

func resize() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var team_height := 0 if team_score_text.is_empty() else 28
	page_size = clampi(int((viewport.y - layout_top() - layout_bottom() - team_height) / ROW_HEIGHT), layout_min_rows(), MAX_VISIBLE)
	panel.size.x = layout_width()
	change_page(0)
	dirty = true
	position_panel()

func position_panel() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var band := layout_band()
	panel.position = Vector2(band.position.x + (band.size.x - panel.size.x) / 2, maxf(layout_top(), (viewport.y - panel.size.y) / 2))

func roster_label() -> String:
	var humans := 0
	var bots := 0
	var npcs := 0
	for entry: Dictionary in entries:
		if entry.npc: npcs += 1
		elif entry.bot: bots += 1
		else: humans += 1
	return roster_text(entries.size(), humans, bots, npcs)

func summary_text(prefix: String, roster: String) -> String:
	# Shared board reads as one compact line; specialists may split it.
	return "%s  ·  %s" % [prefix, roster]

func help_text(first: int) -> String:
	var help := "Release Tab to close"
	if finished:
		help = "Waiting for host to restart" if guest else "Enter: restart round"
		if is_instance_valid(session) and "phase" in session and int(session.get("phase")) == 20:
			help = "Waiting for authoritative round start…"
	if entries.is_empty(): help = "Waiting for player scores  ·  " + help
	if entries.size() > page_size:
		help += "  ·  PgUp / PgDn: %d–%d of %d" % [first + 1, mini(first + page_size, entries.size()), entries.size()]
	if actor_count > MAX_ACTORS: help += "  ·  Roster capped at 64"
	return help

func render() -> void:
	title.text = "ROUND COMPLETE" if finished else "SCOREBOARD"
	subtitle.text = map_mode
	var round_text := "Round %d  ·  " % round_number if round_number > 0 else ""
	summary.text = summary_text(round_text + clock_text, roster_label())
	if not team_score_text.is_empty(): summary.text += "\n" + team_score_text
	var first := page * page_size
	for i: int in range(rows.size()):
		var row: Dictionary = rows[i]
		row.node.visible = i < page_size and first + i < entries.size()
		if not row.node.visible: continue
		var entry: Dictionary = entries[first + i]
		set_row(row, [str(first + i + 1), entry.player_name + ("  · YOU" if entry.local else ""), entry.team, entry.frags, entry.deaths], ACCENT if entry.local else INK)
	footer.text = help_text(first)
	panel.size = Vector2(layout_width(), 0)
	position_panel()
	dirty = false
