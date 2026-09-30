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
	for node: Label in [objective, detail, subtitle, vitals, waypoint, notice, status, heading, body, crosshair]: text_label(node)
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(crosshair)
	objective.add_theme_font_size_override("font_size", 22)
	heading.add_theme_font_size_override("font_size", 27)
	add_child(top)
	top.mouse_filter = MOUSE_FILTER_IGNORE
	for node: Label in [objective, detail, notice, status]: top.add_child(node)
	add_child(bottom)
	bottom.mouse_filter = MOUSE_FILTER_IGNORE
	bottom.add_child(subtitle)
	bottom.add_child(vitals)
	add_child(waypoint)
	waypoint.custom_minimum_size = Vector2(150, 50)
	add_child(card)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.065, 0.97)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	card.add_child(scroll)
	scroll.add_child(stack)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for node: Control in [heading, body, primary, restart]: stack.add_child(node)
	primary.custom_minimum_size.y = 44
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
	var width := minf(600, viewport_size.x - 40)
	top.position = Vector2(20, 18)
	top.size.x = minf(width, viewport_size.x - 220)
	bottom.position = Vector2(20, viewport_size.y - 150)
	bottom.size.x = width
	card.position = Vector2((viewport_size.x - width) * 0.5, 100)
	card.size = Vector2(width, maxf(160, minf(480, viewport_size.y - 160)))
	body.custom_minimum_size.x = width - 72
	crosshair.position = viewport_size * 0.5 - Vector2(10, 14)
	crosshair.size = Vector2(20, 28)
	menu.position = Vector2(viewport_size.x - 200, 18)
	menu.size = Vector2(180, 38)

func show_brief(id: String) -> void:
	brief = true
	card.show()
	heading.text = "THE QUIET RELAY\n" + Catalog.TITLES[Catalog.MAP_IDS.find(id)]
	body.text = "A surviving archive is calling through the quarantine. Follow ECHO along the power corridor, break the security cordon, and restore the network.\n\nWASD move · Shift sprint · Space jump\nMouse aim · LMB fire · RMB aim · R reload\nE interact · Q power · F melee · G grenade\n1–9 / wheel weapons · Esc release cursor\n\nClick the world to take control after each checkpoint."
	primary.text = "Begin chapter"
	restart.hide()

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
	subtitle.text = "%s: %s" % [transmission.get("speaker", "ECHO"), transmission.get("text", "")]
	subtitle.visible = not str(transmission.get("text", "")).is_empty()
	if model.checkpoint_notice != checkpoint_text:
		checkpoint_text = model.checkpoint_notice
		checkpoint_time = 5
	notice.text = checkpoint_text
	var actor: Dictionary = session.presentation.local_actor
	var weapon := int(actor.get("weapon", 0))
	var ammo: Array = actor.get("ammo", [])
	vitals.text = "HP %s   ARMOR %s   %s · %s" % [actor.get("health", "—"), actor.get("armor", "—"), Weapons.display_name(weapon), Weapons.ammo_text(ammo[weapon]) if weapon >= 0 and weapon < ammo.size() else "—"]
	var modal: bool = phase in ["dead", "level-complete", "campaign-complete"] or not session.startup_error.is_empty()
	card.visible = modal
	restart.visible = phase in ["dead", "level-complete"]
	primary.visible = phase in ["dead", "level-complete"] and not session.action_pending
	if not session.startup_error.is_empty():
		heading.text = "Connection ended"
		body.text = session.startup_error
		primary.hide()
		restart.hide()
	elif phase == "dead":
		heading.text = "Signal interrupted"
		body.text = "Return to checkpoint %s. Your recovered objectives are held by the archive." % str(state.get("checkpoint", ""))
		primary.text = "Retry checkpoint · Enter"
	elif phase == "level-complete":
		heading.text = "Relay secured"
		body.text = "%s complete.\nRobots disabled: %s · Chapter time: %d:%02d\nThe next signal is waiting." % [state.get("title", "Chapter"), state.get("kills", 0), int(state.get("elapsed", 0)) / 60, int(state.get("elapsed", 0)) % 60]
		primary.text = "Continue · Enter"
	elif phase == "campaign-complete":
		heading.text = "THE QUIET RELAY\nNetwork restored"
		body.text = "The repair key reaches the Crown Array. Across the corridor, the quarantine falls silent. The archive was calling for rescue—and you answered.\n\nECHO: No more orders. Just a way home.\n\nCampaign complete · Total time %d:%02d" % [int(state.get("totalElapsed", 0)) / 60, int(state.get("totalElapsed", 0)) % 60]

func _process(delta: float) -> void:
	if not is_instance_valid(session): return
	checkpoint_time = maxf(0, checkpoint_time - delta)
	notice.visible = checkpoint_time > 0
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	crosshair.visible = captured and session.campaign.playing() and not Settings.overlay_open()
	menu.visible = not captured and not Settings.overlay_open()
	status.text = "Waiting for authority…" if session.action_pending else (session.snapshot_watch.message() if session.snapshot_watch.stale() and session.phase == 3 else ("Click world to control · Esc releases" if session.phase == 3 and not captured and session.campaign.playing() else ""))
	waypoint.hide()
	if not session.campaign.playing() or session.phase != 3: return
	var marker: Dictionary = session.campaign.state.get("marker", {})
	var target := Vector3(float(marker.get("x", 0)), float(marker.get("y", 0)) + 2, float(marker.get("z", 0)))
	var distance: float = session.camera.position.distance_to(target)
	var point: Vector2 = session.camera.unproject_position(target)
	var view := get_viewport_rect().size
	if session.camera.is_position_behind(target): point = Vector2(30 if point.x > view.x * 0.5 else view.x - 180, view.y * 0.5)
	waypoint.position = Vector2(clampf(point.x, 20, view.x - 180), clampf(point.y, 120, view.y - 190))
	waypoint.text = "◇ OBJECTIVE\n%d m" % roundi(distance)
	waypoint.show()
