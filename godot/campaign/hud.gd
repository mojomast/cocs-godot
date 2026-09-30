extends Control
const Settings = preload("res://ui/settings_access.gd")
const Catalog = preload("res://campaign/catalog.gd")
const Weapons = preload("res://ui/weapon_names.gd")
var session: Node
var objective := Label.new()
var detail := Label.new()
var subtitle := Label.new()
var vitals := Label.new()
var waypoint := Label.new()
var notice := Label.new()
var status := Label.new()
var crosshair := Label.new()
var card := PanelContainer.new()
var heading := Label.new()
var body := Label.new()
var primary := Button.new()
var restart := Button.new()
var settings := Button.new()
var leave := Button.new()
var top := VBoxContainer.new()
var bottom := VBoxContainer.new()
var menu := HBoxContainer.new()
var objective_scroll := ScrollContainer.new()
var comms := ScrollContainer.new()
var boss := Label.new()
var compact := false
var brief := false
var checkpoint_time := 0.0
var checkpoint_text := ""

func text_label(node: Label, font_size: int = 18) -> void:
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color("ecf5f4"))
	node.add_theme_color_override("font_shadow_color", Color.BLACK)
	node.add_theme_constant_override("shadow_offset_x", 2)
	node.add_theme_constant_override("shadow_offset_y", 2)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	for node: Label in [objective, detail, subtitle, vitals, waypoint, notice, status, heading, body, crosshair, boss]: text_label(node)
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(crosshair)
	objective.add_theme_font_size_override("font_size", 22)
	heading.add_theme_font_size_override("font_size", 27)
	add_child(objective_scroll)
	objective_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	objective_scroll.add_child(top)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.mouse_filter = MOUSE_FILTER_IGNORE
	for node: Label in [objective, detail, boss, notice, status]: top.add_child(node)
	add_child(bottom)
	bottom.mouse_filter = MOUSE_FILTER_IGNORE
	bottom.add_child(comms)
	comms.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	comms.add_child(subtitle)
	var comms_style := StyleBoxFlat.new()
	comms_style.bg_color = Color(0.025, 0.05, 0.06, 0.82)
	comms.add_theme_stylebox_override("panel", comms_style)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(vitals)
	add_child(waypoint)
	add_child(card)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.065, 0.97)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	card.add_child(stack)
	stack.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	scroll.add_child(body)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(primary)
	stack.add_child(restart)
	primary.custom_minimum_size.y = 36
	primary.pressed.connect(func() -> void:
		if brief: session.launch_campaign()
		else: session.request_restart())
	restart.text = "Restart chapter"
	restart.pressed.connect(func() -> void: session.request_campaign_action("restart"))
	add_child(menu)
	menu.add_child(settings)
	menu.add_child(leave)
	settings.text = "Settings"
	leave.text = "Leave"
	settings.pressed.connect(func() -> void:
		session.release_pointer()
		Settings.open_panel(true, settings))
	leave.pressed.connect(func() -> void: session.leave_campaign())
	card.hide()
	get_viewport().size_changed.connect(resize)
	resize()

func bind_session(value: Node) -> void:
	session = value

func resize() -> void:
	var viewport_size := get_viewport_rect().size
	compact = viewport_size.y < 540 or viewport_size.x < 800
	for node: Label in [detail, subtitle, vitals, notice, status, boss, body]: node.add_theme_font_size_override("font_size", 14 if compact else 18)
	objective.add_theme_font_size_override("font_size", 16 if compact else 22)
	heading.add_theme_font_size_override("font_size", 22 if compact else 27)
	waypoint.add_theme_font_size_override("font_size", 12 if compact else 16)
	for button: Button in [primary, restart, settings, leave]: button.add_theme_font_size_override("font_size", 14 if compact else 18)
	var width := minf(640, viewport_size.x - 32)
	card.position = Vector2((viewport_size.x - width) * 0.5, 64)
	card.size = Vector2(width, maxf(180, minf(520, viewport_size.y - 104)))
	body.custom_minimum_size.x = width - 52
	crosshair.position = viewport_size * 0.5 - Vector2(10, 14)
	crosshair.size = Vector2(20, 28)
	menu.size = Vector2.ZERO
	menu.position = Vector2(viewport_size.x - menu.get_combined_minimum_size().x - 16, 18)
	layout_live()

func layout_live() -> void:
	var view := get_viewport_rect().size
	var width := minf(640, view.x - 32)
	var top_width := minf(width, menu.position.x - 28) if menu.visible else width
	objective_scroll.position = Vector2(16, 18)
	objective_scroll.size = Vector2(top_width, minf(view.y * 0.30, maxf(30, top.get_combined_minimum_size().y)))
	bottom.size.x = width
	subtitle.custom_minimum_size.x = width - 16
	comms.visible = subtitle.visible
	comms.custom_minimum_size.y = minf(view.y * 0.22, subtitle.get_combined_minimum_size().y) if comms.visible else 0
	bottom.size.y = bottom.get_combined_minimum_size().y
	# Reserve the shared Settings shortcut footer; measured content grows upward.
	bottom.position = Vector2(16, view.y - 40 - bottom.size.y)

func show_brief(id: String) -> void:
	brief = true
	card.show()
	heading.text = "THE QUIET RELAY\n" + Catalog.TITLES[Catalog.MAP_IDS.find(id)]
	body.text = "A surviving archive is calling through the quarantine. Follow ECHO along the power corridor, break the security cordon, and restore the network.\n\nWASD move · Shift sprint · Space jump\nMouse aim · LMB fire · RMB aim · R reload\nE interact · Q power · F melee · G grenade\n1–9 / wheel weapons · Esc release cursor\n\nClick the world to take control after each checkpoint."
	primary.text = "Begin chapter"
	restart.hide()
	objective_scroll.hide()
	bottom.hide()

func hide_brief() -> void:
	brief = false
	card.hide()

func refresh() -> void:
	if not is_instance_valid(session) or brief: return
	var model = session.campaign
	var state: Dictionary = model.state
	var phase: String = str(state.get("phase", ""))
	objective.text = "%s · %s" % [state.get("title", "The Quiet Relay"), state.get("objective", "Connecting…")]
	detail.text = str(state.get("detail", ""))
	if state.get("enemiesRemaining", 0) > 0: detail.text += "  ·  Robots %d" % int(state.enemiesRemaining)
	if float(state.get("holdProgress", 0)) > 0: detail.text += "  ·  Link %d%%" % roundi(float(state.holdProgress) * 100)
	var transmission: Dictionary = state.get("transmission", {})
	var message := "%s: %s" % [transmission.get("speaker", "ECHO"), transmission.get("text", "")]
	if subtitle.text != message: comms.scroll_vertical = 0
	subtitle.text = message
	subtitle.visible = not str(transmission.get("text", "")).is_empty()
	if model.checkpoint_notice != checkpoint_text:
		checkpoint_text = model.checkpoint_notice
		checkpoint_time = 5
	notice.text = checkpoint_text
	var actor: Dictionary = session.presentation.local_actor
	var weapon := int(actor.get("weapon", 0))
	var ammo: Array = actor.get("ammo", [])
	vitals.text = "HP %s   ARMOR %s   %s · %s" % [str(int(actor.health)) if actor.has("health") else "—", str(int(actor.armor)) if actor.has("armor") else "—", Weapons.display_name(weapon), Weapons.ammo_text(ammo[weapon]) if weapon >= 0 and weapon < ammo.size() else "—"]
	var modal: bool = phase in ["dead", "level-complete", "campaign-complete"] or not session.startup_error.is_empty()
	card.visible = modal
	objective_scroll.visible = not modal
	bottom.visible = not modal
	restart.visible = phase in ["dead", "level-complete"]
	primary.visible = phase in ["dead", "level-complete"] and not session.action_pending
	if not session.startup_error.is_empty():
		heading.text = "Connection ended"
		body.text = session.startup_error
		primary.hide()
		restart.hide()
	elif phase == "dead":
		heading.text = "Signal interrupted"
		body.text = "Return to checkpoint %d. Your recovered objectives are held by the archive." % int(state.get("checkpoint", 0))
		primary.text = "Retry checkpoint · Enter"
	elif phase == "level-complete":
		heading.text = "Relay secured"
		body.text = "%s complete.\nRobots disabled: %d · Chapter time: %d:%02d\nThe next signal is waiting." % [state.get("title", "Chapter"), int(state.get("kills", 0)), int(state.get("elapsed", 0)) / 60, int(state.get("elapsed", 0)) % 60]
		primary.text = "Continue · Enter"
	elif phase == "campaign-complete":
		heading.text = "THE QUIET RELAY\nNetwork restored"
		body.text = "The repair key reaches the Crown Array. Across the corridor, the quarantine falls silent. The archive was calling for rescue—and you answered.\n\nECHO: No more orders. Just a way home.\n\nCampaign complete · Total time %d:%02d" % [int(state.get("totalElapsed", 0)) / 60, int(state.get("totalElapsed", 0)) % 60]

func _process(delta: float) -> void:
	if not is_instance_valid(session): return
	checkpoint_time = maxf(0, checkpoint_time - delta)
	notice.visible = checkpoint_time > 0
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	crosshair.visible = captured and session.campaign.playing() and not card.visible and not Settings.overlay_open()
	menu.visible = not captured and not Settings.overlay_open()
	status.text = "Waiting for authority…" if session.action_pending else (session.snapshot_watch.message() if session.snapshot_watch.stale() and session.phase == 3 else ("Click to control · Esc: cursor / scroll comms" if session.phase == 3 and not captured and session.campaign.playing() else ""))
	if captured and comms.visible and subtitle.get_combined_minimum_size().y > comms.size.y + 1: status.text = "Esc: scroll full comms"
	layout_live()
	waypoint.hide()
	if not session.campaign.playing() or session.phase != 3 or card.visible or Settings.overlay_open(): return
	var marker: Dictionary = session.campaign.state.get("marker", {})
	var target := Vector3(float(marker.get("x", 0)), float(marker.get("y", 0)) + 2, float(marker.get("z", 0)))
	var distance: float = session.camera.position.distance_to(target)
	var point: Vector2 = session.camera.unproject_position(target)
	var view := get_viewport_rect().size
	waypoint.text = "◇ OBJECTIVE · %d m" % roundi(distance)
	waypoint.size = Vector2(140 if compact else 180, 24)
	waypoint.position = Vector2(clampf(point.x, 16, view.x - waypoint.size.x - 16), clampf(point.y, 18, view.y - 64))
	var blocked: bool = session.camera.is_position_behind(target)
	for reserved: Control in [objective_scroll, bottom, crosshair, menu]:
		if reserved.visible and waypoint.get_rect().intersects(reserved.get_rect().grow(8)): blocked = true
	if blocked:
		waypoint.position = Vector2(view.x - waypoint.size.x - 16, (objective_scroll.position.y + objective_scroll.size.y + bottom.position.y - waypoint.size.y) * 0.5)
		waypoint.text = "→ ◇ %d m" % roundi(distance)
	waypoint.show()

func observe_boss(state: Dictionary) -> void:
	boss.text = ""
	var singleplayer: Variant = state.get("singleplayer")
	var value: Variant = singleplayer.get("boss") if singleplayer is Dictionary else null
	if value is Dictionary and value.get("alive", false):
		boss.text = "WARDEN · %d%% · Phase %d" % [roundi(100 * float(value.get("hp", 0)) / maxf(1, float(value.get("maxHp", 1)))), int(value.get("phase", 1))]
	boss.visible = not boss.text.is_empty()
