extends Control
## Setup is wholly in-window. Gameplay vitals, death/respawn and scores are shared
## overlays; this adds native map orientation and public round leaders/time only.
signal start_requested(map_id: String, player_name: String, bots: int, seconds: int)
const CatalogData = preload("res://native_arenas/catalog.gd")
const ACCENT := Color("75e1d2")
const INK := Color("e8f0fb")
const MUTED := Color("a6b7cb")
var session: Node
var selected := "prism-foundry"
var menu := PanelContainer.new()
var backdrop := ColorRect.new()
var scroll := ScrollContainer.new()
var cards: Dictionary = {}
var orientation: Label
var player_name := LineEdit.new()
var bots := HSlider.new()
var duration := HSlider.new()
var roster: Label
var duration_label: Label
var launch := Button.new()
var round_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	build_ui()
	get_viewport().size_changed.connect(resize)
	resize()

func text(value: String, size_px: int, color: Color = INK) -> Label:
	var item := Label.new()
	item.text = value
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_size_override("font_size", size_px)
	item.add_theme_color_override("font_color", color)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return item

func box_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func build_ui() -> void:
	backdrop.color = Color("080f1c")
	add_child(backdrop)
	add_child(menu)
	menu.add_theme_stylebox_override("panel", box_style(Color("101e30"), Color("355469")))
	menu.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 14)
	scroll.add_child(stack)
	stack.add_child(text("NATIVE ARENAS  /  DEATHMATCH", 14, ACCENT))
	stack.add_child(text("Your battleground", 32))
	stack.add_child(text("Source-authoritative combat, bots and respawns. Your launch selects the arena; relaunch to choose another.", 16, MUTED))
	var maps := GridContainer.new()
	maps.columns = 3
	maps.add_theme_constant_override("h_separation", 12)
	maps.add_theme_constant_override("v_separation", 12)
	stack.add_child(maps)
	var number := 1
	for id: String in CatalogData.DM_MAP_IDS:
		var card := Button.new()
		card.text = "0%d\n%s\nDEATHMATCH" % [number, CatalogData.TITLES[id]]
		card.toggle_mode = true
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 118
		card.add_theme_font_size_override("font_size", 18)
		card.add_theme_stylebox_override("normal", box_style(Color("152a40"), Color("355469")))
		card.add_theme_stylebox_override("hover", box_style(Color("203d50"), ACCENT))
		card.add_theme_stylebox_override("pressed", box_style(Color("1e484e"), ACCENT))
		card.pressed.connect(func() -> void: select_map(id))
		maps.add_child(card)
		cards[id] = card
		number += 1
	orientation = text("", 15, ACCENT)
	orientation.custom_minimum_size.y = 46
	stack.add_child(orientation)
	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 24)
	stack.add_child(settings)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_child(identity)
	identity.add_child(text("YOUR CALLSIGN", 13, MUTED))
	player_name.text = "Operator"
	player_name.max_length = 32
	player_name.context_menu_enabled = false
	player_name.custom_minimum_size.y = 40
	identity.add_child(player_name)
	var match_settings := VBoxContainer.new()
	match_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_child(match_settings)
	roster = text("", 14)
	match_settings.add_child(roster)
	bots.min_value = 1
	bots.max_value = 24
	bots.step = 1
	bots.value = 2
	bots.custom_minimum_size.y = 22
	match_settings.add_child(bots)
	duration_label = text("", 14)
	match_settings.add_child(duration_label)
	duration.min_value = 60
	duration.max_value = 300
	duration.step = 1
	duration.value = 180
	duration.custom_minimum_size.y = 22
	match_settings.add_child(duration)
	bots.value_changed.connect(func(_value: float) -> void: update_settings())
	duration.value_changed.connect(func(_value: float) -> void: update_settings())
	player_name.text_changed.connect(func(value: String) -> void: launch.disabled = value.strip_edges().is_empty())
	stack.add_child(text("WASD move · Space jump · Shift sprint · Ctrl/C crouch · X mobility · E use\nLMB fire · RMB aim · Z/MMB alt · R reload · Q power · F melee · G grenade\n1–9/0 or wheel: weapons · Tab: scores · Esc: release mouse · Enter: restart after results", 14, MUTED))
	launch.text = "START DEATHMATCH  →"
	launch.custom_minimum_size.y = 48
	launch.add_theme_font_size_override("font_size", 18)
	launch.add_theme_stylebox_override("normal", box_style(Color("1c5959"), ACCENT))
	launch.pressed.connect(func() -> void: start_requested.emit(selected, player_name.text, int(bots.value), int(duration.value)))
	stack.add_child(launch)
	stack.add_child(text("Click to capture the mouse after joining. After elimination, release held controls and click again to resume.", 13, MUTED))
	round_label = text("", 14, ACCENT)
	round_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	round_label.add_theme_constant_override("shadow_offset_x", 2)
	round_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(round_label)
	round_label.hide()
	select_map(selected)
	update_settings()

func configure(target: Node) -> void:
	if session == null:
		session = target
		session.client.snapshot.connect(func(frame: Dictionary) -> void:
			if session.phase == 3: apply_state(frame.state))
		session.client.results.connect(func(frame: Dictionary) -> void:
			if session.phase == 4: apply_state(frame.state))
		session.client.started.connect(func(_frame: Dictionary) -> void: round_label.text = "")
	select_map(target.selected_native_map)
	# The owned authority is pinned to the launch route's map. Other cards show
	# the available lineup; selecting another arena requires a fresh launcher.
	for id: String in cards:
		cards[id].disabled = id != target.selected_native_map
	bots.value = target.bot_count
	duration.value = target.round_seconds
	update_settings()

func select_map(id: String) -> void:
	selected = id
	for key: String in cards: cards[key].set_pressed_no_signal(key == id)
	orientation.text = CatalogData.ORIENTATION[id]

func update_settings() -> void:
	roster.text = "ROSTER  ·  You + %d bots  ·  Free-for-all" % int(bots.value)
	duration_label.text = "ROUND  ·  %d:%02d  ·  Most frags wins" % [int(duration.value) / 60, int(duration.value) % 60]

func apply_state(state: Dictionary) -> void:
	var config: Dictionary = state.get("config", {})
	var remaining := maxi(0, ceili(float(config.get("timeLimit", 180)) - float(state.get("time", 0))))
	var leaders: Array = state.get("leaders", [])
	var names: PackedStringArray = []
	for value: Variant in leaders:
		if value is String: names.append(value.replace("\n", " ").replace("\r", " ").left(32))
	if state.get("over", false):
		round_label.text = ("WINNER  ·  " if names.size() == 1 else "TIED LEAD  ·  ") + ", ".join(names)
		if names.is_empty(): round_label.text = "ROUND COMPLETE  ·  Final scores below"
	else:
		round_label.text = "%d:%02d remaining  ·  %d combatants" % [remaining / 60, remaining % 60, state.get("actors", []).size()]

func _process(_delta: float) -> void:
	if not is_instance_valid(session): return
	# Shared status wraps after the initial layout pass. Refit its height after
	# wrapping so a first-snapshot message cannot leave a full-height dark panel.
	var shared: Node = session.get_node_or_null("GameHUD")
	if shared != null: shared.status_panel.size.y = 0
	var setup: bool = session.phase == -2
	visible = setup or session.phase in [3, 4]
	menu.visible = setup
	backdrop.visible = setup
	round_label.visible = not setup and not session.snapshot_watch.stale() or session.phase == 4

func resize() -> void:
	var viewport := get_viewport().get_visible_rect().size
	size = viewport
	backdrop.size = viewport
	menu.position = Vector2(maxf(16, (viewport.x - 960) / 2), 20)
	menu.size = Vector2(minf(960, viewport.x - 32), maxf(100, viewport.y - 40))
	round_label.position = Vector2(24, 182)
	round_label.size = Vector2(viewport.x - 48, 34)
