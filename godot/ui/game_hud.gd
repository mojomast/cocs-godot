extends CanvasLayer

# Passive session child. Bind deferred so the parent processes authority first.
# Legacy label text/API survives; --debug-hud leaves the original display intact.
const WeaponNames = preload("res://ui/weapon_names.gd")
const INK := Color("e5edf6")
const MUTED := Color("a3b7c9")
const ACCENT := Color("62deca")
const ARMOR := Color("86bffa")
const WARNING := Color("ffd18a")

var session: Node
var client: Node
var debug_hud := false
var root := Control.new()
var top: PanelContainer
var vitals: PanelContainer
var weapon_panel: PanelContainer
var status_panel: PanelContainer
var map_label: Label
var score_label: Label
var health_label: Label
var armor_label: Label
var health_bar: ProgressBar
var armor_bar: ProgressBar
var weapon_label: Label
var ammo_label: Label
var weapon_detail: Label
var status_title: Label
var status_detail: Label
var controls: Label
var actor_present := false
var poll_elapsed := 0.0

func _ready() -> void:
	layer = 3
	debug_hud = "--debug-hud" in OS.get_cmdline_user_args()
	build_ui()
	root.hide()
	get_viewport().size_changed.connect(resize)
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
	client.started.connect(on_started)
	client.snapshot.connect(on_snapshot)
	client.results.connect(on_results)
	client.connection_error.connect(on_error)
	# Advertise the parallel switching lane only when its session hook is installed.
	if session.has_method("weapon_controls_active"):
		controls.text += " · 1–9 / 0 / wheel: weapons"
	clear_actor()
	refresh_status()

func on_started(_frame: Dictionary) -> void:
	clear_actor()
	refresh_status()

func on_snapshot(frame: Dictionary) -> void:
	if not is_instance_valid(session) or int(session.get("phase")) != 3: return
	if frame.get("state") is Dictionary:
		apply_state(frame.state, int(client.get("actor_id")))
	refresh_status()

func on_results(frame: Dictionary) -> void:
	if not is_instance_valid(session) or int(session.get("phase")) != 4: return
	if frame.get("state") is Dictionary:
		apply_state(frame.state, int(client.get("actor_id")))
	refresh_status()

func on_error(_message: String) -> void:
	clear_actor()
	refresh_status()

static func plain(value: Variant, fallback: String = "—", limit: int = 80) -> String:
	if not value is String: return fallback
	var text: String = value.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().left(limit)
	return text if not text.is_empty() else fallback

static func numeric(value: Variant, fallback: float = 0.0) -> float:
	if (value is int or value is float) and is_finite(float(value)):
		return clampf(float(value), -1000000, 1000000)
	return fallback

static func stat(value: Variant) -> String:
	return str(int(numeric(value))) if value is int or value is float else "—"

func clear_actor() -> void:
	actor_present = false
	health_label.text = "HEALTH  —"
	armor_label.text = "ARMOR  —"
	health_bar.value = 0
	armor_bar.value = 0
	weapon_label.text = "Awaiting loadout"
	ammo_label.text = "AMMO  —"
	weapon_detail.text = "Authoritative equipment"
	score_label.text = "FRAGS  —     DEATHS  —"

func apply_state(state: Dictionary, local_id: int) -> void:
	# Retain only displayed scalars. Never cache the full simulation snapshot.
	var actor: Dictionary = {}
	var actors: Array = state.get("actors", []) if state.get("actors", []) is Array else []
	for item: Variant in actors:
		if item is Dictionary and local_id >= 0 and numeric(item.get("id"), -1) == local_id:
			actor = item
			break
	var config: Dictionary = state.get("config", {}) if state.get("config", {}) is Dictionary else {}
	var mode := plain(state.get("modeName"), plain(config.get("mode"), "Mode unknown"))
	map_label.text = "%s  /  %s" % [plain(state.get("mapName"), plain(state.get("mapId"), "Map unknown")), mode]
	if actor.is_empty():
		clear_actor()
		return
	actor_present = true
	var health := maxf(0, numeric(actor.get("health")))
	var armor := maxf(0, numeric(actor.get("armor")))
	health_label.text = "HEALTH  %s" % stat(actor.get("health"))
	armor_label.text = "ARMOR  %s" % stat(actor.get("armor"))
	health_bar.max_value = maxf(1, numeric(actor.get("maxHealth"), 100))
	health_bar.value = health
	# Armor has no wire maxArmor. Use a 100-point gauge; numbers retain overflow.
	armor_bar.max_value = 100
	armor_bar.value = armor
	health_label.add_theme_color_override("font_color", WARNING if health <= health_bar.max_value * 0.25 else INK)
	var weapon := int(numeric(actor.get("weapon"), -1))
	weapon_label.text = WeaponNames.display_name(weapon)
	var ammo: Array = actor.get("ammo", []) if actor.get("ammo", []) is Array else []
	var rounds := WeaponNames.ammo_text(ammo[weapon]) if weapon >= 0 and weapon < ammo.size() else "—"
	ammo_label.text = "AMMO  %s" % rounds
	weapon_detail.text = "Unlimited ammunition" if rounds == "∞" else "R: reload"
	if bool(actor.get("reloading", false)):
		weapon_detail.text = "RELOADING  %.1fs" % maxf(0, numeric(actor.get("reloadTimer")))
	score_label.text = "FRAGS  %s     DEATHS  %s" % [stat(actor.get("frags")), stat(actor.get("deaths"))]

func _process(delta: float) -> void:
	# Minimal local state poll also catches errors/restart failures without signals.
	poll_elapsed += delta
	if poll_elapsed < 0.05: return
	poll_elapsed = 0
	refresh_status()

func refresh_status() -> void:
	if not is_instance_valid(session): return
	var phase := int(session.get("phase"))
	var lobby_open: bool = "lobby_enabled" in session and session.lobby_enabled and phase not in [3, 4, 20]
	root.visible = not debug_hud and phase != -2 and not lobby_open
	if debug_hud or phase == -2 or lobby_open: return
	var legacy: Label = session.get("label")
	var message := ""
	var heading := ""
	var warning := false
	match phase:
		-1:
			heading = "CONNECTION ERROR"
			message = legacy.text
			warning = true
		0, 1, 2, 10:
			heading = "CONNECTING"
			message = legacy.text
		11:
			heading = "WAITING FOR HOST"
			message = legacy.text
		20:
			heading = "STARTING ROUND"
			message = "Waiting for authoritative round start…"
		4:
			heading = "ROUND COMPLETE"
			message = "Enter: restart round" if str(session.get("join_room_id")).is_empty() else "Waiting for host to restart"
			if "Restart could not be queued" in legacy.text:
				message = "Restart could not be queued. Enter: retry"
				warning = true
		3:
			var watch: RefCounted = session.get("snapshot_watch")
			var presentation: Node = session.get("presentation")
			var lifecycle: RefCounted = presentation.get("lifecycle")
			if watch.stale():
				heading = "CONNECTION STALLED" if watch.received else "JOINING ROUND"
				message = watch.message()
				warning = watch.received
			elif not bool(session.get("received_pose")) or not actor_present:
				heading = "WAITING FOR PLAYER"
				message = "Local actor absent — controls neutral"
			elif lifecycle.status == "dead":
				heading = "ELIMINATED"
				message = "Respawn in %.1fs  ·  Waiting for server" % lifecycle.respawn_remaining
			elif not bool(session.get("application_focused")) or not get_window().has_focus():
				heading = "CONTROLS PAUSED"
				message = "Return to this window, then click to play"
			elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				heading = "CLICK TO PLAY"
				message = "Esc releases the mouse  ·  The match continues while controls are paused"
		_:
			heading = "SESSION STATUS"
			message = legacy.text
	# Before connection, catalog/import failures can return before session.on_error.
	if phase == 0 and not str(session.get("catalog").error).is_empty():
		heading = "CONTENT ERROR"
		message = legacy.text
		warning = true
	status_title.text = heading
	status_title.add_theme_color_override("font_color", WARNING if warning else ACCENT)
	if status_detail.text != message:
		status_detail.text = message
		status_panel.size.y = 0
	status_panel.visible = not heading.is_empty()
	vitals.visible = phase == 3 and actor_present
	weapon_panel.visible = vitals.visible
	controls.visible = phase == 3
	if phase not in [3, 4]:
		map_label.text = "%s  /  %s" % [plain(session.get("current_id"), "Native session"), plain(session.get("selected_mode"), "")]
		score_label.text = "NATIVE PLAY"
	# Replacement is ready before hiding diagnostic widgets. Never alter their text.
	legacy.hide()
	var selector: Control = session.get("selector")
	selector.hide()
	var combat_label: Label = session.get("combat_label")
	combat_label.hide()

func passive(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.focus_mode = Control.FOCUS_NONE

func label(font_size: int, color: Color = INK) -> Label:
	var item := Label.new()
	passive(item)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return item

func panel() -> PanelContainer:
	var item := PanelContainer.new()
	passive(item)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.10, 0.94)
	style.border_color = Color("33596a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	item.add_theme_stylebox_override("panel", style)
	root.add_child(item)
	return item

func stack(parent: Control) -> VBoxContainer:
	var item := VBoxContainer.new()
	passive(item)
	item.add_theme_constant_override("separation", 4)
	parent.add_child(item)
	return item

func gauge(color: Color) -> ProgressBar:
	var item := ProgressBar.new()
	passive(item)
	item.show_percentage = false
	item.custom_minimum_size.y = 6
	for slot: String in ["background", "fill"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color if slot == "fill" else Color("203342")
		style.set_corner_radius_all(3)
		item.add_theme_stylebox_override(slot, style)
	return item

func build_ui() -> void:
	passive(root)
	add_child(root)
	top = panel()
	var row := HBoxContainer.new()
	passive(row)
	row.add_theme_constant_override("separation", 16)
	top.add_child(row)
	map_label = label(16, ACCENT)
	map_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_label.text = "Native session"
	score_label = label(14)
	score_label.custom_minimum_size.x = 220
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(map_label)
	row.add_child(score_label)
	vitals = panel()
	var life := stack(vitals)
	health_label = label(22)
	health_bar = gauge(ACCENT)
	armor_label = label(17, ARMOR)
	armor_bar = gauge(ARMOR)
	for item: Control in [health_label, health_bar, armor_label, armor_bar]: life.add_child(item)
	weapon_panel = panel()
	var equipment := stack(weapon_panel)
	weapon_label = label(20)
	ammo_label = label(23, ACCENT)
	weapon_detail = label(13, MUTED)
	for item: Control in [weapon_label, ammo_label, weapon_detail]: equipment.add_child(item)
	status_panel = panel()
	var status := stack(status_panel)
	status_title = label(17, ACCENT)
	status_detail = label(15)
	status_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_detail.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	status.add_child(status_title)
	status.add_child(status_detail)
	controls = label(13, MUTED)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_color_override("font_shadow_color", Color.BLACK)
	controls.add_theme_constant_override("shadow_offset_x", 1)
	controls.add_theme_constant_override("shadow_offset_y", 1)
	controls.text = "WASD move · Space jump · Shift sprint · Ctrl/C crouch · E interact · X mobility · Q power\nLMB fire · RMB ADS · Z/MMB alt · R reload · F melee · G grenade · Esc release · Tab scores"
	root.add_child(controls)
	clear_actor()

func resize() -> void:
	var viewport := get_viewport().get_visible_rect().size
	root.size = viewport
	top.position = Vector2(20, 16)
	top.size = Vector2(viewport.x - 40, 44)
	status_panel.position = Vector2((viewport.x - minf(620, viewport.x - 80)) / 2, 78)
	status_panel.size = Vector2(minf(620, viewport.x - 80), 0)
	vitals.position = Vector2(20, viewport.y - 166)
	vitals.size = Vector2(238, 108)
	weapon_panel.position = Vector2(viewport.x - 304, viewport.y - 166)
	weapon_panel.size = Vector2(284, 108)
	controls.position = Vector2(20, viewport.y - 48)
	controls.size = Vector2(viewport.x - 40, 40)
